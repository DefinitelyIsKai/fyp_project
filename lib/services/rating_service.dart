import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/rating_model.dart';

class RatingService {
  final CollectionReference _ratingsCollection =
      FirebaseFirestore.instance.collection('ratings');

  /// Get all flagged ratings
  Future<List<RatingModel>> getFlaggedRatings() async {
    try {
      final snapshot = await _ratingsCollection
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
      final snapshot = await _ratingsCollection
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
      final snapshot = await _ratingsCollection
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
    await _ratingsCollection.doc(ratingId).update({
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
    
    await _ratingsCollection.doc(ratingId).update({
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNotes': reviewNotes,
      'reviewAction': action,
    });
  }

  /// Remove a rating
  Future<void> removeRating(String ratingId, {String? reason}) async {
    await _ratingsCollection.doc(ratingId).update({
      'status': 'removed',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNotes': reason,
    });
  }

  /// Get ratings for a specific user
  Future<List<RatingModel>> getRatingsForUser(String userId) async {
    try {
      final snapshot = await _ratingsCollection
          .where('ratedUserId', isEqualTo: userId)
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
}

