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
  String _selectedIndustry = 'All Industries';
  String _selectedLocation = 'All Locations';

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final pending = await _postService.getPendingPosts();
      final approved = await _postService.getApprovedPosts();
      final rejected = await _postService.getRejectedPosts();
      if (mounted) {
        setState(() {
          _pendingPosts = pending;
          _approvedPosts = approved;
          _rejectedPosts = rejected;
        });
        _updateFilteredPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPosts() {
    _updateFilteredPosts();
  }

  void _switchTab(int index) {
    setState(() {
      _selectedTab = index;
    });
    _updateFilteredPosts();
  }

  void _updateFilteredPosts() {
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
        final matchesSearch = query.isEmpty ||
            post.title.toLowerCase().contains(query) ||
            post.description.toLowerCase().contains(query) ||
            post.location.toLowerCase().contains(query);
        final matchesIndustry = _selectedIndustry == 'All Industries' ||
            post.category == _selectedIndustry;
        final matchesLocation = _selectedLocation == 'All Locations' ||
            post.location == _selectedLocation;
        return matchesSearch && matchesIndustry && matchesLocation;
      }).toList();
    });
  }

  Future<void> _approvePost(JobPostModel post) async {
    if (!mounted) return;
    try {
      await _postService.approvePost(post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post approved successfully')),
        );
        _loadPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectPost(JobPostModel post) async {
    if (!mounted) return;
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject Post'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Rejection reason',
              hintText: 'Enter reason for rejection',
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (reason != null && mounted) {
        await _postService.rejectPost(post.id, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post rejected')),
          );
          _loadPosts();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  int _getPendingCount() => _pendingPosts.length;
  int _getApprovedCount() => _approvedPosts.length;
  int _getRejectedCount() => _rejectedPosts.length;

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(),
            // Search Bar
            _buildSearchBar(),
            // Filter Dropdowns
            _buildFilters(),
            // Tabs
            _buildTabs(),
            // Posts List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPosts.isEmpty
                      ? const Center(child: Text('No posts found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredPosts.length,
                          itemBuilder: (context, index) {
                            return _buildPostCard(_filteredPosts[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          // Hamburger Menu
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          const SizedBox(width: 16),
          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Post Moderation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Review & approve job posts',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Notification Bell
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Icon(Icons.notifications_outlined),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Profile Picture
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: ClipOval(
              child: Image.network(
                'https://i.pravatar.cc/150?img=1',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.person);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search job posts...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButton<String>(
                value: _selectedIndustry,
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down),
                items: ['All Industries', 'Technology', 'Marketing', 'Retail', 'Healthcare']
                    .map((industry) => DropdownMenuItem(
                          value: industry,
                          child: Text(industry),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedIndustry = value!);
                  _filterPosts();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButton<String>(
                value: _selectedLocation,
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down),
                items: ['All Locations', 'San Francisco', 'New York', 'Seattle', 'Los Angeles']
                    .map((location) => DropdownMenuItem(
                          value: location,
                          child: Text(location),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedLocation = value!);
                  _filterPosts();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildTab(0, 'Pending', _getPendingCount(), Colors.purple),
          ),
          Expanded(
            child: _buildTab(1, 'Approved', _getApprovedCount(), Colors.grey),
          ),
          Expanded(
            child: _buildTab(2, 'Rejected', _getRejectedCount(), Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, int count, Color color) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => _switchTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.purple : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.purple : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(JobPostModel post) {
    final formattedDate = _formatDate(post.postedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status Tag
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(12),
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
            // Company & Category
            Text(
              '${post.category} • ${post.location}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            // Submitter Info and Date
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  post.submitterName ?? 'Unknown',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedTab == 0
                        ? () => _approvePost(post)
                        : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedTab == 0
                        ? () => _rejectPost(post)
                        : null,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(post: post),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.check_circle, 'Moderate', true),
            _buildNavItem(Icons.bar_chart, 'Analytics', false),
            _buildNavItem(Icons.settings, 'Settings', false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return InkWell(
      onTap: () {
        // Handle navigation
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.purple : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.purple : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
