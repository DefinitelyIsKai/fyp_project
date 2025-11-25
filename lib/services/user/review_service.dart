import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/review.dart';
import 'auth_service.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('reviews');

  Future<String> addRecruiterReview({
    required String postId,
    required String jobseekerId,
    required int rating,
    String comment = '',
  }) async {
    final recruiterId = _auth.currentUserId;
    
    // Verify post exists, is completed, and owned by recruiter
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw StateError('Post not found');
    }
    
    final postData = postDoc.data();
    if (postData == null) {
      throw StateError('Post data not found');
    }
    
    final postStatus = postData['status'] as String? ?? '';
    if (postStatus.toLowerCase() != 'completed') {
      throw StateError('Can only review jobseekers for completed posts');
    }
    
    final postOwnerId = postData['ownerId'] as String? ?? '';
    if (postOwnerId != recruiterId) {
      throw StateError('Only the post owner can write reviews');
    }
    
    // Verify jobseeker applied to this post
    final applicationQuery = await _firestore
        .collection('applications')
        .where('postId', isEqualTo: postId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .where('recruiterId', isEqualTo: recruiterId)
        .limit(1)
        .get();
    
    if (applicationQuery.docs.isEmpty) {
      throw StateError('Jobseeker did not apply to this post');
    }
    
    final review = Review(
      id: '',
      postId: postId,
      recruiterId: recruiterId,
      jobseekerId: jobseekerId,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );
    final docRef = await _col.add(review.toFirestore());
    return docRef.id;
  }

  Stream<List<Review>> streamReviewsForUser(String userId) {
    return _col
        .where('jobseekerId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Review.fromFirestore(d)).toList());
  }

  // Reviews authored by the current recruiter (ratings they gave to jobseekers)
  Stream<List<Review>> streamReviewsByRecruiter(String userId) {
    return _col
        .where('recruiterId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Review.fromFirestore(d)).toList());
  }

  Future<double> getAverageRatingForUser(String userId) async {
    final qs = await _col.where('jobseekerId', isEqualTo: userId).get();
    if (qs.docs.isEmpty) return 0.0;
    final total = qs.docs
        .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
        .fold<double>(0.0, (a, b) => a + b);
    return total / qs.docs.length;
  }
}


