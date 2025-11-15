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

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final suspended = await _userService.getSuspendedUsers();
      final reported = await _userService.getReportedUsers();
      setState(() {
        _suspendedUsers = suspended;
        _reportedUsers = reported;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account Management'),
          backgroundColor: Colors.blue[700],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause_circle_outline, size: 18),
                    const SizedBox(width: 6),
                    const Text('Suspended'),
                    if (_suspendedUsers.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _suspendedUsers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, size: 18),
                    const SizedBox(width: 6),
                    const Text('Reported'),
                    if (_reportedUsers.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _reportedUsers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildUserList(_suspendedUsers, true),
                  _buildUserList(_reportedUsers, false),
                ],
              ),
      ),
    );
  }

  Widget _buildUserList(List<UserModel> users, bool isSuspended) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSuspended ? Icons.people_outline : Icons.flag_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isSuspended ? 'No suspended users' : 'No reported users',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSuspended ? Colors.orange[100] : Colors.red[100],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSuspended ? Colors.orange[800] : Colors.red[800],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isSuspended && (user.reportCount ?? 0) > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.flag, size: 12, color: Colors.red[700]),
                              const SizedBox(width: 4),
                              Text(
                                '${user.reportCount} reports',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions
                  isSuspended
                      ? ElevatedButton(
                          onPressed: () => _unsuspendUser(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Unsuspend'),
                        )
                      : Column(
                          children: [
                            ElevatedButton(
                              onPressed: () => _suspendUser(user),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('Suspend'),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton(
                              onPressed: () => _confirmDelete(user),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _unsuspendUser(UserModel user) async {
    await _userService.unsuspendUser(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.fullName} unsuspended'), backgroundColor: Colors.green),
    );
    _loadUsers();
  }

  Future<void> _suspendUser(UserModel user) async {
    await _userService.suspendUser(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.fullName} suspended'), backgroundColor: Colors.orange),
    );
    _loadUsers();
  }

  Future<void> _confirmDelete(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _userService.deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted'), backgroundColor: Colors.green),
      );
      _loadUsers();
    }
  }
}