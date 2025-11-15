import 'package:flutter/material.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/services/user_service.dart';

class UserDetailPage extends StatelessWidget {
  final UserModel user;

  const UserDetailPage({super.key, required this.user});

  Color _getRoleColor(String role) {
    switch (role) {
      case 'employer':
        return Colors.blue;
      case 'job_seeker':
        return Colors.green;
      case 'staff':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'job_seeker':
        return 'Job Seeker';
      case 'employer':
        return 'Employer';
      case 'staff':
        return 'Staff';
      default:
        return role;
    }
  }

  Color _getStatusColor(bool isActive, bool isSuspended) {
    if (isSuspended) return Colors.red;
    return isActive ? Colors.green : Colors.orange;
  }

  String _getStatusText(bool isActive, bool isSuspended) {
    if (isSuspended) return 'Suspended';
    return isActive ? 'Active' : 'Inactive';
  }

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'User Details',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Card with User Avatar and Basic Info
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getRoleColor(user.role).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : user.email.isNotEmpty
                                  ? user.email[0].toUpperCase()
                                  : '?',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(user.role),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Name and Role
                    Text(
                      user.fullName.isNotEmpty ? user.fullName : 'Unnamed User',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // Email
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // Status and Role Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(user.isActive, user.isSuspended)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getStatusColor(user.isActive, user.isSuspended),
                            ),
                          ),
                          child: Text(
                            _getStatusText(user.isActive, user.isSuspended),
                            style: TextStyle(
                              color: _getStatusColor(user.isActive, user.isSuspended),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(user.role).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getRoleColor(user.role),
                            ),
                          ),
                          child: Text(
                            _getRoleDisplayName(user.role),
                            style: TextStyle(
                              color: _getRoleColor(user.role),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // User Details Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _DetailRow(
                      label: 'Name',
                      value: user.fullName,
                      icon: Icons.person,
                    ),
                    _DetailRow(
                      label: 'Email',
                      value: user.email,
                      icon: Icons.email,
                    ),
                    _DetailRow(
                      label: 'Role',
                      value: _getRoleDisplayName(user.role),
                      icon: Icons.work,
                      valueColor: _getRoleColor(user.role),
                    ),
                    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                      _DetailRow(
                        label: 'Phone',
                        value: user.phoneNumber!,
                        icon: Icons.phone,
                      ),
                    _DetailRow(
                      label: 'Account Status',
                      value: _getStatusText(user.isActive, user.isSuspended),
                      icon: Icons.circle,
                      valueColor: _getStatusColor(user.isActive, user.isSuspended),
                    ),
                    if (user.reportCount != null)
                      _DetailRow(
                        label: 'Reports',
                        value: user.reportCount.toString(),
                        icon: Icons.flag,
                        valueColor: user.reportCount! > 0 ? Colors.orange : Colors.green,
                      ),
                    _DetailRow(
                      label: 'Joined Date',
                      value: user.createdAt.toString().split(' ')[0],
                      icon: Icons.calendar_today,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: user.isSuspended 
                                ? null
                                : () async {
                                    if (!context.mounted) return;
                                    try {
                                      await userService.suspendUser(user.id);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${user.fullName} suspended successfully'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context, true);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.pause_circle_outline),
                            label: Text(user.isSuspended ? 'Suspended' : 'Suspend'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: user.isSuspended ? Colors.grey : Colors.orange,
                              ),
                              foregroundColor: user.isSuspended ? Colors.grey : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (!context.mounted) return;
                              
                              try {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete User Account'),
                                    content: Text(
                                      'Are you sure you want to permanently delete ${user.fullName}\'s account? This action cannot be undone and all user data will be lost.',
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
                                        ),
                                        child: const Text('Delete Account'),
                                      ),
                                    ],
                                  ),
                                );

                                if (!context.mounted) return;

                                if (confirm == true) {
                                  try {
                                    await userService.deleteUser(user.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${user.fullName} deleted successfully'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
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
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error showing dialog: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    if (user.isSuspended) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (!context.mounted) return;
                          try {
                            await userService.unsuspendUser(user.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${user.fullName} unsuspended successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Unsuspend User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}