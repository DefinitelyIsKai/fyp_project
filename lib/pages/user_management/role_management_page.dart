import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/models/role_model.dart';
import 'package:fyp_project/services/role_service.dart';
import 'package:fyp_project/services/auth_service.dart';

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  final RoleService _roleService = RoleService();
  List<RoleModel> _roles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRoles();
  }

  Future<void> _initializeRoles() async {
    try {
      // Initialize system roles if they don't exist
      await _roleService.initializeSystemRoles();
      _loadRoles();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error initializing roles: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);
    try {
      // Update user counts
      await _roleService.updateRoleUserCounts();
      final roles = await _roleService.getAllRoles();
      
      if (mounted) {
        setState(() {
          _roles = roles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading roles: $e', isError: true);
        setState(() => _isLoading = false);
      }
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

  bool _canManageRoles() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentAdmin = authService.currentAdmin;
    final userRole = currentAdmin?.role.toLowerCase() ?? '';
    final userPermissions = currentAdmin?.permissions ?? [];
    
    // Staff role should NEVER be able to manage roles, regardless of permissions
    if (userRole == 'staff') {
      debugPrint('Role Management Permission Check: Staff role cannot manage roles');
      return false;
    }
    
    // Managers always have full access
    if (userRole == 'manager') {
      return true;
    }
    
    // HR and other roles need explicit role_management permission or 'all' permission
    final canManage = userPermissions.contains('role_management') || 
                      userPermissions.contains('all');
    
    // Debug logging
    debugPrint('Role Management Permission Check:');
    debugPrint('  User Role: $userRole');
    debugPrint('  User Permissions: $userPermissions');
    debugPrint('  Can Manage Roles: $canManage');
    
    return canManage;
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManageRoles();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'View Roles',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
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
                  'View Roles',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View roles and their assigned permissions',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Roles List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _roles.isEmpty
                    ? _buildEmptyState(canManage)
                    : RefreshIndicator(
                        onRefresh: _loadRoles,
                        color: Colors.blue[700],
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: _roles.length,
                          itemBuilder: (context, index) {
                            final role = _roles[index];
                            return _buildRoleCard(role, canManage);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool canManage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.admin_panel_settings_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Roles Found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first role to get started',
              style: TextStyle(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(RoleModel role, bool canManage) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: role.isSystemRole ? Colors.blue[200]! : Colors.grey[300]!,
          width: role.isSystemRole ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showRoleDetailsDialog(role),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              role.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: role.isSystemRole ? Colors.blue[700] : Colors.black87,
                              ),
                            ),
                            if (role.isSystemRole) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Text(
                                  'System',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (role.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            role.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              '${role.userCount}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${role.userCount == 1 ? 'user' : 'users'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (role.permissions.contains('all'))
                    _buildPermissionChip('Full Access', Colors.green)
                  else
                    ...role.permissions.map((perm) => _buildPermissionChip(
                          RoleService.permissionLabels[perm] ?? perm,
                          Colors.blue,
                        )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showRoleDetailsDialog(role),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionChip(String label, Color color) {
    // Get the darker shade for text
    final textColor = color == Colors.green 
        ? Colors.green[700]! 
        : color == Colors.blue 
            ? Colors.blue[700]! 
            : color;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  void _showRoleDetailsDialog(RoleModel role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                role.name.toUpperCase(),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (role.description.isNotEmpty) ...[
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(role.description),
                const SizedBox(height: 16),
              ],
              Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (role.permissions.contains('all'))
                    _buildPermissionChip('Full Access', Colors.green)
                  else
                    ...role.permissions.map((perm) => _buildPermissionChip(
                          RoleService.permissionLabels[perm] ?? perm,
                          Colors.blue,
                        )),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${role.userCount} user(s) assigned',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (role.isSystemRole) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Text(
                      'System role (cannot be modified)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

