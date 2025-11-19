import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
        _showSnackBar('Error loading users: $e', isError: true);
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

  Future<void> _sendViolationNotification({
    required String userId,
    required String violationReason,
    required int durationDays,
    required String userName,
    required String userEmail,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'body': 'Your account has been suspended for $durationDays days due to violation of our community guidelines. Reason: $violationReason',
        'category': 'account_suspension',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'violationReason': violationReason,
          'suspensionDuration': durationDays,
          'userName': userName,
          'userEmail': userEmail,
          'actionType': 'suspension',
        },
        'title': 'Account Suspension Notice',
        'userId': userId,
      });
    } catch (e) {
      print('Error sending violation notification: $e');
    }
  }

  Future<void> _sendUnsuspensionNotification({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'body': 'Your account suspension has been lifted. You can now access all features normally.',
        'category': 'account_unsuspension',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'userName': userName,
          'userEmail': userEmail,
          'actionType': 'unsuspension',
        },
        'title': 'Account Access Restored',
        'userId': userId,
      });
    } catch (e) {
      print('Error sending unsuspension notification: $e');
    }
  }

  Future<void> _sendDeletionNotification({
    required String userId,
    required String userName,
    required String userEmail,
    required String deletionReason,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'body': 'Your account has been permanently deleted due to severe violations of our community guidelines. Reason: $deletionReason',
        'category': 'account_deletion',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'deletionReason': deletionReason,
          'userName': userName,
          'userEmail': userEmail,
          'actionType': 'deletion',
        },
        'title': 'Account Deletion Notice',
        'userId': userId,
      });
    } catch (e) {
      print('Error sending deletion notification: $e');
    }
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
            if (user.isSuspended) {
              _unsuspendUser(user);
            } else {
              _showSuspendDialog(user);
            }
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
            _showDeleteDialog(user);
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

  Future<void> _showSuspendDialog(UserModel user) async {
    final violationController = TextEditingController();
    final durationController = TextEditingController(text: '7');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Suspend User Account'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to suspend ${user.fullName}.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              const Text(
                'Violation Reason *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: violationController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Explain the violation (this will be sent to the user)...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),

              const Text(
                'Suspension Duration (days)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter number of days',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The user will receive a notification explaining the violation and suspension duration.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final violationReason = violationController.text.trim();
              final duration = int.tryParse(durationController.text.trim()) ?? 7;

              if (violationReason.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a violation reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _suspendUser(user, violationReason, duration);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Suspend Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _suspendUser(UserModel user, String violationReason, int durationDays) async {
    try {
      // Send violation notification first
      await _sendViolationNotification(
        userId: user.id,
        violationReason: violationReason,
        durationDays: durationDays,
        userName: user.fullName,
        userEmail: user.email,
      );

      // Then suspend the user
      await _userService.suspendUser(user.id);

      if (!mounted) return;
      _showSnackBar('${user.fullName} suspended for $durationDays days');
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to suspend user: $e', isError: true);
    }
  }

  Future<void> _unsuspendUser(UserModel user) async {
    try {
      await _userService.unsuspendUser(user.id);

      // Send unsuspension notification
      await _sendUnsuspensionNotification(
        userId: user.id,
        userName: user.fullName,
        userEmail: user.email,
      );

      if (!mounted) return;
      _showSnackBar('${user.fullName} unsuspended successfully');
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to unsuspend user: $e', isError: true);
    }
  }

  Future<void> _showDeleteDialog(UserModel user) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete User Account'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to permanently delete ${user.fullName}\'s account.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone and will permanently remove all user data.',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
              const SizedBox(height: 16),

              const Text(
                'Deletion Reason *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Explain why this account is being deleted...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final deletionReason = reasonController.text.trim();

              if (deletionReason.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a deletion reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _deleteUser(user, deletionReason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserModel user, String deletionReason) async {
    try {
      // Send deletion notification first
      await _sendDeletionNotification(
        userId: user.id,
        userName: user.fullName,
        userEmail: user.email,
        deletionReason: deletionReason,
      );

      // Then delete the user
      await _userService.deleteUser(user.id);

      if (!mounted) return;
      _showSnackBar('${user.fullName}\'s account has been deleted');
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to delete user: $e', isError: true);
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatUserId(String userId) {
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
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        color: Colors.blue[700],
        backgroundColor: Colors.white,
        child: Column(
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

                  // Filter Row (removed refresh button)
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
                  ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Column(
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
                  ),
                ),
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}