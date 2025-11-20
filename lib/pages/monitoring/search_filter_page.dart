import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/job_post_model.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/services/post_service.dart';
import 'package:fyp_project/services/user_service.dart';
import 'package:fyp_project/pages/user_management/user_detail_page.dart';
import 'package:fyp_project/pages/post_moderation/post_detail_page.dart';
import 'package:intl/intl.dart';

class SearchFilterPage extends StatefulWidget {
  const SearchFilterPage({super.key});

  @override
  State<SearchFilterPage> createState() => _SearchFilterPageState();
}

class _SearchFilterPageState extends State<SearchFilterPage> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchType = 'all'; // 'all', 'users', 'posts'
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';
  String _selectedLocation = 'all';
  String _selectedRole = 'all';
  
  List<dynamic> _results = [];
  bool _isLoading = false;
  List<String> _categories = [];
  List<String> _locations = [];
  List<String> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    try {
      // Load categories from posts
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .get();
      final categories = postsSnapshot.docs
          .map((doc) => doc.data()['category'] as String? ?? '')
          .where((cat) => cat.isNotEmpty)
          .toSet()
          .toList();
      categories.sort();

      // Load locations from posts
      final locations = postsSnapshot.docs
          .map((doc) => doc.data()['location'] as String? ?? '')
          .where((loc) => loc.isNotEmpty)
          .toSet()
          .toList();
      locations.sort();

      // Load roles from users
      final roles = await _userService.getAllRoles();

      setState(() {
        _categories = categories;
        _locations = locations;
        _roles = roles;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> results = [];

      if (_searchType == 'users' || _searchType == 'all') {
        final users = await _userService.getAllUsers();
        var filteredUsers = users;

        // Apply filters
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          filteredUsers = filteredUsers.where((user) {
            return user.fullName.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query) ||
                user.location.toLowerCase().contains(query);
          }).toList();
        }

        if (_selectedRole != 'all') {
          filteredUsers = filteredUsers
              .where((user) => user.role == _selectedRole)
              .toList();
        }

        if (_searchType == 'users') {
          results = filteredUsers;
        } else {
          results.addAll(filteredUsers);
        }
      }

      if (_searchType == 'posts' || _searchType == 'all') {
        final postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .get();
        
        var filteredPosts = postsSnapshot.docs
            .map((doc) => JobPostModel.fromFirestore(doc))
            .toList();

        // Apply filters
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          filteredPosts = filteredPosts.where((post) {
            return post.title.toLowerCase().contains(query) ||
                post.description.toLowerCase().contains(query) ||
                post.category.toLowerCase().contains(query) ||
                post.location.toLowerCase().contains(query);
          }).toList();
        }

        if (_selectedCategory != 'all') {
          filteredPosts = filteredPosts
              .where((post) => post.category == _selectedCategory)
              .toList();
        }

        if (_selectedStatus != 'all') {
          filteredPosts = filteredPosts
              .where((post) => post.status == _selectedStatus)
              .toList();
        }

        if (_selectedLocation != 'all') {
          filteredPosts = filteredPosts
              .where((post) => post.location == _selectedLocation)
              .toList();
        }

        if (_searchType == 'posts') {
          results = filteredPosts;
        } else {
          results.addAll(filteredPosts);
        }
      }

      setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = 'all';
      _selectedStatus = 'all';
      _selectedLocation = 'all';
      _selectedRole = 'all';
      _results = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
            tooltip: 'Clear Filters',
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
                  'Search & Filter',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search users and posts using keywords, categories, or status',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Search and Filters Section
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
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by keywords...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _performSearch(),
                ),
                const SizedBox(height: 12),

                // Search Type
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'users', label: Text('Users')),
                          ButtonSegment(value: 'posts', label: Text('Posts')),
                        ],
                        selected: {_searchType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _searchType = newSelection.first;
                            _results = [];
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filters Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Category Filter (for posts)
                    if (_searchType == 'posts' || _searchType == 'all')
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Categories')),
                            ..._categories.map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCategory = value ?? 'all');
                          },
                        ),
                      ),

                    // Status Filter (for posts)
                    if (_searchType == 'posts' || _searchType == 'all')
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Status')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'completed', child: Text('Completed')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedStatus = value ?? 'all');
                          },
                        ),
                      ),

                    // Location Filter (for posts)
                    if (_searchType == 'posts' || _searchType == 'all')
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _selectedLocation,
                          decoration: InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Locations')),
                            ..._locations.map((loc) => DropdownMenuItem(
                                  value: loc,
                                  child: Text(loc),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedLocation = value ?? 'all');
                          },
                        ),
                      ),

                    // Role Filter (for users)
                    if (_searchType == 'users' || _searchType == 'all')
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Roles')),
                            ..._roles.map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedRole = value ?? 'all');
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _performSearch,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Searching...' : 'Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Results Count
                if (_results.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Found ${_results.length} result(s)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search criteria',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          if (result is UserModel) {
                            return _buildUserCard(result);
                          } else if (result is JobPostModel) {
                            return _buildPostCard(result);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            user.fullName.isNotEmpty
                ? user.fullName[0].toUpperCase()
                : user.email.isNotEmpty
                    ? user.email[0].toUpperCase()
                    : '?',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${user.email} • ${user.role}'),
            Text(
              'Location: ${user.location}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (user.reportCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${user.reportCount} report(s)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailPage(user: user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(JobPostModel post) {
    Color statusColor;
    switch (post.status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'active':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.article, color: Colors.blue[700]),
        ),
        title: Text(
          post.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${post.category} • ${post.location}'),
            Text(
              'Created: ${DateFormat('dd/MM/yyyy').format(post.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                post.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailPage(post: post),
            ),
          );
        },
      ),
    );
  }
}
