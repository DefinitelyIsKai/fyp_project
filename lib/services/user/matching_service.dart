import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/computed_match.dart';
import '../../models/user/recruiter_match.dart';
import 'hybrid_matching_engine.dart';


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

  Future<void> recomputeMatches({
    String? role,
  }) async {
    await _matchingEngine.recomputeMatches(
      explicitRole: role,
    );
  }


  Stream<List<ComputedMatch>> streamComputedMatches() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(<ComputedMatch>[]);
    }
    final userStream = _firestore
        .collection('users')
        .doc(userId)
        .snapshots();
    
    final postsStream = _firestore
        .collection('posts')
        .where('isDraft', isEqualTo: false)
        .where('status', isEqualTo: 'active')
        .snapshots();

    return userStream.asyncExpand((userDoc) {
      final combinedStream = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      
      StreamSubscription? postsSubscription;
      StreamSubscription? refreshSubscription;
      
      postsSubscription = postsStream.listen(
        (snapshot) {
          if (!combinedStream.isClosed) {
            combinedStream.add(snapshot);
          }
        },
        onError: (error) {
          debugPrint('Error listening to posts stream (likely during logout): $error');
        },
        cancelOnError: false, 
      );
      
     
      refreshSubscription = _refreshController.stream.listen((_) async {
        if (!combinedStream.isClosed) {
          try {
            final postsSnapshot = await _firestore
                .collection('posts')
                .where('isDraft', isEqualTo: false)
                .where('status', isEqualTo: 'active')
                .get();
            if (!combinedStream.isClosed) {
              combinedStream.add(postsSnapshot);
            }
          } catch (error) {
            debugPrint('Error refreshing posts (likely during logout): $error');
          }
        }
      });
      
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
            debugPrint('Error getting initial posts (likely during logout): $error');
          });
      
      
      combinedStream.onCancel = () {
        postsSubscription?.cancel();
        refreshSubscription?.cancel();
        combinedStream.close();
      };
      
      return combinedStream.stream.asyncMap((postsSnapshot) async {
        try {
          final userData = userDoc.data();
          if (userData == null) return <ComputedMatch>[];

          final role = userData['role'] as String? ?? 'jobseeker';
          if (role != 'jobseeker') return <ComputedMatch>[];

          return await _matchingEngine.computeMatchesForJobseeker(
            userId: userId,
            userData: userData,
          );
        } catch (error, stackTrace) {
          debugPrint('Error computing matches: $error');
          debugPrint('Stack trace: $stackTrace');
          
          if (error.toString().contains('microsecondsSinceEpoch') || 
              error.toString().contains('NoSuchMethodError')) {
            debugPrint('Detected cache corruption, resetting caches...');
            try {
              HybridMatchingEngine.resetAllCaches();
            } catch (resetError) {
              debugPrint('Error resetting caches: $resetError');
            }
          }
          
          return <ComputedMatch>[];
        }
      }).handleError((error, stackTrace) {
        debugPrint('Error in computed matches stream: $error');
        debugPrint('Stack trace: $stackTrace');
        return <ComputedMatch>[];
      });
    });
  }

  void refreshComputedMatches() {
    MatchingService.clearWeightsCache();
    _refreshController.add(null);
  }

  Future<List<RecruiterMatch>> computeMatchesForRecruiterPost({
    required String postId,
    required String recruiterId,
  }) async {
    return await _matchingEngine.computeMatchesForRecruiterPost(
      postId: postId,
      recruiterId: recruiterId,
    );
  }

  Future<int> getMatchedApplicantCount({
    required String postId,
    required String recruiterId,
  }) async {
    return await _matchingEngine.getMatchedApplicantCount(
      postId: postId,
      recruiterId: recruiterId,
    );
  }

  static void clearWeightsCache() {
    HybridMatchingEngine.clearWeightsCache();
  }
  
  static void resetAllCaches() {
    HybridMatchingEngine.resetAllCaches();
  }
}
