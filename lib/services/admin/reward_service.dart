import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

class RewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference<Map<String, dynamic>> _reviewsRef =
      FirebaseFirestore.instance.collection('reviews');
  final CollectionReference<Map<String, dynamic>> _applicationsRef =
      FirebaseFirestore.instance.collection('applications');
  final CollectionReference<Map<String, dynamic>> _postsRef =
      FirebaseFirestore.instance.collection('posts');
  final CollectionReference<Map<String, dynamic>> _walletsRef =
      FirebaseFirestore.instance.collection('wallets');
  final CollectionReference<Map<String, dynamic>> _usersRef =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference<Map<String, dynamic>> _logsRef =
      FirebaseFirestore.instance.collection('logs');
  final CollectionReference<Map<String, dynamic>> _notificationsRef =
      FirebaseFirestore.instance.collection('notifications');

  /// Preview eligible users for monthly rewards (simplified and optimized)
  Future<Map<String, dynamic>> previewEligibleUsers({
    DateTime? month,
    double minRating = 4.0,
    int minCompletedTasks = 3,
    int rewardAmount = 100,
  }) async {
    try {
      final targetMonth = month ?? _getCurrentMonth();
      final monthStart = DateTime(targetMonth.year, targetMonth.month, 1);
      final monthEnd = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);
      final monthStr = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';

      // Ensure UI has a chance to update before starting
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));

      // Step 1: Get completed post IDs in the month
      final completedPostIds = await _getCompletedPostIds(monthStart, monthEnd);
      
      // Yield after posts query
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 20));
      
      if (completedPostIds.isEmpty) {
        return {
          'success': true,
          'eligibleUsers': [],
          'totalEligible': 0,
          'month': monthStr,
          'completedPostsCount': 0,
          'message': 'No completed posts found for this month',
        };
      }

      // Step 2: Get approved applications for completed posts (batch query)
      final applications = await _getApprovedApplicationsForPosts(completedPostIds);
      
      // Yield after applications query
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 20));
      
      if (applications.isEmpty) {
        return {
          'success': true,
          'eligibleUsers': [],
          'totalEligible': 0,
          'month': monthStr,
          'completedPostsCount': completedPostIds.length,
          'message': 'No approved applications found for completed posts',
        };
      }

      // Step 3: Count completed posts per jobseeker (in-memory, fast)
      final jobseekerPostCounts = <String, int>{};
      final jobseekerPostIds = <String, List<String>>{};
      
      for (final app in applications) {
        final jobseekerId = app['jobseekerId'] as String?;
        final postId = app['postId'] as String?;
        if (jobseekerId != null && postId != null) {
          jobseekerPostCounts[jobseekerId] = (jobseekerPostCounts[jobseekerId] ?? 0) + 1;
          jobseekerPostIds.putIfAbsent(jobseekerId, () => []).add(postId);
        }
      }

      // Step 4: Filter by min posts requirement
      final candidateJobseekers = jobseekerPostCounts.entries
          .where((e) => e.value >= minCompletedTasks)
          .map((e) => e.key)
          .toList();

      // Yield before processing candidates
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 20));

      if (candidateJobseekers.isEmpty) {
        return {
          'success': true,
          'eligibleUsers': [],
          'totalEligible': 0,
          'month': monthStr,
          'completedPostsCount': completedPostIds.length,
          'message': 'No jobseekers meet the minimum posts requirement',
        };
      }

      // Step 5: Get user data and ratings for candidates (process one by one with aggressive yields)
      final eligibleUsers = <Map<String, dynamic>>[];
      
      for (int i = 0; i < candidateJobseekers.length; i++) {
        // Aggressive yielding - yield before every user
        await SchedulerBinding.instance.endOfFrame;
        await Future.delayed(Duration.zero);
        await Future.microtask(() {});
        await Future.delayed(const Duration(milliseconds: 15)); // Let UI breathe
        
        final jobseekerId = candidateJobseekers[i];
        
        try {
          // Get user data with timeout
          final userDoc = await _usersRef.doc(jobseekerId).get().timeout(
            const Duration(seconds: 2),
          );
          
          // Yield after user fetch
          await Future.microtask(() {});
          
          if (!userDoc.exists) {
            continue;
          }
          final userData = userDoc.data();
          if (userData == null) {
            continue;
          }
          
          final role = userData['role'] as String? ?? '';
          if (role == 'manager' || role == 'hr' || role == 'staff') {
            continue;
          }
          
          // Get average rating (simple query like review_service)
          final avgRating = await _getAverageRatingForJobseeker(jobseekerId, monthStart, monthEnd);
          
          // Yield after rating fetch
          await Future.microtask(() {});
          
          // Check if qualifies
          if (avgRating >= minRating) {
            eligibleUsers.add({
              'userId': jobseekerId,
              'userName': userData['fullName'] ?? 'Unknown User',
              'userEmail': userData['email'] ?? '',
              'averageRating': avgRating,
              'completedTasks': jobseekerPostCounts[jobseekerId] ?? 0,
              'rewardAmount': rewardAmount,
              'postIds': jobseekerPostIds[jobseekerId] ?? [],
            });
          }
        } catch (e) {
          continue;
        }
      }

      return {
        'success': true,
        'eligibleUsers': eligibleUsers,
        'totalEligible': eligibleUsers.length,
        'month': monthStr,
        'completedPostsCount': completedPostIds.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'eligibleUsers': [],
        'totalEligible': 0,
      };
    }
  }

  /// Get completed post IDs for a month (simplified)
  Future<List<String>> _getCompletedPostIds(DateTime monthStart, DateTime monthEnd) async {
    try {
      final snapshot = await _postsRef
          .where('status', isEqualTo: 'completed')
          .limit(200)
          .get()
          .timeout(const Duration(seconds: 5));

      final postIds = <String>[];
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        final checkDate = completedAt ?? updatedAt ?? createdAt;
        if (checkDate != null &&
            checkDate.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            checkDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
          postIds.add(doc.id);
        }
      }
      return postIds;
    } catch (e) {
      return [];
    }
  }

  /// Get approved applications for completed posts (batch query with aggressive yields)
  Future<List<Map<String, dynamic>>> _getApprovedApplicationsForPosts(List<String> postIds) async {
    final allApplications = <Map<String, dynamic>>[];
    
    // Query in batches of 10 (Firestore whereIn limit)
    for (int i = 0; i < postIds.length; i += 10) {
      // Aggressive yielding before each batch
      await Future.delayed(Duration.zero);
      await Future.microtask(() {});
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 20)); // Let UI breathe
      }
      
      final batch = postIds.skip(i).take(10).toList();
      try {
        final snapshot = await _applicationsRef
            .where('postId', whereIn: batch)
            .where('status', isEqualTo: 'approved')
            .get()
            .timeout(const Duration(seconds: 3)); // Shorter timeout
        
        // Yield after query
        await Future.microtask(() {});
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          allApplications.add({
            'jobseekerId': data['jobseekerId'],
            'postId': data['postId'],
          });
        }
      } catch (e) {
        // Error fetching applications batch - continue
      }
    }
    
    return allApplications;
  }

  /// Get average rating for a jobseeker in a month (simplified like review_service)
  Future<double> _getAverageRatingForJobseeker(
    String jobseekerId,
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    try {
      final snapshot = await _reviewsRef
          .where('jobseekerId', isEqualTo: jobseekerId)
          .get()
          .timeout(const Duration(seconds: 2)); // Shorter timeout

      if (snapshot.docs.isEmpty) {
        return 0.0;
      }

      final ratings = <double>[];
      // Process in chunks with yields
      final docs = snapshot.docs;
      for (int i = 0; i < docs.length; i++) {
        // Yield every 10 docs
        if (i > 0 && i % 10 == 0) {
          await Future.microtask(() {});
        }
        
        final doc = docs[i];
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null &&
            createdAt.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            createdAt.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
          final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
          if (rating > 0) {
            ratings.add(rating);
          }
        }
      }

      if (ratings.isEmpty) {
        return 0.0;
      }
      final avg = ratings.fold<double>(0.0, (sum, r) => sum + r) / ratings.length;
      return avg;
    } catch (e) {
      return 0.0;
    }
  }

  /// Calculate monthly rewards for users based on ratings and completed tasks
  Future<Map<String, dynamic>> calculateMonthlyRewards({
    DateTime? month,
    double minRating = 4.0,
    int minCompletedTasks = 3,
    int rewardAmount = 100,
  }) async {
    try {
      final targetMonth = month ?? _getCurrentMonth();
      final monthStr = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';

      // Use preview to get eligible users
      await Future.delayed(Duration.zero);
      final previewResult = await previewEligibleUsers(
        month: targetMonth,
        minRating: minRating,
        minCompletedTasks: minCompletedTasks,
        rewardAmount: rewardAmount,
      );

      if (previewResult['success'] != true) {
        return {
          'success': false,
          'error': previewResult['error'] ?? 'Failed to get eligible users',
          'eligibleUsers': 0,
          'successCount': 0,
          'failCount': 0,
          'errors': [],
        };
      }

      final eligibleUsers = previewResult['eligibleUsers'] as List<dynamic>? ?? [];
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

      // Distribute rewards
      int successCount = 0;
      int failCount = 0;
      final errors = <String>[];

      for (final user in eligibleUsers) {
        try {
          await Future.delayed(Duration.zero); // Yield between distributions
          
          await _distributeReward(
            userId: user['userId'] as String,
            userName: user['userName'] as String,
            amount: user['rewardAmount'] as int,
            month: targetMonth,
            averageRating: user['averageRating'] as double,
            completedTasks: user['completedTasks'] as int,
            createdBy: currentAdminId,
          );
          successCount++;
        } catch (e) {
          failCount++;
          errors.add('${user['userName']}: ${e.toString()}');
        }
      }

      return {
        'success': true,
        'eligibleUsers': eligibleUsers.length,
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
        'month': monthStr,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Distribute reward to a user
  Future<void> _distributeReward({
    required String userId,
    required String userName,
    required int amount,
    required DateTime month,
    required double averageRating,
    required int completedTasks,
    String? createdBy,
  }) async {
    // Ensure wallet exists
    final walletRef = _walletsRef.doc(userId);
    final walletDoc = await walletRef.get();
    
    if (!walletDoc.exists) {
      await walletRef.set({
        'userId': userId,
        'balance': 0,
        'heldCredits': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final transactionsRef = walletRef.collection('transactions');
    final txnRef = transactionsRef.doc();

    // Use Firestore transaction to atomically update balance
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(walletRef);
      final data = snap.data() ?? <String, dynamic>{'balance': 0};
      final int current = (data['balance'] as num?)?.toInt() ?? 0;
      final int next = current + amount;

      // Update wallet balance
      tx.update(walletRef, {
        'balance': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create transaction record
      tx.set(txnRef, {
        'id': txnRef.id,
        'userId': userId,
        'type': 'credit',
        'amount': amount,
        'description': 'Monthly reward for good performance. Keep it up!',
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': null,
        'metadata': {
          'rewardType': 'monthly_reward',
          'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
          'averageRating': averageRating,
          'completedTasks': completedTasks,
        },
      });
    });

    // Create log entry
    try {
      await _logsRef.add({
        'actionType': 'monthly_reward',
        'userId': userId,
        'userName': userName,
        'amount': amount,
        'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
        'averageRating': averageRating,
        'completedTasks': completedTasks,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      });
    } catch (logError) {
      // Error creating reward log entry - continue
    }

    // Send notification to user
    try {
      await _notificationsRef.add({
        'userId': userId,
        'title': 'Monthly Reward Received! 🎉',
        'body': 'Monthly reward for good performance. Keep it up!',
        'category': 'wallet',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'rewardType': 'monthly_reward',
          'amount': amount,
          'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
          'averageRating': averageRating,
          'completedTasks': completedTasks,
        },
      });
    } catch (notifError) {
      // Error sending reward notification - continue
    }
  }

  /// Get current month
  DateTime _getCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Get reward history grouped by distribution run
  Future<List<Map<String, dynamic>>> getRewardHistory({int limit = 50}) async {
    try {
      // Fetch logs ordered by createdAt (filter in memory to avoid composite index)
      final snapshot = await _logsRef
          .orderBy('createdAt', descending: true)
          .limit(limit * 100) // Fetch more to account for filtering and grouping
          .get();

      // First, collect all monthly_reward logs
      final allRewards = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final actionType = data['actionType'] as String?;
        
        // Filter for monthly_reward only
        if (actionType != 'monthly_reward') continue;
        
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        allRewards.add({
          'id': doc.id,
          'userId': data['userId'] as String? ?? 'Unknown',
          'userName': data['userName'] as String? ?? 'Unknown User',
          'amount': (data['amount'] as num?)?.toInt() ?? 0,
          'month': data['month'] as String? ?? 'Unknown',
          'averageRating': (data['averageRating'] as num?)?.toDouble(),
          'completedTasks': (data['completedTasks'] as num?)?.toInt(),
          'createdAt': createdAt,
          'createdBy': data['createdBy'] as String?,
        });
      }
      
      // Group rewards by distribution run (rewards created within 5 minutes of each other)
      final distributionRuns = <Map<String, dynamic>>[];
      final processedIds = <String>{};
      
      for (int i = 0; i < allRewards.length; i++) {
        if (processedIds.contains(allRewards[i]['id'])) continue;
        
        final firstReward = allRewards[i];
        final firstDate = firstReward['createdAt'] as DateTime?;
        if (firstDate == null) continue;
        
        // Find all rewards in the same distribution run (within 5 minutes)
        final runRewards = <Map<String, dynamic>>[];
        final runStartTime = firstDate;
        final runEndTime = runStartTime.add(const Duration(minutes: 5));
        
        for (int j = i; j < allRewards.length; j++) {
          if (processedIds.contains(allRewards[j]['id'])) continue;
          
          final rewardDate = allRewards[j]['createdAt'] as DateTime?;
          if (rewardDate == null) continue;
          
          // Check if this reward is within the time window
          if (rewardDate.isAfter(runStartTime.subtract(const Duration(minutes: 5))) &&
              rewardDate.isBefore(runEndTime)) {
            runRewards.add(allRewards[j]);
            processedIds.add(allRewards[j]['id']);
          }
        }
        
        if (runRewards.isEmpty) continue;
        
        // Calculate summary for this distribution run
        final totalAmount = runRewards.fold<int>(0, (sum, r) => sum + (r['amount'] as int));
        final rewardAmount = runRewards.isNotEmpty ? (runRewards[0]['amount'] as int) : 0;
        final month = runRewards.isNotEmpty ? (runRewards[0]['month'] as String? ?? 'Unknown') : 'Unknown';
        
        distributionRuns.add({
          'distributionDate': runStartTime,
          'month': month,
          'successCount': runRewards.length,
          'totalAmount': totalAmount,
          'rewardAmount': rewardAmount,
          'eligibleUsers': runRewards.length, // Each reward = one eligible user
        });
        
        if (distributionRuns.length >= limit) break;
      }
      
      return distributionRuns;
    } catch (e) {
      return [];
    }
  }

  /// Stream reward history grouped by distribution run
  Stream<List<Map<String, dynamic>>> streamRewardHistory({int limit = 50}) {
    return _logsRef
        .orderBy('createdAt', descending: true)
        .limit(limit * 100) // Fetch more to account for filtering and grouping
        .snapshots()
        .map((snapshot) {
      // First, collect all monthly_reward logs
      final allRewards = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final actionType = data['actionType'] as String?;
        
        // Filter for monthly_reward only
        if (actionType != 'monthly_reward') continue;
        
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        allRewards.add({
          'id': doc.id,
          'userId': data['userId'] as String? ?? 'Unknown',
          'userName': data['userName'] as String? ?? 'Unknown User',
          'amount': (data['amount'] as num?)?.toInt() ?? 0,
          'month': data['month'] as String? ?? 'Unknown',
          'averageRating': (data['averageRating'] as num?)?.toDouble(),
          'completedTasks': (data['completedTasks'] as num?)?.toInt(),
          'createdAt': createdAt,
          'createdBy': data['createdBy'] as String?,
        });
      }
      
      // Group rewards by distribution run (rewards created within 5 minutes of each other)
      final distributionRuns = <Map<String, dynamic>>[];
      final processedIds = <String>{};
      
      for (int i = 0; i < allRewards.length; i++) {
        if (processedIds.contains(allRewards[i]['id'])) continue;
        
        final firstReward = allRewards[i];
        final firstDate = firstReward['createdAt'] as DateTime?;
        if (firstDate == null) continue;
        
        // Find all rewards in the same distribution run (within 5 minutes)
        final runRewards = <Map<String, dynamic>>[];
        final runStartTime = firstDate;
        final runEndTime = runStartTime.add(const Duration(minutes: 5));
        
        for (int j = i; j < allRewards.length; j++) {
          if (processedIds.contains(allRewards[j]['id'])) continue;
          
          final rewardDate = allRewards[j]['createdAt'] as DateTime?;
          if (rewardDate == null) continue;
          
          // Check if this reward is within the time window
          if (rewardDate.isAfter(runStartTime.subtract(const Duration(minutes: 5))) &&
              rewardDate.isBefore(runEndTime)) {
            runRewards.add(allRewards[j]);
            processedIds.add(allRewards[j]['id']);
          }
        }
        
        if (runRewards.isEmpty) continue;
        
        // Calculate summary for this distribution run
        final totalAmount = runRewards.fold<int>(0, (sum, r) => sum + (r['amount'] as int));
        final rewardAmount = runRewards.isNotEmpty ? (runRewards[0]['amount'] as int) : 0;
        final month = runRewards.isNotEmpty ? (runRewards[0]['month'] as String? ?? 'Unknown') : 'Unknown';
        
        distributionRuns.add({
          'distributionDate': runStartTime,
          'month': month,
          'successCount': runRewards.length,
          'totalAmount': totalAmount,
          'rewardAmount': rewardAmount,
          'eligibleUsers': runRewards.length, // Each reward = one eligible user
        });
        
        if (distributionRuns.length >= limit) break;
      }
      
      return distributionRuns;
    });
  }
}
