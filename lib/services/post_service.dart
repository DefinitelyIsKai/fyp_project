import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/job_post_model.dart';

class PostService {
  final CollectionReference _postsCollection =
  FirebaseFirestore.instance.collection('posts');

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
    await _postsCollection.doc(postId).update({
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a post with reason (pending -> rejected)
  Future<void> rejectPost(String postId, String reason) async {
    await _postsCollection.doc(postId).update({
      'status': 'rejected',
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark post as completed (active -> completed)
  Future<void> completePost(String postId) async {
    await _postsCollection.doc(postId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reopen a completed post (completed -> active)
  Future<void> reopenPost(String postId) async {
    await _postsCollection.doc(postId).update({
      'status': 'active',
      'reopenedAt': FieldValue.serverTimestamp(),
    });
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