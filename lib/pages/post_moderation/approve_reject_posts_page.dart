import 'package:flutter/material.dart';
import 'package:fyp_project/models/job_post_model.dart';
import 'package:fyp_project/services/post_service.dart';
import 'package:fyp_project/pages/post_moderation/post_detail_page.dart';

class ApproveRejectPostsPage extends StatefulWidget {
  const ApproveRejectPostsPage({super.key});

  @override
  State<ApproveRejectPostsPage> createState() => _ApproveRejectPostsPageState();
}

class _ApproveRejectPostsPageState extends State<ApproveRejectPostsPage> {
  final PostService _postService = PostService();
  final TextEditingController _searchController = TextEditingController();
  bool _isStatsExpanded = true;
  final PageController _tabPageController = PageController();
  int _currentTabIndex = 0;

  // Store posts data
  List<JobPostModel> _allPosts = [];
  List<JobPostModel> _pendingPosts = [];
  List<JobPostModel> _approvedPosts = [];
  List<JobPostModel> _rejectedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Trigger rebuild for search
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabPageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() => _currentTabIndex = index);
    if (_tabPageController.hasClients) {
      _tabPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentTabIndex = index);
  }

  void _toggleStatsExpansion() {
    setState(() {
      _isStatsExpanded = !_isStatsExpanded;
    });
  }

  Future<void> _approvePost(JobPostModel post) async {
    try {
      await _postService.approvePost(post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post approved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectPost(JobPostModel post) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Post'),
        content: const Text('Are you sure you want to reject this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, 'Rejected by admin'),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (reason != null) {
      try {
        await _postService.rejectPost(post.id, reason);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post rejected'), backgroundColor: Colors.orange),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _viewPost(JobPostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
    );
  }

  List<JobPostModel> _filterPosts(List<JobPostModel> posts) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return posts;
    
    return posts.where((post) =>
      post.title.toLowerCase().contains(query) ||
      post.description.toLowerCase().contains(query)
    ).toList();
  }

  void _handlePostsUpdate(List<JobPostModel> posts) {
    // Use WidgetsBinding to schedule the state update after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _allPosts = posts;
        _pendingPosts = _allPosts.where((p) => p.status == 'pending').toList();
        _approvedPosts = _allPosts.where((p) => p.status == 'approved').toList();
        _rejectedPosts = _allPosts.where((p) => p.status == 'rejected').toList();
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post Moderation',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search job posts by title or description...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Stats Section with Expand/Collapse
          Container(
            color: Colors.grey[50],
            child: Column(
              children: [
                // Expand/Collapse Header
                GestureDetector(
                  onTap: _toggleStatsExpansion,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Post Statistics',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        Icon(
                          _isStatsExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Stats Cards
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _isStatsExpanded 
                      ? CrossFadeState.showFirst 
                      : CrossFadeState.showSecond,
                  firstChild: _buildStatsSection(),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                _TabButton(
                  label: 'Pending',
                  isSelected: _currentTabIndex == 0,
                  count: _pendingPosts.length,
                  onTap: () => _switchTab(0),
                ),
                _TabButton(
                  label: 'Approved',
                  isSelected: _currentTabIndex == 1,
                  count: _approvedPosts.length,
                  onTap: () => _switchTab(1),
                ),
                _TabButton(
                  label: 'Rejected',
                  isSelected: _currentTabIndex == 2,
                  count: _rejectedPosts.length,
                  onTap: () => _switchTab(2),
                ),
              ],
            ),
          ),

          // Swipe indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  'Swipe to switch between tabs',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Stream posts and swipable content area
          Expanded(
            child: StreamBuilder<List<JobPostModel>>(
              stream: _postService.streamAllPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading posts...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading posts',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Handle data when it arrives
                if (snapshot.hasData) {
                  final posts = snapshot.data!;
                  _handlePostsUpdate(posts);
                }

                return PageView(
                  controller: _tabPageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    // Pending Tab
                    _PostsList(
                      posts: _filterPosts(_pendingPosts),
                      status: 'pending',
                      onApprove: _approvePost,
                      onReject: _rejectPost,
                      onView: _viewPost,
                    ),
                    // Approved Tab
                    _PostsList(
                      posts: _filterPosts(_approvedPosts),
                      status: 'approved',
                      onApprove: _approvePost,
                      onReject: _rejectPost,
                      onView: _viewPost,
                    ),
                    // Rejected Tab
                    _PostsList(
                      posts: _filterPosts(_rejectedPosts),
                      status: 'rejected',
                      onApprove: _approvePost,
                      onReject: _rejectPost,
                      onView: _viewPost,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              count: _pendingPosts.length,
              label: 'Pending Review',
              color: Colors.orange,
              icon: Icons.pending_actions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              count: _approvedPosts.length,
              label: 'Approved',
              color: Colors.green,
              icon: Icons.check_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              count: _rejectedPosts.length,
              label: 'Rejected',
              color: Colors.red,
              icon: Icons.cancel,
            ),
          ),
        ],
      ),
    );
  }
}

// Posts List for each tab
class _PostsList extends StatelessWidget {
  final List<JobPostModel> posts;
  final String status;
  final Function(JobPostModel) onApprove;
  final Function(JobPostModel) onReject;
  final Function(JobPostModel) onView;

  const _PostsList({
    required this.posts,
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Results count
        if (posts.isNotEmpty)
          Padding(
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
        
        // Posts list or empty state
        Expanded(
          child: posts.isNotEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _PostCard(
                      post: post,
                      onApprove: onApprove,
                      onReject: onReject,
                      onView: onView,
                    );
                  },
                )
              : _buildEmptyState(status),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String status) {
    final emptyMessages = {
      'pending': 'No pending posts to review',
      'approved': 'No approved posts yet',
      'rejected': 'No rejected posts'
    };
    final emptyIcons = {
      'pending': Icons.pending_actions,
      'approved': Icons.check_circle,
      'rejected': Icons.cancel
    };

    return Center(
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
    );
  }
}

// ---------------- Widgets ----------------

class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, // Fixed height for same size
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  Color getTabColor() {
    switch (label) {
      case 'Pending':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? getTabColor() : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? getTabColor() : Colors.grey[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final JobPostModel post;
  final Function(JobPostModel) onApprove;
  final Function(JobPostModel) onReject;
  final Function(JobPostModel) onView;

  const _PostCard({
    required this.post,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actionButtons = [];

    if (post.status == 'pending') {
      actionButtons = [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => onApprove(post),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => onReject(post),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ];
    } else if (post.status == 'approved') {
      actionButtons = [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => onReject(post),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: SizedBox()), // Spacer for alignment
      ];
    } else {
      actionButtons = [
        const Expanded(child: SizedBox()),
        const SizedBox(width: 8),
        const Expanded(child: SizedBox()),
      ];
    }

    // Always add view button
    actionButtons.add(const SizedBox(width: 8));
    actionButtons.add(
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => onView(post),
          icon: Icon(Icons.visibility, color: Colors.grey[600]),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${post.category} • ${post.location}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(post.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getStatusColor(post.status).withOpacity(0.3)),
                    ),
                    child: Text(
                      _getStatusText(post.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(post.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Author and date
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    post.submitterName ?? 'Unknown',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    '${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(children: actionButtons),
            ],
          ),
        ),
      ),
    );
  }
}