import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/rating_model.dart';

class RatingService {
  final CollectionReference _reviewsCollection =
      FirebaseFirestore.instance.collection('reviews');

  /// Get all flagged ratings
  Future<List<RatingModel>> getFlaggedRatings() async {
    try {
      final snapshot = await _reviewsCollection
          .where('status', isEqualTo: 'flagged')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RatingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all ratings
  Future<List<RatingModel>> getAllRatings() async {
    try {
      final snapshot = await _reviewsCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RatingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get ratings by status
  Future<List<RatingModel>> getRatingsByStatus(RatingStatus status) async {
    try {
      final snapshot = await _reviewsCollection
          .where('status', isEqualTo: status.toString().split('.').last)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RatingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Flag a rating for review
  Future<void> flagRating(String ratingId, String reason) async {
    await _reviewsCollection.doc(ratingId).update({
      'status': 'flagged',
      'flaggedReason': reason,
      'flaggedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Review a flagged rating
  Future<void> reviewRating({
    required String ratingId,
    required String action, // 'approved', 'removed', 'warning'
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    final status = action == 'approved' ? 'active' : 'removed';
    
    await _reviewsCollection.doc(ratingId).update({
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNotes': reviewNotes,
      'reviewAction': action,
    });
  }

  /// Remove a rating
  Future<void> removeRating(String ratingId, {String? reason}) async {
    await _reviewsCollection.doc(ratingId).update({
      'status': 'removed',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNotes': reason,
    });
  }

  /// Delete a rating (soft delete - change status to 'deleted')
  Future<void> deleteRating(String ratingId, {String? reason}) async {
    await _reviewsCollection.doc(ratingId).update({
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'reviewNotes': reason,
    });
  }

  /// Get ratings for a specific employee
  Future<List<RatingModel>> getRatingsForUser(String userId) async {
    try {
      final snapshot = await _reviewsCollection
          .where('employeeId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RatingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get average rating for a user
  Future<double> getAverageRating(String userId) async {
    try {
      final ratings = await getRatingsForUser(userId);
      if (ratings.isEmpty) return 0.0;
      
      final sum = ratings.fold<double>(0.0, (sum, rating) => sum + rating.rating);
      return sum / ratings.length;
    } catch (e) {
      return 0.0;
    }
  }

  /// Stream all ratings
  Stream<List<RatingModel>> streamAllRatings() {
    return _reviewsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromFirestore(doc))
            .toList());
  }

  /// Stream ratings by status
  Stream<List<RatingModel>> streamRatingsByStatus(RatingStatus status) {
    return _reviewsCollection
        .where('status', isEqualTo: status.toString().split('.').last)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromFirestore(doc))
            .toList());
  }
}

