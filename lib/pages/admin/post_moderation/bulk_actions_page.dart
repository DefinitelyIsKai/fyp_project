import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:fyp_project/pages/admin/post_moderation/post_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class BulkActionsPage extends StatefulWidget {
  const BulkActionsPage({super.key});

  @override
  State<BulkActionsPage> createState() => _BulkActionsPageState();
}

class _BulkActionsPageState extends State<BulkActionsPage> {
  final PostService _postService = PostService();
  final Set<String> _selectedPostIds = {};
  String _filterStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Actions'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bulk Actions',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Perform batch operations on multiple posts efficiently',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Compact Search and Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Search Bar (Compact)
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
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
                        borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Filter Chips (Horizontal Scroll)
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All', Colors.grey),
                        const SizedBox(width: 6),
                        _buildFilterChip('pending', 'Pending', Colors.orange),
                        const SizedBox(width: 6),
                        _buildFilterChip('active', 'Active', Colors.green),
                        const SizedBox(width: 6),
                        _buildFilterChip('completed', 'Completed', Colors.blue),
                        const SizedBox(width: 6),
                        _buildFilterChip('rejected', 'Rejected', Colors.red),
                        if (_filterStatus != 'all' || _searchQuery.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _filterStatus = 'all';
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Compact Selection Bar (Fixed at bottom when items selected)
          if (_selectedPostIds.isNotEmpty)
            StreamBuilder<List<JobPostModel>>(
              stream: _getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                
                final allPosts = snapshot.data ?? [];
                final selectedPosts = allPosts.where((post) => _selectedPostIds.contains(post.id)).toList();
                
                // Check which actions are valid for selected posts
                final canApprove = selectedPosts.any((post) => post.status == 'pending' || post.status == 'rejected');
                final canComplete = selectedPosts.any((post) => post.status == 'active');
                final canReject = selectedPosts.any((post) => post.status == 'pending' || post.status == 'active');
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.blue[200]!, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_selectedPostIds.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickActionButton(
                                label: 'Approve',
                                color: Colors.green,
                                onPressed: canApprove ? () => _performBulkAction('approve') : null,
                              ),
                              const SizedBox(width: 4),
                              _buildQuickActionButton(
                                label: 'Complete',
                                color: Colors.blue,
                                onPressed: canComplete ? () => _performBulkAction('complete') : null,
                              ),
                              const SizedBox(width: 4),
                              _buildQuickActionButton(
                                label: 'Reject',
                                color: Colors.orange,
                                onPressed: canReject ? () => _performBulkAction('reject') : null,
                              ),
                              const SizedBox(width: 4),
                              _buildQuickActionButton(
                                label: 'Delete',
                                color: Colors.red,
                                onPressed: () => _showDeleteConfirmation(),
                              ),
                              const SizedBox(width: 4),
                              _buildQuickActionButton(
                                label: 'More',
                                color: Colors.grey,
                                onPressed: _showBulkActionDialog,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () {
                          setState(() => _selectedPostIds.clear());
                        },
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.blue[700],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Clear selection',
                      ),
                    ],
                  ),
                );
              },
            ),

          // Compact Results Count and Select All
          StreamBuilder<List<JobPostModel>>(
            stream: _getPostsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              
              final posts = snapshot.data ?? [];
              final filteredPosts = _filterPosts(posts);
              
              if (filteredPosts.isEmpty) {
                return const SizedBox.shrink();
              }
              
              final allSelected = filteredPosts.every((post) => _selectedPostIds.contains(post.id));
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${filteredPosts.length} post${filteredPosts.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (filteredPosts.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              for (var post in filteredPosts) {
                                _selectedPostIds.remove(post.id);
                              }
                            } else {
                              for (var post in filteredPosts) {
                                _selectedPostIds.add(post.id);
                              }
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Posts List
          Expanded(
            child: StreamBuilder<List<JobPostModel>>(
              stream: _getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final posts = snapshot.data ?? [];
                final filteredPosts = _filterPosts(posts);

                if (filteredPosts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No posts found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try adjusting your search or filter'
                              : 'No posts match the current filter',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) {
                    final post = filteredPosts[index];
                    final isSelected = _selectedPostIds.contains(post.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 4 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? BorderSide(color: Colors.blue[700]!, width: 2)
                            : BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Checkbox
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedPostIds.add(post.id);
                                  } else {
                                    _selectedPostIds.remove(post.id);
                                  }
                                });
                              },
                              activeColor: Colors.blue[700],
                            ),
                          ),
                          // Post Content (Clickable to view details)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostDetailPage(post: post),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            post.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        _buildStatusChip(post.status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (post.category.isNotEmpty) ...[
                                      _buildInfoRow(Icons.category, post.category),
                                      const SizedBox(height: 4),
                                    ],
                                    if (post.location.isNotEmpty) ...[
                                      _buildInfoRow(Icons.location_on, post.location),
                                      const SizedBox(height: 4),
                                    ],
                                    _buildInfoRow(
                                      Icons.calendar_today,
                                      DateFormat('dd MMM yyyy, HH:mm').format(post.createdAt),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'View Details',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 12,
                                          color: Colors.blue[700],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedPostIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showBulkActionDialog,
              backgroundColor: AppColors.primaryDark,
              icon: const Icon(Icons.play_arrow),
              label: Text('${_selectedPostIds.length} Selected'),
            )
          : null,
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Stream<List<JobPostModel>> _getPostsStream() {
    if (_filterStatus == 'all') {
      return _postService.streamAllPosts();
    } else {
      return _postService.streamPostsByStatus(_filterStatus);
    }
  }

  List<JobPostModel> _filterPosts(List<JobPostModel> posts) {
    if (_searchQuery.isEmpty) return posts;

    final query = _searchQuery.toLowerCase();
    return posts.where((post) {
      return post.title.toLowerCase().contains(query) ||
          post.category.toLowerCase().contains(query) ||
          post.location.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'active':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.done_all;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, Color color) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _selectedPostIds.clear();
        });
      },
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey[300]!,
        width: isSelected ? 1.5 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDisabled ? Colors.grey : color,
        side: BorderSide(color: isDisabled ? Colors.grey[300]! : color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: isDisabled ? Colors.grey : null)),
    );
  }

  void _showBulkActionDialog() {
    if (_selectedPostIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.playlist_add_check, color: Colors.blue[700], size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk Actions',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedPostIds.length} post${_selectedPostIds.length == 1 ? '' : 's'} selected',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Action Cards
              _buildActionCard(
                icon: Icons.check_circle,
                iconColor: Colors.green,
                backgroundColor: Colors.green[50]!,
                title: 'Approve Selected',
                description: 'Move selected posts to active status',
                onTap: () {
                  Navigator.pop(context);
                  _performBulkAction('approve');
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.done_all,
                iconColor: Colors.blue,
                backgroundColor: Colors.blue[50]!,
                title: 'Mark as Completed',
                description: 'Mark selected posts as completed',
                onTap: () {
                  Navigator.pop(context);
                  _performBulkAction('complete');
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.cancel,
                iconColor: Colors.orange,
                backgroundColor: Colors.orange[50]!,
                title: 'Reject Selected',
                description: 'Reject selected posts with a reason',
                onTap: () {
                  Navigator.pop(context);
                  _performBulkAction('reject');
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.delete_outline,
                iconColor: Colors.red,
                backgroundColor: Colors.red[50]!,
                title: 'Delete Selected',
                description: 'Mark selected posts as deleted',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation();
                },
              ),
              const SizedBox(height: 20),
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red[900] : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber, color: Colors.red[700], size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirm Deletion',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedPostIds.length} post${_selectedPostIds.length == 1 ? '' : 's'}? The post${_selectedPostIds.length == 1 ? '' : 's'} will be marked as deleted.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performBulkAction('delete');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkAction(String action) async {
    if (_selectedPostIds.isEmpty) return;

    // Get current posts to validate action
    final postsSnapshot = await _getPostsStream().first;
    final selectedPosts = postsSnapshot.where((post) => _selectedPostIds.contains(post.id)).toList();
    
    // Validate action based on post statuses
    List<JobPostModel> validPosts = [];
    List<String> invalidStatuses = [];
    
    for (final post in selectedPosts) {
      bool isValid = false;
      switch (action) {
        case 'approve':
          isValid = post.status == 'pending' || post.status == 'rejected';
          break;
        case 'complete':
          isValid = post.status == 'active';
          break;
        case 'reject':
          isValid = post.status == 'pending' || post.status == 'active';
          break;
        case 'delete':
          isValid = true; // Can delete any post
          break;
        default:
          isValid = false;
      }
      
      if (isValid) {
        validPosts.add(post);
      } else {
        invalidStatuses.add('${post.title} (${post.status})');
      }
    }
    
    // Show warning if some posts can't be processed
    if (invalidStatuses.isNotEmpty && validPosts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot $action selected posts. None of the selected posts are in a valid status for this action.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    if (invalidStatuses.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Some Posts Cannot Be Processed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${invalidStatuses.length} post(s) cannot be $action${action == 'approve' ? 'd' : action == 'complete' ? 'd' : action == 'reject' ? 'ed' : 'd'} due to their current status:'),
              const SizedBox(height: 12),
              ...invalidStatuses.take(5).map((status) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $status', style: const TextStyle(fontSize: 12)),
              )),
              if (invalidStatuses.length > 5)
                Text('... and ${invalidStatuses.length - 5} more', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              const Text('Do you want to proceed with the remaining posts?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      
      if (proceed != true) return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Processing ${validPosts.length} post${validPosts.length == 1 ? '' : 's'}...'),
          ],
        ),
      ),
    );

    try {
      int successCount = 0;
      int failCount = 0;
      List<String> failedIds = [];

      for (final post in validPosts) {
        try {
          switch (action) {
            case 'approve':
              await _postService.approvePost(post.id);
              break;
            case 'reject':
              // For bulk reject, we'll use a default reason
              // Individual rejection with custom reason can be done separately
              await _postService.rejectPost(post.id, 'Rejected via bulk action');
              break;
            case 'delete':
              await _postService.deletePost(post.id);
              break;
            case 'complete':
              await _postService.completePost(post.id);
              break;
          }
          successCount++;
        } catch (e) {
          failCount++;
          failedIds.add(post.id);
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  failCount > 0 ? Icons.warning_amber : Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    failCount > 0
                        ? 'Completed: $successCount, Failed: $failCount'
                        : 'Successfully processed $successCount post${successCount == 1 ? '' : 's'}',
                  ),
                ),
              ],
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        setState(() {
          _selectedPostIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
