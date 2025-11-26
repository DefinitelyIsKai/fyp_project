import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/application.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'wallet_service.dart';

class ApplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('applications');

  // Create an application
  Future<String> createApplication({
    required String postId,
    required String recruiterId,
  }) async {
    final jobseekerId = _authService.currentUserId;
    // Ensure the post is not completed
    final postSnap = await _firestore.collection('posts').doc(postId).get();
    final postData = postSnap.data();
    final String status = postData?['status'] as String? ?? 'active';
    if (status.toLowerCase() == 'completed') {
      throw StateError('POST_COMPLETED');
    }

    // Check if application already exists
    final existing = await _col
        .where('postId', isEqualTo: postId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw StateError('Application already exists');
    }

    final postTitle = postData?['title'] as String? ?? 'your post';

    final application = Application(
      id: '',
      postId: postId,
      jobseekerId: jobseekerId,
      recruiterId: recruiterId,
      status: ApplicationStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _col.add(application.toFirestore());

    // Update post applicants count
    await _firestore.collection('posts').doc(postId).update({
      'applicants': FieldValue.increment(1),
    });

    try {
      final jobseekerDoc = await _authService.getUserDoc();
      final jobseekerName =
          jobseekerDoc.data()?['fullName'] as String? ?? 'A candidate';
      await _notificationService.notifyRecruiterNewApplication(
        recruiterId: recruiterId,
        jobseekerName: jobseekerName,
        postTitle: postTitle,
      );
    } catch (_) {
      // Best-effort notification, ignore errors
    }

    return docRef.id;
  }

  // Get applications for a post (recruiter view)
  Stream<List<Application>> streamPostApplications(String postId) {
    // Scope by both post and recruiter to align with security rules and
    // avoid permission errors when non-owners attempt to query this stream.
    final recruiterId = _authService.currentUserId;
    // Trigger auto-reject check when stream is first accessed
    checkAndAutoRejectApplications();
    // Initialize approvedApplicants field if missing (for old posts)
    _initializeApprovedApplicantsIfMissing(postId, recruiterId);
    return _col
        .where('postId', isEqualTo: postId)
        .where('recruiterId', isEqualTo: recruiterId)
        .snapshots()
        .map((snapshot) {
          final applications = snapshot.docs
              .map((doc) => Application.fromFirestore(doc))
              .toList();
          // Sort by createdAt descending (newest first)
          applications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return applications;
        })
        .handleError((error) {
          // Ignore permission errors during logout - return empty list instead
          debugPrint('Error in streamPostApplications (likely during logout): $error');
          return <Application>[];
        });
  }

  // Helper method to initialize approvedApplicants field if missing
  Future<void> _initializeApprovedApplicantsIfMissing(
    String postId,
    String recruiterId,
  ) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      final postData = postDoc.data();
      // Check if field exists
      if (postData?.containsKey('approvedApplicants') == true) {
        return; // Field already exists
      }

      // Calculate and initialize the field
      final approvedApplications = await _col
          .where('postId', isEqualTo: postId)
          .where('recruiterId', isEqualTo: recruiterId)
          .where('status', isEqualTo: 'approved')
          .get();

      final approvedCount = approvedApplications.docs.length;

      // Initialize the field
      await _firestore.collection('posts').doc(postId).update({
        'approvedApplicants': approvedCount,
      });
    } catch (e) {
      // Silently fail - this is a background initialization
      debugPrint('Error initializing approvedApplicants: $e');
    }
  }

  // Get applications for current user (jobseeker view)
  Stream<List<Application>> streamMyApplications() {
    final jobseekerId = _authService.currentUserId;
    // Trigger auto-reject check when stream is first accessed
    checkAndAutoRejectApplications();
    // Process held credits for applications (deduct if approved, release if rejected)
    _processHeldCreditsForApplications(jobseekerId);
    return _col.where('jobseekerId', isEqualTo: jobseekerId).snapshots().map((
      snapshot,
    ) {
      final applications = snapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();
      // Sort by createdAt descending (newest first)
      applications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return applications;
    }).handleError((error) {
      // Ignore permission errors during logout - return empty list instead
      debugPrint('Error in streamMyApplications (likely during logout): $error');
      return <Application>[];
    });
  }

  // Process held credits based on application status
  // Deducts held credits for approved applications, releases for rejected ones
  // Only processes credits once per application (idempotent)
  Future<void> _processHeldCreditsForApplications(String jobseekerId) async {
    try {
      final walletService = WalletService();
      final applications = await _col
          .where('jobseekerId', isEqualTo: jobseekerId)
          .where('status', whereIn: ['approved', 'rejected'])
          .get();

      for (final appDoc in applications.docs) {
        final appData = appDoc.data();
        final status = appData['status'] as String? ?? '';
        final postId = appData['postId'] as String? ?? '';
        final creditsProcessed = appData['creditsProcessed'] as bool? ?? false;

        if (postId.isEmpty) continue;

        // Skip if credits were already processed
        if (creditsProcessed) continue;

        try {
          bool processed = false;
          if (status == 'approved') {
            // Deduct held credits (actual charge)
            // ✅ 修复：传入 jobseekerId 作为 userId 参数
            processed = await walletService.deductHeldCredits(
              postId: postId,
              userId: jobseekerId, // 这里直接使用方法参数中已有的 jobseekerId
              feeCredits: 100,
            );
          } else if (status == 'rejected') {
            // Release held credits (no charge)
            processed = await walletService.releaseHeldCredits(
              postId: postId,
              feeCredits: 100,
            );
            // If no credits were held (already processed), still mark as processed
            // to avoid retrying
            if (!processed) {
              processed =
                  true; // Mark as processed even if no credits to release
            }
          }

          // Mark as processed if operation succeeded
          if (processed) {
            await appDoc.reference.set({
              'creditsProcessed': true,
            }, SetOptions(merge: true));
          }
        } catch (e) {
          // Log but don't fail - might already be processed
          debugPrint(
            'Error processing held credits for application ${appDoc.id}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('Error processing held credits: $e');
      // Don't throw - this is a background process
    }
  }

  // Get all applications for recruiter's posts
  Stream<List<Application>> streamRecruiterApplications() {
    final recruiterId = _authService.currentUserId;
    // Trigger auto-reject check when stream is first accessed
    checkAndAutoRejectApplications();
    return _col.where('recruiterId', isEqualTo: recruiterId).snapshots().map((
      snapshot,
    ) {
      final applications = snapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();
      // Sort by createdAt descending (newest first)
      applications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return applications;
    }).handleError((error) {
      // Ignore permission errors during logout - return empty list instead
      debugPrint('Error in streamRecruiterApplications (likely during logout): $error');
      return <Application>[];
    });
  }

  // Check if user has applied to a post
  Future<bool> hasApplied(String postId) async {
    final jobseekerId = _authService.currentUserId;
    final result = await _col
        .where('postId', isEqualTo: postId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  // Get application for a post by current user
  Future<Application?> getApplicationForPost(String postId) async {
    final jobseekerId = _authService.currentUserId;
    final result = await _col
        .where('postId', isEqualTo: postId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .limit(1)
        .get();

    if (result.docs.isEmpty) return null;
    return Application.fromFirestore(result.docs.first);
  }

  // Stream application for a post by current user (for real-time updates)
  Stream<Application?> streamApplicationForPost(String postId) {
    final jobseekerId = _authService.currentUserId;
    return _col
        .where('postId', isEqualTo: postId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return Application.fromFirestore(snapshot.docs.first);
        })
        .handleError((error) {
          // Ignore permission errors during logout - return null instead
          debugPrint('Error in streamApplicationForPost (likely during logout): $error');
          return null;
        });
  }

  // Approve an application
  Future<void> approveApplication(String applicationId) async {
    final docRef = _col.doc(applicationId);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Application not found');
    }

    final postId = data['postId'] as String? ?? '';
    if (postId.isEmpty) {
      throw StateError('Post ID not found in application');
    }

    // Extract required fields early for use in quota check and update
    final jobseekerId = data['jobseekerId'] as String?;
    final recruiterId = data['recruiterId'] as String?;
    final createdAt = data['createdAt'];

    if (jobseekerId == null || jobseekerId.isEmpty) {
      throw StateError('Jobseeker ID not found in application');
    }
    if (recruiterId == null || recruiterId.isEmpty) {
      throw StateError('Recruiter ID not found in application');
    }

    // Helper to safely parse int from Firestore (handles int, double, num)
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Check if applicant quota has been reached (based on approved applications)
    final postSnap = await _firestore.collection('posts').doc(postId).get();
    final postData = postSnap.data();
    final applicantQuota = _parseInt(postData?['applicantQuota']);

    // Check current status to see if already approved
    final currentStatus = data['status'] as String? ?? 'pending';
    final isAlreadyApproved = currentStatus == 'approved';

    // Get current approved count from post document
    // If field is missing, initialize it first
    int currentApprovedCount = _parseInt(postData?['approvedApplicants']) ?? 0;

    // If field is missing (old post), calculate and initialize it
    if (postData?.containsKey('approvedApplicants') != true) {
      try {
        final approvedApplications = await _col
            .where('postId', isEqualTo: postId)
            .where('recruiterId', isEqualTo: recruiterId)
            .where('status', isEqualTo: 'approved')
            .get();
        currentApprovedCount = approvedApplications.docs.length;

        // Initialize the field
        await _firestore.collection('posts').doc(postId).update({
          'approvedApplicants': currentApprovedCount,
        });
      } catch (e) {
        debugPrint('Error initializing approvedApplicants: $e');
        // Continue with 0 as fallback
      }
    }

    if (applicantQuota != null) {
      // If not already approved and quota is reached, block approval
      if (!isAlreadyApproved && currentApprovedCount >= applicantQuota) {
        throw StateError('QUOTA_EXCEEDED');
      }
    }

    // Use set with merge to ensure all fields are present for security rule validation
    // This ensures request.resource.data contains all required fields
    await docRef.set({
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
      'jobseekerId': jobseekerId,
      'recruiterId': recruiterId,
      'postId': postId,
      'createdAt': createdAt, // Preserve original createdAt
    }, SetOptions(merge: true));

    // Update approved count in post document (increment only if not already approved)
    if (!isAlreadyApproved) {
      await _firestore.collection('posts').doc(postId).update({
        'approvedApplicants': FieldValue.increment(1),
      });
    }

    final postTitle = await _getPostTitle(postId);

    if (jobseekerId.isNotEmpty) {
      await _notificationService.notifyApplicationDecision(
        jobseekerId: jobseekerId,
        postTitle: postTitle,
        approved: true,
      );
    }

    // Deduct held credits immediately when application is approved
    if (jobseekerId.isNotEmpty && currentStatus == 'pending') {
      try {
        final success = await WalletService.deductHeldCreditsForUser(
          firestore: _firestore,
          userId: jobseekerId,
          postId: postId,
          feeCredits: 100,
        );
        // Mark as processed immediately
        await docRef.set({'creditsProcessed': true}, SetOptions(merge: true));
        
        // Send wallet notification if deduction was successful
        if (success) {
          try {
            await _notificationService.notifyWalletDebit(
              userId: jobseekerId,
              amount: 100,
              reason: 'Application fee',
              metadata: {'postId': postId, 'type': 'application_fee'},
            );
          } catch (e) {
            // Log but don't fail - notification is not critical
            debugPrint('Error sending wallet debit notification: $e');
          }
        }
      } catch (e) {
        // Log error but don't fail approval - credits can be processed later
        debugPrint(
          'Error deducting held credits for jobseeker $jobseekerId: $e',
        );
      }
    }
  }

  // Reject an application
  Future<void> rejectApplication(String applicationId) async {
    final docRef = _col.doc(applicationId);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Application not found');
    }

    // Include all required fields in update to satisfy Firestore security rules
    // Ensure all fields are non-null strings to match security rule requirements
    final jobseekerId = data['jobseekerId'] as String?;
    final recruiterId = data['recruiterId'] as String?;
    final postId = data['postId'] as String? ?? '';
    final createdAt = data['createdAt'];

    if (jobseekerId == null || jobseekerId.isEmpty) {
      throw StateError('Jobseeker ID not found in application');
    }
    if (recruiterId == null || recruiterId.isEmpty) {
      throw StateError('Recruiter ID not found in application');
    }
    if (postId.isEmpty) {
      throw StateError('Post ID not found in application');
    }

    // Check if application was previously approved (to decrement count)
    final currentStatus = data['status'] as String? ?? 'pending';
    final wasApproved = currentStatus == 'approved';

    // Use set with merge to ensure all fields are present for security rule validation
    // This ensures request.resource.data contains all required fields
    await docRef.set({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
      'jobseekerId': jobseekerId,
      'recruiterId': recruiterId,
      'postId': postId,
      'createdAt': createdAt, // Preserve original createdAt
    }, SetOptions(merge: true));

    // Update approved count in post document (decrement only if was approved)
    if (wasApproved) {
      await _firestore.collection('posts').doc(postId).update({
        'approvedApplicants': FieldValue.increment(-1),
      });
    }

    // Release held credits immediately when application is rejected
    if (jobseekerId.isNotEmpty && currentStatus == 'pending') {
      try {
        final success = await WalletService.releaseHeldCreditsForUser(
          firestore: _firestore,
          userId: jobseekerId,
          postId: postId,
          feeCredits: 100,
        );
        // Mark as processed immediately
        await docRef.set({'creditsProcessed': true}, SetOptions(merge: true));
        
        // Send wallet notification if release was successful
        if (success) {
          try {
            await _notificationService.notifyWalletCredit(
              userId: jobseekerId,
              amount: 100,
              reason: 'Application fee (Released)',
              metadata: {'postId': postId, 'type': 'application_fee_released'},
            );
          } catch (e) {
            // Log but don't fail - notification is not critical
            debugPrint('Error sending wallet credit notification: $e');
          }
        }
      } catch (e) {
        // Log error but don't fail rejection - credits can be processed later
        debugPrint(
          'Error releasing held credits for jobseeker $jobseekerId: $e',
        );
      }
    }

    final postTitle = await _getPostTitle(postId);

    if (jobseekerId.isNotEmpty) {
      await _notificationService.notifyApplicationDecision(
        jobseekerId: jobseekerId,
        postTitle: postTitle,
        approved: false,
      );
    }
  }

  // Check if application is approved (for messaging permission)
  Future<bool> isApplicationApproved(String postId, String jobseekerId) async {
    final result = await _col
        .where('postId', isEqualTo: postId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  // Get count of approved applications for a post
  // Reads from post document for efficiency and to allow jobseekers to check quota
  // If field is missing (old posts), initializes it by calculating from applications
  Future<int> getApprovedApplicationsCount(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        return 0;
      }
      final postData = postDoc.data();

      // Helper to safely parse int from Firestore (handles int, double, num)
      int? _parseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }

      // Check if approvedApplicants field exists
      if (postData?.containsKey('approvedApplicants') == true) {
        // Field exists, return the value
        final approvedCount = _parseInt(postData?['approvedApplicants']) ?? 0;
        return approvedCount;
      }

      // Field is missing (old post) - need to initialize it
      // Get post owner to query applications
      final ownerId = postData?['ownerId'] as String?;
      if (ownerId == null || ownerId.isEmpty) {
        return 0;
      }

      // Calculate approved count from applications
      // Only works if current user is the recruiter (due to security rules)
      final currentUserId = _authService.currentUserId;
      if (currentUserId != ownerId) {
        // Jobseeker viewing - can't query by recruiterId
        // Try to initialize asynchronously (fire and forget) by checking if we can access
        // For now, return a safe default - the field will be initialized when recruiter views
        // This means jobseekers might see incorrect status until recruiter initializes it
        _initializeApprovedApplicantsIfMissing(postId, ownerId).catchError((e) {
          debugPrint('Background initialization failed: $e');
        });
        return 0; // Safe default for jobseekers until field is initialized
      }

      // Recruiter can query - calculate and initialize the field
      try {
        final approvedApplications = await _col
            .where('postId', isEqualTo: postId)
            .where('recruiterId', isEqualTo: ownerId)
            .where('status', isEqualTo: 'approved')
            .get();

        final approvedCount = approvedApplications.docs.length;

        // Initialize the field in post document for future reads
        await _firestore.collection('posts').doc(postId).update({
          'approvedApplicants': approvedCount,
        });

        return approvedCount;
      } catch (e) {
        debugPrint('Error calculating approved applications count: $e');
        return 0;
      }
    } catch (e) {
      debugPrint('Error getting approved applications count: $e');
      return 0;
    }
  }

  Future<String> _getPostTitle(String postId) async {
    if (postId.isEmpty) return 'your post';
    try {
      final snap = await _firestore.collection('posts').doc(postId).get();
      return snap.data()?['title'] as String? ?? 'your post';
    } catch (_) {
      return 'your post';
    }
  }

  // Get all applications for a post (for notifications, etc.)
  // Requires recruiterId to comply with Firestore security rules
  Future<List<Application>> getApplicationsByPostId({
    required String postId,
    required String recruiterId,
  }) async {
    try {
      final applicationsSnapshot = await _col
          .where('postId', isEqualTo: postId)
          .where('recruiterId', isEqualTo: recruiterId)
          .get();

      return applicationsSnapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting applications for post $postId: $e');
      return [];
    }
  }

  // Delete all applications for a given post
  // Requires recruiterId to comply with Firestore security rules
  Future<void> deleteApplicationsByPostId({
    required String postId,
    required String recruiterId,
  }) async {
    try {
      // Get all applications for this post (filtered by recruiterId for security)
      final applicationsSnapshot = await _col
          .where('postId', isEqualTo: postId)
          .where('recruiterId', isEqualTo: recruiterId)
          .get();

      // Mark each application as deleted instead of actually deleting it
      final batch = _firestore.batch();
      for (final doc in applicationsSnapshot.docs) {
        batch.update(doc.reference, {
          'status': 'deleted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch update
      if (applicationsSnapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // Log error but don't throw - cleanup failure shouldn't prevent post deletion
      debugPrint('Error marking applications as deleted for post $postId: $e');
      // Re-throw only if it's a critical error that should be handled
      // For permission errors, we'll just log and continue
    }
  }

  // Check and auto-reject pending applications for posts where event start date is one day away
  // This should be called when loading applications to ensure they are rejected in time
  Future<void> checkAndAutoRejectApplications() async {
    try {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      // Get pending applications for current user's posts (as recruiter)
      // This ensures we only query applications the user has permission to read
      final recruiterId = _authService.currentUserId;
      final pendingApplications = await _col
          .where('status', isEqualTo: 'pending')
          .where('recruiterId', isEqualTo: recruiterId)
          .get();

      if (pendingApplications.docs.isEmpty) {
        return;
      }

      // Group applications by postId to minimize Firestore reads
      final Map<String, List<DocumentSnapshot>> applicationsByPost = {};
      for (final doc in pendingApplications.docs) {
        final postId = doc.data()['postId'] as String? ?? '';
        if (postId.isNotEmpty) {
          applicationsByPost.putIfAbsent(postId, () => []).add(doc);
        }
      }

      // Check each post's event start date
      final batch = _firestore.batch();
      int rejectedCount = 0;

      for (final entry in applicationsByPost.entries) {
        final postId = entry.key;
        final applications = entry.value;

        try {
          final postDoc = await _firestore
              .collection('posts')
              .doc(postId)
              .get();
          if (!postDoc.exists) continue;

          final postData = postDoc.data();
          if (postData == null) continue;

          // Get event start date
          final eventStartDateValue = postData['eventStartDate'];
          if (eventStartDateValue == null) continue;

          DateTime? eventStartDate;
          if (eventStartDateValue is Timestamp) {
            eventStartDate = eventStartDateValue.toDate();
          } else if (eventStartDateValue is DateTime) {
            eventStartDate = eventStartDateValue;
          }

          if (eventStartDate == null) continue;

          // Normalize dates to compare only dates (ignore time)
          final eventStartDateOnly = DateTime(
            eventStartDate.year,
            eventStartDate.month,
            eventStartDate.day,
          );

          // Check if event start date is exactly one day from now (tomorrow)
          if (eventStartDateOnly.isAtSameMomentAs(tomorrow)) {
            // Reject all pending applications for this post
            for (final appDoc in applications) {
              final appData = appDoc.data() as Map<String, dynamic>?;
              if (appData == null) continue;

              final currentStatus = appData['status'] as String? ?? 'pending';

              // Only reject if still pending (might have been approved/rejected since query)
              if (currentStatus == 'pending') {
                batch.update(appDoc.reference, {
                  'status': 'rejected',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                rejectedCount++;

                // Send notification to jobseeker
                final jobseekerId = appData['jobseekerId'] as String? ?? '';
                final postTitle = postData['title'] as String? ?? 'your post';
                if (jobseekerId.isNotEmpty) {
                  try {
                    await _notificationService.notifyApplicationDecision(
                      jobseekerId: jobseekerId,
                      postTitle: postTitle,
                      approved: false,
                    );
                  } catch (e) {
                    debugPrint(
                      'Error notifying jobseeker about auto-rejection: $e',
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error checking post $postId for auto-rejection: $e');
          // Continue with other posts
        }
      }

      // Commit all rejections in a single batch
      if (rejectedCount > 0) {
        await batch.commit();
        debugPrint(
          'Auto-rejected $rejectedCount applications for posts starting tomorrow',
        );
      }
    } catch (e) {
      debugPrint('Error in checkAndAutoRejectApplications: $e');
      // Don't throw - this is a background check that shouldn't break the app
    }
  }

  // Helper method to check a single application and auto-reject if needed
  Future<void> checkAndAutoRejectApplication(String applicationId) async {
    try {
      final appDoc = await _col.doc(applicationId).get();
      if (!appDoc.exists) return;

      final appData = appDoc.data();
      if (appData == null) return;

      final status = appData['status'] as String? ?? 'pending';
      if (status != 'pending') return; // Only check pending applications

      final postId = appData['postId'] as String? ?? '';
      if (postId.isEmpty) return;

      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      final postData = postDoc.data();
      if (postData == null) return;

      final eventStartDateValue = postData['eventStartDate'];
      if (eventStartDateValue == null) return;

      DateTime? eventStartDate;
      if (eventStartDateValue is Timestamp) {
        eventStartDate = eventStartDateValue.toDate();
      } else if (eventStartDateValue is DateTime) {
        eventStartDate = eventStartDateValue;
      }

      if (eventStartDate == null) return;

      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final eventStartDateOnly = DateTime(
        eventStartDate.year,
        eventStartDate.month,
        eventStartDate.day,
      );

      // If event starts tomorrow, reject the application
      if (eventStartDateOnly.isAtSameMomentAs(tomorrow)) {
        await appDoc.reference.update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final jobseekerId = appData['jobseekerId'] as String? ?? '';
        final postTitle = postData['title'] as String? ?? 'your post';
        if (jobseekerId.isNotEmpty) {
          try {
            await _notificationService.notifyApplicationDecision(
              jobseekerId: jobseekerId,
              postTitle: postTitle,
              approved: false,
            );
          } catch (e) {
            debugPrint('Error notifying jobseeker about auto-rejection: $e');
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Error checking application $applicationId for auto-rejection: $e',
      );
    }
  }
}
