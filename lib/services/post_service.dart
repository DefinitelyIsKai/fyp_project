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

  /// Stream posts filtered by status: 'pending', 'approved', 'rejected'
  Stream<List<JobPostModel>> streamPostsByStatus(String status) {
    return _postsCollection
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => JobPostModel.fromFirestore(doc)).toList();
    });
  }

  /// Approve a post
  Future<void> approvePost(String postId) async {
    await _postsCollection.doc(postId).update({'status': 'approved'});
  }

  /// Reject a post with reason
  Future<void> rejectPost(String postId, String reason) async {
    await _postsCollection.doc(postId).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
  }

  /// Optional: search posts by title or description
  Future<List<JobPostModel>> searchPosts(String query) async {
    final snapshot = await _postsCollection
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    return snapshot.docs.map((doc) => JobPostModel.fromFirestore(doc)).toList();
  }

  /// Update status dynamically (approved, rejected, pending)
  Future<void> updateStatus(String postId, String status, {String? reason}) async {
    final validStatuses = ['pending', 'approved', 'rejected'];
    if (!validStatuses.contains(status)) {
      throw Exception('Invalid status: $status');
    }

    final data = <String, dynamic>{'status': status};

    if (status == 'rejected' && reason != null) {
      data['rejectionReason'] = reason;
    }

    await _postsCollection.doc(postId).update(data);
  }
}
