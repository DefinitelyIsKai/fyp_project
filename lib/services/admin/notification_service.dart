// services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService() : _notificationsRef = FirebaseFirestore.instance.collection('notifications');

  final CollectionReference<Map<String, dynamic>> _notificationsRef;

  Future<void> sendViolationWarning({
    required String userId,
    required String userName,
    required String userEmail,
    required String violationReason,
    required int durationDays,
  }) async {
    await _notificationsRef.add({
      'body': 'Your account has been suspended for $durationDays days due to violation of our community guidelines.',
      'category': 'account_suspension',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'metadata': {
        'violationReason': violationReason,
        'suspensionDuration': durationDays,
        'userName': userName,
        'userEmail': userEmail,
        'actionType': 'suspension',
      },
      'title': 'Account Suspension Notice',
      'userId': userId,
    });
  }

  Future<void> sendAccountDeletionWarning({
    required String userId,
    required String userName,
    required String userEmail,
    required String reason,
  }) async {
    await _notificationsRef.add({
      'body': 'Your account has been permanently deleted due to severe violations of our community guidelines.',
      'category': 'account_deletion',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'metadata': {
        'deletionReason': reason,
        'userName': userName,
        'userEmail': userEmail,
        'actionType': 'deletion',
      },
      'title': 'Account Deletion Notice',
      'userId': userId,
    });
  }

  Future<void> sendUnsuspensionNotice({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    await _notificationsRef.add({
      'body': 'Your account suspension has been lifted. You can now access all features normally.',
      'category': 'account_unsuspension',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'metadata': {
        'userName': userName,
        'userEmail': userEmail,
        'actionType': 'unsuspension',
      },
      'title': 'Account Access Restored',
      'userId': userId,
    });
  }

  /// Send notification when a post is approved
  Future<void> sendPostApprovalNotification({
    required String userId,
    required String postId,
    required String postTitle,
  }) async {
    await _notificationsRef.add({
      'title': 'Post published',
      'body': '"$postTitle" is now live.',
      'category': 'post', // Use 'post' category to match user-side NotificationCategory.post
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'userId': userId,
      'metadata': {
        'postId': postId,
        'postTitle': postTitle,
        'actionType': 'post_approved',
      },
    });
  }

  /// Send notification when a post is rejected
  Future<void> sendPostRejectionNotification({
    required String userId,
    required String postId,
    required String postTitle,
    required String rejectionReason,
  }) async {
    await _notificationsRef.add({
      'title': 'Post Rejected',
      'body': 'Your job post "$postTitle" has been rejected. Reason: $rejectionReason',
      'category': 'post_rejection',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'userId': userId,
      'metadata': {
        'postId': postId,
        'postTitle': postTitle,
        'rejectionReason': rejectionReason,
        'actionType': 'post_rejected',
      },
    });
  }
}