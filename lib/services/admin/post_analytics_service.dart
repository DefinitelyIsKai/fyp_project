import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';

class PostAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get comprehensive post analytics for a date range
  Future<Map<String, dynamic>> getPostAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Use exact date and time from the provided DateTime objects
    final start = startDate;
    final end = endDate;

    // Get all posts
    final allPostsSnapshot = await _firestore
        .collection('posts')
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final allPosts = allPostsSnapshot.docs
        .map((doc) => JobPostModel.fromFirestore(doc))
        .toList();

    // Filter posts within date range
    final postsInRange = allPosts.where((post) {
      return post.createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
          post.createdAt.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    // Calculate statistics
    final totalPosts = allPosts.length;
    final postsInPeriod = postsInRange.length;
    
    final pending = allPosts.where((p) => p.status == 'pending').length;
    final active = allPosts.where((p) => p.status == 'active').length;
    final completed = allPosts.where((p) => p.status == 'completed').length;
    final rejected = allPosts.where((p) => p.status == 'rejected').length;

    // Status breakdown for the period
    final pendingInPeriod = postsInRange.where((p) => p.status == 'pending').length;
    final activeInPeriod = postsInRange.where((p) => p.status == 'active').length;
    final completedInPeriod = postsInRange.where((p) => p.status == 'completed').length;
    final rejectedInPeriod = postsInRange.where((p) => p.status == 'rejected').length;

    // Event breakdown (using event field instead of category) - All Time
    final eventBreakdown = <String, int>{};
    for (final post in allPosts) {
      final event = post.event ?? 'No Event';
      eventBreakdown[event] = (eventBreakdown[event] ?? 0) + 1;
    }

    // Event breakdown for the period
    final eventBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      final event = post.event ?? 'No Event';
      eventBreakdownInPeriod[event] = (eventBreakdownInPeriod[event] ?? 0) + 1;
    }

    // Location breakdown - extract state only - All Time
    final locationBreakdown = <String, int>{};
    for (final post in allPosts) {
      if (post.location.isNotEmpty) {
        // Extract state from location (format: "Address, City, State, Country")
        // State is usually the second to last part
        final parts = post.location.split(',').map((p) => p.trim()).toList();
        String state = post.location; // fallback to full location
        if (parts.length >= 2) {
          // Try to get the state (second to last part before country)
          state = parts.length >= 3 ? parts[parts.length - 2] : parts.last;
        }
        locationBreakdown[state] = (locationBreakdown[state] ?? 0) + 1;
      }
    }

    // Location breakdown for the period
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

    // Tags breakdown - All Time
    final tagsBreakdown = <String, int>{};
    for (final post in allPosts) {
      for (final tag in post.tags) {
        if (tag.isNotEmpty) {
          tagsBreakdown[tag] = (tagsBreakdown[tag] ?? 0) + 1;
        }
      }
    }

    // Tags breakdown for the period
    final tagsBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      for (final tag in post.tags) {
        if (tag.isNotEmpty) {
          tagsBreakdownInPeriod[tag] = (tagsBreakdownInPeriod[tag] ?? 0) + 1;
        }
      }
    }

    // Industry breakdown - All Time (using event field)
    final industryBreakdown = <String, int>{};
    for (final post in allPosts) {
      final event = post.event ?? '';
      if (event.isNotEmpty) {
        industryBreakdown[event] = (industryBreakdown[event] ?? 0) + 1;
      }
    }

    // Industry breakdown for the period (using event field)
    final industryBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      final event = post.event ?? '';
      if (event.isNotEmpty) {
        industryBreakdownInPeriod[event] = (industryBreakdownInPeriod[event] ?? 0) + 1;
      }
    }

    // Job type breakdown - All Time
    final jobTypeBreakdown = <String, int>{};
    for (final post in allPosts) {
      jobTypeBreakdown[post.jobType] = (jobTypeBreakdown[post.jobType] ?? 0) + 1;
    }

    // Job type breakdown for the period
    final jobTypeBreakdownInPeriod = <String, int>{};
    for (final post in postsInRange) {
      jobTypeBreakdownInPeriod[post.jobType] = (jobTypeBreakdownInPeriod[post.jobType] ?? 0) + 1;
    }

    // Daily breakdown for the period
    final dailyBreakdown = <String, int>{};
    for (final post in postsInRange) {
      final dateKey = '${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}';
      dailyBreakdown[dateKey] = (dailyBreakdown[dateKey] ?? 0) + 1;
    }

    // Budget analysis - All Time
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

    // Budget analysis for the period
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

    // Approval rate: Pending → Active/Completed (approved) or Rejected - All Time
    // Approved posts = active + completed (both went through approval process)
    final approvedPosts = active + completed;
    final totalProcessed = approvedPosts + rejected;
    final approvalRate = totalProcessed > 0 ? (approvedPosts / totalProcessed) * 100 : 0.0;

    // Rejection rate - All Time
    final rejectionRate = totalProcessed > 0 ? (rejected / totalProcessed) * 100 : 0.0;

    // Approval and rejection rates for the period
    final approvedPostsInPeriod = activeInPeriod + completedInPeriod;
    final totalProcessedInPeriod = approvedPostsInPeriod + rejectedInPeriod;
    final approvalRateInPeriod = totalProcessedInPeriod > 0 ? (approvedPostsInPeriod / totalProcessedInPeriod) * 100 : 0.0;
    final rejectionRateInPeriod = totalProcessedInPeriod > 0 ? (rejectedInPeriod / totalProcessedInPeriod) * 100 : 0.0;

    // Average processing time (if we have approval/rejection timestamps)
    // This would require additional fields in the model

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
      'categoryBreakdown': eventBreakdown, // Keep for backward compatibility
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

  /// Get posts by date range
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

