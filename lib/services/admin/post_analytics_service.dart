import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';

class PostAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getPostAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    
    final start = startDate;
    final end = endDate;

    final allPostsSnapshot = await _firestore
        .collection('posts')
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final allPosts = allPostsSnapshot.docs
        .map((doc) => JobPostModel.fromFirestore(doc))
        .toList();

    final postsInRange = allPosts.where((post) {
      return post.createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
          post.createdAt.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    final totalPosts = allPosts.length;
    final postsInPeriod = postsInRange.length;
    
    final pending = allPosts.where((p) => p.status == 'pending').length;
    final active = allPosts.where((p) => p.status == 'active').length;
    final completed = allPosts.where((p) => p.status == 'completed').length;
    final rejected = allPosts.where((p) => p.status == 'rejected').length;

    final pendingInPeriod = postsInRange.where((p) => p.status == 'pending').length;
    final activeInPeriod = postsInRange.where((p) => p.status == 'active').length;
    final completedInPeriod = postsInRange.where((p) => p.status == 'completed').length;
    final rejectedInPeriod = postsInRange.where((p) => p.status == 'rejected').length;

    final eventBreakdown = <String, int>{};
    for (final post in allPosts) {
      final event = post.event ?? 'No Event';
      eventBreakdown[event] = (eventBreakdown[event] ?? 0) + 1;
    }

    final eventBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      final event = post.event ?? 'No Event';
      eventBreakdownInPeriod[event] = (eventBreakdownInPeriod[event] ?? 0) + 1;
    }

    final locationBreakdown = <String, int>{};
    for (final post in allPosts) {
      if (post.location.isNotEmpty) {
        
        final parts = post.location.split(',').map((p) => p.trim()).toList();
        String state = post.location; 
        if (parts.length >= 2) {
          
          state = parts.length >= 3 ? parts[parts.length - 2] : parts.last;
        }
        locationBreakdown[state] = (locationBreakdown[state] ?? 0) + 1;
      }
    }

    final locationBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      if (post.location.isNotEmpty) {
        final parts = post.location.split(',').map((p) => p.trim()).toList();
        String state = post.location;
        if (parts.length >= 2) {
          state = parts.length >= 3 ? parts[parts.length - 2] : parts.last;
        }
        locationBreakdownInPeriod[state] = (locationBreakdownInPeriod[state] ?? 0) + 1;
      }
    }

    final tagsBreakdown = <String, int>{};
    for (final post in allPosts) {
      for (final tag in post.tags) {
        if (tag.isNotEmpty) {
          tagsBreakdown[tag] = (tagsBreakdown[tag] ?? 0) + 1;
        }
      }
    }

    final tagsBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      for (final tag in post.tags) {
        if (tag.isNotEmpty) {
          tagsBreakdownInPeriod[tag] = (tagsBreakdownInPeriod[tag] ?? 0) + 1;
        }
      }
    }

    final industryBreakdown = <String, int>{};
    for (final post in allPosts) {
      final event = post.event ?? '';
      if (event.isNotEmpty) {
        industryBreakdown[event] = (industryBreakdown[event] ?? 0) + 1;
      }
    }

    final industryBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      final event = post.event ?? '';
      if (event.isNotEmpty) {
        industryBreakdownInPeriod[event] = (industryBreakdownInPeriod[event] ?? 0) + 1;
      }
    }

    final jobTypeBreakdown = <String, int>{};
    for (final post in allPosts) {
      jobTypeBreakdown[post.jobType] = (jobTypeBreakdown[post.jobType] ?? 0) + 1;
    }

    final jobTypeBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      jobTypeBreakdownInPeriod[post.jobType] = (jobTypeBreakdownInPeriod[post.jobType] ?? 0) + 1;
    }

    final dailyBreakdown = <String, int>{};
    for (final post in postsInRange) {
      final dateKey = '${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}';
      dailyBreakdown[dateKey] = (dailyBreakdown[dateKey] ?? 0) + 1;
    }

    final postsWithBudget = allPosts.where((p) => p.budgetMin != null || p.budgetMax != null).toList();
    double? avgBudgetMin;
    double? avgBudgetMax;
    if (postsWithBudget.isNotEmpty) {
      final totalMin = postsWithBudget
          .where((p) => p.budgetMin != null)
          .fold<double>(0, (sum, p) => sum + (p.budgetMin ?? 0));
      final totalMax = postsWithBudget
          .where((p) => p.budgetMax != null)
          .fold<double>(0, (sum, p) => sum + (p.budgetMax ?? 0));
      final countMin = postsWithBudget.where((p) => p.budgetMin != null).length;
      final countMax = postsWithBudget.where((p) => p.budgetMax != null).length;
      
      avgBudgetMin = countMin > 0 ? totalMin / countMin : null;
      avgBudgetMax = countMax > 0 ? totalMax / countMax : null;
    }

    final postsWithBudgetInPeriod = postsInRange.where((p) => p.budgetMin != null || p.budgetMax != null).toList();
    double? avgBudgetMinInPeriod;
    double? avgBudgetMaxInPeriod;
    if (postsWithBudgetInPeriod.isNotEmpty) {
      final totalMin = postsWithBudgetInPeriod
          .where((p) => p.budgetMin != null)
          .fold<double>(0, (sum, p) => sum + (p.budgetMin ?? 0));
      final totalMax = postsWithBudgetInPeriod
          .where((p) => p.budgetMax != null)
          .fold<double>(0, (sum, p) => sum + (p.budgetMax ?? 0));
      final countMin = postsWithBudgetInPeriod.where((p) => p.budgetMin != null).length;
      final countMax = postsWithBudgetInPeriod.where((p) => p.budgetMax != null).length;
      
      avgBudgetMinInPeriod = countMin > 0 ? totalMin / countMin : null;
      avgBudgetMaxInPeriod = countMax > 0 ? totalMax / countMax : null;
    }

    final approvedPosts = active + completed;
    final totalProcessed = approvedPosts + rejected;
    final approvalRate = totalProcessed > 0 ? (approvedPosts / totalProcessed) * 100 : 0.0;

    final rejectionRate = totalProcessed > 0 ? (rejected / totalProcessed) * 100 : 0.0;

    final approvedPostsInPeriod = activeInPeriod + completedInPeriod;
    final totalProcessedInPeriod = approvedPostsInPeriod + rejectedInPeriod;
    final approvalRateInPeriod = totalProcessedInPeriod > 0 ? (approvedPostsInPeriod / totalProcessedInPeriod) * 100 : 0.0;
    final rejectionRateInPeriod = totalProcessedInPeriod > 0 ? (rejectedInPeriod / totalProcessedInPeriod) * 100 : 0.0;

    return {
      'totalPosts': totalPosts,
      'postsInPeriod': postsInPeriod,
      'pending': pending,
      'active': active,
      'completed': completed,
      'rejected': rejected,
      'pendingInPeriod': pendingInPeriod,
      'activeInPeriod': activeInPeriod,
      'completedInPeriod': completedInPeriod,
      'rejectedInPeriod': rejectedInPeriod,
      'eventBreakdown': eventBreakdown,
      'eventBreakdownInPeriod': eventBreakdownInPeriod,
      'categoryBreakdown': eventBreakdown, 
      'locationBreakdown': locationBreakdown,
      'locationBreakdownInPeriod': locationBreakdownInPeriod,
      'tagsBreakdown': tagsBreakdown,
      'tagsBreakdownInPeriod': tagsBreakdownInPeriod,
      'industryBreakdown': industryBreakdown,
      'industryBreakdownInPeriod': industryBreakdownInPeriod,
      'jobTypeBreakdown': jobTypeBreakdown,
      'jobTypeBreakdownInPeriod': jobTypeBreakdownInPeriod,
      'dailyBreakdown': dailyBreakdown,
      'avgBudgetMin': avgBudgetMin,
      'avgBudgetMax': avgBudgetMax,
      'avgBudgetMinInPeriod': avgBudgetMinInPeriod,
      'avgBudgetMaxInPeriod': avgBudgetMaxInPeriod,
      'approvalRate': approvalRate,
      'rejectionRate': rejectionRate,
      'approvalRateInPeriod': approvalRateInPeriod,
      'rejectionRateInPeriod': rejectionRateInPeriod,
      'startDate': start,
      'endDate': end,
    };
  }

  Future<List<JobPostModel>> getPostsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('posts')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return snapshot.docs
        .map((doc) => JobPostModel.fromFirestore(doc))
        .toList();
  }
}
