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
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
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
        final matchesSearch = user.fullName.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);

        final matchesRole = _selectedRole == 'all' || user.role == _selectedRole;

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Color _getStatusColor(UserModel user) {
    if (user.isSuspended) return Colors.orange;
    if (!user.isActive) return Colors.red;
    return Colors.green;
  }

  String _getStatusText(UserModel user) {
    if (user.isSuspended) return 'Suspended';
    if (!user.isActive) return 'Inactive';
    return 'Active';
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'job_seeker':
        return 'Jobseeker';
      case 'employer':
        return 'Employer';
      case 'employee':
        return 'Employee';
      case 'staff':
        return 'Staff';
      case 'HR':
        return 'HR';
      case 'manager':
        return 'Manager';
      default:
        return role;
    }
  }

  Widget _buildActionButtons(UserModel user) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // View Profile Button
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailPage(user: user),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[50],
            foregroundColor: Colors.blue[700],
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          icon: const Icon(Icons.person, size: 16),
          label: const Text(
            'View Profile',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),

        // Status Toggle Button
        ElevatedButton.icon(
          onPressed: () {
            _toggleUserStatus(user);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: user.isSuspended ? Colors.green[50] : Colors.orange[50],
            foregroundColor: user.isSuspended ? Colors.green[700] : Colors.orange[700],
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          icon: Icon(
            user.isSuspended ? Icons.check_circle : Icons.pause_circle,
            size: 16,
          ),
          label: Text(
            user.isSuspended ? 'Activate' : 'Suspend',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),

        // Delete Button
        ElevatedButton.icon(
          onPressed: () {
            _deleteUser(user);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[50],
            foregroundColor: Colors.red[700],
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          icon: const Icon(Icons.delete, size: 16),
          label: const Text(
            'Delete',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _toggleUserStatus(UserModel user) {
    final bool isSuspended = user.status == 'Suspended';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSuspended ? 'Activate User' : 'Suspend User'),
        content: Text(
          'Are you sure you want to ${isSuspended ? 'activate' : 'suspend'} ${user.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (isSuspended) {
                  await _userService.unsuspendUser(user.id);
                } else {
                  await _userService.suspendUser(user.id);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${user.fullName} ${isSuspended ? 'activated' : 'suspended'} successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                _loadUsers(); // refresh
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isSuspended ? 'Activate' : 'Suspend'),
          ),
        ],
      ),
    );
  }


  void _deleteUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.fullName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _userService.deleteUser(user.id);
                _loadUsers(); // Refresh the list
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.fullName} deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatUserId(String userId) {
    // Show only first 8 characters of user ID for better readability
    return userId.length > 8 ? '${userId.substring(0, 8)}...' : userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
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
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users by name or email...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedRole,
                              isExpanded: true,
                              icon: const Icon(Icons.filter_list, color: Colors.grey),
                              items: const [
                                DropdownMenuItem(
                                    value: 'all', child: Text('All Roles')),
                                DropdownMenuItem(
                                    value: 'job_seeker', child: Text('Job Seekers')),
                                DropdownMenuItem(
                                    value: 'employer', child: Text('Employers')),
                                DropdownMenuItem(
                                    value: 'employee', child: Text('Employees')),
                                DropdownMenuItem(
                                    value: 'staff', child: Text('Staff')),
                                DropdownMenuItem(
                                    value: 'HR', child: Text('HR')),
                                DropdownMenuItem(
                                    value: 'manager', child: Text('Manager')),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedRole = value ?? 'all');
                                _filterUsers();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
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
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.grey),
                        onPressed: _loadUsers,
                        tooltip: 'Refresh',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Count
          if (!_isLoading && _filteredUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.grey[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredUsers.length} user${_filteredUsers.length == 1 ? '' : 's'} found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedRole != 'all')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getRoleDisplayName(_selectedRole),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading users...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : _filteredUsers.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isEmpty &&
                      _selectedRole == 'all'
                      ? 'No users found'
                      : 'No users match your search',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your search or filters',
                  style: TextStyle(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            )
                : ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                final status = _getStatusText(user);
                final statusColor = _getStatusColor(user);

                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name and Status Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName
                                      : 'Unnamed User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Email
                          Text(
                            user.email,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Role and ID
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_getRoleDisplayName(user.role)} + ID: ${_formatUserId(user.id)}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Joined: ${_formatDate(user.createdAt)}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Action Buttons
                          _buildActionButtons(user),
                        ],
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