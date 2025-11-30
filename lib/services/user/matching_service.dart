import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/computed_match.dart';
import '../../models/user/recruiter_match.dart';
import 'hybrid_matching_engine.dart';






// Re-export MatchingStrategy for convenience
export 'hybrid_matching_engine.dart' show MatchingStrategy;


class MatchingService {
  MatchingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    HybridMatchingEngine? matchingEngine,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _matchingEngine = matchingEngine ?? HybridMatchingEngine();

  final FirebaseFirestore _firestore;
  final StreamController<void> _refreshController = StreamController<void>.broadcast();
  final FirebaseAuth _auth;
  final HybridMatchingEngine _matchingEngine;

  // Removed streamJobMatches, applyToJobMatch, and scheduleInterview methods
  // These methods were used for the old job_matches collection system
  // The system now uses real-time computed matches (ComputedMatch and RecruiterMatch)

  // Recompute matches using matching engine (for recruiters only, no longer stores to job_matches)
  Future<void> recomputeMatches({
    String? role,
    MatchingStrategy strategy = MatchingStrategy.embeddingsAnn,
  }) async {
    await _matchingEngine.recomputeMatches(
      explicitRole: role,
      strategy: strategy,
    );
  }

  /// Stream computed matches in real-time without storing to Firestore.
  /// This is for jobseekers to see their matches based on active job posts.
  /// Returns a stream that recomputes matches when user data or posts change.
  Stream<List<ComputedMatch>> streamComputedMatches() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(<ComputedMatch>[]);
    }

    // Combine streams: user data changes, posts changes, and manual refresh
    final userStream = _firestore
        .collection('users')
        .doc(userId)
        .snapshots();
    
    final postsStream = _firestore
        .collection('posts')
        .where('isDraft', isEqualTo: false)
        .where('status', isEqualTo: 'active')
        .snapshots();

    // When either user data or posts change, recompute matches
    // Also listen to refresh controller for manual refresh
    return userStream.asyncExpand((userDoc) {
      // Combine posts stream with refresh controller
      // Create a stream that emits when either posts change or refresh is triggered
      final combinedStream = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      
      StreamSubscription? postsSubscription;
      StreamSubscription? refreshSubscription;
      
      // Listen to posts stream
      postsSubscription = postsStream.listen(
        (snapshot) {
          if (!combinedStream.isClosed) {
            combinedStream.add(snapshot);
          }
        },
        onError: (error) {
          // Ignore permission errors during logout - don't add anything to stream
          debugPrint('Error listening to posts stream (likely during logout): $error');
          // Stream will naturally end, which will result in empty matches list
        },
        cancelOnError: false, // Don't cancel stream on error
      );
      
      // Listen to refresh controller
      refreshSubscription = _refreshController.stream.listen((_) async {
        if (!combinedStream.isClosed) {
          try {
            // On manual refresh, fetch latest posts
            final postsSnapshot = await _firestore
                .collection('posts')
                .where('isDraft', isEqualTo: false)
                .where('status', isEqualTo: 'active')
                .get();
            if (!combinedStream.isClosed) {
              combinedStream.add(postsSnapshot);
            }
          } catch (error) {
            // Ignore permission errors during logout
            debugPrint('Error refreshing posts (likely during logout): $error');
            // Don't add anything - stream will handle empty state naturally
          }
        }
      });
      
      // Get initial posts
      _firestore
          .collection('posts')
          .where('isDraft', isEqualTo: false)
          .where('status', isEqualTo: 'active')
          .get()
          .then((snapshot) {
            if (!combinedStream.isClosed) {
              combinedStream.add(snapshot);
            }
          })
          .catchError((error) {
            // Ignore permission errors during logout
            debugPrint('Error getting initial posts (likely during logout): $error');
            // Don't add anything - stream will handle empty state naturally
          });
      
      // Clean up when stream is cancelled
      combinedStream.onCancel = () {
        postsSubscription?.cancel();
        refreshSubscription?.cancel();
        combinedStream.close();
      };
      
      return combinedStream.stream.asyncMap((postsSnapshot) async {
        try {
          final userData = userDoc.data();
          if (userData == null) return <ComputedMatch>[];
          
          // Only compute for jobseekers
          final role = userData['role'] as String? ?? 'jobseeker';
          if (role != 'jobseeker') return <ComputedMatch>[];

          return await _matchingEngine.computeMatchesForJobseeker(
            userId: userId,
            userData: userData,
          );
        } catch (error) {
          // Ignore errors during logout
          debugPrint('Error computing matches (likely during logout): $error');
          return <ComputedMatch>[];
        }
      }).handleError((error) {
        // Ignore permission errors during logout
        debugPrint('Error in computed matches stream (likely during logout): $error');
        return <ComputedMatch>[];
      });
    });
  }

  /// Manually trigger a refresh of computed matches
  void refreshComputedMatches() {
    _refreshController.add(null);
  }

  /// Compute matches for a specific recruiter post and its applicants.
  /// Returns list of RecruiterMatch objects showing which applicants match the post.
  Future<List<RecruiterMatch>> computeMatchesForRecruiterPost({
    required String postId,
    required String recruiterId,
    MatchingStrategy strategy = MatchingStrategy.embeddingsAnn,
  }) async {
    return await _matchingEngine.computeMatchesForRecruiterPost(
      postId: postId,
      recruiterId: recruiterId,
      strategy: strategy,
    );
  }

  /// Get count of matched applicants for a specific post.
  /// This is a lightweight method that returns only the count.
  Future<int> getMatchedApplicantCount({
    required String postId,
    required String recruiterId,
    MatchingStrategy strategy = MatchingStrategy.embeddingsAnn,
  }) async {
    return await _matchingEngine.getMatchedApplicantCount(
      postId: postId,
      recruiterId: recruiterId,
      strategy: strategy,
    );
  }
}
