import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/services/admin/notification_service.dart';

class PostService {
  final CollectionReference _postsCollection =
  FirebaseFirestore.instance.collection('posts');
  final CollectionReference<Map<String, dynamic>> _logsRef =
      FirebaseFirestore.instance.collection('logs');
  final NotificationService _notificationService = NotificationService();

  /// Stream all posts in real-time
  Stream<List<JobPostModel>> streamAllPosts() {
    return _postsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return JobPostModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// Stream posts filtered by status: 'pending', 'active', 'completed'
  Stream<List<JobPostModel>> streamPostsByStatus(String status) {
    return _postsCollection
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => JobPostModel.fromFirestore(doc)).toList();
    });
  }

  /// Approve a post (pending -> active)
  Future<void> approvePost(String postId) async {
    // Get post details for logging
    final postDoc = await _postsCollection.doc(postId).get();
    final postData = postDoc.data() as Map<String, dynamic>?;
    final postTitle = postData?['title'] ?? 'Unknown Post';
    final ownerId = postData?['ownerId'] ?? '';
    final previousStatus = postData?['status'] ?? 'unknown';
    
    // Update post status
    await _postsCollection.doc(postId).update({
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    // Create log entry
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      await _logsRef.add({
        'actionType': 'post_approved',
        'postId': postId,
        'postTitle': postTitle,
        'ownerId': ownerId,
        'previousStatus': previousStatus,
        'newStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId,
      });
    } catch (logError) {
      print('Error creating approval log entry: $logError');
      // Don't fail the operation if logging fails
    }

    // Send notification to user if ownerId exists
    if (ownerId.isNotEmpty) {
      try {
        await _notificationService.sendPostApprovalNotification(
          userId: ownerId,
          postId: postId,
          postTitle: postTitle,
        );
      } catch (notifError) {
        print('Error sending approval notification: $notifError');
        // Don't fail the operation if notification fails
      }
    }
  }

  /// Reject a post with reason (pending -> rejected)
  Future<void> rejectPost(String postId, String reason) async {
    // Get post details for logging
    final postDoc = await _postsCollection.doc(postId).get();
    final postData = postDoc.data() as Map<String, dynamic>?;
    final postTitle = postData?['title'] ?? 'Unknown Post';
    final ownerId = postData?['ownerId'] ?? '';
    final previousStatus = postData?['status'] ?? 'unknown';
    
    // Update post status
    await _postsCollection.doc(postId).update({
      'status': 'rejected',
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    // Create log entry
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      await _logsRef.add({
        'actionType': 'post_rejected',
        'postId': postId,
        'postTitle': postTitle,
        'ownerId': ownerId,
        'previousStatus': previousStatus,
        'newStatus': 'rejected',
        'rejectionReason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId,
      });
    } catch (logError) {
      print('Error creating rejection log entry: $logError');
      // Don't fail the operation if logging fails
    }

    // Send notification to user if ownerId exists
    if (ownerId.isNotEmpty) {
      try {
        await _notificationService.sendPostRejectionNotification(
          userId: ownerId,
          postId: postId,
          postTitle: postTitle,
          rejectionReason: reason,
        );
      } catch (notifError) {
        print('Error sending rejection notification: $notifError');
        // Don't fail the operation if notification fails
      }
    }
  }

  /// Delete a post (soft delete - change status to 'deleted')
  Future<void> deletePost(String postId) async {
    // Get post details for logging
    final postDoc = await _postsCollection.doc(postId).get();
    final postData = postDoc.data() as Map<String, dynamic>?;
    final postTitle = postData?['title'] ?? 'Unknown Post';
    final ownerId = postData?['ownerId'] ?? '';
    final previousStatus = postData?['status'] ?? 'unknown';
    
    // Update post status to deleted
    await _postsCollection.doc(postId).update({
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // Create log entry
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      await _logsRef.add({
        'actionType': 'post_deleted',
        'postId': postId,
        'postTitle': postTitle,
        'ownerId': ownerId,
        'previousStatus': previousStatus,
        'newStatus': 'deleted',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId,
      });
    } catch (logError) {
      print('Error creating deletion log entry: $logError');
      // Don't fail the operation if logging fails
    }
  }

  /// Mark post as completed (active -> completed)
  Future<void> completePost(String postId) async {
    // Get post details for logging
    final postDoc = await _postsCollection.doc(postId).get();
    final postData = postDoc.data() as Map<String, dynamic>?;
    final postTitle = postData?['title'] ?? 'Unknown Post';
    final ownerId = postData?['ownerId'] ?? '';
    final previousStatus = postData?['status'] ?? 'unknown';
    
    // Update post status
    await _postsCollection.doc(postId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Create log entry
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      await _logsRef.add({
        'actionType': 'post_completed',
        'postId': postId,
        'postTitle': postTitle,
        'ownerId': ownerId,
        'previousStatus': previousStatus,
        'newStatus': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId,
      });
    } catch (logError) {
      print('Error creating completion log entry: $logError');
      // Don't fail the operation if logging fails
    }
  }

  /// Reopen a completed post (completed -> active)
  Future<void> reopenPost(String postId) async {
    // Get post details for logging
    final postDoc = await _postsCollection.doc(postId).get();
    final postData = postDoc.data() as Map<String, dynamic>?;
    final postTitle = postData?['title'] ?? 'Unknown Post';
    final ownerId = postData?['ownerId'] ?? '';
    final previousStatus = postData?['status'] ?? 'unknown';
    
    // Update post status
    await _postsCollection.doc(postId).update({
      'status': 'active',
      'reopenedAt': FieldValue.serverTimestamp(),
    });

    // Create log entry
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      await _logsRef.add({
        'actionType': 'post_reopened',
        'postId': postId,
        'postTitle': postTitle,
        'ownerId': ownerId,
        'previousStatus': previousStatus,
        'newStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId,
      });
    } catch (logError) {
      print('Error creating reopen log entry: $logError');
      // Don't fail the operation if logging fails
    }
  }

  Future<List<JobPostModel>> searchPosts(String query) async {
    final snapshot = await _postsCollection
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    return snapshot.docs.map((doc) => JobPostModel.fromFirestore(doc)).toList();
  }

  /// Update status dynamically (pending, active, completed, rejected)
  Future<void> updateStatus(String postId, String status, {String? reason}) async {
    final validStatuses = ['pending', 'active', 'completed', 'rejected'];
    if (!validStatuses.contains(status)) {
      throw Exception('Invalid status: $status');
    }

    final data = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Add timestamp based on status
    switch (status) {
      case 'active':
        data['approvedAt'] = FieldValue.serverTimestamp();
        break;
      case 'completed':
        data['completedAt'] = FieldValue.serverTimestamp();
        break;
      case 'rejected':
        data['rejectedAt'] = FieldValue.serverTimestamp();
        if (reason != null) {
          data['rejectionReason'] = reason;
        }
        break;
    }

    await _postsCollection.doc(postId).update(data);
  }

  /// Get post statistics
  Future<Map<String, int>> getPostStats() async {
    final snapshot = await _postsCollection.get();
    final posts = snapshot.docs.map((doc) => JobPostModel.fromFirestore(doc)).toList();

    return {
      'pending': posts.where((p) => p.status == 'pending').length,
      'active': posts.where((p) => p.status == 'active').length,
      'completed': posts.where((p) => p.status == 'completed').length,
      'rejected': posts.where((p) => p.status == 'rejected').length,
    };
  }
}