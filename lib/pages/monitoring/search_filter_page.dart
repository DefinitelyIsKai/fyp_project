import 'package:flutter/material.dart';
import 'package:fyp_project/models/job_post_model.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/services/post_service.dart';
import 'package:fyp_project/services/user_service.dart';

class SearchFilterPage extends StatefulWidget {
  const SearchFilterPage({super.key});

  @override
  State<SearchFilterPage> createState() => _SearchFilterPageState();
}

class _SearchFilterPageState extends State<SearchFilterPage> {
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'all'; // 'all', 'users', 'posts'
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';
  List<dynamic> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_searchType == 'users' || _searchType == 'all') {
        final users = await _userService.searchUsers(_searchController.text);
        if (_searchType == 'users') {
          setState(() => _results = users);
        } else {
          // Combine with posts if searching all
          final posts = await _postService.searchPosts(_searchController.text);
          setState(() => _results = [...users, ...posts]);
        }
      } else if (_searchType == 'posts') {
        final posts = await _postService.searchPosts(_searchController.text);
        setState(() => _results = posts);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search & Filter')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _results = []);
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _searchType,
                        decoration: const InputDecoration(
                          labelText: 'Search Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'users', child: Text('Users')),
                          DropdownMenuItem(value: 'posts', child: Text('Posts')),
                        ],
                        onChanged: (value) {
                          setState(() => _searchType = value ?? 'all');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _performSearch,
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(child: Text('No results found'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          if (result is UserModel) {
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    result.fullName.isNotEmpty 
                                        ? result.fullName[0].toUpperCase() 
                                        : result.email.isNotEmpty 
                                            ? result.email[0].toUpperCase() 
                                            : '?',
                                  ),
                                ),
                                title: Text(result.fullName),
                                subtitle: Text('${result.email} • ${result.role}'),
                              ),
                            );
                          } else if (result is JobPostModel) {
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text(result.title),
                                subtitle: Text('${result.location} • ${result.category}'),
                                trailing: Chip(
                                  label: Text(result.status.toString().split('.').last),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

