import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/models/admin/role_model.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/services/admin/role_service.dart';
import 'package:fyp_project/services/admin/profile_pic_service.dart';
import 'package:fyp_project/services/admin/admin_user_service.dart';
import 'package:fyp_project/services/admin/face_recognition_service.dart';
import 'package:fyp_project/models/admin/add_admin_form_model.dart';
import 'package:fyp_project/pages/admin/user_management/user_detail_page.dart';
import 'package:fyp_project/widgets/user/location_autocomplete_field.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/utils/admin/phone_number_formatter.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/warning_dialog.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/suspend_dialog.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/delete_dialog.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/image_preview_dialog.dart';

class ViewUsersPage extends StatefulWidget {
  const ViewUsersPage({super.key});

  @override
  State<ViewUsersPage> createState() => _ViewUsersPageState();
}

class _ViewUsersPageState extends State<ViewUsersPage> {
  final UserService _userService = UserService();
  final RoleService _roleService = RoleService();
  final FaceRecognitionService _faceService = FaceRecognitionService();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  List<String> _availableRoles = [];
  List<RoleModel> _adminRoles = []; // Roles available for admin users
  bool _isLoading = true;
  String _selectedRole = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Check and auto unsuspend expired suspensions
      await _userService.checkAndAutoUnsuspendExpiredUsers();
      
      // Load users first (most important)
      final users = await _userService.getAllUsers();
      
      // Load roles separately with error handling
      List<String> roles = [];
      List<RoleModel> adminRoles = [];
      
      try {
        roles = await _userService.getAllRoles();
      } catch (e) {
        debugPrint('Error loading user roles: $e');
        // Continue even if this fails
      }
      
      try {
        final allAdminRoles = await _roleService.getAllRoles();
        adminRoles = allAdminRoles.where((role) {
          final roleName = role.name.toLowerCase();
          return roleName == 'manager' || 
                 roleName == 'hr' || 
                 roleName == 'staff' || 
                 roleName == 'admin' ||
                 role.permissions.contains('all') ||
                 role.permissions.any((perm) => ['user_management', 'post_moderation', 'analytics'].contains(perm));
        }).toList();
      } catch (e) {
        debugPrint('Error loading admin roles: $e');
        // Continue even if this fails - users list is more important
      }

