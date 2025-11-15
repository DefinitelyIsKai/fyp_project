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
  List<JobPostModel> _pendingPosts = [];
  List<JobPostModel> _approvedPosts = [];
  List<JobPostModel> _rejectedPosts = [];
  List<JobPostModel> _filteredPosts = [];
  bool _isLoading = true;
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _searchController.addListener(_filterPosts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _postService.getPendingPosts();
      final approved = await _postService.getApprovedPosts();
      final rejected = await _postService.getRejectedPosts();
      setState(() {
        _pendingPosts = pending;
        _approvedPosts = approved;
        _rejectedPosts = rejected;
        _filteredPosts = pending;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterPosts() {
    List<JobPostModel> currentList;
    switch (_selectedTab) {
      case 0:
        currentList = _pendingPosts;
        break;
      case 1:
        currentList = _approvedPosts;
        break;
      case 2:
        currentList = _rejectedPosts;
        break;
      default:
        currentList = _pendingPosts;
    }

    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPosts = currentList.where((post) {
        return query.isEmpty ||
            post.title.toLowerCase().contains(query) ||
            post.description.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _switchTab(int index) {
    setState(() => _selectedTab = index);
    _filterPosts();
  }

  Future<void> _approvePost(JobPostModel post) async {
    try {
      await _postService.approvePost(post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post approved'), backgroundColor: Colors.green),
      );
      _loadPosts();
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
        _loadPosts();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Moderation'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search job posts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatCard(
                  count: _pendingPosts.length,
                  label: 'Pending',
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  count: _approvedPosts.length,
                  label: 'Approved',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  count: _rejectedPosts.length,
                  label: 'Rejected',
                  color: Colors.red,
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _TabButton(
                  label: 'Pending',
                  isSelected: _selectedTab == 0,
                  count: _pendingPosts.length,
                  onTap: () => _switchTab(0),
                ),
                _TabButton(
                  label: 'Approved',
                  isSelected: _selectedTab == 1,
                  count: _approvedPosts.length,
                  onTap: () => _switchTab(1),
                ),
                _TabButton(
                  label: 'Rejected',
                  isSelected: _selectedTab == 2,
                  count: _rejectedPosts.length,
                  onTap: () => _switchTab(2),
                ),
              ],
            ),
          ),

          // Posts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPosts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No posts found', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredPosts.length,
                        itemBuilder: (context, index) {
                          return _PostCard(
                            post: _filteredPosts[index],
                            showActions: _selectedTab == 0,
                            onApprove: _approvePost,
                            onReject: _rejectPost,
                            onView: (post) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatCard({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? Colors.blue[700] : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.blue[700]! : Colors.grey[700],
                      fontSize: 10,
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
  final bool showActions;
  final Function(JobPostModel) onApprove;
  final Function(JobPostModel) onReject;
  final Function(JobPostModel) onView;

  const _PostCard({
    required this.post,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    post.status.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Category & Location
            Text(
              '${post.category} • ${post.location}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            // Author & Date
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  post.submitterName ?? 'Unknown',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${post.postedAt.day}/${post.postedAt.month}/${post.postedAt.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Actions
            if (showActions)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onApprove(post),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => onView(post),
                    icon: const Icon(Icons.visibility),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}