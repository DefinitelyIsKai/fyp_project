import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/models/admin/analytics_model.dart';

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

      // Calculate engagement rates for both periods
      final currentEngagementRateUncapped = _calculateEngagementRate(
        activeUsers: userAnalytics['activeUsers'] ?? 0,
        totalUsers: userAnalytics['totalUsers'] ?? 0,
        totalApplications: applicationAnalytics['totalApplications'] ?? 0,
        totalMessages: messageAnalytics['totalMessages'] ?? 0,
      );
      
      final previousEngagementRateUncapped = _calculateEngagementRate(
        activeUsers: previousAnalytics['activeUsers'] ?? 0,
        totalUsers: previousAnalytics['totalUsers'] ?? 0,
        totalApplications: previousAnalytics['totalApplications'] ?? 0,
        totalMessages: previousAnalytics['totalMessages'] ?? 0,
      );

      // Cap engagement rates at 100% before calculating growth
      final currentEngagementRate = currentEngagementRateUncapped > 100.0 ? 100.0 : currentEngagementRateUncapped;
      final previousEngagementRate = previousEngagementRateUncapped > 100.0 ? 100.0 : previousEngagementRateUncapped;

      // Calculate growth rates
      final growthRates = _calculateGrowthRates(
        currentAnalytics: {
          ...userAnalytics,
          ...jobPostAnalytics,
          ...applicationAnalytics,
          ...reportAnalytics,
          ...messageAnalytics,
          ...paymentAnalytics,
          'engagementRate': currentEngagementRate,
        },
        previousAnalytics: {
          ...previousAnalytics,
          'engagementRate': previousEngagementRate,
        },
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
        dismissedReports: reportAnalytics['dismissedReports'] ?? 0,
        profileViews: userAnalytics['profileViews'] ?? 0,
        avgSessionDuration: userAnalytics['avgSessionDuration'] ?? 0.0,
        engagementRate: currentEngagementRate,
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
    
    // Parse all users to check their active status
    final allUsers = totalUsersSnapshot.docs
        .map((doc) => UserModel.fromJson(doc.data(), doc.id))
        .toList();
    
    final totalUsers = allUsers.length;
    
    // Active users: count users who are currently active (based on isActive field and status)
    // Exclude deleted and suspended users
    final activeUsers = allUsers.where((user) {
      // User is active if:
      // 1. isActive is true AND
      // 2. status is not 'Deleted' AND
      // 3. status is not 'Suspended'
      return user.isActive && 
             user.status != 'Deleted' && 
             user.status != 'Suspended';
    }).length;

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
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    
    // Get all posts from 'posts' collection
    final allPostsSnapshot = await _firestore.collection('posts').get();
    final allPosts = allPostsSnapshot.docs;
    
    // Filter posts created in the period
    final postsInPeriod = allPosts.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final date = createdAt.toDate();
      return date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
             date.isBefore(endOfDay.add(const Duration(seconds: 1)));
    }).toList();

    // Total posts in the period
    final totalJobPosts = postsInPeriod.length;

    // Filter by status for period posts (pending, active, completed, rejected)
    final pendingJobPosts = postsInPeriod
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
        .length;

    final approvedJobPosts = postsInPeriod
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'active')
        .length;

    final rejectedJobPosts = postsInPeriod
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'rejected')
        .length;
    
    final completedJobPosts = postsInPeriod
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'completed')
        .length;

    return {
      'totalJobPosts': totalJobPosts,
      'pendingJobPosts': pendingJobPosts,
      'approvedJobPosts': approvedJobPosts, // This represents 'active' status
      'rejectedJobPosts': rejectedJobPosts,
      'completedJobPosts': completedJobPosts,
      'newJobPosts': totalJobPosts, // Same as total for period
    };
  }

  Future<Map<String, dynamic>> _getApplicationAnalytics(DateTime startDate, DateTime endDate) async {
    // Get applications within the date range only
    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      // Applications in the period
      final applicationsSnapshot = await _firestore
          .collection('applications')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      final totalApplications = applicationsSnapshot.docs.length;

      return {
        'totalApplications': totalApplications, // Only count applications within the date range
        'newApplications': totalApplications,
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
    // Normalize dates to start and end of day in local timezone
    // toDate() from Firestore returns local time, so we compare in local time
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    
    // Try to get from reports collection first
    try {
      final allReportsSnapshot = await _firestore.collection('reports').get();
      final allReports = allReportsSnapshot.docs;
      
      // Filter reports created in the period (inclusive of both boundaries)
      final reportsInPeriod = allReports.where((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        // toDate() returns local time, so we compare in local time
        final date = createdAt.toDate();
        // Compare only the date part (year, month, day) to avoid timezone issues
        final reportDate = DateTime(date.year, date.month, date.day);
        final startDateOnly = DateTime(startOfDay.year, startOfDay.month, startOfDay.day);
        final endDateOnly = DateTime(endOfDay.year, endOfDay.month, endOfDay.day);
        // Use inclusive comparison: reportDate >= startDateOnly && reportDate <= endDateOnly
        return reportDate.compareTo(startDateOnly) >= 0 && reportDate.compareTo(endDateOnly) <= 0;
      }).toList();
      
      final totalReports = reportsInPeriod.length;
      final pendingReports = reportsInPeriod
          .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
          .length;
      final resolvedReports = reportsInPeriod
          .where((doc) => (doc.data()['status'] ?? 'pending') == 'resolved')
          .length;
      final dismissedReports = reportsInPeriod
          .where((doc) => (doc.data()['status'] ?? 'pending') == 'dismissed')
          .length;
      
      return {
        'totalReports': totalReports,
        'pendingReports': pendingReports,
        'resolvedReports': resolvedReports,
        'dismissedReports': dismissedReports,
        'newReports': totalReports,
      };
    } catch (e) {
      // Fallback to user reportCount if reports collection doesn't exist
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
        'pendingReports': 0,
        'resolvedReports': 0,
        'dismissedReports': 0,
        'newReports': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getMessageAnalytics(DateTime startDate, DateTime endDate) async {
    // Fetch messages from conversations collection -> messages subcollection
    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      // Get all conversations
      final conversationsSnapshot = await _firestore.collection('conversations').get();
      
      int totalMessages = 0;
      int newMessages = 0;
      
      print('Found ${conversationsSnapshot.docs.length} conversations');
      
      // Iterate through each conversation and get messages from subcollection
      for (final conversationDoc in conversationsSnapshot.docs) {
        try {
          // Get messages subcollection for this conversation
          final messagesSnapshot = await conversationDoc.reference
              .collection('messages')
              .get();
          
          final messageCount = messagesSnapshot.docs.length;
          totalMessages += messageCount;
          
          print('Conversation ${conversationDoc.id} has $messageCount messages');
          
          // Count new messages in the period
          for (final messageDoc in messagesSnapshot.docs) {
            final messageData = messageDoc.data() as Map<String, dynamic>?;
            if (messageData == null) continue;
            
            // Try different possible field names for timestamp
            dynamic timestampValue = messageData['createdAt'] ?? 
                                    messageData['timestamp'] ?? 
                                    messageData['sentAt'] ??
                                    messageData['time'];
            
            if (timestampValue != null) {
              DateTime? messageDate;
              
              if (timestampValue is Timestamp) {
                messageDate = timestampValue.toDate();
              } else if (timestampValue is DateTime) {
                messageDate = timestampValue;
              } else if (timestampValue is int) {
                messageDate = DateTime.fromMillisecondsSinceEpoch(timestampValue);
              } else if (timestampValue is String) {
                messageDate = DateTime.tryParse(timestampValue);
              }
              
              if (messageDate != null) {
                if (messageDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
                    messageDate.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
                  newMessages++;
                }
              }
            }
          }
        } catch (e) {
          // Skip conversations that don't have messages subcollection or have errors
          print('Error fetching messages for conversation ${conversationDoc.id}: $e');
        }
      }

      print('Total messages: $totalMessages, New messages in period: $newMessages');

      return {
        'totalMessages': newMessages, // Only count messages within the date range
        'reportedMessages': 0, // Replace with actual query if needed
        'newMessages': newMessages,
      };
    } catch (e) {
      print('Error getting message analytics: $e');
      // Return defaults if conversations collection doesn't exist
      return {
        'totalMessages': 0,
        'reportedMessages': 0,
        'newMessages': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getPaymentAnalytics(DateTime startDate, DateTime endDate) async {
    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      // Get processed payments - filter by status only to avoid index requirement
      // Then filter by date range client-side
      final allPaymentsSnapshot = await _firestore
          .collection('pending_payments')
          .where('status', isEqualTo: 'processed')
          .get();
      
      // Filter by date range client-side
      final paymentDocs = allPaymentsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        final date = createdAt.toDate();
        return date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
               date.isBefore(endOfDay.add(const Duration(seconds: 1)));
      }).cast<QueryDocumentSnapshot<Map<String, dynamic>>>().toList();

      double totalRevenue = 0;
      int totalCreditsUsed = 0;
      int creditPurchases = 0;

      for (final doc in paymentDocs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          totalRevenue += ((data['amount'] ?? 0) as num).toDouble();
          totalCreditsUsed += ((data['credits'] ?? 0) as num).toInt();
          creditPurchases++;
        }
      }

      // Active subscriptions (users with processed payments in the date range)
      final activeSubscriptions = paymentDocs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data != null ? (data['uid'] as String?) : null;
          })
          .where((uid) => uid != null)
          .toSet()
          .length;

      return {
        'revenue': totalRevenue,
        'totalCreditsUsed': totalCreditsUsed,
        'creditPurchases': creditPurchases,
        'activeSubscriptions': activeSubscriptions,
      };
    } catch (e) {
      print('Error getting payment analytics: $e');
      // Return defaults if payments collection doesn't exist or has issues
      return {
        'revenue': 0.0,
        'totalCreditsUsed': 0,
        'creditPurchases': 0,
        'activeSubscriptions': 0,
      };
    }
  }

  /// Get credit logs (payment transactions) for a date range
  Future<List<Map<String, dynamic>>> getCreditLogs(DateTime startDate, DateTime endDate) async {
    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      // Get all payments and filter/sort client-side to avoid index requirement
      final allPaymentsSnapshot = await _firestore
          .collection('pending_payments')
          .get();
      
      // Filter by date range and sort client-side
      final filteredDocs = allPaymentsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        final date = createdAt.toDate();
        return date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
               date.isBefore(endOfDay.add(const Duration(seconds: 1)));
      }).toList();
      
      // Sort by createdAt descending
      filteredDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aDate = (aData?['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bDate = (bData?['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      
      // Limit to 100 most recent and cast to proper type
      final paymentDocs = filteredDocs.take(100).cast<QueryDocumentSnapshot<Map<String, dynamic>>>().toList();

      return paymentDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) {
          return {
            'id': doc.id,
            'uid': '',
            'amount': 0.0,
            'credits': 0,
            'status': 'pending',
            'sessionId': '',
            'createdAt': DateTime.now(),
          };
        }
        return {
          'id': doc.id,
          'uid': data['uid'] as String? ?? '',
          'amount': ((data['amount'] ?? 0) as num).toDouble(),
          'credits': ((data['credits'] ?? 0) as num).toInt(),
          'status': data['status'] as String? ?? 'pending',
          'sessionId': data['sessionId'] as String? ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('Error getting credit logs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _getPreviousPeriodAnalytics(DateTime startDate, DateTime endDate) async {
    // Calculate the duration of the current period
    final periodDuration = endDate.difference(startDate);
    
    // Previous period should be the same length, ending just before the current period starts
    final previousEndDate = startDate.subtract(const Duration(seconds: 1));
    final previousStartDate = previousEndDate.subtract(periodDuration);

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
    // Special value to indicate "new" data (previous was 0, current > 0)
    // Using -999 as a sentinel value that UI can detect
    const double newDataIndicator = -999.0;
    
    double _calculateGrowth(double current, double previous) {
      if (previous == 0) {
        // If previous was 0 and current > 0, return special indicator for "new"
        if (current > 0) return newDataIndicator;
        // If both are 0, return 0 (no change)
        return 0.0;
      }
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
      // Calculate engagement growth from engagement rates
      'engagementGrowth': _calculateGrowth(
        (currentAnalytics['engagementRate'] ?? 0).toDouble(),
        (previousAnalytics['engagementRate'] ?? 0).toDouble(),
      ),
      // Default values for metrics that need separate tracking
      'sessionGrowth': 5.0,
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

      // Calculate engagement rates for both periods
      final currentEngagementRateUncapped = _calculateEngagementRate(
        activeUsers: userAnalytics['activeUsers'] ?? 0,
        totalUsers: userAnalytics['totalUsers'] ?? 0,
        totalApplications: applicationAnalytics['totalApplications'] ?? 0,
        totalMessages: messageAnalytics['totalMessages'] ?? 0,
      );
      
      final previousEngagementRateUncapped = _calculateEngagementRate(
        activeUsers: previousAnalytics['activeUsers'] ?? 0,
        totalUsers: previousAnalytics['totalUsers'] ?? 0,
        totalApplications: previousAnalytics['totalApplications'] ?? 0,
        totalMessages: previousAnalytics['totalMessages'] ?? 0,
      );

      // Cap engagement rates at 100% before calculating growth
      final currentEngagementRate = currentEngagementRateUncapped > 100.0 ? 100.0 : currentEngagementRateUncapped;
      final previousEngagementRate = previousEngagementRateUncapped > 100.0 ? 100.0 : previousEngagementRateUncapped;

      // Calculate growth rates
      final growthRates = _calculateGrowthRates(
        currentAnalytics: {
          ...userAnalytics,
          ...jobPostAnalytics,
          ...applicationAnalytics,
          ...reportAnalytics,
          ...messageAnalytics,
          ...paymentAnalytics,
          'engagementRate': currentEngagementRate,
        },
        previousAnalytics: {
          ...previousAnalytics,
          'engagementRate': previousEngagementRate,
        },
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
        dismissedReports: reportAnalytics['dismissedReports'] ?? 0,
        profileViews: userAnalytics['profileViews'] ?? 0,
        avgSessionDuration: userAnalytics['avgSessionDuration'] ?? 0.0,
        engagementRate: currentEngagementRate,
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