      if (mounted) {
        setState(() {
          _users = users;
          _availableRoles = roles;
          _adminRoles = adminRoles;
        });
        // Apply current filters to update filtered list
        _filterUsers();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading data: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      }).toList()
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
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

  Color _getStatusColor(UserModel user) {
    if (user.status == 'Inactive' && !user.isActive) return Colors.grey;
    if (user.isSuspended) return Colors.orange;
    if (!user.isActive) return Colors.red;
    return Colors.green;
  }

  String _getStatusText(UserModel user) {
    if (user.status == 'Inactive' && !user.isActive) return 'Inactive';
    if (user.isSuspended) return 'Suspended';
    if (!user.isActive) return 'Inactive';
    return 'Active';
  }

  String _getRoleDisplayName(String role) {
    // Convert snake_case to Title Case
    return role.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  bool _canAddAdmin() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentRole = authService.currentAdmin?.role.toLowerCase() ?? '';
    return currentRole == 'manager' || currentRole == 'hr';
  }

  bool _isHR() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentRole = authService.currentAdmin?.role.toLowerCase() ?? '';
    return currentRole == 'hr';
  }

  bool _isStaff() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentRole = authService.currentAdmin?.role.toLowerCase() ?? '';
    return currentRole == 'staff';
  }

  bool _canPerformActionsOnUser(UserModel user) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentAdmin = authService.currentAdmin;
    
    // Cannot perform actions on yourself (view only)
    if (currentAdmin != null && currentAdmin.id == user.id) {
      return false;
    }
    
    final userRole = user.role.toLowerCase();
    
    // If current user is HR and target user is Manager, cannot perform actions (only view)
    if (_isHR()) {
      if (userRole == 'manager') {
        return false;
      }
    }
    
    // If current user is Staff, can only perform actions on Jobseeker and Recruiter
    // Other roles (Manager, HR, Staff, etc.) are view only
    if (_isStaff()) {
      // Only allow actions on Jobseeker and Recruiter
      if (userRole == 'jobseeker' || userRole == 'recruiter') {
        return true;
      }
      // All other roles are view only
      return false;
    }
    
    // Manager can perform actions on all users (except themselves)
    return true;
  }

  Widget _buildActionButtons(UserModel user) {
    final isDeleted = user.status == 'Inactive' && !user.isActive;
    final canPerformActions = _canPerformActionsOnUser(user);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // View Profile Button (always available)
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserDetailPage(user: user),
                ),
              );
              // Refresh if an action was performed
              if (result == true) {
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[50],
              foregroundColor: Colors.blue[700],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: const Icon(Icons.person, size: 16),
            label: const Text(
              'View',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          
          if (canPerformActions) ...[
            const SizedBox(width: 6),

            if (isDeleted) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  await _reactivateUser(user);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[50],
                  foregroundColor: Colors.green[700],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text(
                  'Activate',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ] else ...[
              // Warning Button
              ElevatedButton.icon(
                onPressed: () {
                  if (user.isSuspended) {
                    _unsuspendUser(user);
                  } else {
                    _showWarningDialog(user);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: user.isSuspended ? Colors.green[50] : Colors.orange[50],
                  foregroundColor: user.isSuspended ? Colors.green[700] : Colors.orange[700],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: Icon(
                  user.isSuspended ? Icons.check_circle : Icons.warning_amber,
                  size: 16,
                ),
                label: Text(
                  user.isSuspended ? 'Activate' : 'Warning',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 6),

              // Direct Suspend Button (only show if not suspended)
              if (!user.isSuspended) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    _showSuspendDialog(user);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text(
                    'Suspend',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 6),
              ],

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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showWarningDialog(UserModel user) async {
    await WarningDialog.show(
      context: context,
      user: user,
      userService: _userService,
      onShowSnackBar: (message, {bool isError = false}) => _showSnackBar(message, isError: isError),
      onLoadData: _loadData,
    );
  }


  Future<void> _unsuspendUser(UserModel user) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Activating user...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _userService.unsuspendUserWithReset(user.id);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final userName = result['userName'];
        _showSnackBar('$userName unsuspended successfully. Strikes reset to 0.');
      } else {
        _showSnackBar('Failed to unsuspend user: ${result['error']}', isError: true);
      }

      _loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showSnackBar('Failed to unsuspend user: $e', isError: true);
    }
  }

  Future<void> _showSuspendDialog(UserModel user) async {
    await SuspendDialog.show(
      context: context,
      user: user,
      userService: _userService,
      onShowSnackBar: (message, {bool isError = false}) => _showSnackBar(message, isError: isError),
      onLoadData: _loadData,
    );
  }



  Future<void> _showDeleteDialog(UserModel user) async {
    await DeleteDialog.show(
      context: context,
      user: user,
      userService: _userService,
      onShowSnackBar: (message, {bool isError = false}) => _showSnackBar(message, isError: isError),
      onLoadData: _loadData,
    );
  }

  Future<void> _reactivateUser(UserModel user) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reactivating user...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _userService.reactivateUser(user.id);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final userName = result['userName'];
        _showSnackBar('$userName\'s account has been reactivated');
      } else {
        _showSnackBar('Failed to reactivate user: ${result['error']}', isError: true);
      }

      _loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showSnackBar('Failed to reactivate user: $e', isError: true);
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
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

                  // Filter Row with dynamic roles
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
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Roles'),
                            ),
                            ..._availableRoles.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(_getRoleDisplayName(role)),
                              );
                            }).toList(),
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

                  return FutureBuilder<int>(
                    future: _userService.getStrikeCount(user.id),
                    builder: (context, snapshot) {
                      final strikeCount = snapshot.data ?? 0;

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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
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
                                        if (strikeCount > 0 && !user.isSuspended) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$strikeCount/3 strikes',
                                              style: TextStyle(
                                                color: Colors.orange[800],
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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

                                // Role and Joined Date
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        _getRoleDisplayName(user.role),
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _canAddAdmin()
          ? FloatingActionButton.extended(
              onPressed: () => _showAddAdminDialog(),
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Admin'),
              tooltip: 'Add New Admin User',
            )
          : null,
    );
  }

  // Cache for decoded images to avoid re-decoding on every rebuild
  final Map<String, Uint8List> _imageCache = {};

  void _showImagePreview(String base64String) {
    ImagePreviewDialog.show(
      context: context,
      base64String: base64String,
      imageCache: _imageCache,
    );
  }

  Future<Map<String, String>?> _pickImageBase64() async {
    try {
      final source = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Select Profile Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_camera, color: Colors.blue),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.blue),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );

      if (source == null) return null;

      final profilePicService = ProfilePicService();
      return await profilePicService.pickImageBase64(fromCamera: source == 'camera');
    } catch (e) {
      if (context.mounted) {
        // Show user-friendly error notification
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
      return null;
    }
  }

  void _showAddAdminDialog() {
    // Save the page context before showing dialog
    final pageContext = context;
    
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final locationController = TextEditingController();
    final ageController = TextEditingController();
    final phoneNumberController = TextEditingController();
    final currentPasswordController = TextEditingController();
    
    String selectedRole = _adminRoles.isNotEmpty ? _adminRoles.first.name : 'staff';
    String? selectedGender;
    
    final selectedImageBase64Notifier = ValueNotifier<String?>(null);
    final selectedImageFileTypeNotifier = ValueNotifier<String?>(null);
    final isPickingImageNotifier = ValueNotifier<bool>(false);
    final isImageUploadedNotifier = ValueNotifier<bool>(false);
    final faceDetectedNotifier = ValueNotifier<bool?>(null); // null = not checked, true = detected, false = not detected
    final isDetectingFaceNotifier = ValueNotifier<bool>(false);
    
    final pageController = PageController(initialPage: 0);
    final currentPageNotifier = ValueNotifier<int>(0);
    
    // Use ValueNotifier for error states to optimize performance
    final nameErrorNotifier = ValueNotifier<String?>(null);
    final emailErrorNotifier = ValueNotifier<String?>(null);
    final passwordErrorNotifier = ValueNotifier<String?>(null);
    final confirmPasswordErrorNotifier = ValueNotifier<String?>(null);
    final ageErrorNotifier = ValueNotifier<String?>(null);
    final phoneNumberErrorNotifier = ValueNotifier<String?>(null);
    
    // Use ValueNotifier for password visibility to avoid setDialogState
    final obscurePasswordNotifier = ValueNotifier<bool>(true);
    final obscureConfirmPasswordNotifier = ValueNotifier<bool>(true);
    final obscureCurrentPasswordNotifier = ValueNotifier<bool>(true);
    
    // Cache keyboard height to avoid frequent MediaQuery calls
    final keyboardHeightNotifier = ValueNotifier<double>(0.0);

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final mediaQuery = MediaQuery.of(context);
          // Update keyboard height when it changes (cache to avoid frequent rebuilds)
          final currentKeyboardHeight = mediaQuery.viewInsets.bottom;
          if ((keyboardHeightNotifier.value - currentKeyboardHeight).abs() > 1.0) {
            keyboardHeightNotifier.value = currentKeyboardHeight;
          }
          
          return Container(
            height: mediaQuery.size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: currentPageNotifier,
                        builder: (context, currentPage, _) => Text(
                          currentPage == 0 ? 'Step 1: Upload Profile Photo' : 'Step 2: Admin Information',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Page View
              Expanded(
                child: PageView(
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  onPageChanged: (index) {
                    currentPageNotifier.value = index;
                  },
                  children: [
                    // Step 1: Image Upload
                    _buildImageUploadStep(
                      context,
                      selectedImageBase64Notifier,
                      selectedImageFileTypeNotifier,
                      isPickingImageNotifier,
                      isImageUploadedNotifier,
                      faceDetectedNotifier,
                      isDetectingFaceNotifier,
                      () {
                        pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    // Step 2: Information Form
                    _buildInformationStep(
                      context,
                      pageContext,
                      setDialogState,
                      nameController,
                      emailController,
                      passwordController,
                      confirmPasswordController,
                      locationController,
                      ageController,
                      phoneNumberController,
                      currentPasswordController,
                      selectedRole,
                      selectedGender,
                      obscurePasswordNotifier,
                      obscureConfirmPasswordNotifier,
                      obscureCurrentPasswordNotifier,
                      nameErrorNotifier,
                      emailErrorNotifier,
                      passwordErrorNotifier,
                      confirmPasswordErrorNotifier,
                      ageErrorNotifier,
                      phoneNumberErrorNotifier,
                      selectedImageBase64Notifier,
                      selectedImageFileTypeNotifier,
                      keyboardHeightNotifier,
                      (role) => selectedRole = role,
                      (gender) => selectedGender = gender,
                      (obscure) => obscurePasswordNotifier.value = obscure,
                      (obscure) => obscureConfirmPasswordNotifier.value = obscure,
                      (obscure) => obscureCurrentPasswordNotifier.value = obscure,
                      (errors) {
                        nameErrorNotifier.value = errors['name'];
                        emailErrorNotifier.value = errors['email'];
                        passwordErrorNotifier.value = errors['password'];
                        confirmPasswordErrorNotifier.value = errors['confirmPassword'];
                        ageErrorNotifier.value = errors['age'];
                        phoneNumberErrorNotifier.value = errors['phoneNumber'];
                      },
                      () => Navigator.pop(context),
                    ),
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

  // Step 1: Image Upload Page
  Widget _buildImageUploadStep(
    BuildContext context,
    ValueNotifier<String?> selectedImageBase64Notifier,
    ValueNotifier<String?> selectedImageFileTypeNotifier,
    ValueNotifier<bool> isPickingImageNotifier,
    ValueNotifier<bool> isImageUploadedNotifier,
    ValueNotifier<bool?> faceDetectedNotifier,
    ValueNotifier<bool> isDetectingFaceNotifier,
    VoidCallback onNext,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Upload Profile Photo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please upload or take a photo for the admin profile',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Image Upload Area
          ValueListenableBuilder<String?>(
            valueListenable: selectedImageBase64Notifier,
            builder: (context, selectedImageBase64, _) => ValueListenableBuilder<bool>(
              valueListenable: isPickingImageNotifier,
              builder: (context, isPickingImage, _) => GestureDetector(
                onTap: isPickingImage ? null : () async {
                  isPickingImageNotifier.value = true;
                  try {
                    final imageData = await _pickImageBase64();
                    if (imageData != null && imageData['base64'] != null) {
                      final cleanBase64 = imageData['base64']!.trim().replaceAll(RegExp(r'\s+'), '');
                      selectedImageBase64Notifier.value = cleanBase64;
                      selectedImageFileTypeNotifier.value = imageData['fileType'];
                      isPickingImageNotifier.value = false;
                      
                      // Reset face detection status
                      faceDetectedNotifier.value = null;
                      
                      // Detect face in image
                      await _detectFaceInImage(
                        context,
                        cleanBase64,
                        faceDetectedNotifier,
                        isDetectingFaceNotifier,
                      );
                      
                      // Only mark as uploaded if face is detected
                      isImageUploadedNotifier.value = faceDetectedNotifier.value == true;
                    } else {
                      isPickingImageNotifier.value = false;
                      isImageUploadedNotifier.value = false;
                    }
                  } catch (e) {
                    isPickingImageNotifier.value = false;
                    isImageUploadedNotifier.value = false;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(e.toString().replaceFirst('Exception: ', '')),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedImageBase64 != null ? Colors.green : Colors.grey[300]!,
                      width: 3,
                    ),
                    color: selectedImageBase64 != null ? Colors.green[50] : Colors.grey[50],
                  ),
                  child: isPickingImage
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : selectedImageBase64 != null
                          ? ClipOval(
                              child: _buildPreviewImage(selectedImageBase64),
                            )
                          : Icon(
                              Icons.add_photo_alternate,
                              color: Colors.grey[400],
                              size: 64,
                            ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Face Detection Status
          ValueListenableBuilder<bool?>(
            valueListenable: faceDetectedNotifier,
            builder: (context, faceDetected, _) => ValueListenableBuilder<bool>(
              valueListenable: isDetectingFaceNotifier,
              builder: (context, isDetectingFace, _) {
                if (selectedImageBase64Notifier.value == null) {
                  return const SizedBox.shrink();
                }
                if (isDetectingFace) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Detecting face...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (faceDetected == true) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                        const SizedBox(width: 12),
                        const Text(
                          'Face detected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (faceDetected == false) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 12),
                        const Text(
                          'No face detected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          const SizedBox(height: 16),
          // Preview and Remove buttons
          ValueListenableBuilder<String?>(
            valueListenable: selectedImageBase64Notifier,
            builder: (context, selectedImageBase64, _) {
              if (selectedImageBase64 != null) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showImagePreview(selectedImageBase64),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.preview, size: 20),
                      label: const Text(
                        'Preview',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        selectedImageBase64Notifier.value = null;
                        selectedImageFileTypeNotifier.value = null;
                        isImageUploadedNotifier.value = false;
                        faceDetectedNotifier.value = null;
                        isDetectingFaceNotifier.value = false;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 60),
          // Next Button
          ValueListenableBuilder<bool>(
            valueListenable: isImageUploadedNotifier,
            builder: (context, isUploaded, _) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUploaded ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Detect face in image
  Future<void> _detectFaceInImage(
    BuildContext context,
    String imageBase64,
    ValueNotifier<bool?> faceDetectedNotifier,
    ValueNotifier<bool> isDetectingFaceNotifier,
  ) async {
    isDetectingFaceNotifier.value = true;
    faceDetectedNotifier.value = null;
    
    try {
      // Initialize face service if not already initialized
      await _faceService.initialize();
      
      // Decode base64 image
      final imageBytes = base64Decode(imageBase64);
      
      // Save image to temporary file, then use file path for detection (more reliable)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/face_detection_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);
      
      // Create InputImage using file path (more reliable method)
      final inputImage = InputImage.fromFilePath(tempFile.path);
      
      final faces = await _faceService.detectFaces(inputImage);
      
      // Clean up temporary file
      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }
      
      if (context.mounted) {
        faceDetectedNotifier.value = faces.isNotEmpty;
        isDetectingFaceNotifier.value = false;
        
        if (faces.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No face detected. Please take another photo with your face clearly visible.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Face detected! ${faces.length} face(s) found.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        faceDetectedNotifier.value = false;
        isDetectingFaceNotifier.value = false;
        debugPrint('Error detecting face: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error detecting face: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper method to build preview image
  Widget _buildPreviewImage(String base64String) {
    try {
      final cleanBase64 = base64String.trim().replaceAll(RegExp(r'\s+'), '');
      Uint8List bytes = _imageCache[cleanBase64] ?? base64Decode(cleanBase64);
      if (!_imageCache.containsKey(cleanBase64)) {
        _imageCache[cleanBase64] = bytes;
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: 200,
        height: 200,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[100],
            child: Icon(Icons.broken_image, color: Colors.red[300], size: 40),
          );
        },
      );
    } catch (e) {
      return Container(
        width: 200,
        height: 200,
        color: Colors.grey[100],
        child: Icon(Icons.broken_image, color: Colors.red[300], size: 40),
      );
    }
  }

  // Step 2: Information Form Page
  Widget _buildInformationStep(
    BuildContext context,
    BuildContext pageContext,
    StateSetter setDialogState,
    TextEditingController nameController,
    TextEditingController emailController,
    TextEditingController passwordController,
    TextEditingController confirmPasswordController,
    TextEditingController locationController,
    TextEditingController ageController,
    TextEditingController phoneNumberController,
    TextEditingController currentPasswordController,
    String selectedRole,
    String? selectedGender,
    ValueNotifier<bool> obscurePasswordNotifier,
    ValueNotifier<bool> obscureConfirmPasswordNotifier,
    ValueNotifier<bool> obscureCurrentPasswordNotifier,
    ValueNotifier<String?> nameErrorNotifier,
    ValueNotifier<String?> emailErrorNotifier,
    ValueNotifier<String?> passwordErrorNotifier,
    ValueNotifier<String?> confirmPasswordErrorNotifier,
    ValueNotifier<String?> ageErrorNotifier,
    ValueNotifier<String?> phoneNumberErrorNotifier,
    ValueNotifier<String?> selectedImageBase64Notifier,
    ValueNotifier<String?> selectedImageFileTypeNotifier,
    ValueNotifier<double> keyboardHeightNotifier,
    Function(String) onRoleChanged,
    Function(String?) onGenderChanged,
    Function(bool) onObscurePasswordChanged,
    Function(bool) onObscureConfirmPasswordChanged,
    Function(bool) onObscureCurrentPasswordChanged,
    Function(Map<String, String?>) onErrorsChanged,
    VoidCallback onCancel,
  ) {
    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Container: All Information
                Container(
                  padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_circle_outlined, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Admin Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Full Name Field
                RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: nameErrorNotifier,
                    builder: (context, nameError, _) {
                      final hasError = nameError != null;
                      return TextField(
                        controller: nameController,
                        onChanged: (value) {
                          if (nameError != null) {
                            nameErrorNotifier.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'Enter full name',
                          errorText: nameError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          prefixIcon: Icon(Icons.person_outline, color: hasError ? Colors.red : Colors.grey),
                          filled: true,
                          fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Email Field
                RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: emailErrorNotifier,
                    builder: (context, emailError, _) {
                      final hasError = emailError != null;
                      return TextField(
                        controller: emailController,
                        onChanged: (value) {
                          if (emailError != null) {
                            emailErrorNotifier.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Email Address *',
                          hintText: 'example@email.com',
                          errorText: emailError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          prefixIcon: Icon(Icons.email_outlined, color: hasError ? Colors.red : Colors.grey),
                          filled: true,
                          fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Password Field
                RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: passwordErrorNotifier,
                    builder: (context, passwordError, _) {
                      final hasError = passwordError != null;
                      return TextField(
                        controller: passwordController,
                        onChanged: (value) {
                          if (passwordError != null) {
                            passwordErrorNotifier.value = null;
                          }
                          if (confirmPasswordErrorNotifier.value != null && value == confirmPasswordController.text) {
                            confirmPasswordErrorNotifier.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          hintText: 'Minimum 6 characters',
                          errorText: passwordError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          prefixIcon: Icon(Icons.lock_outline, color: hasError ? Colors.red : Colors.grey),
                          suffixIcon: ValueListenableBuilder<bool>(
                            valueListenable: obscurePasswordNotifier,
                            builder: (context, obscurePassword, _) {
                              return IconButton(
                                icon: Icon(
                                  obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: hasError ? Colors.red : Colors.grey[600],
                                ),
                                onPressed: () {
                                  obscurePasswordNotifier.value = !obscurePassword;
                                  onObscurePasswordChanged(obscurePasswordNotifier.value);
                                },
                              );
                            },
                          ),
                          filled: true,
                          fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        obscureText: obscurePasswordNotifier.value,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Confirm Password Field
                RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: confirmPasswordErrorNotifier,
                    builder: (context, confirmPasswordError, _) {
                      final hasError = confirmPasswordError != null;
                      return TextField(
                        controller: confirmPasswordController,
                        onChanged: (value) {
                          if (confirmPasswordError != null && value == passwordController.text) {
                            confirmPasswordErrorNotifier.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirm Password *',
                          hintText: 'Re-enter password',
                          errorText: confirmPasswordError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          prefixIcon: Icon(Icons.lock_outline, color: hasError ? Colors.red : Colors.grey),
                          suffixIcon: ValueListenableBuilder<bool>(
                            valueListenable: obscureConfirmPasswordNotifier,
                            builder: (context, obscureConfirmPassword, _) {
                              return IconButton(
                                icon: Icon(
                                  obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: hasError ? Colors.red : Colors.grey[600],
                                ),
                                onPressed: () {
                                  obscureConfirmPasswordNotifier.value = !obscureConfirmPassword;
                                  onObscureConfirmPasswordChanged(obscureConfirmPasswordNotifier.value);
                                },
                              );
                            },
                          ),
                          filled: true,
                          fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        obscureText: obscureConfirmPasswordNotifier.value,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Location Field
                LocationAutocompleteField(
                  controller: locationController,
                  label: 'Location (Optional)',
                  hintText: 'Search location... (e.g., Kuala Lumpur)',
                  restrictToCountry: 'my',
                  onLocationSelected: (description, latitude, longitude) {
                    if (latitude != null && longitude != null) {
                      print('Selected location: $description');
                      print('Coordinates: $latitude, $longitude');
                    }
                  },
                ),
                const SizedBox(height: 12),
                
                // Age Field
                RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: ageErrorNotifier,
                    builder: (context, ageError, _) {
                      final hasError = ageError != null;
                      return TextField(
                        controller: ageController,
                        onChanged: (value) {
                          if (ageError != null) {
                            ageErrorNotifier.value = null;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Age (Optional)',
                          hintText: 'Enter age (18-80)',
                          errorText: ageError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          prefixIcon: Icon(Icons.cake_outlined, color: hasError ? Colors.red : Colors.grey),
                          filled: true,
                          fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Phone Number Field
                RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: phoneNumberErrorNotifier,
                    builder: (context, phoneNumberError, _) {
                      final hasError = phoneNumberError != null;
                      return TextField(
                        controller: phoneNumberController,
                        onChanged: (value) {
                          if (phoneNumberError != null) {
                            final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                            if (digitsOnly.length == 10) {
                              phoneNumberErrorNotifier.value = null;
                            }
                          }
                        },
                        inputFormatters: [
                          PhoneNumberFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          hintText: 'XXX-XXX XXXX',
                          errorText: phoneNumberError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: hasError ? Colors.red : Colors.blue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          prefixIcon: Icon(Icons.phone_outlined, color: hasError ? Colors.red : Colors.grey),
                          filled: true,
                          fillColor: hasError ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 13,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Gender Field
                const Text(
                  'Gender (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedGender,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                      hint: const Text(
                        'Select gender',
                        style: TextStyle(color: Colors.grey),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Not specified'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'Male',
                          child: Text('Male'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          onGenderChanged(value);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Role Field
                const Text(
                  'Role *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                      items: _adminRoles.map((role) {
                        return DropdownMenuItem(
                          value: role.name,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getRoleDisplayName(role.name),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              if (role.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  role.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            onRoleChanged(value);
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Current Password Field (to stay logged in)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Current Password (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your current password to stay logged in after creating the new admin. If left empty, you will need to log in again.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange[900],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Your Current Password',
                    hintText: 'Enter your password to stay logged in',
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
                      borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
                    ),
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.orange[700]),
                    suffixIcon: ValueListenableBuilder<bool>(
                      valueListenable: obscureCurrentPasswordNotifier,
                      builder: (context, obscureCurrentPassword, _) {
                        return IconButton(
                          icon: Icon(
                            obscureCurrentPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            obscureCurrentPasswordNotifier.value = !obscureCurrentPassword;
                            onObscureCurrentPasswordChanged(obscureCurrentPasswordNotifier.value);
                          },
                        );
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  obscureText: obscureCurrentPasswordNotifier.value,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Info Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The new admin will be able to log in immediately with the provided credentials.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[900],
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        
        // Fixed Footer with Actions (always visible above keyboard)
        SafeArea(
          top: false,
          child: ValueListenableBuilder<double>(
            valueListenable: keyboardHeightNotifier,
            builder: (context, keyboardHeight, _) {
              return Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: keyboardHeight > 0 ? keyboardHeight + 8 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final password = passwordController.text;
                    final confirmPassword = confirmPasswordController.text.trim();

                    // Reset all errors
                    String? nameErr;
                    String? emailErr;
                    String? passwordErr;
                    String? confirmPasswordErr;
                    String? ageErr;
                    String? phoneNumberErr;
                    bool hasError = false;

                    // Validation
                    if (name.isEmpty) {
                      nameErr = 'Please enter a name';
                      hasError = true;
                    }

                    if (email.isEmpty || !email.contains('@')) {
                      emailErr = 'Please enter a valid email address';
                      hasError = true;
                    }

                    if (password.isEmpty || password.length < 6) {
                      passwordErr = 'Password must be at least 6 characters';
                      hasError = true;
                    }

                    if (password != confirmPassword) {
                      confirmPasswordErr = 'Passwords do not match';
                      hasError = true;
                    }

                    // Age validation (18-80)
                    final ageText = ageController.text.trim();
                    if (ageText.isNotEmpty) {
                      final age = int.tryParse(ageText);
                      if (age == null) {
                        ageErr = 'Please enter a valid age';
                        hasError = true;
                      } else if (age < 18 || age > 80) {
                        ageErr = 'Age must be between 18 and 80';
                        hasError = true;
                      }
                    }

                    // Phone number validation (XXX-XXX XXXX format)
                    final phoneText = phoneNumberController.text.trim();
                    if (phoneText.isNotEmpty) {
                      final digitsOnly = phoneText.replaceAll(RegExp(r'[^\d]'), '');
                      if (digitsOnly.length != 10) {
                        phoneNumberErr = 'Phone number must be 10 digits (XXX-XXX XXXX)';
                        hasError = true;
                      }
                    }

                    // Update error states using ValueNotifier (no need for setDialogState)
                    nameErrorNotifier.value = nameErr;
                    emailErrorNotifier.value = emailErr;
                    passwordErrorNotifier.value = passwordErr;
                    confirmPasswordErrorNotifier.value = confirmPasswordErr;
                    ageErrorNotifier.value = ageErr;
                    phoneNumberErrorNotifier.value = phoneNumberErr;

                    if (hasError) {
                      return;
                    }

                    // Validate role
                    try {
                      final roleService = RoleService();
                      final roleModel = await roleService.getRoleByName(selectedRole.toLowerCase());
                      if (roleModel == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: Role "$selectedRole" not found. Please select a valid role.'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                      
                      if (roleModel.permissions.isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: Role "$selectedRole" has no permissions assigned. Please assign permissions to this role first.'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error validating role: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }
                    
                    final adminUserService = AdminUserService();
                    final form = AddAdminFormModel(
                      name: name,
                      email: email,
                      password: password,
                      confirmPassword: confirmPassword,
                      role: selectedRole,
                      location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                      age: ageController.text.trim().isEmpty ? null : int.tryParse(ageController.text.trim()),
                      phoneNumber: phoneNumberController.text.trim().isEmpty ? null : phoneNumberController.text.trim(),
                      gender: selectedGender,
                      currentPassword: currentPasswordController.text.trim().isEmpty ? null : currentPasswordController.text.trim(),
                      imageBase64: selectedImageBase64Notifier.value,
                      imageFileType: selectedImageFileTypeNotifier.value,
                    );
                    
                    Navigator.pop(context);
                    
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    final result = await adminUserService.createAdminUser(pageContext, form);
                    
                    // Ensure loading dialog from createAdminUser is closed
                    if (pageContext.mounted) {
                      try {
                        // Try to close any remaining dialogs
                        Navigator.of(pageContext, rootNavigator: true).popUntil((route) {
                          return route.isFirst || !route.willHandlePopInternally;
                        });
                      } catch (e) {
                        debugPrint('Dialog already closed: $e');
                      }
                    }
                    
                    await Future.delayed(const Duration(milliseconds: 200));
                    
                    if (result.success) {
                      // Success - show success message and keep logged in
                      _showSnackBar(result.message ?? 'Admin user "$name" created successfully');
                      
                      // Wait a bit before refreshing to ensure UI is ready
                      await Future.delayed(const Duration(milliseconds: 300));
                      
                      if (mounted) {
                        // Refresh data
                        await _loadData();
                      }
                    } else {
                      // Failed - show error message
                      _showSnackBar(result.error ?? 'Failed to create admin user.', isError: true);
                      
                      // If password was wrong, navigate to login after showing error
                      if (result.requiresReauth && mounted) {
                        await Future.delayed(const Duration(milliseconds: 2000));
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        }
                      }
                    }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.person_add, size: 20),
                        label: const Text(
                          'Complete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}