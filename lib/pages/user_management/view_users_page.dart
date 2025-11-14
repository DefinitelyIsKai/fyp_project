import 'package:flutter/material.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/services/user_service.dart';
import 'package:fyp_project/pages/user_management/user_detail_page.dart';

class ViewUsersPage extends StatefulWidget {
  const ViewUsersPage({super.key});

  @override
  State<ViewUsersPage> createState() => _ViewUsersPageState();
}

class _ViewUsersPageState extends State<ViewUsersPage> {
  final UserService _userService = UserService();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedRole = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
        final matchesRole = _selectedRole == 'all' || user.role == _selectedRole;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search users',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'job_seeker', child: Text('Job Seeker')),
                    DropdownMenuItem(value: 'employer', child: Text('Employer')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedRole = value ?? 'all');
                    _filterUsers();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(user.name[0].toUpperCase()),
                              ),
                              title: Text(user.name),
                              subtitle: Text('${user.email} • ${user.role}'),
                              trailing: user.isSuspended
                                  ? const Chip(
                                      label: Text('Suspended'),
                                      backgroundColor: Colors.red,
                                    )
                                  : null,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailPage(user: user),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

