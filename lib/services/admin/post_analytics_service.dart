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

    // Event breakdown (using event field instead of category)
    final eventBreakdown = <String, int>{};
    for (final post in allPosts) {
      final event = post.event ?? 'No Event';
      eventBreakdown[event] = (eventBreakdown[event] ?? 0) + 1;
    }

    // Location breakdown - extract state only
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

    // Tags breakdown
    final tagsBreakdown = <String, int>{};
    for (final post in allPosts) {
      for (final tag in post.tags) {
        if (tag.isNotEmpty) {
          tagsBreakdown[tag] = (tagsBreakdown[tag] ?? 0) + 1;
        }
      }
    }

    // Industry breakdown
    final industryBreakdown = <String, int>{};
    for (final post in allPosts) {
      industryBreakdown[post.industry] = (industryBreakdown[post.industry] ?? 0) + 1;
    }

    // Job type breakdown
    final jobTypeBreakdown = <String, int>{};
    for (final post in allPosts) {
      jobTypeBreakdown[post.jobType] = (jobTypeBreakdown[post.jobType] ?? 0) + 1;
    }

    // Daily breakdown for the period
    final dailyBreakdown = <String, int>{};
    for (final post in postsInRange) {
      final dateKey = '${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}';
      dailyBreakdown[dateKey] = (dailyBreakdown[dateKey] ?? 0) + 1;
    }

    // Budget analysis
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

    // Approval rate: Pending → Active/Completed (approved) or Rejected
    // Approved posts = active + completed (both went through approval process)
    final approvedPosts = active + completed;
    final totalProcessed = approvedPosts + rejected;
    final approvalRate = totalProcessed > 0 ? (approvedPosts / totalProcessed) * 100 : 0.0;

    // Rejection rate
    final rejectionRate = totalProcessed > 0 ? (rejected / totalProcessed) * 100 : 0.0;

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
      'categoryBreakdown': eventBreakdown, // Keep for backward compatibility
      'locationBreakdown': locationBreakdown,
      'tagsBreakdown': tagsBreakdown,
      'industryBreakdown': industryBreakdown,
      'jobTypeBreakdown': jobTypeBreakdown,
      'dailyBreakdown': dailyBreakdown,
      'avgBudgetMin': avgBudgetMin,
      'avgBudgetMax': avgBudgetMax,
      'approvalRate': approvalRate,
      'rejectionRate': rejectionRate,
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

