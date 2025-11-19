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
  List<JobPostModel> _activePosts = [];
  List<JobPostModel> _completedPosts = [];
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
        const SnackBar(content: Text('Post approved and now active'), backgroundColor: Colors.green),
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
      builder: (context) => _RejectPostDialog(post: post), // Pass the post here
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

  Future<void> _completePost(JobPostModel post) async {
    try {
      await _postService.completePost(post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post marked as completed'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reopenPost(JobPostModel post) async {
    try {
      await _postService.reopenPost(post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post reopened'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
        post.description.toLowerCase().contains(query) ||
        (post.submitterName ?? '').toLowerCase().contains(query)
    ).toList();
  }

  void _handlePostsUpdate(List<JobPostModel> posts) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _allPosts = posts;
        _pendingPosts = _allPosts.where((p) => p.status == 'pending').toList();
        _activePosts = _allPosts.where((p) => p.status == 'active').toList();
        _completedPosts = _allPosts.where((p) => p.status == 'completed').toList();
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
          'Job Post Management',
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
                hintText: 'Search job posts by title, description, or author...',
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
                  onTap: () => _switchTab(0),
                ),
                _TabButton(
                  label: 'Active',
                  isSelected: _currentTabIndex == 1,
                  onTap: () => _switchTab(1),
                ),
                _TabButton(
                  label: 'Completed',
                  isSelected: _currentTabIndex == 2,
                  onTap: () => _switchTab(2),
                ),
                _TabButton(
                  label: 'Rejected',
                  isSelected: _currentTabIndex == 3,
                  onTap: () => _switchTab(3),
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
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                    ),
                    // Active Tab
                    _PostsList(
                      posts: _filterPosts(_activePosts),
                      status: 'active',
                      onApprove: null,
                      onReject: _rejectPost,
                      onComplete: _completePost,
                      onReopen: null,
                      onView: _viewPost,
                    ),
                    // Completed Tab
                    _PostsList(
                      posts: _filterPosts(_completedPosts),
                      status: 'completed',
                      onApprove: null,
                      onReject: null,
                      onComplete: null,
                      onReopen: _reopenPost,
                      onView: _viewPost,
                    ),
                    // Rejected Tab
                    _PostsList(
                      posts: _filterPosts(_rejectedPosts),
                      status: 'rejected',
                      onApprove: _approvePost,
                      onReject: null,
                      onComplete: null,
                      onReopen: null,
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
              label: 'Pending',
              color: Colors.orange,
              icon: Icons.pending_actions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              count: _activePosts.length,
              label: 'Active',
              color: Colors.green,
              icon: Icons.play_arrow,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              count: _completedPosts.length,
              label: 'Completed',
              color: Colors.blue,
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

// Reject Post Dialog
class _RejectPostDialog extends StatefulWidget {
  final JobPostModel post;

  const _RejectPostDialog({required this.post});

  @override
  State<_RejectPostDialog> createState() => _RejectPostDialogState();
}

class _RejectPostDialogState extends State<_RejectPostDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedReason;
  bool _isCustomReason = false;

  final List<Map<String, String>> _commonReasons = [
    {
      'title': 'Incomplete Information',
      'description': 'Missing essential job details'
    },
    {
      'title': 'Inappropriate Content',
      'description': 'Contains offensive language'
    },
    {
      'title': 'Duplicate Post',
      'description': 'Similar job already exists'
    },
    {
      'title': 'Violates Guidelines',
      'description': 'Breaks community rules'
    },
    {
      'title': 'Spam Content',
      'description': 'Promotional or spam content'
    },
    {
      'title': 'Unclear Description',
      'description': 'Job details are vague'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.warning_amber, color: Colors.red[700]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reject Job Post',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please provide a reason for rejecting this post',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Post Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Container(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.post.category} • ${widget.post.location}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Common Reasons Section
                    Text(
                      'Select a reason',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose from common reasons or write your own',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Common Reasons - Single Column for better layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmallScreen = constraints.maxWidth < 400;
                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isSmallScreen ? 1 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: isSmallScreen ? 3.5 : 2.5,
                            mainAxisExtent: isSmallScreen ? 80 : 90,
                          ),
                          itemCount: _commonReasons.length,
                          itemBuilder: (context, index) {
                            final reason = _commonReasons[index];
                            final isSelected = _selectedReason == reason['title'] && !_isCustomReason;

                            return _ReasonCard(
                              title: reason['title']!,
                              description: reason['description']!,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedReason = reason['title'];
                                  _reasonController.text = reason['title']!;
                                  _isCustomReason = false;
                                });
                              },
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Custom Reason Option
                    _CustomReasonCard(
                      isSelected: _isCustomReason,
                      controller: _reasonController,
                      onTap: () {
                        setState(() {
                          _isCustomReason = true;
                          _selectedReason = null;
                          _reasonController.clear();
                        });
                      },
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _reasonController.text.trim().isNotEmpty
                          ? () => Navigator.pop(context, _reasonController.text.trim())
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 18),
                          SizedBox(width: 8),
                          Text('Reject Post'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.red[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.red : Colors.grey[400]!,
                    width: 2,
                  ),
                  color: isSelected ? Colors.red : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.red[700] : Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.red[600] : Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomReasonCard extends StatelessWidget {
  final bool isSelected;
  final TextEditingController controller;
  final VoidCallback onTap;
  final Function(String) onChanged;

  const _CustomReasonCard({
    required this.isSelected,
    required this.controller,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[400]!,
                        width: 2,
                      ),
                      color: isSelected ? Colors.blue : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Custom Reason',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.blue[700] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                onChanged: onChanged,
                enabled: isSelected,
                maxLines: 3,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Type your reason here...',
                  filled: true,
                  fillColor: isSelected ? Colors.white : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue!),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              if (!isSelected) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap to enable custom reason',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
// Posts List for each tab
class _PostsList extends StatelessWidget {
  final List<JobPostModel> posts;
  final String status;
  final Function(JobPostModel)? onApprove;
  final Function(JobPostModel)? onReject;
  final Function(JobPostModel)? onComplete;
  final Function(JobPostModel)? onReopen;
  final Function(JobPostModel) onView;

  const _PostsList({
    required this.posts,
    required this.status,
    this.onApprove,
    this.onReject,
    this.onComplete,
    this.onReopen,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                onComplete: onComplete,
                onReopen: onReopen,
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
      height: 80,
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
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  Color getTabColor() {
    switch (label) {
      case 'Pending':
        return Colors.orange;
      case 'Active':
        return Colors.green;
      case 'Completed':
        return Colors.blue;
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
  final Function(JobPostModel)? onApprove;
  final Function(JobPostModel)? onReject;
  final Function(JobPostModel)? onComplete;
  final Function(JobPostModel)? onReopen;
  final Function(JobPostModel) onView;

  const _PostCard({
    required this.post,
    this.onApprove,
    this.onReject,
    this.onComplete,
    this.onReopen,
    required this.onView,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
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
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actionButtons = [];

    // Build action buttons based on current status
    switch (post.status) {
      case 'pending':
        actionButtons = [
          if (onApprove != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onApprove!(post),
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
          if (onApprove != null && onReject != null) const SizedBox(width: 8),
          if (onReject != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onReject!(post),
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
        break;
      case 'active':
        actionButtons = [
          if (onComplete != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onComplete!(post),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          if (onComplete != null && onReject != null) const SizedBox(width: 8),
          if (onReject != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onReject!(post),
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
        break;
      case 'completed':
        actionButtons = [
          if (onReopen != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onReopen!(post),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Reopen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ];
        break;
      case 'rejected':
        actionButtons = [
          if (onApprove != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onApprove!(post),
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
        ];
        break;
    }

    // Add view button
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