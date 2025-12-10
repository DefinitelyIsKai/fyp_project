import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/user/app_notification.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('notifications');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('No authenticated user');
    }
    return uid;
  }

  //lload notifications once
  Future<List<AppNotification>> loadInitialNotifications({int limit = 10}) async {
    if (_auth.currentUser == null) {
      debugPrint('No authenticated user for loading notifications');
      return [];
    }

    try {
      debugPrint('Loading initial notifications with limit: $limit for user: $_uid');
      
      final query = _col
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      final snapshot = await query.get();
      
      final notifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
      
      debugPrint('Loaded ${notifications.length} notifications (requested limit: $limit)');
      
      //check limit
      if (notifications.length > limit) {
        debugPrint('WARNING: Received ${notifications.length} notifications but limit was $limit. Truncating.');
        return notifications.sublist(0, limit);
      }
      
      return notifications;
    } catch (e, stackTrace) {
      debugPrint('Error loading initial notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Stream<List<AppNotification>> streamNewNotifications({int limit = 1}) {
    if (_auth.currentUser == null) {
      return Stream.value(<AppNotification>[]);
    }

    return _col
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
    }).handleError((error) {
      debugPrint('Stream error: $error');
      return <AppNotification>[];
    }, test: (error) {
      return error.toString().contains('permission-denied') ||
          error.toString().contains('PERMISSION_DENIED');
    });
  }

  //pagination
  Future<List<AppNotification>> loadMoreNotifications({
    required DateTime lastNotificationTime,
    String? lastNotificationId,
    int limit = 10, 
  }) async {
    if (_auth.currentUser == null) {
      debugPrint('loadMoreNotifications: No authenticated user');
      return [];
    }

    try {
      //compare convert datetime: firestore timestamp

      final Timestamp timestampCursor = Timestamp.fromDate(lastNotificationTime);

      debugPrint('loadMoreNotifications: Loading with cursor time: $timestampCursor, docId: $lastNotificationId, limit: $limit');

      if (lastNotificationId != null) {
        try {
          debugPrint('loadMoreNotifications: Attempting composite query with document ID');
          final snapshot = await _col
              .where('userId', isEqualTo: _uid)
              .orderBy('createdAt', descending: true)
              .orderBy(FieldPath.documentId, descending: true)
              .startAfter([timestampCursor, lastNotificationId])
              .limit(limit)
              .get();

          final notifications = snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList();
          
          debugPrint('loadMoreNotifications: Composite query returned ${notifications.length} notifications');
          return notifications;
        } catch (e) {
          debugPrint('loadMoreNotifications: Composite index may be missing, using simple pagination: $e');
        }
      }

      //pagination timestamp 
      debugPrint('loadMoreNotifications: Using simple query with timestamp only');
      final snapshot = await _col
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .startAfter([timestampCursor])
          .limit(limit)
          .get();

      final notifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
      
      debugPrint('loadMoreNotifications: Simple query returned ${notifications.length} notifications');
      return notifications;
    } catch (e, stackTrace) {
      debugPrint('loadMoreNotifications: Error loading more notifications: $e');
      debugPrint('loadMoreNotifications: Stack trace: $stackTrace');
      return [];
    }
  }

  Stream<int> streamUnreadCount({NotificationCategory? category}) {
    if (_auth.currentUser == null) {
      return Stream.value(0);
    }

    Query<Map<String, dynamic>> query = _col
        .where('userId', isEqualTo: _uid)
        .where('isRead', isEqualTo: false);
    
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    return query.snapshots().map((snap) => snap.docs.length).handleError((error) {
      return 0;
    }, test: (error) {
      return error.toString().contains('permission-denied') ||
          error.toString().contains('PERMISSION_DENIED');
    });
  }

  Future<void> markAllAsRead() async {
    final uid = _uid;
    final unread = await _col
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .limit(200) 
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({'isRead': true});
  }

  Future<void> notifyMessageReceived({
    required String receiverId,
    required String conversationId,
    required String preview,
  }) async {
    await _createNotification(
      userId: receiverId,
      category: NotificationCategory.message,
      title: 'New message received',
      body: preview,
      metadata: {'conversationId': conversationId},
    );
  }

  Future<void> notifyWalletDebit({
    required String userId,
    required int amount,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    await _createNotification(
      userId: userId,
      category: NotificationCategory.wallet,
      title: 'Credits spent',
      body: '$amount credits deducted for $reason.',
      metadata: metadata,
    );
  }

  Future<void> notifyWalletCredit({
    required String userId,
    required int amount,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    await _createNotification(
      userId: userId,
      category: NotificationCategory.wallet,
      title: 'Credits added',
      body: '$amount credits added for $reason.',
      metadata: metadata,
    );
  }

  Future<void> notifyTopUpStatus({
    required String userId,
    required bool success,
    required int credits,
    String? error,
  }) async {
    await _createNotification(
      userId: userId,
      category: NotificationCategory.wallet,
      title: success ? 'Top up successful' : 'Top up failed',
      body: success
          ? '$credits credits have been added to your wallet.'
          : (error ?? 'We could not process your top up.'),
      metadata: {
        'credits': credits,
        'status': success ? 'success' : 'failed',
        if (error != null) 'error': error,
      },
    );
  }

  Future<void> notifyPostPublished({
    required String userId,
    required String postTitle,
  }) async {
    await _createNotification(
      userId: userId,
      category: NotificationCategory.post,
      title: 'Post published',
      body: '"$postTitle" is now live.',
    );
  }

  Future<void> notifyApplicationDecision({
    required String jobseekerId,
    required String postTitle,
    required bool approved,
  }) async {
    await _createNotification(
      userId: jobseekerId,
      category: NotificationCategory.application,
      title: approved ? 'Application approved' : 'Application rejected',
      body: approved
          ? 'You can now chat with the recruiter for "$postTitle".'
          : 'Your application for "$postTitle" was rejected.',
    );
  }

  Future<void> notifyRecruiterNewApplication({
    required String recruiterId,
    required String jobseekerName,
    required String postTitle,
  }) async {
    await _createNotification(
      userId: recruiterId,
      category: NotificationCategory.application,
      title: 'New applicant',
      body: '$jobseekerName applied for "$postTitle".',
    );
  }

  Future<void> notifyPostDeletedToJobseekers({
    required String jobseekerId,
    required String postTitle,
  }) async {
    await _createNotification(
      userId: jobseekerId,
      category: NotificationCategory.post,
      title: 'Post removed',
      body: 'The post "$postTitle" that you applied to has been removed by the recruiter.',
      metadata: {'postTitle': postTitle},
    );
  }

  Future<void> notifyPostDeletedToRecruiter({
    required String recruiterId,
    required String postTitle,
  }) async {
    await _createNotification(
      userId: recruiterId,
      category: NotificationCategory.post,
      title: 'Post removed',
      body: 'Your post "$postTitle" has been removed.',
      metadata: {'postTitle': postTitle},
    );
  }

  Future<void> notifyBookingRequestSentToRecruiter({
    required String recruiterId,
    required String jobseekerName,
    required String slotTimeDisplay,
  }) async {
    await _createNotification(
      userId: recruiterId,
      category: NotificationCategory.booking,
      title: 'New booking request',
      body: '$jobseekerName sent a booking request for $slotTimeDisplay.',
      metadata: {
        'jobseekerName': jobseekerName,
        'slotTimeDisplay': slotTimeDisplay,
      },
    );
  }

  Future<void> notifyBookingRequestSentToJobseeker({
    required String jobseekerId,
    required String recruiterName,
    required String slotTimeDisplay,
  }) async {
    await _createNotification(
      userId: jobseekerId,
      category: NotificationCategory.booking,
      title: 'Booking request sent',
      body: 'Your booking request for $slotTimeDisplay has been sent to $recruiterName.',
      metadata: {
        'recruiterName': recruiterName,
        'slotTimeDisplay': slotTimeDisplay,
      },
    );
  }

  Future<void> notifyBookingRequestApproved({
    required String jobseekerId,
    required String recruiterName,
    required String slotTimeDisplay,
  }) async {
    await _createNotification(
      userId: jobseekerId,
      category: NotificationCategory.booking,
      title: 'Booking approved',
      body: '$recruiterName approved your booking request for $slotTimeDisplay.',
      metadata: {
        'recruiterName': recruiterName,
        'slotTimeDisplay': slotTimeDisplay,
      },
    );
  }

  Future<void> notifySlotDeletedToRequestingJobseekers({
    required List<String> jobseekerIds,
    required String recruiterName,
    required String slotTimeDisplay,
  }) async {
    if (jobseekerIds.isEmpty) return;

    await notifyMultipleUsers(
      userIds: jobseekerIds,
      category: NotificationCategory.booking,
      title: 'Booking request cancelled',
      body: '$recruiterName removed the time slot $slotTimeDisplay that you requested.',
      metadata: {
        'recruiterName': recruiterName,
        'slotTimeDisplay': slotTimeDisplay,
      },
    );
  }

  Future<void> notifySlotDeletedToBookedJobseeker({
    required String jobseekerId,
    required String recruiterName,
    required String slotTimeDisplay,
  }) async {
    await _createNotification(
      userId: jobseekerId,
      category: NotificationCategory.booking,
      title: 'Booking cancelled',
      body: '$recruiterName removed the time slot $slotTimeDisplay that you booked.',
      metadata: {
        'recruiterName': recruiterName,
        'slotTimeDisplay': slotTimeDisplay,
      },
    );
  }

  Future<void> notifyVerificationApproved({
    required String userId,
  }) async {
    await _createNotification(
      userId: userId,
      category: NotificationCategory.system,
      title: 'Account Verification Approved',
      body: 'Your account verification has been approved. Your account is now verified.',
      metadata: {
        'type': 'verification_approved',
      },
    );
  }

  Future<void> notifyVerificationRejected({
    required String userId,
    String? rejectionReason,
  }) async {
    await _createNotification(
      userId: userId,
      category: NotificationCategory.system,
      title: 'Account Verification Rejected',
      body: rejectionReason != null && rejectionReason.isNotEmpty
          ? 'Your account verification was rejected. Reason: $rejectionReason. Please submit a new verification request with clearer photos.'
          : 'Your account verification was rejected. Please submit a new verification request with clearer photos.',
      metadata: {
        'type': 'verification_rejected',
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      },
    );
  }

  Future<void> notifySlotDeletedToRecruiter({
    required String recruiterId,
    required String slotTimeDisplay,
    required int pendingRequestsCount,
    required bool hasBookedJobseeker,
  }) async {
    String body;
    if (hasBookedJobseeker && pendingRequestsCount > 0) {
      body = 'You removed the time slot $slotTimeDisplay. This cancelled ${pendingRequestsCount} pending request${pendingRequestsCount > 1 ? 's' : ''} and 1 booking.';
    } else if (hasBookedJobseeker) {
      body = 'You removed the time slot $slotTimeDisplay. This cancelled 1 booking.';
    } else if (pendingRequestsCount > 0) {
      body = 'You removed the time slot $slotTimeDisplay. This cancelled ${pendingRequestsCount} pending request${pendingRequestsCount > 1 ? 's' : ''}.';
    } else {
      body = 'You removed the time slot $slotTimeDisplay.';
    }

    await _createNotification(
      userId: recruiterId,
      category: NotificationCategory.booking,
      title: 'Time slot deleted',
      body: body,
      metadata: {
        'slotTimeDisplay': slotTimeDisplay,
        'pendingRequestsCount': pendingRequestsCount,
        'hasBookedJobseeker': hasBookedJobseeker,
      },
    );
  }

  Future<void> notifyMultipleUsers({
    required List<String> userIds,
    required NotificationCategory category,
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    if (userIds.isEmpty) return;

    final validUserIds = userIds.where((id) => id.isNotEmpty).toList();
    if (validUserIds.isEmpty) {
      debugPrint('No valid user IDs provided for batch notification');
      return;
    }

    const batchLimit = 500;
    final batches = <WriteBatch>[];
    WriteBatch currentBatch = _firestore.batch();
    int operationCount = 0;

    try {
      final timestamp = FieldValue.serverTimestamp();

      for (final userId in validUserIds) {
        final docRef = _col.doc();
        currentBatch.set(docRef, {
          'userId': userId,
          'category': category.name,
          'title': title,
          'body': body,
          'metadata': metadata ?? {},
          'isRead': false,
          'createdAt': timestamp,
        });

        operationCount++;

        if (operationCount >= batchLimit) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      for (final batch in batches) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error sending batch notifications: $e');
    }
  }

  Future<void> createNotification({
    required String userId,
    required NotificationCategory category,
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    await _createNotification(
      userId: userId,
      category: category,
      title: title,
      body: body,
      metadata: metadata,
    );
  }

  Future<void> markMessageNotificationsAsRead(String conversationId) async {
    final uid = _uid;
    final query = await _col
        .where('userId', isEqualTo: uid)
        .where('category', isEqualTo: NotificationCategory.message.name)
        .get();

    if (query.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      final metadata = doc.data()['metadata'] as Map<String, dynamic>? ?? {};
      if (metadata['conversationId'] == conversationId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  Future<void> _createNotification({
    required String userId,
    required NotificationCategory category,
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    await _col.add({
      'userId': userId,
      'category': category.name,
      'title': title,
      'body': body,
      'metadata': metadata ?? {},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}