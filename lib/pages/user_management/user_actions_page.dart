import 'package:flutter/material.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/services/user_service.dart';

class UserActionsPage extends StatefulWidget {
  const UserActionsPage({super.key});

  @override
  State<UserActionsPage> createState() => _UserActionsPageState();
}

class _UserActionsPageState extends State<UserActionsPage> {
  final UserService _userService = UserService();
  List<UserModel> _suspendedUsers = [];
  List<UserModel> _reportedUsers = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final suspended = await _userService.getSuspendedUsers();
      final reported = await _userService.getReportedUsers();
      if (mounted) {
        setState(() {
          _suspendedUsers = suspended;
          _reportedUsers = reported;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suspend / Delete Accounts'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              onTap: (index) {
                if (mounted) {
                  setState(() => _selectedTab = index);
                }
              },
              indicatorColor: Colors.purple,
              labelColor: Colors.purple,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Suspended Users'),
                Tab(text: 'Reported Users'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                    ? _buildSuspendedUsersList()
                    : _buildReportedUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspendedUsersList() {
    if (_suspendedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No suspended users',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suspendedUsers.length,
      itemBuilder: (context, index) {
        final user = _suspendedUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.orange[100],
              child: Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(user.email),
            trailing: ElevatedButton(
              onPressed: () async {
                if (!mounted) return;
                try {
                  await _userService.unsuspendUser(user.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User unsuspended successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  if (mounted) {
                    _loadUsers();
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Unsuspend'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportedUsersList() {
    if (_reportedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reported users',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportedUsers.length,
      itemBuilder: (context, index) {
        final user = _reportedUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.red[100],
              child: Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.flag, size: 14, color: Colors.red[700]),
                    const SizedBox(width: 4),
                    Text(
                      '${user.reportCount ?? 0} reports',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Suspend User',
                  child: IconButton(
                    icon: const Icon(Icons.block, color: Colors.orange),
                    onPressed: () async {
                      if (!mounted) return;
                      try {
                        await _userService.suspendUser(user.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User suspended successfully'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        if (mounted) {
                          _loadUsers();
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
                    },
                  ),
                ),
                Tooltip(
                  message: 'Delete User',
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      if (!mounted) return;
                      
                      try {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Delete User'),
                            content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (!mounted) return;
                        
                        if (confirm == true) {
                          try {
                            await _userService.deleteUser(user.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            if (mounted) {
                              _loadUsers();
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
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error showing dialog: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

