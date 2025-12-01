import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/category_service.dart';
import 'package:fyp_project/pages/admin/user_management/user_detail_page.dart';
import 'package:fyp_project/pages/admin/post_moderation/post_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class SearchFilterPage extends StatefulWidget {
  const SearchFilterPage({super.key});

  @override
  State<SearchFilterPage> createState() => _SearchFilterPageState();
}

class _SearchFilterPageState extends State<SearchFilterPage> {
  final UserService _userService = UserService();
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchType = 'all'; 
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';
  String _selectedLocation = 'all';
  String _selectedRole = 'all';
  
  List<dynamic> _results = [];
  bool _isLoading = false;
  bool _isFiltersExpanded = true;
  List<String> _categories = [];
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
      // Load categories from categories collection (only active ones)
      final categoryModels = await _categoryService.getAllCategories();
      final categories = categoryModels
          .where((cat) => cat.isActive == true)
          .map((cat) => cat.name)
          .where((name) => name.isNotEmpty)
          .toList();
      categories.sort();

      // Load roles from users
      final roles = await _userService.getAllRoles();

      setState(() {
        _categories = categories;
        _roles = roles;
      });
    } catch (e) {
      debugPrint('Error loading filter options: $e');
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

        filteredUsers.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

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
            .where((post) => post.isDraft != true) // Exclude drafts
            .toList();

        // Apply filters
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          filteredPosts = filteredPosts.where((post) {
            final postState = _extractState(post.location).toLowerCase();
            return post.title.toLowerCase().contains(query) ||
                post.description.toLowerCase().contains(query) ||
                post.category.toLowerCase().contains(query) ||
                post.location.toLowerCase().contains(query) ||
                postState.contains(query);
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
              .where((post) {
                final postState = _extractState(post.location);
                return postState.toLowerCase() == _selectedLocation.toLowerCase();
              })
              .toList();
        }

        // Sort posts alphabetically by title
        filteredPosts.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

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

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'all';
      _selectedStatus = 'all';
      _selectedLocation = 'all';
      _selectedRole = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search & Filter',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Section with Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primaryMedium,
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                // Search Bar and Button Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _performSearch,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _isLoading ? 'Searching...' : 'Search',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
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

                // Filter Section (Expandable)
                if (_searchType == 'posts' || _searchType == 'all' || _searchType == 'users') ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isFiltersExpanded = !_isFiltersExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 20,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const Spacer(),
                          // Show active filter count
                          if (_hasActiveFilters())
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_getActiveFilterCount()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Icon(
                            _isFiltersExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Expandable Filters Content
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _isFiltersExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                children: [
                                  // First Row
                                  Row(
                                    children: [
                                      // Category Filter (for posts)
                                      if (_searchType == 'posts' || _searchType == 'all')
                                        Expanded(
                                          child: _FilterChip(
                                            label: 'Category',
                                            value: _selectedCategory == 'all' ? 'All' : _selectedCategory,
                                            onTap: () => _showCategoryFilter(),
                                          ),
                                        ),
                                      if (_searchType == 'posts' || _searchType == 'all') const SizedBox(width: 8),
                                      // Status Filter (for posts)
                                      if (_searchType == 'posts' || _searchType == 'all')
                                        Expanded(
                                          child: _FilterChip(
                                            label: 'Status',
                                            value: _selectedStatus == 'all' ? 'All' : _selectedStatus.toUpperCase(),
                                            onTap: () => _showStatusFilter(),
                                          ),
                                        ),
                                      // Role Filter (for users only)
                                      if (_searchType == 'users' && _searchType != 'all')
                                        Expanded(
                                          child: _FilterChip(
                                            label: 'Role',
                                            value: _selectedRole == 'all' ? 'All' : _getRoleDisplayName(_selectedRole),
                                            onTap: () => _showRoleFilter(),
                                          ),
                                        ),
                                    ],
                                  ),
                                  // Second Row
                                  if ((_searchType == 'posts' || _searchType == 'all') || (_searchType == 'users' || _searchType == 'all')) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        // State Filter (for posts)
                                        if (_searchType == 'posts' || _searchType == 'all')
                                          Expanded(
                                            child: _FilterChip(
                                              label: 'State',
                                              value: _selectedLocation == 'all' ? 'All' : _selectedLocation,
                                              onTap: () => _showLocationFilter(),
                                            ),
                                          ),
                                        if (_searchType == 'posts' || _searchType == 'all') const SizedBox(width: 8),
                                        // Role Filter (for users or all)
                                        if (_searchType == 'users' || _searchType == 'all')
                                          Expanded(
                                            child: _FilterChip(
                                              label: 'Role',
                                              value: _selectedRole == 'all' ? 'All' : _getRoleDisplayName(_selectedRole),
                                              onTap: () => _showRoleFilter(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  // Active Filters Indicator
                                  if (_hasActiveFilters()) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${_getActiveFilterCount()} filter${_getActiveFilterCount() > 1 ? 's' : ''} active',
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: _resetFilters,
                                          icon: const Icon(Icons.clear_all, size: 16),
                                          label: const Text('Clear All'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Results Count
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Found ${_results.length} result${_results.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Results List with Pull to Refresh
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Searching...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      // Re-perform search when pulled to refresh
                      await _performSearch();
                    },
                    child: _results.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No results found',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your search criteria or filters',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    OutlinedButton.icon(
                                      onPressed: _clearFilters,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Clear All Filters'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
          ),
        ],
      ),
    );
  }

  Color _getUserStatusColor(UserModel user) {
    if (user.isSuspended) return Colors.orange;
    if (!user.isActive) return Colors.red;
    return Colors.green;
  }

  String _getUserStatusText(UserModel user) {
    if (user.isSuspended) return 'Suspended';
    if (!user.isActive) return 'Inactive';
    return 'Active';
  }

  String _getRoleDisplayName(String role) {
    return role.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Extract Malaysian state from location string
  String _extractState(String location) {
    if (location.isEmpty) return '';
    
    final locationLower = location.toLowerCase();
    
    // List of Malaysian states and federal territories
    final states = [
      'johor',
      'kedah',
      'kelantan',
      'kuala lumpur',
      'labuan',
      'malacca',
      'melaka',
      'negeri sembilan',
      'pahang',
      'penang',
      'pulau pinang',
      'perak',
      'perlis',
      'putrajaya',
      'sabah',
      'sarawak',
      'selangor',
      'terengganu',
    ];
    
    for (final state in states) {
      if (locationLower.contains(state)) {
        // Normalize state names
        if (state == 'kuala lumpur') return 'Kuala Lumpur';
        if (state == 'pulau pinang' || state == 'penang') return 'Penang';
        if (state == 'melaka' || state == 'malacca') return 'Melaka';
        return state.split(' ').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
      }
    }
    
    return '';
  }

  bool _hasActiveFilters() {
    if (_searchType == 'posts' || _searchType == 'all') {
      return _selectedCategory != 'all' ||
          _selectedStatus != 'all' ||
          _selectedLocation != 'all' ||
          (_searchType == 'all' && _selectedRole != 'all');
    } else if (_searchType == 'users') {
      return _selectedRole != 'all';
    }
    return false;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_searchType == 'posts' || _searchType == 'all') {
      if (_selectedCategory != 'all') count++;
      if (_selectedStatus != 'all') count++;
      if (_selectedLocation != 'all') count++;
      if (_searchType == 'all' && _selectedRole != 'all') count++;
    } else if (_searchType == 'users') {
      if (_selectedRole != 'all') count++;
    }
    return count;
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('All Categories'),
                    trailing: _selectedCategory == 'all'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _selectedCategory = 'all');
                      Navigator.pop(context);
                      _performSearch();
                    },
                  ),
                  ..._categories.map((category) {
                    return ListTile(
                      title: Text(category),
                      trailing: _selectedCategory == category
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() => _selectedCategory = category);
                        Navigator.pop(context);
                        _performSearch();
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['all', 'pending', 'active', 'completed', 'rejected'].map((status) {
              return ListTile(
                title: Text(status == 'all' ? 'All Status' : status.toUpperCase()),
                trailing: _selectedStatus == status
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedStatus = status);
                  Navigator.pop(context);
                  _performSearch();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLocationFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => FutureBuilder<List<String>>(
        future: _getStates(),
        builder: (context, snapshot) {
          final states = snapshot.data ?? [];
          return Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select State',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          children: [
                            ListTile(
                              title: const Text('All States'),
                              trailing: _selectedLocation == 'all'
                                  ? const Icon(Icons.check, color: Colors.blue)
                                  : null,
                              onTap: () {
                                setState(() => _selectedLocation = 'all');
                                Navigator.pop(context);
                                _performSearch();
                              },
                            ),
                            ...states.map((state) {
                              return ListTile(
                                title: Text(state),
                                trailing: _selectedLocation == state
                                    ? const Icon(Icons.check, color: Colors.blue)
                                    : null,
                                onTap: () {
                                  setState(() => _selectedLocation = state);
                                  Navigator.pop(context);
                                  _performSearch();
                                },
                              );
                            }),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<String>> _getStates() async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance.collection('posts').get();
      
      final states = <String>{};
      for (var doc in postsSnapshot.docs) {
        final loc = doc.data()['location'] as String? ?? '';
        if (loc.isNotEmpty) {
          final state = _extractState(loc);
          if (state.isNotEmpty) {
            states.add(state);
          }
        }
      }
      
      final stateList = states.toList()..sort();
      return stateList;
    } catch (e) {
      return [];
    }
  }

  void _showRoleFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Role',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All Roles'),
              trailing: _selectedRole == 'all'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                setState(() => _selectedRole = 'all');
                Navigator.pop(context);
                _performSearch();
              },
            ),
            ..._roles.map((role) {
              return ListTile(
                title: Text(_getRoleDisplayName(role)),
                trailing: _selectedRole == role
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedRole = role);
                  Navigator.pop(context);
                  _performSearch();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final statusColor = _getUserStatusColor(user);
    final statusText = _getUserStatusText(user);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailPage(user: user),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
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
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName.isNotEmpty ? user.fullName : 'Unnamed User',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.email, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getRoleDisplayName(user.role),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (user.location.isNotEmpty)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      user.location,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (user.reportCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag, size: 12, color: Colors.red[700]),
                                const SizedBox(width: 4),
                                Text(
                                  '${user.reportCount} report${user.reportCount > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPostStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatBudget(JobPostModel post) {
    final min = post.budgetMin;
    final max = post.budgetMax;
    if (min == null && max == null) return 'Not specified';
    if (min != null && max != null) {
      return '\$${min.toStringAsFixed(0)} - \$${max.toStringAsFixed(0)}';
    }
    return '\$${(min ?? max)!.toStringAsFixed(0)}';
  }

  Widget _buildPostCard(JobPostModel post) {
    final statusColor = _getPostStatusColor(post.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.work_outline, color: Colors.blue[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  // Title and Status
                  Expanded(
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
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Description preview
                        if (post.description.isNotEmpty)
                          Text(
                            post.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tags and Info
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (post.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category, size: 14, color: Colors.purple[700]),
                          const SizedBox(width: 4),
                          Text(
                            post.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (post.location.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                post.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (post.jobType.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            post.jobType,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_money, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          _formatBudget(post),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Footer with date and view button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Created: ${DateFormat('MMM dd, yyyy').format(post.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: Colors.blue[700]),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != 'All';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.blue[300]! : Colors.grey[300]!,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.blue[700] : Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive ? Colors.blue[700] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}

