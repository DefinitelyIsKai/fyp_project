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

  final int newRegistrations;
  final int rejectedJobPosts;
  final int resolvedReports;
  final int dismissedReports;
  final int profileViews;
  final double avgSessionDuration; // in minutes
  final double engagementRate; // percentage
  final int totalCreditsUsed;
  final int activeSubscriptions;
  final double revenue;
  final int creditPurchases;

// All this is percentage
  final double userGrowthRate; 
  final double activeUserGrowth; 
  final double registrationGrowth; 
  final double sessionGrowth; 
  final double engagementGrowth; 
  final double applicationGrowth; 
  final double messageGrowth; 
  final double profileViewGrowth; 
  final double jobPostGrowth;
  final double reportGrowth; 
  final double reportedMessageGrowth;
  final double creditUsageGrowth; 
  final double subscriptionGrowth; 
  final double revenueGrowth; 
  final double purchaseGrowth; 

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

    this.newRegistrations = 0,
    this.rejectedJobPosts = 0,
    this.resolvedReports = 0,
    this.dismissedReports = 0,
    this.profileViews = 0,
    this.avgSessionDuration = 0.0,
    this.engagementRate = 0.0,
    this.totalCreditsUsed = 0,
    this.activeSubscriptions = 0,
    this.revenue = 0.0,
    this.creditPurchases = 0,

    this.userGrowthRate = 0.0,
    this.activeUserGrowth = 0.0,
    this.registrationGrowth = 0.0,
    this.sessionGrowth = 0.0,
    this.engagementGrowth = 0.0,
    this.applicationGrowth = 0.0,
    this.messageGrowth = 0.0,
    this.profileViewGrowth = 0.0,
    this.jobPostGrowth = 0.0,
    this.reportGrowth = 0.0,
    this.reportedMessageGrowth = 0.0,
    this.creditUsageGrowth = 0.0,
    this.subscriptionGrowth = 0.0,
    this.revenueGrowth = 0.0,
    this.purchaseGrowth = 0.0,
  });

  int get inactiveUsers => totalUsers - activeUsers;
  double get activeUserPercentage =>
      totalUsers == 0 ? 0 : (activeUsers / totalUsers) * 100;

  int get totalJobPostsProcessed => approvedJobPosts + rejectedJobPosts;
  double get jobPostApprovalRate =>
      totalJobPostsProcessed == 0 ? 0 : (approvedJobPosts / totalJobPostsProcessed) * 100;

  int get totalReportsProcessed => resolvedReports + dismissedReports + pendingReports;
  double get reportResolutionRate =>
      totalReports == 0 ? 0 : (resolvedReports / totalReports) * 100;

  double get messageReportRate =>
      totalMessages == 0 ? 0 : (reportedMessages / totalMessages) * 100;

  double get avgApplicationsPerJob =>
      totalJobPosts == 0 ? 0 : totalApplications / totalJobPosts.toDouble();

  double get avgCreditsPerUser =>
      totalUsers == 0 ? 0 : totalCreditsUsed / totalUsers.toDouble();

  double get avgRevenuePerUser =>
      totalUsers == 0 ? 0 : revenue / totalUsers.toDouble();

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsModel(
      date: DateTime.parse(json['date']),
      totalUsers: json['totalUsers'] ?? 0,
      activeUsers: json['activeUsers'] ?? 0,
      totalJobPosts: json['totalJobPosts'] ?? 0,
      pendingJobPosts: json['pendingJobPosts'] ?? 0,
      approvedJobPosts: json['approvedJobPosts'] ?? 0,
      totalApplications: json['totalApplications'] ?? 0,
      totalReports: json['totalReports'] ?? 0,
      pendingReports: json['pendingReports'] ?? 0,
      totalMessages: json['totalMessages'] ?? 0,
      reportedMessages: json['reportedMessages'] ?? 0,
      additionalMetrics: json['additionalMetrics'],

      // New fields
      newRegistrations: json['newRegistrations'] ?? 0,
      rejectedJobPosts: json['rejectedJobPosts'] ?? 0,
      resolvedReports: json['resolvedReports'] ?? 0,
      dismissedReports: json['dismissedReports'] ?? 0,
      profileViews: json['profileViews'] ?? 0,
      avgSessionDuration: (json['avgSessionDuration'] ?? 0).toDouble(),
      engagementRate: (json['engagementRate'] ?? 0).toDouble(),
      totalCreditsUsed: json['totalCreditsUsed'] ?? 0,
      activeSubscriptions: json['activeSubscriptions'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
      creditPurchases: json['creditPurchases'] ?? 0,

      // Growth rates
      userGrowthRate: (json['userGrowthRate'] ?? 0).toDouble(),
      activeUserGrowth: (json['activeUserGrowth'] ?? 0).toDouble(),
      registrationGrowth: (json['registrationGrowth'] ?? 0).toDouble(),
      sessionGrowth: (json['sessionGrowth'] ?? 0).toDouble(),
      engagementGrowth: (json['engagementGrowth'] ?? 0).toDouble(),
      applicationGrowth: (json['applicationGrowth'] ?? 0).toDouble(),
      messageGrowth: (json['messageGrowth'] ?? 0).toDouble(),
      profileViewGrowth: (json['profileViewGrowth'] ?? 0).toDouble(),
      jobPostGrowth: (json['jobPostGrowth'] ?? 0).toDouble(),
      reportGrowth: (json['reportGrowth'] ?? 0).toDouble(),
      reportedMessageGrowth: (json['reportedMessageGrowth'] ?? 0).toDouble(),
      creditUsageGrowth: (json['creditUsageGrowth'] ?? 0).toDouble(),
      subscriptionGrowth: (json['subscriptionGrowth'] ?? 0).toDouble(),
      revenueGrowth: (json['revenueGrowth'] ?? 0).toDouble(),
      purchaseGrowth: (json['purchaseGrowth'] ?? 0).toDouble(),
    );
  }

  // Convert to JSON
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

      // New fields
      'newRegistrations': newRegistrations,
      'rejectedJobPosts': rejectedJobPosts,
      'resolvedReports': resolvedReports,
      'dismissedReports': dismissedReports,
      'profileViews': profileViews,
      'avgSessionDuration': avgSessionDuration,
      'engagementRate': engagementRate,
      'totalCreditsUsed': totalCreditsUsed,
      'activeSubscriptions': activeSubscriptions,
      'revenue': revenue,
      'creditPurchases': creditPurchases,

      // Growth rates
      'userGrowthRate': userGrowthRate,
      'activeUserGrowth': activeUserGrowth,
      'registrationGrowth': registrationGrowth,
      'sessionGrowth': sessionGrowth,
      'engagementGrowth': engagementGrowth,
      'applicationGrowth': applicationGrowth,
      'messageGrowth': messageGrowth,
      'profileViewGrowth': profileViewGrowth,
      'jobPostGrowth': jobPostGrowth,
      'reportGrowth': reportGrowth,
      'reportedMessageGrowth': reportedMessageGrowth,
      'creditUsageGrowth': creditUsageGrowth,
      'subscriptionGrowth': subscriptionGrowth,
      'revenueGrowth': revenueGrowth,
      'purchaseGrowth': purchaseGrowth,
    };
  }

  // Helper method to create a copy with updated values
  AnalyticsModel copyWith({
    DateTime? date,
    int? totalUsers,
    int? activeUsers,
    int? totalJobPosts,
    int? pendingJobPosts,
    int? approvedJobPosts,
    int? totalApplications,
    int? totalReports,
    int? pendingReports,
    int? totalMessages,
    int? reportedMessages,
    Map<String, dynamic>? additionalMetrics,
    int? newRegistrations,
    int? rejectedJobPosts,
    int? resolvedReports,
    int? dismissedReports,
    int? profileViews,
    double? avgSessionDuration,
    double? engagementRate,
    int? totalCreditsUsed,
    int? activeSubscriptions,
    double? revenue,
    int? creditPurchases,
    double? userGrowthRate,
    double? activeUserGrowth,
    double? registrationGrowth,
    double? sessionGrowth,
    double? engagementGrowth,
    double? applicationGrowth,
    double? messageGrowth,
    double? profileViewGrowth,
    double? jobPostGrowth,
    double? reportGrowth,
    double? reportedMessageGrowth,
    double? creditUsageGrowth,
    double? subscriptionGrowth,
    double? revenueGrowth,
    double? purchaseGrowth,
  }) {
    return AnalyticsModel(
      date: date ?? this.date,
      totalUsers: totalUsers ?? this.totalUsers,
      activeUsers: activeUsers ?? this.activeUsers,
      totalJobPosts: totalJobPosts ?? this.totalJobPosts,
      pendingJobPosts: pendingJobPosts ?? this.pendingJobPosts,
      approvedJobPosts: approvedJobPosts ?? this.approvedJobPosts,
      totalApplications: totalApplications ?? this.totalApplications,
      totalReports: totalReports ?? this.totalReports,
      pendingReports: pendingReports ?? this.pendingReports,
      totalMessages: totalMessages ?? this.totalMessages,
      reportedMessages: reportedMessages ?? this.reportedMessages,
      additionalMetrics: additionalMetrics ?? this.additionalMetrics,
      newRegistrations: newRegistrations ?? this.newRegistrations,
      rejectedJobPosts: rejectedJobPosts ?? this.rejectedJobPosts,
      resolvedReports: resolvedReports ?? this.resolvedReports,
      dismissedReports: dismissedReports ?? this.dismissedReports,
      profileViews: profileViews ?? this.profileViews,
      avgSessionDuration: avgSessionDuration ?? this.avgSessionDuration,
      engagementRate: engagementRate ?? this.engagementRate,
      totalCreditsUsed: totalCreditsUsed ?? this.totalCreditsUsed,
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      revenue: revenue ?? this.revenue,
      creditPurchases: creditPurchases ?? this.creditPurchases,
      userGrowthRate: userGrowthRate ?? this.userGrowthRate,
      activeUserGrowth: activeUserGrowth ?? this.activeUserGrowth,
      registrationGrowth: registrationGrowth ?? this.registrationGrowth,
      sessionGrowth: sessionGrowth ?? this.sessionGrowth,
      engagementGrowth: engagementGrowth ?? this.engagementGrowth,
      applicationGrowth: applicationGrowth ?? this.applicationGrowth,
      messageGrowth: messageGrowth ?? this.messageGrowth,
      profileViewGrowth: profileViewGrowth ?? this.profileViewGrowth,
      jobPostGrowth: jobPostGrowth ?? this.jobPostGrowth,
      reportGrowth: reportGrowth ?? this.reportGrowth,
      reportedMessageGrowth: reportedMessageGrowth ?? this.reportedMessageGrowth,
      creditUsageGrowth: creditUsageGrowth ?? this.creditUsageGrowth,
      subscriptionGrowth: subscriptionGrowth ?? this.subscriptionGrowth,
      revenueGrowth: revenueGrowth ?? this.revenueGrowth,
      purchaseGrowth: purchaseGrowth ?? this.purchaseGrowth,
    );
  }

  @override
  String toString() {
    return 'AnalyticsModel(\n'
        '  date: $date,\n'
        '  totalUsers: $totalUsers,\n'
        '  activeUsers: $activeUsers,\n'
        '  totalJobPosts: $totalJobPosts,\n'
        '  engagementRate: ${engagementRate.toStringAsFixed(1)}%,\n'
        '  revenue: \$${revenue.toStringAsFixed(2)},\n'
        '  totalCreditsUsed: $totalCreditsUsed\n'
        ')';
  }
}