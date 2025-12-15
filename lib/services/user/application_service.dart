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

  Future<String> createApplication({
    required String postId,
    required String recruiterId,
  }) async {
    final jobseekerId = _authService.currentUserId;
    final userDoc = await _authService.getUserDoc();
    final userData = userDoc.data();
    final isVerified = userData?['isVerified'] as bool? ?? false;
    if (!isVerified) {
      throw StateError('USER_NOT_VERIFIED');
    }
    
    final postSnap = await _firestore.collection('posts').doc(postId).get();
    final postData = postSnap.data();
    final String status = postData?['status'] as String? ?? 'active';
    if (status.toLowerCase() == 'completed') {
      throw StateError('POST_COMPLETED');
    }


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
      likes: [],
      dislikes: [],
    );

    final docRef = await _col.add(application.toFirestore());

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
    }

    return docRef.id;
  }

  Stream<List<Application>> streamPostApplications(String postId) {
    final recruiterId = _authService.currentUserId;
    checkAndAutoRejectApplications();
    _initializeApprovedApplicantsIfMissing(postId, recruiterId);
    return _col
        .where('postId', isEqualTo: postId)
        .where('recruiterId', isEqualTo: recruiterId)
        .snapshots()
        .map((snapshot) {
          final applications = snapshot.docs
              .map((doc) => Application.fromFirestore(doc))
              .toList();
          applications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return applications;
        })
        .handleError((error) {
          debugPrint('Error in streamPostApplications (likely during logout): $error');
          return <Application>[];
        });
  }

  
  Future<void> _initializeApprovedApplicantsIfMissing(
    String postId,
    String recruiterId,
  ) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      final postData = postDoc.data();
     
      if (postData?.containsKey('approvedApplicants') == true) {
        return; 
      }

      final approvedApplications = await _col
          .where('postId', isEqualTo: postId)
          .where('recruiterId', isEqualTo: recruiterId)
          .where('status', isEqualTo: 'approved')
          .get();

      final approvedCount = approvedApplications.docs.length;

      await _firestore.collection('posts').doc(postId).update({
        'approvedApplicants': approvedCount,
      });
    } catch (e) {
      debugPrint('Error initializing approvedApplicants: $e');
    }
  }

  Stream<List<Application>> streamMyApplications() {
    final jobseekerId = _authService.currentUserId;
    checkAndAutoRejectApplications();
    _processHeldCreditsForApplications(jobseekerId);
    return _col.where('jobseekerId', isEqualTo: jobseekerId).snapshots().map((
      snapshot,
    ) {
      final applications = snapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();
      applications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return applications;
    }).handleError((error) {
      debugPrint('Error in streamMyApplications (likely during logout): $error');
      return <Application>[];
    });
  }

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

        if (creditsProcessed) continue;

        try {
          bool processed = false;
          if (status == 'approved') {
            processed = await walletService.deductHeldCredits(
              postId: postId,
              userId: jobseekerId, 
              feeCredits: 100,
            );
          } else if (status == 'rejected') {
            processed = await walletService.releaseHeldCredits(
              postId: postId,
              feeCredits: 100,
            );
            if (!processed) {
              processed =
                  true; 
            }
          }

          if (processed) {
            await appDoc.reference.set({
              'creditsProcessed': true,
            }, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint(
            'Error processing held credits for application ${appDoc.id}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('Error processing held credits: $e');
    }
  }

  Stream<List<Application>> streamRecruiterApplications() {
    final recruiterId = _authService.currentUserId;
    checkAndAutoRejectApplications();
    return _col.where('recruiterId', isEqualTo: recruiterId).snapshots().map((
      snapshot,
    ) {
      final applications = snapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();
      applications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return applications;
    }).handleError((error) {
      debugPrint('Error in streamRecruiterApplications (likely during logout): $error');
      return <Application>[];
    });
  }

  Future<bool> hasApplied(String postId) async {
    final jobseekerId = _authService.currentUserId;
    final result = await _col
        .where('postId', isEqualTo: postId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

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
          
          debugPrint('Error in streamApplicationForPost (likely during logout): $error');
          return null;
        });
  }

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

    final jobseekerId = data['jobseekerId'] as String?;
    final recruiterId = data['recruiterId'] as String?;
    final createdAt = data['createdAt'];

    if (jobseekerId == null || jobseekerId.isEmpty) {
      throw StateError('Jobseeker ID not found in application');
    }
    if (recruiterId == null || recruiterId.isEmpty) {
      throw StateError('Recruiter ID not found in application');
    }

   
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final postSnap = await _firestore.collection('posts').doc(postId).get();
    final postData = postSnap.data();
    final applicantQuota = _parseInt(postData?['applicantQuota']);

  
    final currentStatus = data['status'] as String? ?? 'pending';
    final isAlreadyApproved = currentStatus == 'approved';

    
    int currentApprovedCount = _parseInt(postData?['approvedApplicants']) ?? 0;

  
    if (postData?.containsKey('approvedApplicants') != true) {
      try {
        final approvedApplications = await _col
            .where('postId', isEqualTo: postId)
            .where('recruiterId', isEqualTo: recruiterId)
            .where('status', isEqualTo: 'approved')
            .get();
        currentApprovedCount = approvedApplications.docs.length;


        await _firestore.collection('posts').doc(postId).update({
          'approvedApplicants': currentApprovedCount,
        });
      } catch (e) {
        debugPrint('Error initializing approvedApplicants: $e');
      
      }
    }

    if (applicantQuota != null) {
     
      if (!isAlreadyApproved && currentApprovedCount >= applicantQuota) {
        throw StateError('QUOTA_EXCEEDED');
      }
    }

   
    await docRef.set({
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
      'jobseekerId': jobseekerId,
      'recruiterId': recruiterId,
      'postId': postId,
      'createdAt': createdAt, 
    }, SetOptions(merge: true));

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

    if (jobseekerId.isNotEmpty && currentStatus == 'pending') {
      try {
        final success = await WalletService.deductHeldCreditsForUser(
          firestore: _firestore,
          userId: jobseekerId,
          postId: postId,
          feeCredits: 100,
        );
      
        await docRef.set({'creditsProcessed': true}, SetOptions(merge: true));
        
       
        if (success) {
          try {
            await _notificationService.notifyWalletDebit(
              userId: jobseekerId,
              amount: 100,
              reason: 'Application fee',
              metadata: {'postId': postId, 'type': 'application_fee'},
            );
          } catch (e) {
           
            debugPrint('Error sending wallet debit notification: $e');
          }
        }
      } catch (e) {
        
        debugPrint(
          'Error deducting held credits for jobseeker $jobseekerId: $e',
        );
      }
    }
  }

  Future<void> rejectApplication(String applicationId) async {
    final docRef = _col.doc(applicationId);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Application not found');
    }

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

   
    final currentStatus = data['status'] as String? ?? 'pending';
    final wasApproved = currentStatus == 'approved';

   
    await docRef.set({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
      'jobseekerId': jobseekerId,
      'recruiterId': recruiterId,
      'postId': postId,
      'createdAt': createdAt, 
    }, SetOptions(merge: true));

    
    if (wasApproved) {
      await _firestore.collection('posts').doc(postId).update({
        'approvedApplicants': FieldValue.increment(-1),
      });
    }

    if (jobseekerId.isNotEmpty && currentStatus == 'pending') {
      try {
        final success = await WalletService.releaseHeldCreditsForUser(
          firestore: _firestore,
          userId: jobseekerId,
          postId: postId,
          feeCredits: 100,
        );
      
        await docRef.set({'creditsProcessed': true}, SetOptions(merge: true));
        
        if (success) {
          try {
            await _notificationService.notifyWalletCredit(
              userId: jobseekerId,
              amount: 100,
              reason: 'Application fee (Released)',
              metadata: {'postId': postId, 'type': 'application_fee_released'},
            );
          } catch (e) {
            debugPrint('Error sending wallet credit notification: $e');
          }
        }
      } catch (e) {
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


  Future<void> toggleLikeApplication(String applicationId) async {
    final userId = _authService.currentUserId;
    final docRef = _col.doc(applicationId);
    final doc = await docRef.get();
    if (!doc.exists) throw StateError('Application not found');
    
    final data = doc.data();
    List<String> likes = List<String>.from(data?['likes'] as List? ?? []);
    List<String> dislikes = List<String>.from(data?['dislikes'] as List? ?? []);
    
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
      dislikes.remove(userId); 
    }
    
    await docRef.update({
      'likes': likes,
      'dislikes': dislikes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleDislikeApplication(String applicationId) async {
    final userId = _authService.currentUserId;
    final docRef = _col.doc(applicationId);
    final doc = await docRef.get();
    if (!doc.exists) throw StateError('Application not found');
    
    final data = doc.data();
    List<String> likes = List<String>.from(data?['likes'] as List? ?? []);
    List<String> dislikes = List<String>.from(data?['dislikes'] as List? ?? []);
    
    if (dislikes.contains(userId)) {
      dislikes.remove(userId);
    } else {
      dislikes.add(userId);
      likes.remove(userId); 
    }
    
    await docRef.update({
      'likes': likes,
      'dislikes': dislikes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> isApplicationApproved(String postId, String jobseekerId) async {
    final result = await _col
        .where('postId', isEqualTo: postId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  Future<int> getApprovedApplicationsCount(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        return 0;
      }
      final postData = postDoc.data();

    
      int? _parseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }

      if (postData?.containsKey('approvedApplicants') == true) {
        final approvedCount = _parseInt(postData?['approvedApplicants']) ?? 0;
        return approvedCount;
      }

      final ownerId = postData?['ownerId'] as String?;
      if (ownerId == null || ownerId.isEmpty) {
        return 0;
      }


      final currentUserId = _authService.currentUserId;
      if (currentUserId != ownerId) {
       
        _initializeApprovedApplicantsIfMissing(postId, ownerId).catchError((e) {
          debugPrint('Background initialization failed: $e');
        });
        return 0; 
      }


      try {
        final approvedApplications = await _col
            .where('postId', isEqualTo: postId)
            .where('recruiterId', isEqualTo: ownerId)
            .where('status', isEqualTo: 'approved')
            .get();

        final approvedCount = approvedApplications.docs.length;

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


  Future<void> deleteApplicationsByPostId({
    required String postId,
    required String recruiterId,
  }) async {
    try {

      final applicationsSnapshot = await _col
          .where('postId', isEqualTo: postId)
          .where('recruiterId', isEqualTo: recruiterId)
          .get();


      final batch = _firestore.batch();
      for (final doc in applicationsSnapshot.docs) {
        batch.update(doc.reference, {
          'status': 'deleted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (applicationsSnapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {

      debugPrint('Error marking applications as deleted for post $postId: $e');
      
    }
  }

  Future<void> checkAndAutoRejectApplications() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final recruiterId = _authService.currentUserId;
      final pendingApplications = await _col
          .where('status', isEqualTo: 'pending')
          .where('recruiterId', isEqualTo: recruiterId)
          .get();

      if (pendingApplications.docs.isEmpty) {
        return;
      }

      final Map<String, List<DocumentSnapshot>> applicationsByPost = {};
      for (final doc in pendingApplications.docs) {
        final postId = doc.data()['postId'] as String? ?? '';
        if (postId.isNotEmpty) {
          applicationsByPost.putIfAbsent(postId, () => []).add(doc);
        }
      }

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

          final eventStartDateValue = postData['eventStartDate'];
          if (eventStartDateValue == null) continue;

          DateTime? eventStartDate;
          if (eventStartDateValue is Timestamp) {
            eventStartDate = eventStartDateValue.toDate();
          } else if (eventStartDateValue is DateTime) {
            eventStartDate = eventStartDateValue;
          }

          if (eventStartDate == null) continue;
          final eventStartDateOnly = DateTime(
            eventStartDate.year,
            eventStartDate.month,
            eventStartDate.day,
          );

          if (eventStartDateOnly.isAtSameMomentAs(today) || eventStartDateOnly.isBefore(today)) {
            for (final appDoc in applications) {
              final appData = appDoc.data() as Map<String, dynamic>?;
              if (appData == null) continue;

              final currentStatus = appData['status'] as String? ?? 'pending';

              if (currentStatus == 'pending') {
                batch.update(appDoc.reference, {
                  'status': 'rejected',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                rejectedCount++;

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
  
        }
      }

  
      if (rejectedCount > 0) {
        await batch.commit();
        debugPrint(
          'Auto-rejected $rejectedCount applications for posts starting tomorrow',
        );
      }
    } catch (e) {
      debugPrint('Error in checkAndAutoRejectApplications: $e');
 
    }
  }

  
  Future<void> checkAndAutoRejectApplication(String applicationId) async {
    try {
      final appDoc = await _col.doc(applicationId).get();
      if (!appDoc.exists) return;

      final appData = appDoc.data();
      if (appData == null) return;

      final status = appData['status'] as String? ?? 'pending';
      if (status != 'pending') return; 

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
      final today = DateTime(now.year, now.month, now.day);
      final eventStartDateOnly = DateTime(
        eventStartDate.year,
        eventStartDate.month,
        eventStartDate.day,
      );

      if (eventStartDateOnly.isAtSameMomentAs(today) || eventStartDateOnly.isBefore(today)) {
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
