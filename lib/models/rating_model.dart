import 'package:cloud_firestore/cloud_firestore.dart';

enum RatingStatus {
  active,
  flagged,
  removed,
  pendingReview,
}

class RatingModel {
  final String id;
  final String raterId; // User who gave the rating
  final String ratedUserId; // User who received the rating
  final double rating; // 1-5 stars
  final String? comment;
  final DateTime createdAt;
  final RatingStatus status;
  final String? flaggedReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? reviewAction; // 'approved', 'removed', 'warning'

  RatingModel({
    required this.id,
    required this.raterId,
    required this.ratedUserId,
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
      raterId: data['raterId'] ?? '',
      ratedUserId: data['ratedUserId'] ?? '',
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
    if (str.contains('removed')) return RatingStatus.removed;
    if (str.contains('pending')) return RatingStatus.pendingReview;
    return RatingStatus.active;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'raterId': raterId,
      'ratedUserId': ratedUserId,
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

