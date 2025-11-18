import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/models/analytics_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch user analytics for a specific date
  Future<AnalyticsModel> getAnalytics(DateTime date) async {
    final endOfDay = DateTime(date.year, date.month, date.day + 1);

    // Fetch all users created before end of the day
    final snapshot = await _firestore
        .collection('users')
        .where('createdAt', isLessThan: endOfDay)
        .get();

    final users = snapshot.docs
        .map((doc) => UserModel.fromJson(doc.data(), doc.id))
        .toList();

    final totalUsers = users.length;
    final activeUsers = users.where((u) => u.isActive).length;
    final totalReports = users.fold<int>(0, (sum, u) => sum + u.reportCount);

    return AnalyticsModel(
      date: date,
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      totalReports: totalReports,

      // Set job & message related fields to 0
      totalJobPosts: 0,
      pendingJobPosts: 0,
      approvedJobPosts: 0,
      totalApplications: 0,
      pendingReports: 0,
      totalMessages: 0,
      reportedMessages: 0,
    );
  }

  Future<String> generateReport(DateTime startDate, DateTime endDate) async {
    return 'User report generated';
  }
}
