import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/job_post_model.dart';
import 'package:fyp_project/services/post_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Actions'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedPostIds.isNotEmpty)
            TextButton.icon(
              onPressed: _showBulkActionDialog,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text(
                'Actions',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green[700],
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
                  'Perform batch operations on multiple posts',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Filters and Search
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search posts by title...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 12),
                // Status Filter
                Row(
                  children: [
                    const Text('Filter by Status: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'pending', label: Text('Pending')),
                          ButtonSegment(value: 'active', label: Text('Active')),
                          ButtonSegment(value: 'rejected', label: Text('Rejected')),
                        ],
                        selected: {_filterStatus},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _filterStatus = newSelection.first;
                            _selectedPostIds.clear();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Selection Info
                if (_selectedPostIds.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedPostIds.length} post(s) selected',
                          style: TextStyle(
                            color: Colors.green[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedPostIds.clear());
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
                  return Center(child: Text('Error: ${snapshot.error}'));
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
                          style: TextStyle(color: Colors.grey[600]),
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
                            ? BorderSide(color: Colors.green[700]!, width: 2)
                            : BorderSide.none,
                      ),
                      child: CheckboxListTile(
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
                        title: Text(
                          post.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Category: ${post.category}'),
                            Text('Location: ${post.location}'),
                            Text(
                              'Created: ${_formatDate(post.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        secondary: _buildStatusChip(post.status),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
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
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'active':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showBulkActionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Approve Selected'),
              onTap: () {
                Navigator.pop(context);
                _performBulkAction('approve');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Reject Selected'),
              onTap: () {
                Navigator.pop(context);
                _performBulkAction('reject');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Selected'),
              onTap: () {
                Navigator.pop(context);
                _performBulkAction('delete');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.blue),
              title: const Text('Mark as Completed'),
              onTap: () {
                Navigator.pop(context);
                _performBulkAction('complete');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkAction(String action) async {
    if (_selectedPostIds.isEmpty) return;

    try {
      int successCount = 0;
      int failCount = 0;

      for (final postId in _selectedPostIds) {
        try {
          switch (action) {
            case 'approve':
              await _postService.approvePost(postId);
              break;
            case 'reject':
              await _showRejectDialog(postId);
              break;
            case 'delete':
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .delete();
              break;
            case 'complete':
              await _postService.completePost(postId);
              break;
          }
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Success: $successCount, Failed: $failCount',
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          ),
        );
        setState(() {
          _selectedPostIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(String postId) async {
    final reasonController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Post'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter reason for rejection...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, reasonController.text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _postService.rejectPost(postId, result);
    }
  }
}

