class AnalyticsModel {
  final DateTime date;
  final int totalUsers;
  final int activeUsers;
  final int totalJobPosts;
  final int pendingJobPosts;
  final int approvedJobPosts;
  final int totalApplications;
  final int totalReports;
  final int pendingReports;
  final int totalMessages;
  final int reportedMessages;
  final Map<String, dynamic>? additionalMetrics;

  AnalyticsModel({
    required this.date,
    required this.totalUsers,
    required this.activeUsers,
    required this.totalJobPosts,
    required this.pendingJobPosts,
    required this.approvedJobPosts,
    required this.totalApplications,
    required this.totalReports,
    required this.pendingReports,
    required this.totalMessages,
    required this.reportedMessages,
    this.additionalMetrics,
  });

  int get inactiveUsers => totalUsers - activeUsers;
  double get activeUserPercentage =>
      totalUsers == 0 ? 0 : (activeUsers / totalUsers) * 100;
}
