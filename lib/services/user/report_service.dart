import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/report.dart';
import '../../models/admin/report_category_model.dart';
import 'auth_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  //jobseeker report
  Future<void> reportPost({
    required String postId,
    required String reason,
    required String description,
  }) async {
    try {
      final userDoc = await _authService.getUserDoc();
      final reporterId = userDoc.id;

      //find recruiter
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      final recruiterId = postData['ownerId'] as String;

      //check reported
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

  //recruiter report 
  Future<void> reportJobseeker({
    required String jobseekerId,
    required String postId,
    required String reason,
    required String description,
  }) async {
    try {
      final userDoc = await _authService.getUserDoc();
      final reporterId = userDoc.id;

      //vverify the post belonging
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      final postOwnerId = postData['ownerId'] as String;

      if (postOwnerId != reporterId) {
        throw Exception('You can only report jobseekers from your own posts');
      }

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

  //check recruiter reported jobseekr
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

  Future<List<ReportCategoryModel>> getReportCategoriesByUserRole() async {
    try {
      final userDoc = await _authService.getUserDoc();
      final userData = userDoc.data();
      final role = userData?['role'] as String? ?? 'jobseeker';
      
      final categoryType = role == 'jobseeker' ? 'jobseeker' : 'recruiter';
      
      return await getReportCategories(categoryType);
    } catch (e) {
      print('Error getting user role for report categories: $e');
      return [];
    }
  }

  Future<List<ReportCategoryModel>> getReportCategories(String type) async {
    try {
      final snapshot = await _firestore
          .collection('report_categories')
          .where('type', isEqualTo: type)
          .get();

      //filter  categories in memory
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
      categories.sort((a, b) => a.name.compareTo(b.name));

      return categories;
    } catch (e) {
      print('Error loading report categories for type $type: $e');
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

