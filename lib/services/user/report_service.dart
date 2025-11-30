import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/report.dart';
import '../../models/admin/report_category_model.dart';
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

  /// Get report categories based on current user's role
  /// - If user is jobseeker: returns type='jobseeker' categories (for reporting posts)
  /// - If user is recruiter: returns type='recruiter' categories (for reporting jobseekers)
  Future<List<ReportCategoryModel>> getReportCategoriesByUserRole() async {
    try {
      final userDoc = await _authService.getUserDoc();
      final userData = userDoc.data();
      final role = userData?['role'] as String? ?? 'jobseeker';
      
      // Jobseekers report posts, so they need 'jobseeker' type categories
      // Recruiters report jobseekers, so they need 'recruiter' type categories
      final categoryType = role == 'jobseeker' ? 'jobseeker' : 'recruiter';
      
      return await getReportCategories(categoryType);
    } catch (e) {
      print('Error getting user role for report categories: $e');
      return [];
    }
  }

  /// Get report categories from Firebase by type
  /// type: 'jobseeker' for jobseekers to report posts, 'recruiter' for recruiters to report jobseekers
  Future<List<ReportCategoryModel>> getReportCategories(String type) async {
    try {
      // First, get all categories with the specified type
      final snapshot = await _firestore
          .collection('report_categories')
          .where('type', isEqualTo: type)
          .get();

      // Filter enabled categories in memory (to avoid composite index requirement)
      final categories = snapshot.docs
          .map((doc) {
            try {
              return ReportCategoryModel.fromJson(doc.data(), doc.id);
            } catch (e) {
              return null;
            }
          })
          .where((category) => category != null && category.isEnabled)
          .cast<ReportCategoryModel>()
          .toList();

      // Sort by name alphabetically
      categories.sort((a, b) => a.name.compareTo(b.name));

      return categories;
    } catch (e) {
      print('Error loading report categories for type $type: $e');
      // If query fails (e.g., missing index), try fetching all and filtering in memory
      try {
        final allSnapshot = await _firestore
            .collection('report_categories')
            .get();
        
        final allCategories = allSnapshot.docs
            .map((doc) {
              try {
                return ReportCategoryModel.fromJson(doc.data(), doc.id);
              } catch (e) {
                return null;
              }
            })
            .where((category) => category != null && category.type == type && category.isEnabled)
            .cast<ReportCategoryModel>()
            .toList();
        
        allCategories.sort((a, b) => a.name.compareTo(b.name));
        return allCategories;
      } catch (fallbackError) {
        print('Fallback method also failed: $fallbackError');
        return [];
      }
    }
  }
}

