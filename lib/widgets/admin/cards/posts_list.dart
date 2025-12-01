import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/widgets/admin/cards/post_card.dart';

/// A reusable posts list widget with refresh indicator and empty state
class PostsList extends StatelessWidget {
  final List<JobPostModel> posts;
  final String status;
  final void Function(JobPostModel)? onApprove;
  final void Function(JobPostModel)? onReject;
  final void Function(JobPostModel)? onComplete;
  final void Function(JobPostModel)? onReopen;
  final void Function(JobPostModel) onView;
  final String Function(String?) getUserName;
  final Set<String> processingPostIds;
  final Future<void> Function()? onRefresh;

  const PostsList({
    super.key,
    required this.posts,
    required this.status,
    this.onApprove,
    this.onReject,
    this.onComplete,
    this.onReopen,
    required this.onView,
    required this.getUserName,
    required this.processingPostIds,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Build scrollable widget
    Widget scrollView;
    
    if (posts.isEmpty) {
      scrollView = _buildEmptyState(context, status);
    } else {
      scrollView = CustomScrollView(
        slivers: [
          // Header with post count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${posts.length} post${posts.length == 1 ? '' : 's'} found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Posts list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = posts[index];
                  return PostCard(
                    post: post,
                    onApprove: onApprove,
                    onReject: onReject,
                    onComplete: onComplete,
                    onReopen: onReopen,
                    onView: onView,
                    getUserName: getUserName,
                    isProcessing: processingPostIds.contains(post.id),
                  );
                },
                childCount: posts.length,
              ),
            ),
          ),
        ],
      );
    }

    // Wrap with RefreshIndicator if refresh callback is provided
    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: scrollView is CustomScrollView
            ? scrollView
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: scrollView,
                ),
              ),
      );
    }

    return scrollView;
  }

  Widget _buildEmptyState(BuildContext context, String status) {
    final emptyMessages = {
      'pending': 'No pending posts to review',
      'active': 'No active posts',
      'completed': 'No completed posts',
      'rejected': 'No rejected posts'
    };
    final emptyIcons = {
      'pending': Icons.pending_actions,
      'active': Icons.play_arrow,
      'completed': Icons.check_circle,
      'rejected': Icons.cancel
    };

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                emptyIcons[status] ?? Icons.article,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessages[status] ?? 'No posts found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Posts will appear here once available',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

