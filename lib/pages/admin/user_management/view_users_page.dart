import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/models/admin/role_model.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/services/admin/role_service.dart';
import 'package:fyp_project/pages/admin/user_management/user_detail_page.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class ViewUsersPage extends StatefulWidget {
  const ViewUsersPage({super.key});

  @override
  State<ViewUsersPage> createState() => _ViewUsersPageState();
}

class _ViewUsersPageState extends State<ViewUsersPage> {
  final UserService _userService = UserService();
  final RoleService _roleService = RoleService();
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
        // Filter to only admin roles (manager, HR, staff, and any custom admin roles)
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

  Widget _buildActionButtons(UserModel user) {
    final isDeleted = user.status == 'Inactive' && !user.isActive;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // View Profile Button
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
          const SizedBox(width: 6),

          // If user is deleted, show only Activate button
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
      ),
    );
  }

  Future<void> _showWarningDialog(UserModel user) async {
    final violationController = TextEditingController();

    // Get current strike count
    final currentStrikes = await _userService.getStrikeCount(user.id);
    final strikesRemaining = 3 - currentStrikes;

    // Use a variable that persists across rebuilds
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text('Handle User Warning'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Issue a warning to ${user.fullName}.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
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
                    enabled: !isLoading,
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
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Issuing warning...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final violationReason = violationController.text.trim();

                        if (violationReason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please provide a violation reason'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // Set loading state and trigger rebuild
                        // Update loading state and rebuild
                        isLoading = true;
                        setDialogState(() {});

                        try {
                          // Issue warning
                          final result = await _userService.issueWarning(
                            userId: user.id,
                            violationReason: violationReason,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);

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

                            _loadData();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            _showSnackBar('Failed to process action: $e', isError: true);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Issue Warning'),
              ),
            ],
          );
        },
      ),
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
    final reasonController = TextEditingController();
    final durationController = TextEditingController(text: '30'); // Default 30 days

    bool isLoading = false;
    String? reasonError;
    String? durationError;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
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
                'You are about to suspend ${user.fullName}\'s account immediately.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will suspend the user immediately without waiting for 3 warnings.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Suspension Reason *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 3,
                enabled: !isLoading,
                onChanged: (value) {
                  if (reasonError != null) {
                    setDialogState(() => reasonError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Explain why this account is being suspended...',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: reasonError != null ? Colors.red : Colors.grey,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: reasonError != null ? Colors.red : Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: reasonError != null ? Colors.red : Colors.blue,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  errorText: reasonError,
                  contentPadding: const EdgeInsets.all(12),
                  prefixIcon: Icon(
                    Icons.description_outlined,
                    color: reasonError != null ? Colors.red : Colors.grey,
                  ),
                  fillColor: reasonError != null ? Colors.red[50] : null,
                  filled: reasonError != null,
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              const Text(
                'Suspension Duration (Days) *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: durationController,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                enabled: !isLoading,
                onChanged: (value) {
                  if (durationError != null) {
                    setDialogState(() => durationError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Enter number of days (e.g., 30)',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: durationError != null ? Colors.red : Colors.grey,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: durationError != null ? Colors.red : Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: durationError != null ? Colors.red : Colors.blue,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  errorText: durationError,
                  contentPadding: const EdgeInsets.all(12),
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: durationError != null ? Colors.red : Colors.grey,
                  ),
                  fillColor: durationError != null ? Colors.red[50] : null,
                  filled: durationError != null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a number greater than 0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Suspending user...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    final suspensionReason = reasonController.text.trim();
                    final durationText = durationController.text.trim();

                    // Reset errors
                    reasonError = null;
                    durationError = null;

                    // Validate reason
                    if (suspensionReason.isEmpty) {
                      setDialogState(() {
                        reasonError = 'Please provide a suspension reason';
                      });
                      return;
                    }

                    // Validate duration - cannot be empty
                    if (durationText.isEmpty) {
                      setDialogState(() {
                        durationError = 'Please enter suspension duration';
                      });
                      return;
                    }

                    int? durationDays = int.tryParse(durationText);
                    if (durationDays == null || durationDays <= 0) {
                      setDialogState(() {
                        durationError = 'Must be greater than 0';
                      });
                      return;
                    }

                    isLoading = true;
                    setDialogState(() {});

                    try {
                      await _userService.suspendUser(
                        user.id,
                        violationReason: suspensionReason,
                        durationDays: durationDays,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        _showSnackBar('${user.fullName}\'s account has been suspended for $durationDays day${durationDays == 1 ? '' : 's'}');

                        _loadData();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showSnackBar('Failed to suspend user: $e', isError: true);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Suspend Account'),
          ),
        ],
      ),
      ),
    );
  }


  Future<void> _showDeleteDialog(UserModel user) async {
    final reasonController = TextEditingController();

    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                enabled: !isLoading,
                decoration: const InputDecoration(
                  hintText: 'Explain why this account is being deleted...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Deleting user...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    final deletionReason = reasonController.text.trim();

                    if (deletionReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please provide a deletion reason'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    isLoading = true;
                    setDialogState(() {});

                    try {
                      final result = await _userService.deleteUserWithNotification(
                        userId: user.id,
                        deletionReason: deletionReason,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        if (result['success'] == true) {
                          final userName = result['userName'];
                          _showSnackBar('$userName\'s account has been deleted');
                        } else {
                          _showSnackBar('Failed to delete user: ${result['error']}', isError: true);
                        }

                        _loadData();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showSnackBar('Failed to delete user: $e', isError: true);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Delete Account'),
          ),
        ],
      ),
      ),
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

  void _showAddAdminDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final currentPasswordController = TextEditingController();
    String selectedRole = _adminRoles.isNotEmpty ? _adminRoles.first.name : 'staff';
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    bool obscureCurrentPassword = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_add, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add New Admin User',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter full name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  
                  // Email Field
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'example@email.com',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimum 6 characters',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setDialogState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    obscureText: obscurePassword,
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm Password Field
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    obscureText: obscureConfirmPassword,
                  ),
                  const SizedBox(height: 16),
                  
                  // Current User Password Field (to restore session)
                  TextField(
                    controller: currentPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Your Password',
                      hintText: 'Enter your current password to stay logged in',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrentPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setDialogState(() => obscureCurrentPassword = !obscureCurrentPassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    obscureText: obscureCurrentPassword,
                  ),
                  const SizedBox(height: 16),
                  
                  // Role Field
                  const Text(
                    'Role',
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
                            setDialogState(() => selectedRole = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The new admin will be able to log in immediately with the provided credentials. Enter your current password to stay logged in after creating the new admin.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text;
                final confirmPassword = confirmPasswordController.text.trim();

                // Validation
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email address'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (password.isEmpty || password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (password != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validate that the role exists and has permissions before creating
                // This prevents creating users with roles that don't exist
                try {
                  final roleService = RoleService();
                  final roleModel = await roleService.getRoleByName(selectedRole.toLowerCase());
                  if (roleModel == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: Role "$selectedRole" not found. Please select a valid role.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  if (roleModel.permissions.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: Role "$selectedRole" has no permissions assigned. Please assign permissions to this role first.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error validating role: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                Navigator.pop(context);
                await _createAdminUser(name, email, password, selectedRole, currentPasswordController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text(
                'Create Admin',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAdminUser(String name, String email, String password, String role, String currentPassword) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await authService.register(name, email, password, role: role, originalUserPassword: currentPassword.isNotEmpty ? currentPassword : null);

      if (!mounted) return;
      
      Navigator.pop(context); // Close loading dialog

      if (result.success) {
        // If re-authentication is required, navigate immediately to prevent crashes
        if (result.requiresReauth) {
          if (!mounted) return;
          
          // Show message first
          _showSnackBar(result.message ?? 'Admin user "$name" created successfully. Please log in again.');
          
          // Wait a moment for the message to show, then navigate
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (!mounted) return;
          
          // Navigate immediately to prevent any Firestore listeners from causing crashes
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        } else {
          // Session was restored successfully - refresh data
          _showSnackBar(result.message ?? 'Admin user "$name" created successfully');
          // Wait a moment before reloading to ensure session is fully restored
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _loadData();
          }
        }
      } else {
        _showSnackBar(result.error ?? 'Failed to create admin user.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      _showSnackBar('Error creating admin user: $e', isError: true);
    }
  }
}