import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    debugPrint('🟢 [SERVICE] previewEligibleUsers: START');
    debugPrint('🟢 [SERVICE] Parameters: minRating=$minRating, minCompletedTasks=$minCompletedTasks, rewardAmount=$rewardAmount');
    try {
      final targetMonth = month ?? _getCurrentMonth();
      final monthStart = DateTime(targetMonth.year, targetMonth.month, 1);
      final monthEnd = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);
      final monthStr = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';
      debugPrint('🟢 [SERVICE] Month: $monthStr ($monthStart to $monthEnd)');

      // Ensure UI has a chance to update before starting
      debugPrint('🟢 [SERVICE] Waiting for endOfFrame');
      await SchedulerBinding.instance.endOfFrame;
      debugPrint('🟢 [SERVICE] Waiting 50ms');
      await Future.delayed(const Duration(milliseconds: 50));

      // Step 1: Get completed post IDs in the month
      debugPrint('🟢 [SERVICE] Step 1: Getting completed post IDs');
      final completedPostIds = await _getCompletedPostIds(monthStart, monthEnd);
      debugPrint('🟢 [SERVICE] Step 1: Found ${completedPostIds.length} completed posts');
      
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
      debugPrint('🟢 [SERVICE] Step 2: Getting approved applications');
      final applications = await _getApprovedApplicationsForPosts(completedPostIds);
      debugPrint('🟢 [SERVICE] Step 2: Found ${applications.length} approved applications');
      
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
      debugPrint('🟢 [SERVICE] Step 3: Counting posts per jobseeker');
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
      debugPrint('🟢 [SERVICE] Step 3: Found ${jobseekerPostCounts.length} unique jobseekers');

      // Step 4: Filter by min posts requirement
      debugPrint('🟢 [SERVICE] Step 4: Filtering by min posts ($minCompletedTasks)');
      final candidateJobseekers = jobseekerPostCounts.entries
          .where((e) => e.value >= minCompletedTasks)
          .map((e) => e.key)
          .toList();
      
      debugPrint('🟢 [SERVICE] Step 4: Found ${candidateJobseekers.length} jobseekers with >= $minCompletedTasks posts');

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
      debugPrint('🟢 [SERVICE] Step 5: Processing ${candidateJobseekers.length} candidates');
      final eligibleUsers = <Map<String, dynamic>>[];
      
      for (int i = 0; i < candidateJobseekers.length; i++) {
        debugPrint('🟢 [SERVICE] Step 5: Processing candidate ${i + 1}/${candidateJobseekers.length}');
        // Aggressive yielding - yield before every user
        await SchedulerBinding.instance.endOfFrame;
        await Future.delayed(Duration.zero);
        await Future.microtask(() {});
        await Future.delayed(const Duration(milliseconds: 15)); // Let UI breathe
        
        final jobseekerId = candidateJobseekers[i];
        debugPrint('🟢 [SERVICE] Step 5: Fetching user data for $jobseekerId');
        
        try {
          // Get user data with timeout
          final userDoc = await _usersRef.doc(jobseekerId).get().timeout(
            const Duration(seconds: 2),
          );
          debugPrint('🟢 [SERVICE] Step 5: User data fetched for $jobseekerId');
          
          // Yield after user fetch
          await Future.microtask(() {});
          
          if (!userDoc.exists) {
            debugPrint('🟡 [SERVICE] Step 5: User $jobseekerId does not exist, skipping');
            continue;
          }
          final userData = userDoc.data();
          if (userData == null) {
            debugPrint('🟡 [SERVICE] Step 5: User $jobseekerId has no data, skipping');
            continue;
          }
          
          final role = userData['role'] as String? ?? '';
          if (role == 'manager' || role == 'hr' || role == 'staff') {
            debugPrint('🟡 [SERVICE] Step 5: User $jobseekerId is admin ($role), skipping');
            continue;
          }
          
          // Get average rating (simple query like review_service)
          debugPrint('🟢 [SERVICE] Step 5: Getting average rating for $jobseekerId');
          final avgRating = await _getAverageRatingForJobseeker(jobseekerId, monthStart, monthEnd);
          debugPrint('🟢 [SERVICE] Step 5: Average rating for $jobseekerId: $avgRating');
          
          // Yield after rating fetch
          await Future.microtask(() {});
          
          // Check if qualifies
          if (avgRating >= minRating) {
            debugPrint('✅ [SERVICE] Step 5: User $jobseekerId QUALIFIES (rating: $avgRating >= $minRating)');
            eligibleUsers.add({
              'userId': jobseekerId,
              'userName': userData['fullName'] ?? 'Unknown User',
              'userEmail': userData['email'] ?? '',
              'averageRating': avgRating,
              'completedTasks': jobseekerPostCounts[jobseekerId] ?? 0,
              'rewardAmount': rewardAmount,
              'postIds': jobseekerPostIds[jobseekerId] ?? [],
            });
          } else {
            debugPrint('🟡 [SERVICE] Step 5: User $jobseekerId does NOT qualify (rating: $avgRating < $minRating)');
          }
        } catch (e) {
          debugPrint('🔴 [SERVICE] Error processing jobseeker $jobseekerId: $e');
          continue;
        }
      }
      
      debugPrint('🟢 [SERVICE] Step 5: Found ${eligibleUsers.length} eligible users');

      return {
        'success': true,
        'eligibleUsers': eligibleUsers,
        'totalEligible': eligibleUsers.length,
        'month': monthStr,
        'completedPostsCount': completedPostIds.length,
      };
    } catch (e) {
      debugPrint('Error previewing eligible users: $e');
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
    debugPrint('🔵 [HELPER] _getCompletedPostIds: START');
    try {
      debugPrint('🔵 [HELPER] Querying posts collection for completed posts');
      final snapshot = await _postsRef
          .where('status', isEqualTo: 'completed')
          .limit(200)
          .get()
          .timeout(const Duration(seconds: 5));
      debugPrint('🔵 [HELPER] Query completed, found ${snapshot.docs.length} docs');

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
      debugPrint('🔵 [HELPER] _getCompletedPostIds: END, returning ${postIds.length} post IDs');
      return postIds;
    } catch (e) {
      debugPrint('🔴 [HELPER] Error getting completed posts: $e');
      return [];
    }
  }

  /// Get approved applications for completed posts (batch query with aggressive yields)
  Future<List<Map<String, dynamic>>> _getApprovedApplicationsForPosts(List<String> postIds) async {
    debugPrint('🔵 [HELPER] _getApprovedApplicationsForPosts: START, ${postIds.length} post IDs');
    final allApplications = <Map<String, dynamic>>[];
    
    // Query in batches of 10 (Firestore whereIn limit)
    final numBatches = (postIds.length / 10).ceil();
    debugPrint('🔵 [HELPER] Will query in $numBatches batches');
    
    for (int i = 0; i < postIds.length; i += 10) {
      final batchNum = (i ~/ 10) + 1;
      debugPrint('🔵 [HELPER] Processing batch $batchNum/$numBatches');
      
      // Aggressive yielding before each batch
      await Future.delayed(Duration.zero);
      await Future.microtask(() {});
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 20)); // Let UI breathe
      }
      
      final batch = postIds.skip(i).take(10).toList();
      try {
        debugPrint('🔵 [HELPER] Querying applications for batch $batchNum (${batch.length} post IDs)');
        final snapshot = await _applicationsRef
            .where('postId', whereIn: batch)
            .where('status', isEqualTo: 'approved')
            .get()
            .timeout(const Duration(seconds: 3)); // Shorter timeout
        debugPrint('🔵 [HELPER] Batch $batchNum query completed, found ${snapshot.docs.length} applications');
        
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
        debugPrint('🔴 [HELPER] Error fetching applications batch $batchNum: $e');
      }
    }
    
    debugPrint('🔵 [HELPER] _getApprovedApplicationsForPosts: END, returning ${allApplications.length} applications');
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
        debugPrint('🟡 [HELPER] No reviews found for $jobseekerId');
        return 0.0;
      }

      debugPrint('🔵 [HELPER] Found ${snapshot.docs.length} reviews for $jobseekerId');
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
        debugPrint('🟡 [HELPER] No ratings in month range for $jobseekerId');
        return 0.0;
      }
      final avg = ratings.fold<double>(0.0, (sum, r) => sum + r) / ratings.length;
      debugPrint('🔵 [HELPER] Average rating for $jobseekerId: $avg (from ${ratings.length} ratings)');
      return avg;
    } catch (e) {
      debugPrint('🔴 [HELPER] Error getting rating for $jobseekerId: $e');
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
          debugPrint('Error rewarding user ${user['userId']}: $e');
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
      debugPrint('Error calculating monthly rewards: $e');
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
        'description': 'Monthly reward for ${month.year}-${month.month.toString().padLeft(2, '0')} (Rating: ${averageRating.toStringAsFixed(1)}, Tasks: $completedTasks)',
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
      debugPrint('Error creating reward log entry: $logError');
    }

    // Send notification to user
    try {
      await _notificationsRef.add({
        'userId': userId,
        'title': 'Monthly Reward Received! 🎉',
        'body': 'You received $amount credits as a monthly reward for ${month.year}-${month.month.toString().padLeft(2, '0')} (Rating: ${averageRating.toStringAsFixed(1)}, Tasks: $completedTasks)',
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
      debugPrint('Error sending reward notification: $notifError');
    }
  }

  /// Get current month
  DateTime _getCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Get reward history from logs collection
  Future<List<Map<String, dynamic>>> getRewardHistory({int limit = 10}) async {
    try {
      // Fetch logs with actionType 'monthly_reward'
      final snapshot = await _logsRef
          .orderBy('createdAt', descending: true)
          .limit(limit * 100) // Fetch more to group by month
          .get();

      // Group logs by month
      final Map<String, Map<String, dynamic>> monthlyRewards = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final actionType = data['actionType'] as String?;
        
        // Filter for monthly_reward only
        if (actionType != 'monthly_reward') continue;
        
        final month = data['month'] as String? ?? 'Unknown';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        
        if (!monthlyRewards.containsKey(month)) {
          monthlyRewards[month] = {
            'month': month,
            'eligibleUsers': 0,
            'successCount': 0,
            'failCount': 0,
            'rewardAmount': amount,
            'calculatedAt': createdAt,
          };
        }
        
        final monthData = monthlyRewards[month]!;
        monthData['successCount'] = (monthData['successCount'] as int) + 1;
        monthData['eligibleUsers'] = (monthData['eligibleUsers'] as int) + 1;
        
        // Update calculatedAt to the earliest one (first reward of the month)
        if (createdAt != null) {
          final currentDate = monthData['calculatedAt'] as DateTime?;
          if (currentDate == null || createdAt.isBefore(currentDate)) {
            monthData['calculatedAt'] = createdAt;
          }
        }
      }
      
      // Convert to list and sort by calculatedAt
      final result = monthlyRewards.values.toList();
      result.sort((a, b) {
        final aDate = a['calculatedAt'] as DateTime?;
        final bDate = b['calculatedAt'] as DateTime?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      
      return result.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting reward history: $e');
      return [];
    }
  }

  /// Stream reward history from logs collection
  Stream<List<Map<String, dynamic>>> streamRewardHistory({int limit = 10}) {
    return _logsRef
        .orderBy('createdAt', descending: true)
        .limit(limit * 100) // Fetch more to group by month
        .snapshots()
        .map((snapshot) {
      // Group logs by month
      final Map<String, Map<String, dynamic>> monthlyRewards = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final actionType = data['actionType'] as String?;
        
        // Filter for monthly_reward only
        if (actionType != 'monthly_reward') continue;
        
        final month = data['month'] as String? ?? 'Unknown';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        
        if (!monthlyRewards.containsKey(month)) {
          monthlyRewards[month] = {
            'month': month,
            'eligibleUsers': 0,
            'successCount': 0,
            'failCount': 0,
            'rewardAmount': amount,
            'calculatedAt': createdAt,
          };
        }
        
        final monthData = monthlyRewards[month]!;
        monthData['successCount'] = (monthData['successCount'] as int) + 1;
        monthData['eligibleUsers'] = (monthData['eligibleUsers'] as int) + 1;
        
        // Update calculatedAt to the earliest one (first reward of the month)
        if (createdAt != null) {
          final currentDate = monthData['calculatedAt'] as DateTime?;
          if (currentDate == null || createdAt.isBefore(currentDate)) {
            monthData['calculatedAt'] = createdAt;
          }
        }
      }
      
      // Convert to list and sort by calculatedAt
      final result = monthlyRewards.values.toList();
      result.sort((a, b) {
        final aDate = a['calculatedAt'] as DateTime?;
        final bDate = b['calculatedAt'] as DateTime?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      
      return result.take(limit).toList();
    });
  }
}
