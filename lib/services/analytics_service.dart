import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/models/analytics_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== EXISTING FEATURES ====================

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

  // ==================== NEW ENHANCED ANALYTICS FEATURES ====================

  /// Get comprehensive analytics for a date range (30 days by default)
  Future<AnalyticsModel> getComprehensiveAnalytics(DateTime endDate) async {
    final startDate = endDate.subtract(const Duration(days: 30));

    try {
      // Execute all queries in parallel for better performance
      final futures = await Future.wait([
        _getEnhancedUserAnalytics(startDate, endDate),
        _getJobPostAnalytics(startDate, endDate),
        _getApplicationAnalytics(startDate, endDate),
        _getReportAnalytics(startDate, endDate),
        _getMessageAnalytics(startDate, endDate),
        _getPaymentAnalytics(startDate, endDate),
        _getPreviousPeriodAnalytics(startDate, endDate),
      ]);

      final userAnalytics = futures[0] as Map<String, dynamic>;
      final jobPostAnalytics = futures[1] as Map<String, dynamic>;
      final applicationAnalytics = futures[2] as Map<String, dynamic>;
      final reportAnalytics = futures[3] as Map<String, dynamic>;
      final messageAnalytics = futures[4] as Map<String, dynamic>;
      final paymentAnalytics = futures[5] as Map<String, dynamic>;
      final previousAnalytics = futures[6] as Map<String, dynamic>;

      // Calculate growth rates
      final growthRates = _calculateGrowthRates(
        currentAnalytics: {
          ...userAnalytics,
          ...jobPostAnalytics,
          ...applicationAnalytics,
          ...reportAnalytics,
          ...messageAnalytics,
          ...paymentAnalytics,
        },
        previousAnalytics: previousAnalytics,
      );

      return AnalyticsModel(
        date: endDate,
        totalUsers: userAnalytics['totalUsers'] ?? 0,
        activeUsers: userAnalytics['activeUsers'] ?? 0,
        totalJobPosts: jobPostAnalytics['totalJobPosts'] ?? 0,
        pendingJobPosts: jobPostAnalytics['pendingJobPosts'] ?? 0,
        approvedJobPosts: jobPostAnalytics['approvedJobPosts'] ?? 0,
        totalApplications: applicationAnalytics['totalApplications'] ?? 0,
        totalReports: reportAnalytics['totalReports'] ?? 0,
        pendingReports: reportAnalytics['pendingReports'] ?? 0,
        totalMessages: messageAnalytics['totalMessages'] ?? 0,
        reportedMessages: messageAnalytics['reportedMessages'] ?? 0,

        // New fields
        newRegistrations: userAnalytics['newRegistrations'] ?? 0,
        rejectedJobPosts: jobPostAnalytics['rejectedJobPosts'] ?? 0,
        resolvedReports: reportAnalytics['resolvedReports'] ?? 0,
        profileViews: userAnalytics['profileViews'] ?? 0,
        avgSessionDuration: userAnalytics['avgSessionDuration'] ?? 0.0,
        engagementRate: _calculateEngagementRate(
          activeUsers: userAnalytics['activeUsers'] ?? 0,
          totalUsers: userAnalytics['totalUsers'] ?? 0,
          totalApplications: applicationAnalytics['totalApplications'] ?? 0,
          totalMessages: messageAnalytics['totalMessages'] ?? 0,
        ),
        totalCreditsUsed: paymentAnalytics['totalCreditsUsed'] ?? 0,
        activeSubscriptions: paymentAnalytics['activeSubscriptions'] ?? 0,
        revenue: paymentAnalytics['revenue'] ?? 0.0,
        creditPurchases: paymentAnalytics['creditPurchases'] ?? 0,

        // Growth rates
        userGrowthRate: growthRates['userGrowthRate'] ?? 0.0,
        activeUserGrowth: growthRates['activeUserGrowth'] ?? 0.0,
        registrationGrowth: growthRates['registrationGrowth'] ?? 0.0,
        sessionGrowth: growthRates['sessionGrowth'] ?? 0.0,
        engagementGrowth: growthRates['engagementGrowth'] ?? 0.0,
        applicationGrowth: growthRates['applicationGrowth'] ?? 0.0,
        messageGrowth: growthRates['messageGrowth'] ?? 0.0,
        profileViewGrowth: growthRates['profileViewGrowth'] ?? 0.0,
        jobPostGrowth: growthRates['jobPostGrowth'] ?? 0.0,
        reportGrowth: growthRates['reportGrowth'] ?? 0.0,
        reportedMessageGrowth: growthRates['reportedMessageGrowth'] ?? 0.0,
        creditUsageGrowth: growthRates['creditUsageGrowth'] ?? 0.0,
        subscriptionGrowth: growthRates['subscriptionGrowth'] ?? 0.0,
        revenueGrowth: growthRates['revenueGrowth'] ?? 0.0,
        purchaseGrowth: growthRates['purchaseGrowth'] ?? 0.0,
      );
    } catch (e) {
      throw Exception('Failed to load comprehensive analytics: $e');
    }
  }

  // ==================== PRIVATE ANALYTICS METHODS ====================

  Future<Map<String, dynamic>> _getEnhancedUserAnalytics(DateTime startDate, DateTime endDate) async {
    // Total users up to the end date (all users created before or on endDate)
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final totalUsersSnapshot = await _firestore
        .collection('users')
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();
    final totalUsers = totalUsersSnapshot.docs.length;

    // Active users: users who logged in during the selected date range
    // Or users with lastLoginAt within the date range
    final activeUsersSnapshot = await _firestore
        .collection('users')
        .where('lastLoginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('lastLoginAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();
    final activeUsers = activeUsersSnapshot.docs.length;

    // New registrations in the period
    final newRegistrationsSnapshot = await _firestore
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();
    final newRegistrations = newRegistrationsSnapshot.docs.length;

    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'newRegistrations': newRegistrations,
      'profileViews': 0, // You'll need to track this separately
      'avgSessionDuration': 15.0, // You'll need to track this separately
    };
  }

  Future<Map<String, dynamic>> _getJobPostAnalytics(DateTime startDate, DateTime endDate) async {
    final jobPostsSnapshot = await _firestore.collection('job_posts').get();
    final totalJobPosts = jobPostsSnapshot.docs.length;

    // Filter by status
    final pendingJobPosts = jobPostsSnapshot.docs
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
        .length;

    final approvedJobPosts = jobPostsSnapshot.docs
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'approved')
        .length;

    final rejectedJobPosts = jobPostsSnapshot.docs
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'rejected')
        .length;

    // New job posts in the period
    final newJobPostsSnapshot = await _firestore
        .collection('job_posts')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();
    final newJobPosts = newJobPostsSnapshot.docs.length;

    return {
      'totalJobPosts': totalJobPosts,
      'pendingJobPosts': pendingJobPosts,
      'approvedJobPosts': approvedJobPosts,
      'rejectedJobPosts': rejectedJobPosts,
      'newJobPosts': newJobPosts,
    };
  }

  Future<Map<String, dynamic>> _getApplicationAnalytics(DateTime startDate, DateTime endDate) async {
    // Assuming you have an 'applications' collection
    try {
      final applicationsSnapshot = await _firestore.collection('applications').get();
      final totalApplications = applicationsSnapshot.docs.length;

      // New applications in the period
      final newApplicationsSnapshot = await _firestore
          .collection('applications')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      final newApplications = newApplicationsSnapshot.docs.length;

      return {
        'totalApplications': totalApplications,
        'newApplications': newApplications,
      };
    } catch (e) {
      // Return defaults if applications collection doesn't exist
      return {
        'totalApplications': 0,
        'newApplications': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getReportAnalytics(DateTime startDate, DateTime endDate) async {
    // Use user reports as fallback, or create a separate reports collection
    final usersSnapshot = await _firestore.collection('users').get();
    final totalReports = usersSnapshot.docs.fold<int>(0, (sum, doc) {
      final data = doc.data();
      final reportCount = data['reportCount'];
      if (reportCount is int) {
        return sum + reportCount;
      } else if (reportCount is double) {
        return sum + reportCount.toInt();
      } else {
        return sum + 0;
      }
    });

    return {
      'totalReports': totalReports,
      'pendingReports': 0, // You'll need to track this separately
      'resolvedReports': 0, // You'll need to track this separately
      'newReports': 0,
    };
  }

  Future<Map<String, dynamic>> _getMessageAnalytics(DateTime startDate, DateTime endDate) async {
    // Assuming you have a 'messages' collection
    try {
      final messagesSnapshot = await _firestore.collection('messages').get();
      final totalMessages = messagesSnapshot.docs.length;

      // New messages in the period
      final newMessagesSnapshot = await _firestore
          .collection('messages')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      final newMessages = newMessagesSnapshot.docs.length;

      return {
        'totalMessages': totalMessages,
        'reportedMessages': 0, // Replace with actual query
        'newMessages': newMessages,
      };
    } catch (e) {
      // Return defaults if messages collection doesn't exist
      return {
        'totalMessages': 0,
        'reportedMessages': 0,
        'newMessages': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getPaymentAnalytics(DateTime startDate, DateTime endDate) async {
    try {
      final paymentsSnapshot = await _firestore
          .collection('pending_payments')
          .where('status', isEqualTo: 'processed')
          .get();

      double totalRevenue = 0;
      int totalCreditsUsed = 0;
      int creditPurchases = 0;

      for (final doc in paymentsSnapshot.docs) {
        final data = doc.data();
        totalRevenue += ((data['amount'] ?? 0) as num).toDouble();
        totalCreditsUsed += ((data['credits'] ?? 0) as num).toInt();
        creditPurchases++;
      }

      // Active subscriptions (users with processed payments in last 30 days)
      final activeSubscriptionsSnapshot = await _firestore
          .collection('pending_payments')
          .where('status', isEqualTo: 'processed')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();
      final activeSubscriptions = activeSubscriptionsSnapshot.docs.length;

      return {
        'revenue': totalRevenue,
        'totalCreditsUsed': totalCreditsUsed,
        'creditPurchases': creditPurchases,
        'activeSubscriptions': activeSubscriptions,
      };
    } catch (e) {
      // Return defaults if payments collection doesn't exist or has issues
      return {
        'totalRevenue': 0.0,
        'totalCreditsUsed': 0,
        'creditPurchases': 0,
        'activeSubscriptions': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getPreviousPeriodAnalytics(DateTime startDate, DateTime endDate) async {
    final previousStartDate = startDate.subtract(const Duration(days: 30));
    final previousEndDate = startDate;

    final futures = await Future.wait([
      _getEnhancedUserAnalytics(previousStartDate, previousEndDate),
      _getJobPostAnalytics(previousStartDate, previousEndDate),
      _getApplicationAnalytics(previousStartDate, previousEndDate),
      _getReportAnalytics(previousStartDate, previousEndDate),
      _getMessageAnalytics(previousStartDate, previousEndDate),
      _getPaymentAnalytics(previousStartDate, previousEndDate),
    ]);

    return {
      ...futures[0],
      ...futures[1],
      ...futures[2],
      ...futures[3],
      ...futures[4],
      ...futures[5],
    };
  }

  double _calculateEngagementRate({
    required int activeUsers,
    required int totalUsers,
    required int totalApplications,
    required int totalMessages,
  }) {
    if (totalUsers == 0) return 0.0;

    // Simple engagement calculation - you can adjust this formula
    final applicationRate = totalApplications / totalUsers;
    final messageRate = totalMessages / totalUsers;
    final activeUserRate = activeUsers / totalUsers;

    return ((applicationRate + messageRate + activeUserRate) / 3) * 100;
  }

  Map<String, double> _calculateGrowthRates({
    required Map<String, dynamic> currentAnalytics,
    required Map<String, dynamic> previousAnalytics,
  }) {
    double _calculateGrowth(double current, double previous) {
      if (previous == 0) return current > 0 ? 100.0 : 0.0;
      return ((current - previous) / previous) * 100;
    }

    return {
      'userGrowthRate': _calculateGrowth(
        (currentAnalytics['totalUsers'] ?? 0).toDouble(),
        (previousAnalytics['totalUsers'] ?? 0).toDouble(),
      ),
      'activeUserGrowth': _calculateGrowth(
        (currentAnalytics['activeUsers'] ?? 0).toDouble(),
        (previousAnalytics['activeUsers'] ?? 0).toDouble(),
      ),
      'registrationGrowth': _calculateGrowth(
        (currentAnalytics['newRegistrations'] ?? 0).toDouble(),
        (previousAnalytics['newRegistrations'] ?? 0).toDouble(),
      ),
      'jobPostGrowth': _calculateGrowth(
        (currentAnalytics['totalJobPosts'] ?? 0).toDouble(),
        (previousAnalytics['totalJobPosts'] ?? 0).toDouble(),
      ),
      'applicationGrowth': _calculateGrowth(
        (currentAnalytics['totalApplications'] ?? 0).toDouble(),
        (previousAnalytics['totalApplications'] ?? 0).toDouble(),
      ),
      'reportGrowth': _calculateGrowth(
        (currentAnalytics['totalReports'] ?? 0).toDouble(),
        (previousAnalytics['totalReports'] ?? 0).toDouble(),
      ),
      'messageGrowth': _calculateGrowth(
        (currentAnalytics['totalMessages'] ?? 0).toDouble(),
        (previousAnalytics['totalMessages'] ?? 0).toDouble(),
      ),
      'creditUsageGrowth': _calculateGrowth(
        (currentAnalytics['totalCreditsUsed'] ?? 0).toDouble(),
        (previousAnalytics['totalCreditsUsed'] ?? 0).toDouble(),
      ),
      'revenueGrowth': _calculateGrowth(
        (currentAnalytics['totalRevenue'] ?? 0).toDouble(),
        (previousAnalytics['totalRevenue'] ?? 0).toDouble(),
      ),
      'subscriptionGrowth': _calculateGrowth(
        (currentAnalytics['activeSubscriptions'] ?? 0).toDouble(),
        (previousAnalytics['activeSubscriptions'] ?? 0).toDouble(),
      ),
      'purchaseGrowth': _calculateGrowth(
        (currentAnalytics['creditPurchases'] ?? 0).toDouble(),
        (previousAnalytics['creditPurchases'] ?? 0).toDouble(),
      ),
      // Default values for metrics that need separate tracking
      'sessionGrowth': 5.0,
      'engagementGrowth': 8.0,
      'profileViewGrowth': 12.0,
      'reportedMessageGrowth': -2.0,
    };
  }

  // ==================== ADDITIONAL UTILITY METHODS ====================

  /// Get analytics for a custom date range
  Future<AnalyticsModel> getAnalyticsForRange(DateTime startDate, DateTime endDate) async {
    try {
      // Normalize dates to start and end of day
      final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      // Calculate the period duration for comparison
      final periodDuration = normalizedEnd.difference(normalizedStart).inDays;
      final previousStartDate = normalizedStart.subtract(Duration(days: periodDuration + 1));
      final previousEndDate = normalizedStart.subtract(const Duration(seconds: 1));

      // Execute all queries in parallel for better performance
      final futures = await Future.wait([
        _getEnhancedUserAnalytics(normalizedStart, normalizedEnd),
        _getJobPostAnalytics(normalizedStart, normalizedEnd),
        _getApplicationAnalytics(normalizedStart, normalizedEnd),
        _getReportAnalytics(normalizedStart, normalizedEnd),
        _getMessageAnalytics(normalizedStart, normalizedEnd),
        _getPaymentAnalytics(normalizedStart, normalizedEnd),
        _getPreviousPeriodAnalytics(previousStartDate, previousEndDate),
      ]);

      final userAnalytics = futures[0] as Map<String, dynamic>;
      final jobPostAnalytics = futures[1] as Map<String, dynamic>;
      final applicationAnalytics = futures[2] as Map<String, dynamic>;
      final reportAnalytics = futures[3] as Map<String, dynamic>;
      final messageAnalytics = futures[4] as Map<String, dynamic>;
      final paymentAnalytics = futures[5] as Map<String, dynamic>;
      final previousAnalytics = futures[6] as Map<String, dynamic>;

      // Calculate growth rates
      final growthRates = _calculateGrowthRates(
        currentAnalytics: {
          ...userAnalytics,
          ...jobPostAnalytics,
          ...applicationAnalytics,
          ...reportAnalytics,
          ...messageAnalytics,
          ...paymentAnalytics,
        },
        previousAnalytics: previousAnalytics,
      );

      // Calculate engagement rate for the selected period
      final engagementRate = _calculateEngagementRate(
        activeUsers: userAnalytics['activeUsers'] ?? 0,
        totalUsers: userAnalytics['totalUsers'] ?? 0,
        totalApplications: applicationAnalytics['totalApplications'] ?? 0,
        totalMessages: messageAnalytics['totalMessages'] ?? 0,
      );

      return AnalyticsModel(
        date: normalizedEnd,
        totalUsers: userAnalytics['totalUsers'] ?? 0,
        activeUsers: userAnalytics['activeUsers'] ?? 0,
        totalJobPosts: jobPostAnalytics['totalJobPosts'] ?? 0,
        pendingJobPosts: jobPostAnalytics['pendingJobPosts'] ?? 0,
        approvedJobPosts: jobPostAnalytics['approvedJobPosts'] ?? 0,
        totalApplications: applicationAnalytics['totalApplications'] ?? 0,
        totalReports: reportAnalytics['totalReports'] ?? 0,
        pendingReports: reportAnalytics['pendingReports'] ?? 0,
        totalMessages: messageAnalytics['totalMessages'] ?? 0,
        reportedMessages: messageAnalytics['reportedMessages'] ?? 0,
        newRegistrations: userAnalytics['newRegistrations'] ?? 0,
        rejectedJobPosts: jobPostAnalytics['rejectedJobPosts'] ?? 0,
        resolvedReports: reportAnalytics['resolvedReports'] ?? 0,
        profileViews: userAnalytics['profileViews'] ?? 0,
        avgSessionDuration: userAnalytics['avgSessionDuration'] ?? 0.0,
        engagementRate: engagementRate,
        totalCreditsUsed: paymentAnalytics['totalCreditsUsed'] ?? 0,
        activeSubscriptions: paymentAnalytics['activeSubscriptions'] ?? 0,
        revenue: paymentAnalytics['revenue'] ?? 0.0,
        creditPurchases: paymentAnalytics['creditPurchases'] ?? 0,

        // Growth rates
        userGrowthRate: growthRates['userGrowthRate'] ?? 0.0,
        activeUserGrowth: growthRates['activeUserGrowth'] ?? 0.0,
        registrationGrowth: growthRates['registrationGrowth'] ?? 0.0,
        sessionGrowth: growthRates['sessionGrowth'] ?? 0.0,
        engagementGrowth: growthRates['engagementGrowth'] ?? 0.0,
        applicationGrowth: growthRates['applicationGrowth'] ?? 0.0,
        messageGrowth: growthRates['messageGrowth'] ?? 0.0,
        profileViewGrowth: growthRates['profileViewGrowth'] ?? 0.0,
        jobPostGrowth: growthRates['jobPostGrowth'] ?? 0.0,
        reportGrowth: growthRates['reportGrowth'] ?? 0.0,
        reportedMessageGrowth: growthRates['reportedMessageGrowth'] ?? 0.0,
        creditUsageGrowth: growthRates['creditUsageGrowth'] ?? 0.0,
        subscriptionGrowth: growthRates['subscriptionGrowth'] ?? 0.0,
        revenueGrowth: growthRates['revenueGrowth'] ?? 0.0,
        purchaseGrowth: growthRates['purchaseGrowth'] ?? 0.0,
      );
    } catch (e) {
      throw Exception('Failed to load analytics for range: $e');
    }
  }

  /// Get real-time analytics stream
  Stream<AnalyticsModel> getAnalyticsStream() {
    return Stream.periodic(const Duration(minutes: 5), (_) => DateTime.now())
        .asyncMap((date) => getComprehensiveAnalytics(date))
        .handleError((error) {
      print('Analytics stream error: $error');
    });
  }

  /// Enhanced report generation with comprehensive data
  Future<String> generateComprehensiveReport(DateTime startDate, DateTime endDate) async {
    final analytics = await getComprehensiveAnalytics(endDate);

    final report = '''
Comprehensive Analytics Report
Period: ${startDate.toLocal()} to ${endDate.toLocal()}

USER STATISTICS:
- Total Users: ${analytics.totalUsers}
- Active Users: ${analytics.activeUsers}
- New Registrations: ${analytics.newRegistrations}
- User Growth: ${analytics.userGrowthRate.toStringAsFixed(1)}%

ENGAGEMENT METRICS:
- Engagement Rate: ${analytics.engagementRate.toStringAsFixed(1)}%
- Total Applications: ${analytics.totalApplications}
- Total Messages: ${analytics.totalMessages}

CONTENT STATISTICS:
- Total Job Posts: ${analytics.totalJobPosts}
- Pending Job Posts: ${analytics.pendingJobPosts}
- Approved Job Posts: ${analytics.approvedJobPosts}

FINANCIAL METRICS:
- Total Revenue: \$${analytics.revenue.toStringAsFixed(2)}
- Credits Used: ${analytics.totalCreditsUsed}
- Active Subscriptions: ${analytics.activeSubscriptions}

Generated on: ${DateTime.now().toLocal()}
    ''';

    return report;
  }
}