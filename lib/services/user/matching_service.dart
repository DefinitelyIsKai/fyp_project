import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user/job_match.dart';
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
  final FirebaseAuth _auth;
  final HybridMatchingEngine _matchingEngine;

  // Get job matches for current user (jobseeker sees matches, recruiter sees applications)
  Stream<List<JobMatch>> streamJobMatches({String? role}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(<JobMatch>[]);
    }

    // Determine role if not provided
    if (role == null) {
      return _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .asyncMap((userDoc) async {
        final userData = userDoc.data();
        final userRole = userData?['role'] as String? ?? 'jobseeker';
        return _streamMatchesForRole(userId, userRole);
      }).asyncExpand((stream) => stream);
    }

    return _streamMatchesForRole(userId, role);
  }

  Stream<List<JobMatch>> _streamMatchesForRole(String userId, String role) {
    if (role == 'recruiter') {
      // Recruiters see matches for their job posts
      return _firestore
          .collection('job_matches')
          .where('recruiterId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return JobMatch(
            id: doc.id,
            jobTitle: data['jobTitle'] as String? ?? '',
            companyName: data['companyName'] as String? ?? '',
            recruiterId: data['recruiterId'] as String? ?? '',
            status: data['status'] as String? ?? 'pending',
            matchPercentage: (data['matchPercentage'] as int?) ?? null,
            matchedSkills: (data['matchedSkills'] as List?)?.cast<String>() ?? null,
            candidateName: data['candidateName'] as String? ?? null,
            matchingStrategy: data['matchingStrategy'] as String? ?? null,
            createdAt: (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : (data['createdAt'] as DateTime?),
          );
        }).toList();
      });
    } else {
      // Jobseekers see their own matches
      return _firestore
          .collection('job_matches')
          .where('jobseekerId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return JobMatch(
            id: doc.id,
            jobTitle: data['jobTitle'] as String? ?? '',
            companyName: data['companyName'] as String? ?? '',
            recruiterId: data['recruiterId'] as String? ?? '',
            status: data['status'] as String? ?? 'pending',
            matchPercentage: (data['matchPercentage'] as int?) ?? null,
            matchedSkills: (data['matchedSkills'] as List?)?.cast<String>() ?? null,
            candidateName: data['candidateName'] as String? ?? null,
            matchingStrategy: data['matchingStrategy'] as String? ?? null,
            createdAt: (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : (data['createdAt'] as DateTime?),
          );
        }).toList();
      });
    }
  }

  // Apply to a job match (jobseeker action)
  // This creates an application from a match
  Future<void> applyToJobMatch(String matchId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('User not authenticated');

    // Get the match document
    final matchDoc = await _firestore.collection('job_matches').doc(matchId).get();
    if (!matchDoc.exists) throw StateError('Match not found');

    final matchData = matchDoc.data()!;
    final jobId = matchData['jobId'] as String?;
    if (jobId == null) throw StateError('Job ID not found in match');

    // Check if application already exists
    final existingApp = await _firestore
        .collection('applications')
        .where('postId', isEqualTo: jobId)
        .where('applicantId', isEqualTo: userId)
        .limit(1)
        .get();

    if (existingApp.docs.isNotEmpty) {
      // Application already exists
      return;
    }

    // Create application from match
    await _firestore.collection('applications').add({
      'postId': jobId,
      'applicantId': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update match status to 'applied'
    await _firestore.collection('job_matches').doc(matchId).update({
      'status': 'applied',
    });
  }

  // Schedule interview (links match to availability slot)
  Future<void> scheduleInterview({
    required String matchId,
    required String slotId,
    required DateTime interviewDate,
  }) async {
    // Update match status to 'interview_scheduled'
    await _firestore.collection('job_matches').doc(matchId).update({
      'status': 'interview_scheduled',
      'slotId': slotId,
      'interviewDate': Timestamp.fromDate(interviewDate),
    });
  }

  // Recompute matches using matching engine
  Future<void> recomputeMatches({
    String? role,
    MatchingStrategy strategy = MatchingStrategy.embeddingsAnn,
  }) async {
    await _matchingEngine.recomputeMatches(
      explicitRole: role,
      strategy: strategy,
    );
  }
}
