import 'package:cloud_firestore/cloud_firestore.dart';

enum RatingStatus {
  active,
  flagged,
  removed,
  deleted,
  pendingReview,
}

class RatingModel {
  final String id;
  final String recruiterId; 
  final String jobseekerId; 
  final String postId;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final RatingStatus status;
  final String? flaggedReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? reviewAction;

  RatingModel({
    required this.id,
    required this.recruiterId,
    required this.jobseekerId,
    required this.postId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.status = RatingStatus.active,
    this.flaggedReason,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    this.reviewAction,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RatingModel(
      id: doc.id,
      recruiterId: data['recruiterId'] ?? data['employerId'] ?? '',
      jobseekerId: data['jobseekerId'] ?? data['employeeId'] ?? '',
      postId: data['postId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(data['status']),
      flaggedReason: data['flaggedReason'],
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNotes: data['reviewNotes'],
      reviewAction: data['reviewAction'],
    );
  }

  static RatingStatus _parseStatus(dynamic value) {
    if (value == null) return RatingStatus.active;
    final str = value.toString().toLowerCase();
    if (str.contains('flagged')) return RatingStatus.flagged;
    if (str.contains('deleted')) return RatingStatus.deleted;
    if (str.contains('removed')) return RatingStatus.removed;
    if (str.contains('pending')) return RatingStatus.pendingReview;
    return RatingStatus.active;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recruiterId': recruiterId,
      'jobseekerId': jobseekerId,
      'postId': postId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.toString().split('.').last,
      'flaggedReason': flaggedReason,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewNotes': reviewNotes,
      'reviewAction': reviewAction,
    };
  }
}
