import 'package:flutter/material.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/services/user_service.dart';
import 'package:fyp_project/pages/user_management/user_detail_page.dart';

class UserActionsPage extends StatefulWidget {
  const UserActionsPage({super.key});

  @override
  State<UserActionsPage> createState() => _UserActionsPageState();
}

class _UserActionsPageState extends State<UserActionsPage> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _suspendedUsers = [];
  List<UserModel> _reportedUsers = [];
  List<UserModel> _filteredSuspendedUsers = [];
  List<UserModel> _filteredReportedUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';

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

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredSuspendedUsers = _suspendedUsers.where((user) {
        return user.fullName.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
      }).toList();
      _filteredReportedUsers = _reportedUsers.where((user) {
        return user.fullName.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final suspended = await _userService.getSuspendedUsers();
      final reported = await _userService.getReportedUsers();
      setState(() {
        _suspendedUsers = suspended;
        _reportedUsers = reported;
        _filteredSuspendedUsers = suspended;
        _filteredReportedUsers = reported;
        _isLoading = false;
      });
      _filterUsers();
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
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header Section
                  _buildHeaderSection(),
                  
                  // Search Bar (above tabs)
                  _buildSearchSection(),
                  
                  // Tab Bar
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      indicatorColor: Colors.blue[700],
                      indicatorWeight: 3,
                      labelColor: Colors.blue[700],
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontSize: 14),
                      tabs: [
                        _buildTab('Suspended', Icons.pause_circle_outline, _filteredSuspendedUsers.length, Colors.orange),
                        _buildTab('Reported', Icons.flag, _filteredReportedUsers.length, Colors.red),
                      ],
                    ),
                  ),
                  
                  // Tab Content
                  Expanded(
                    child: RefreshIndicator(
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
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
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
            'Account Management',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage suspended and reported user accounts',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
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
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    if (_filteredSuspendedUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: _suspendedUsers.isEmpty ? 'No Suspended Users' : 'No Results Found',
        subtitle: _suspendedUsers.isEmpty 
            ? 'All user accounts are currently active'
            : 'Try adjusting your search',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSuspendedUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredSuspendedUsers[index];
        return _buildUserCard(user, isSuspended: true);
      },
    );
  }

  Widget _buildReportedUsersList() {
    if (_filteredReportedUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.flag_outlined,
        title: _reportedUsers.isEmpty ? 'No Reported Users' : 'No Results Found',
        subtitle: _reportedUsers.isEmpty 
            ? 'No user reports at this time'
            : 'Try adjusting your search',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredReportedUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredReportedUsers[index];
        return _buildUserCard(user, isSuspended: false);
      },
    );
  }

  String _getRoleDisplayName(String role) {
    return role.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildUserCard(UserModel user, {required bool isSuspended}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSuspended ? Colors.orange[100]! : Colors.red[100]!,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserDetailPage(user: user),
              ),
            ).then((refreshed) {
              if (refreshed == true) {
                _loadUsers();
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Avatar with status
                    _buildUserAvatar(user, isSuspended),
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSuspended ? Colors.orange[50] : Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSuspended ? Colors.orange[200]! : Colors.red[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isSuspended ? 'Suspended' : 'Reported',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSuspended ? Colors.orange[800] : Colors.red[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  user.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),

                const SizedBox(height: 12),

                // Role and Additional Info
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          Text(
                            _getRoleDisplayName(user.role),
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Report Count (for reported users)
                    if (!isSuspended && user.reportCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!, width: 1),
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Strike Count (for reported users)
                    if (!isSuspended)
                      FutureBuilder<int>(
                        future: _userService.getStrikeCount(user.id),
                        builder: (context, snapshot) {
                          final strikeCount = snapshot.data ?? 0;
                          if (strikeCount > 0) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange[800]),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$strikeCount/3 strikes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: isSuspended
                      ? [_buildUnsuspendButton(user)]
                      : [
                    Expanded(child: _buildWarningButton(user)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDeleteButton(user)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(UserModel user, bool isSuspended) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSuspended 
                  ? [Colors.orange[300]!, Colors.orange[500]!]
                  : [Colors.red[300]!, Colors.red[500]!],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isSuspended ? Colors.orange : Colors.red).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (isSuspended)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.orange[700],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.pause, size: 9, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildUnsuspendButton(UserModel user) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _unsuspendUser(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Unsuspend Account',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildWarningButton(UserModel user) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _showWarningDialog(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[50],
          foregroundColor: Colors.orange[700],
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange[300]!, width: 1.5),
          ),
        ),
        child: const Text(
          'Give Warning',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(UserModel user) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _showDeleteDialog(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[50],
          foregroundColor: Colors.red[700],
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red[300]!, width: 1.5),
          ),
        ),
        child: const Text(
          'Delete',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unsuspendUser(UserModel user) async {
    try {
      final result = await _userService.unsuspendUserWithReset(user.id);
      if (!mounted) return;
      if (result['success'] == true) {
        _showSnackBar('${user.fullName} unsuspended successfully. Strikes reset to 0.');
      } else {
        _showSnackBar('Failed to unsuspend user: ${result['error']}', isError: true);
      }
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to unsuspend user: $e', isError: true);
    }
  }

  Future<void> _showWarningDialog(UserModel user) async {
    final violationController = TextEditingController();

    // Get current strike count
    final currentStrikes = await _userService.getStrikeCount(user.id);
    final strikesRemaining = 3 - currentStrikes;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Issue Warning'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to issue a warning to ${user.fullName}.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current strikes: $currentStrikes/3\n${strikesRemaining > 0 ? '$strikesRemaining more strike${strikesRemaining == 1 ? '' : 's'} until automatic suspension' : 'Account will be suspended automatically'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
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
              const SizedBox(height: 8),
              Text(
                'The user will receive a warning notification. After 3 strikes, their account will be automatically suspended.',
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
              await _issueWarning(user, violationReason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Issue Warning'),
          ),
        ],
      ),
    );
  }

  Future<void> _issueWarning(UserModel user, String violationReason) async {
    try {
      final result = await _userService.issueWarning(
        userId: user.id,
        violationReason: violationReason,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final strikeCount = result['strikeCount'];
        final wasSuspended = result['wasSuspended'];
        final userName = result['userName'];

        if (wasSuspended) {
          _showSnackBar('$userName has reached 3 strikes and has been automatically suspended');
        } else {
          _showSnackBar('Warning issued to $userName (Strike $strikeCount/3)');
        }
      } else {
        _showSnackBar('Failed to issue warning: ${result['error']}', isError: true);
      }

      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to issue warning: $e', isError: true);
    }
  }

  Future<void> _showDeleteDialog(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User Account'),
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