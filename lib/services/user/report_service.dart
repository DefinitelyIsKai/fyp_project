import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/report.dart';
import 'auth_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Create a report for a post (by jobseeker)
  Future<void> reportPost({
    required String postId,
    required String reason,
    required String description,
  }) async {
    try {
      final userDoc = await _authService.getUserDoc();
      final reporterId = userDoc.id;

      // Get post details to find recruiter
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      final recruiterId = postData['ownerId'] as String;

      // Check if user already reported this post
      final existingReport = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: reporterId)
          .where('reportedPostId', isEqualTo: postId)
          .where('type', isEqualTo: 'post')
          .limit(1)
          .get();

      if (existingReport.docs.isNotEmpty) {
        throw Exception('You have already reported this post');
      }

      final report = Report(
        id: _firestore.collection('reports').doc().id,
        type: ReportType.post,
        reporterId: reporterId,
        reportedPostId: postId,
        reportedRecruiterId: recruiterId,
        reason: reason,
        description: description,
      );

      await _firestore
          .collection('reports')
          .doc(report.id)
          .set(report.toFirestore());
    } catch (e) {
      throw Exception('Failed to create report: $e');
    }
  }

  /// Create a report for an jobseeker (by recruiter)
  Future<void> reportJobseeker({
    required String jobseekerId,
    required String postId,
    required String reason,
    required String description,
  }) async {
    try {
      final userDoc = await _authService.getUserDoc();
      final reporterId = userDoc.id;

      // Verify the post belongs to the reporter
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      final postOwnerId = postData['ownerId'] as String;

      if (postOwnerId != reporterId) {
        throw Exception('You can only report jobseekers from your own posts');
      }

      // Allow multiple reports for the same jobseeker (user may report for different reasons or new incidents)
      // No need to check for existing reports

      final report = Report(
        id: _firestore.collection('reports').doc().id,
        type: ReportType.jobseeker,
        reporterId: reporterId,
        reportedPostId: postId,
        reportedJobseekerId: jobseekerId,
        reason: reason,
        description: description,
      );

      await _firestore
          .collection('reports')
          .doc(report.id)
          .set(report.toFirestore());
    } catch (e) {
      throw Exception('Failed to create report: $e');
    }
  }

  /// Check if user has already reported a post
  Future<bool> hasReportedPost(String postId) async {
    try {
      final userDoc = await _authService.getUserDoc();
      final reporterId = userDoc.id;

      final reports = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: reporterId)
          .where('reportedPostId', isEqualTo: postId)
          .where('type', isEqualTo: 'post')
          .limit(1)
          .get();

      return reports.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if recruiter has already reported an jobseeker for a post
  Future<bool> hasReportedJobseeker(String jobseekerId, String postId) async {
    try {
      final userDoc = await _authService.getUserDoc();
      final reporterId = userDoc.id;

      final reports = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: reporterId)
          .where('reportedPostId', isEqualTo: postId)
          .where('reportedJobseekerId', isEqualTo: jobseekerId)
          .where('type', isEqualTo: 'jobseeker')
          .limit(1)
          .get();

      return reports.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Stream all reports (for admin use)
  Stream<List<Report>> streamReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Report.fromFirestore(doc))
            .toList());
  }
}

