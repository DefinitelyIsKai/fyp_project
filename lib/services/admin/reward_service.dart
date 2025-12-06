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

      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));

      final completedPostIds = await _getCompletedPostIds(monthStart, monthEnd);
      
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

      final applications = await _getApprovedApplicationsForPosts(completedPostIds);
      
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

      final candidateJobseekers = jobseekerPostCounts.entries
          .where((e) => e.value >= minCompletedTasks)
          .map((e) => e.key)
          .toList();

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

      final eligibleUsers = <Map<String, dynamic>>[];
      
      for (int i = 0; i < candidateJobseekers.length; i++) {
        
        await SchedulerBinding.instance.endOfFrame;
        await Future.delayed(Duration.zero);
        await Future.microtask(() {});
        await Future.delayed(const Duration(milliseconds: 15)); 
        
        final jobseekerId = candidateJobseekers[i];
        
        try {
          
          final userDoc = await _usersRef.doc(jobseekerId).get().timeout(
            const Duration(seconds: 2),
          );
          
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
          
          final avgRating = await _getAverageRatingForJobseeker(jobseekerId, monthStart, monthEnd);
          
          await Future.microtask(() {});
          
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

  Future<List<Map<String, dynamic>>> _getApprovedApplicationsForPosts(List<String> postIds) async {
    final allApplications = <Map<String, dynamic>>[];
    
    for (int i = 0; i < postIds.length; i += 10) {
      
      await Future.delayed(Duration.zero);
      await Future.microtask(() {});
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 20)); 
      }
      
      final batch = postIds.skip(i).take(10).toList();
      try {
        final snapshot = await _applicationsRef
            .where('postId', whereIn: batch)
            .where('status', isEqualTo: 'approved')
            .get()
            .timeout(const Duration(seconds: 3)); 
        
        await Future.microtask(() {});
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          allApplications.add({
            'jobseekerId': data['jobseekerId'],
            'postId': data['postId'],
          });
        }
      } catch (e) {
        
      }
    }
    
    return allApplications;
  }

  Future<double> _getAverageRatingForJobseeker(
    String jobseekerId,
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    try {
      final snapshot = await _reviewsRef
          .where('jobseekerId', isEqualTo: jobseekerId)
          .get()
          .timeout(const Duration(seconds: 2)); 

      if (snapshot.docs.isEmpty) {
        return 0.0;
      }

      final ratings = <double>[];
      
      final docs = snapshot.docs;
      for (int i = 0; i < docs.length; i++) {
        
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

  Future<Map<String, dynamic>> calculateMonthlyRewards({
    DateTime? month,
    double minRating = 4.0,
    int minCompletedTasks = 3,
    int rewardAmount = 100,
  }) async {
    try {
      final targetMonth = month ?? _getCurrentMonth();
      final monthStr = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';

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

      int successCount = 0;
      int failCount = 0;
      final errors = <String>[];

      for (final user in eligibleUsers) {
        try {
          await Future.delayed(Duration.zero); 
          
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

  Future<void> _distributeReward({
    required String userId,
    required String userName,
    required int amount,
    required DateTime month,
    required double averageRating,
    required int completedTasks,
    String? createdBy,
  }) async {
    
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

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(walletRef);
      final data = snap.data() ?? <String, dynamic>{'balance': 0};
      final int current = (data['balance'] as num?)?.toInt() ?? 0;
      final int next = current + amount;

      tx.update(walletRef, {
        'balance': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
      
    }

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
      
    }
  }

  DateTime _getCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  Future<List<Map<String, dynamic>>> getRewardHistory({int limit = 50}) async {
    try {
      
      final snapshot = await _logsRef
          .orderBy('createdAt', descending: true)
          .limit(limit * 100) 
          .get();

      final allRewards = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final actionType = data['actionType'] as String?;
        
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
      
      final distributionRuns = <Map<String, dynamic>>[];
      final processedIds = <String>{};
      
      for (int i = 0; i < allRewards.length; i++) {
        if (processedIds.contains(allRewards[i]['id'])) continue;
        
        final firstReward = allRewards[i];
        final firstDate = firstReward['createdAt'] as DateTime?;
        if (firstDate == null) continue;
        
        final runRewards = <Map<String, dynamic>>[];
        final runStartTime = firstDate;
        final runEndTime = runStartTime.add(const Duration(minutes: 5));
        
        for (int j = i; j < allRewards.length; j++) {
          if (processedIds.contains(allRewards[j]['id'])) continue;
          
          final rewardDate = allRewards[j]['createdAt'] as DateTime?;
          if (rewardDate == null) continue;
          
          if (rewardDate.isAfter(runStartTime.subtract(const Duration(minutes: 5))) &&
              rewardDate.isBefore(runEndTime)) {
            runRewards.add(allRewards[j]);
            processedIds.add(allRewards[j]['id']);
          }
        }
        
        if (runRewards.isEmpty) continue;
        
        final totalAmount = runRewards.fold<int>(0, (sum, r) => sum + (r['amount'] as int));
        final rewardAmount = runRewards.isNotEmpty ? (runRewards[0]['amount'] as int) : 0;
        final month = runRewards.isNotEmpty ? (runRewards[0]['month'] as String? ?? 'Unknown') : 'Unknown';
        
        distributionRuns.add({
          'distributionDate': runStartTime,
          'month': month,
          'successCount': runRewards.length,
          'totalAmount': totalAmount,
          'rewardAmount': rewardAmount,
          'eligibleUsers': runRewards.length, 
        });
        
        if (distributionRuns.length >= limit) break;
      }
      
      return distributionRuns;
    } catch (e) {
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamRewardHistory({int limit = 50}) {
    return _logsRef
        .orderBy('createdAt', descending: true)
        .limit(limit * 100) 
        .snapshots()
        .map((snapshot) {
      
      final allRewards = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final actionType = data['actionType'] as String?;
        
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
      
      final distributionRuns = <Map<String, dynamic>>[];
      final processedIds = <String>{};
      
      for (int i = 0; i < allRewards.length; i++) {
        if (processedIds.contains(allRewards[i]['id'])) continue;
        
        final firstReward = allRewards[i];
        final firstDate = firstReward['createdAt'] as DateTime?;
        if (firstDate == null) continue;
        
        final runRewards = <Map<String, dynamic>>[];
        final runStartTime = firstDate;
        final runEndTime = runStartTime.add(const Duration(minutes: 5));
        
        for (int j = i; j < allRewards.length; j++) {
          if (processedIds.contains(allRewards[j]['id'])) continue;
          
          final rewardDate = allRewards[j]['createdAt'] as DateTime?;
          if (rewardDate == null) continue;
          
          if (rewardDate.isAfter(runStartTime.subtract(const Duration(minutes: 5))) &&
              rewardDate.isBefore(runEndTime)) {
            runRewards.add(allRewards[j]);
            processedIds.add(allRewards[j]['id']);
          }
        }
        
        if (runRewards.isEmpty) continue;
        
        final totalAmount = runRewards.fold<int>(0, (sum, r) => sum + (r['amount'] as int));
        final rewardAmount = runRewards.isNotEmpty ? (runRewards[0]['amount'] as int) : 0;
        final month = runRewards.isNotEmpty ? (runRewards[0]['month'] as String? ?? 'Unknown') : 'Unknown';
        
        distributionRuns.add({
          'distributionDate': runStartTime,
          'month': month,
          'successCount': runRewards.length,
          'totalAmount': totalAmount,
          'rewardAmount': rewardAmount,
          'eligibleUsers': runRewards.length, 
        });
        
        if (distributionRuns.length >= limit) break;
      }
      
      return distributionRuns;
    });
  }
}
