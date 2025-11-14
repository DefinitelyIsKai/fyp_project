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

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsModel(
      date: DateTime.parse(json['date'] as String),
      totalUsers: json['totalUsers'] as int,
      activeUsers: json['activeUsers'] as int,
      totalJobPosts: json['totalJobPosts'] as int,
      pendingJobPosts: json['pendingJobPosts'] as int,
      approvedJobPosts: json['approvedJobPosts'] as int,
      totalApplications: json['totalApplications'] as int,
      totalReports: json['totalReports'] as int,
      pendingReports: json['pendingReports'] as int,
      totalMessages: json['totalMessages'] as int,
      reportedMessages: json['reportedMessages'] as int,
      additionalMetrics: json['additionalMetrics'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'totalJobPosts': totalJobPosts,
      'pendingJobPosts': pendingJobPosts,
      'approvedJobPosts': approvedJobPosts,
      'totalApplications': totalApplications,
      'totalReports': totalReports,
      'pendingReports': pendingReports,
      'totalMessages': totalMessages,
      'reportedMessages': reportedMessages,
      'additionalMetrics': additionalMetrics,
    };
  }
}

