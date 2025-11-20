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
      _showSnackBar('Error loading users: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Account Management',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.blue[700],
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontSize: 14),
            tabs: [
              _buildTab('Suspended', Icons.pause_circle_outline, _suspendedUsers.length, Colors.orange),
              _buildTab('Reported', Icons.flag, _reportedUsers.length, Colors.red),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadUsers,
          color: Colors.blue[700],
          child: TabBarView(
            children: [
              _buildSuspendedUsersList(),
              _buildReportedUsersList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String title, IconData icon, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(title),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
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
    );
  }

  Widget _buildSuspendedUsersList() {
    if (_suspendedUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Suspended Users',
        subtitle: 'All user accounts are currently active',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suspendedUsers.length,
      itemBuilder: (context, index) {
        final user = _suspendedUsers[index];
        return _buildUserCard(user, isSuspended: true);
      },
    );
  }

  Widget _buildReportedUsersList() {
    if (_reportedUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.flag_outlined,
        title: 'No Reported Users',
        subtitle: 'No user reports at this time',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportedUsers.length,
      itemBuilder: (context, index) {
        final user = _reportedUsers[index];
        return _buildUserCard(user, isSuspended: false);
      },
    );
  }

  Widget _buildUserCard(UserModel user, {required bool isSuspended}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Avatar with status
                  _buildUserAvatar(user, isSuspended),
                  const SizedBox(width: 12),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.isNotEmpty ? user.fullName : 'Unnamed User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSuspended ? Colors.orange[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSuspended ? Colors.orange[200]! : Colors.red[200]!,
                      ),
                    ),
                    child: Text(
                      isSuspended ? 'Suspended' : 'Reported',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSuspended ? Colors.orange[800] : Colors.red[800],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Report Count (for reported users)
              if (!isSuspended && (user.reportCount ?? 0) > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Text(
                        '${user.reportCount} report${user.reportCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Action Buttons
              Row(
                children: isSuspended
                    ? [_buildUnsuspendButton(user)]
                    : [
                  Expanded(child: _buildSuspendButton(user)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDeleteButton(user)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(UserModel user, bool isSuspended) {
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSuspended ? Colors.orange[100] : Colors.red[100],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSuspended ? Colors.orange[800] : Colors.red[800],
              ),
            ),
          ),
        ),
        if (isSuspended)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
              ),
              child: const Icon(Icons.pause, size: 8, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildUnsuspendButton(UserModel user) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _unsuspendUser(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text(
          'Unsuspend Account',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSuspendButton(UserModel user) {
    return ElevatedButton.icon(
      onPressed: () => _showSuspendDialog(user),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[50],
        foregroundColor: Colors.orange[700],
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.orange[300]!),
        ),
      ),
      icon: const Icon(Icons.pause_circle_outline, size: 16),
      label: const Text(
        'Suspend',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _buildDeleteButton(UserModel user) {
    return ElevatedButton.icon(
      onPressed: () => _showDeleteDialog(user),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red[700],
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.red[300]!),
        ),
      ),
      icon: const Icon(Icons.delete_outline, size: 16),
      label: const Text(
        'Delete',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _unsuspendUser(UserModel user) async {
    try {
      await _userService.unsuspendUser(user.id);
      if (!mounted) return;
      _showSnackBar('${user.fullName} has been unsuspended');
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to unsuspend user: $e', isError: true);
    }
  }

  Future<void> _showSuspendDialog(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Suspend User Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to suspend ${user.fullName}\'s account.'),
            const SizedBox(height: 8),
            const Text(
              'Suspended users cannot access the platform until their account is unsuspended.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Suspend Account'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _suspendUser(user);
    }
  }

  Future<void> _suspendUser(UserModel user) async {
    try {
      await _userService.suspendUser(user.id);
      if (!mounted) return;
      _showSnackBar('${user.fullName} has been suspended');
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to suspend user: $e', isError: true);
    }
  }

  Future<void> _showDeleteDialog(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete User Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to permanently delete ${user.fullName}\'s account.'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All user data will be permanently removed from the system.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteUser(user);
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    try {
      await _userService.deleteUser(user.id);
      if (!mounted) return;
      _showSnackBar('${user.fullName}\'s account has been deleted');
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to delete user: $e', isError: true);
    }
  }
}