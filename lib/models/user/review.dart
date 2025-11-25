import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String postId;
  final String recruiterId;
  final String jobseekerId;
  final int rating; // 1-5
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.postId,
    required this.recruiterId,
    required this.jobseekerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      postId: data['postId'] as String,
      recruiterId: data['recruiterId'] as String,
      jobseekerId: data['jobseekerId'] as String,
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: (data['comment'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'recruiterId': recruiterId,
      'jobseekerId': jobseekerId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}













