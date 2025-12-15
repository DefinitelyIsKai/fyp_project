import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/models/admin/analytics_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AnalyticsModel> getAnalytics(DateTime date) async {
    final endOfDay = DateTime(date.year, date.month, date.day + 1);

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

  Future<AnalyticsModel> getComprehensiveAnalytics(DateTime endDate) async {
    final startDate = endDate.subtract(const Duration(days: 30));

    try {
      
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

      final currentEngagementRate = currentEngagementRateUncapped > 100.0 ? 100.0 : currentEngagementRateUncapped;
      final previousEngagementRate = previousEngagementRateUncapped > 100.0 ? 100.0 : previousEngagementRateUncapped;

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

        newRegistrations: userAnalytics['newRegistrations'] ?? 0,
        rejectedJobPosts: jobPostAnalytics['rejectedJobPosts'] ?? 0,
        resolvedReports: reportAnalytics['resolvedReports'] ?? 0,
        dismissedReports: reportAnalytics['dismissedReports'] ?? 0,
        profileViews: userAnalytics['profileViews'] ?? 0,
        engagementRate: currentEngagementRate,
        totalCreditsUsed: paymentAnalytics['totalCreditsUsed'] ?? 0,
        activeSubscriptions: paymentAnalytics['activeSubscriptions'] ?? 0,
        revenue: paymentAnalytics['revenue'] ?? 0.0,
        creditPurchases: paymentAnalytics['creditPurchases'] ?? 0,

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

  Future<Map<String, dynamic>> _getEnhancedUserAnalytics(DateTime startDate, DateTime endDate) async {
    
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final totalUsersSnapshot = await _firestore
        .collection('users')
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();
    
    final allUsers = totalUsersSnapshot.docs
        .map((doc) => UserModel.fromJson(doc.data(), doc.id))
        .toList();
    
    final totalUsers = allUsers.length;
    
    final activeUsers = allUsers.where((user) {
      
      return user.isActive && 
             user.status != 'Deleted' && 
             user.status != 'Suspended';
    }).length;

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
      'profileViews': 0, 
    };
  }

  Future<Map<String, dynamic>> _getJobPostAnalytics(DateTime startDate, DateTime endDate) async {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    
    final allPostsSnapshot = await _firestore.collection('posts').get();
    final allPosts = allPostsSnapshot.docs;
    
    final postsInPeriod = allPosts.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final date = createdAt.toDate();
      return date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
             date.isBefore(endOfDay.add(const Duration(seconds: 1)));
    }).toList();

    final totalJobPosts = postsInPeriod.length;

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
      'approvedJobPosts': approvedJobPosts, 
      'rejectedJobPosts': rejectedJobPosts,
      'completedJobPosts': completedJobPosts,
      'newJobPosts': totalJobPosts, 
    };
  }

  Future<Map<String, dynamic>> _getApplicationAnalytics(DateTime startDate, DateTime endDate) async {
    
    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      final applicationsSnapshot = await _firestore
          .collection('applications')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      final totalApplications = applicationsSnapshot.docs.length;

      return {
        'totalApplications': totalApplications, 
        'newApplications': totalApplications,
      };
    } catch (e) {
      
      return {
        'totalApplications': 0,
        'newApplications': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getReportAnalytics(DateTime startDate, DateTime endDate) async {
    
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    
    try {
      final allReportsSnapshot = await _firestore.collection('reports').get();
      final allReports = allReportsSnapshot.docs;
      
      final reportsInPeriod = allReports.where((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        
        final date = createdAt.toDate();
        
        final reportDate = DateTime(date.year, date.month, date.day);
        final startDateOnly = DateTime(startOfDay.year, startOfDay.month, startOfDay.day);
        final endDateOnly = DateTime(endOfDay.year, endOfDay.month, endOfDay.day);
        
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
    
    try {
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      final startTimestamp = Timestamp.fromDate(startOfDay);
      final endTimestamp = Timestamp.fromDate(endOfDay);
      
      int newMessages = 0;
      
      final conversationsSnapshot = await _firestore.collection('conversations').get();
      
      const batchSize = 10;
      final conversationDocs = conversationsSnapshot.docs;
      
      for (int i = 0; i < conversationDocs.length; i += batchSize) {
        final batch = conversationDocs.skip(i).take(batchSize).toList();
        
        final batchResults = await Future.wait(
          batch.map((conversationDoc) async {
            try {
              QuerySnapshot messagesSnapshot;
              try {
                messagesSnapshot = await conversationDoc.reference
                    .collection('messages')
                    .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
                    .where('createdAt', isLessThanOrEqualTo: endTimestamp)
                    .get();
                return messagesSnapshot.docs.length;
              } catch (e) {
                try {
                  messagesSnapshot = await conversationDoc.reference
                      .collection('messages')
                      .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
                      .where('timestamp', isLessThanOrEqualTo: endTimestamp)
                      .get();
                  return messagesSnapshot.docs.length;
                } catch (e2) {
                  final allMessagesSnapshot = await conversationDoc.reference
                      .collection('messages')
                      .limit(1000)
                      .get();
                  
                  int count = 0;
                  for (final messageDoc in allMessagesSnapshot.docs) {
                    final messageData = messageDoc.data() as Map<String, dynamic>?;
                    if (messageData == null) continue;
                    
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
                        if (messageDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                            messageDate.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
                          count++;
                        }
                      }
                    }
                  }
                  return count;
                }
              }
            } catch (e) {
              return 0;
            }
          }),
        );
        
        newMessages += batchResults.fold<int>(0, (sum, count) => sum + count);
      }

      return {
        'totalMessages': newMessages, 
        'reportedMessages': 0, 
        'newMessages': newMessages,
      };
    } catch (e) {
      print('Error getting message analytics: $e');
      
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
      
      final allPaymentsSnapshot = await _firestore
          .collection('pending_payments')
          .where('status', isEqualTo: 'processed')
          .get();
      
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
      
      return {
        'revenue': 0.0,
        'totalCreditsUsed': 0,
        'creditPurchases': 0,
        'activeSubscriptions': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getCreditLogs(DateTime startDate, DateTime endDate) async {
    try {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      final allPaymentsSnapshot = await _firestore
          .collection('pending_payments')
          .get();
      
      final filteredDocs = allPaymentsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        final date = createdAt.toDate();
        return date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
               date.isBefore(endOfDay.add(const Duration(seconds: 1)));
      }).toList();
      
      filteredDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aDate = (aData?['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bDate = (bData?['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      
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
    
    final periodDuration = endDate.difference(startDate);
    
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

    final applicationRate = totalApplications / totalUsers;
    final messageRate = totalMessages / totalUsers;
    final activeUserRate = activeUsers / totalUsers;

    return ((applicationRate + messageRate + activeUserRate) / 3) * 100;
  }

  Map<String, double> _calculateGrowthRates({
    required Map<String, dynamic> currentAnalytics,
    required Map<String, dynamic> previousAnalytics,
  }) {
    
    const double newDataIndicator = -999.0;
    
    double _calculateGrowth(double current, double previous) {
      if (previous == 0) {
        
        if (current > 0) return newDataIndicator;
        
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
      
      'engagementGrowth': _calculateGrowth(
        (currentAnalytics['engagementRate'] ?? 0).toDouble(),
        (previousAnalytics['engagementRate'] ?? 0).toDouble(),
      ),
      
      'sessionGrowth': 5.0,
      'profileViewGrowth': 12.0,
      'reportedMessageGrowth': -2.0,
    };
  }

  Future<AnalyticsModel> getAnalyticsForRange(DateTime startDate, DateTime endDate) async {
    try {
      
      final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      final periodDuration = normalizedEnd.difference(normalizedStart).inDays;
      final previousStartDate = normalizedStart.subtract(Duration(days: periodDuration + 1));
      final previousEndDate = normalizedStart.subtract(const Duration(seconds: 1));

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

      final currentEngagementRate = currentEngagementRateUncapped > 100.0 ? 100.0 : currentEngagementRateUncapped;
      final previousEngagementRate = previousEngagementRateUncapped > 100.0 ? 100.0 : previousEngagementRateUncapped;

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
        engagementRate: currentEngagementRate,
        totalCreditsUsed: paymentAnalytics['totalCreditsUsed'] ?? 0,
        activeSubscriptions: paymentAnalytics['activeSubscriptions'] ?? 0,
        revenue: paymentAnalytics['revenue'] ?? 0.0,
        creditPurchases: paymentAnalytics['creditPurchases'] ?? 0,

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

  Stream<AnalyticsModel> getAnalyticsStream() {
    return Stream.periodic(const Duration(minutes: 5), (_) => DateTime.now())
        .asyncMap((date) => getComprehensiveAnalytics(date))
        .handleError((error) {
      print('Analytics stream error: $error');
    });
  }

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