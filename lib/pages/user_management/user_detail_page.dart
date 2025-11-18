import 'package:flutter/material.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/services/user_service.dart';
import 'package:intl/intl.dart';

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
      case 'HR':
        return Colors.orange;
      case 'manager':
        return Colors.red;
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
      case 'HR':
        return 'HR Manager';
      case 'manager':
        return 'Manager';
      default:
        return role;
    }
  }

  Color _getStatusColor(bool isActive, bool isSuspended) {
    if (isSuspended) return Colors.orange;
    return isActive ? Colors.green : Colors.grey;
  }

  String _getStatusText(bool isActive, bool isSuspended) {
    if (isSuspended) return 'Suspended';
    return isActive ? 'Active' : 'Inactive';
  }

  IconData _getStatusIcon(bool isActive, bool isSuspended) {
    if (isSuspended) return Icons.pause_circle;
    return isActive ? Icons.check_circle : Icons.remove_circle;
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  void _showStatusConfirmationDialog(BuildContext context, UserService userService, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              action == 'suspend' ? Icons.pause_circle_outline :
              action == 'activate' ? Icons.play_arrow : Icons.delete,
              color: action == 'suspend' ? Colors.orange :
              action == 'activate' ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Text('${action.capitalize()} User'),
          ],
        ),
        content: Text(
          action == 'suspend'
              ? 'Are you sure you want to suspend ${user.fullName}? They will not be able to access their account until unsuspended.'
              : action == 'activate'
              ? 'Are you sure you want to activate ${user.fullName}? They will regain full access to their account.'
              : 'Are you sure you want to permanently delete ${user.fullName}\'s account? This action cannot be undone and all user data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performStatusAction(context, userService, action);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'suspend' ? Colors.orange :
              action == 'activate' ? Colors.green : Colors.red,
            ),
            child: Text(action.capitalize()),
          ),
        ],
      ),
    );
  }

  Future<void> _performStatusAction(BuildContext context, UserService userService, String action) async {
    try {
      if (action == 'suspend') {
        await userService.suspendUser(user.id);
      } else if (action == 'activate') {
        await userService.unsuspendUser(user.id);
      } else if (action == 'delete') {
        await userService.deleteUser(user.id);
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'suspend' ? 'User suspended successfully' :
            action == 'activate' ? 'User activated successfully' :
            'User deleted successfully',
          ),
          backgroundColor: action == 'suspend' ? Colors.orange :
          action == 'activate' ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userService = UserService();
    final statusColor = _getStatusColor(user.isActive, user.isSuspended);
    final statusText = _getStatusText(user.isActive, user.isSuspended);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Details',
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
            onPressed: () {
              // Refresh user data if needed
              Navigator.pop(context, true);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header Card
            _buildProfileHeader(context),
            const SizedBox(height: 20),

            // Quick Stats Row
            _buildQuickStats(),
            const SizedBox(height: 20),

            // User Information Card
            _buildUserInfoCard(),
            const SizedBox(height: 20),

            // Professional Information Card (if available)
            if (user.professionalSummary.isNotEmpty || user.workExperience.isNotEmpty)
              _buildProfessionalInfoCard(),
            if (user.professionalSummary.isNotEmpty || user.workExperience.isNotEmpty)
              const SizedBox(height: 20),

            // Account Actions Card
            _buildActionsCard(context, userService, statusColor, statusText),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar with online status
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getRoleColor(user.role).withOpacity(0.3),
                      width: 3,
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
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(user.role),
                      ),
                    ),
                  ),
                ),
                // Status indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getStatusColor(user.isActive, user.isSuspended),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    _getStatusIcon(user.isActive, user.isSuspended),
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name and basic info
            Column(
              children: [
                Text(
                  user.fullName.isNotEmpty ? user.fullName : 'Unnamed User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Status and Role badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _InfoChip(
                      text: _getStatusText(user.isActive, user.isSuspended),
                      color: _getStatusColor(user.isActive, user.isSuspended),
                      icon: _getStatusIcon(user.isActive, user.isSuspended),
                    ),
                    _InfoChip(
                      text: _getRoleDisplayName(user.role),
                      color: _getRoleColor(user.role),
                      icon: Icons.work,
                    ),
                    if (user.reportCount > 0)
                      _InfoChip(
                        text: '${user.reportCount} Report${user.reportCount == 1 ? '' : 's'}',
                        color: Colors.orange,
                        icon: Icons.flag,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Joined',
            value: _formatDate(user.createdAt),
            icon: Icons.calendar_today,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Status',
            value: _getStatusText(user.isActive, user.isSuspended),
            icon: _getStatusIcon(user.isActive, user.isSuspended),
            color: _getStatusColor(user.isActive, user.isSuspended),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Role',
            value: _getRoleDisplayName(user.role),
            icon: Icons.work,
            color: _getRoleColor(user.role),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'User Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Full Name',
              value: user.fullName,
              icon: Icons.person,
            ),
            _DetailRow(
              label: 'Email Address',
              value: user.email,
              icon: Icons.email,
            ),
            _DetailRow(
              label: 'User Role',
              value: _getRoleDisplayName(user.role),
              icon: Icons.work,
              valueColor: _getRoleColor(user.role),
            ),
            if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
              _DetailRow(
                label: 'Phone Number',
                value: user.phoneNumber!,
                icon: Icons.phone,
              ),
            _DetailRow(
              label: 'Location',
              value: user.location.isNotEmpty ? user.location : 'Not specified',
              icon: Icons.location_on,
            ),
            _DetailRow(
              label: 'Account Created',
              value: _formatDateTime(user.createdAt),
              icon: Icons.calendar_today,
            ),
            _DetailRow(
              label: 'Profile Completed',
              value: user.profileCompleted ? 'Yes' : 'No',
              icon: Icons.check_circle,
              valueColor: user.profileCompleted ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Professional Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (user.professionalSummary.isNotEmpty)
              _DetailSection(
                label: 'Professional Summary',
                value: user.professionalSummary,
                icon: Icons.description,
              ),
            if (user.workExperience.isNotEmpty)
              _DetailSection(
                label: 'Work Experience',
                value: user.workExperience,
                icon: Icons.business_center,
              ),
            if (user.seeking.isNotEmpty)
              _DetailSection(
                label: 'Currently Seeking',
                value: user.seeking,
                icon: Icons.search,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, UserService userService, Color statusColor, String statusText) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Account Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Current Status: $statusText',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Suspend/Activate Button
                if (!user.isSuspended)
                  ActionButton(
                    text: 'Suspend User',
                    icon: Icons.pause_circle_outline,
                    color: Colors.orange,
                    onPressed: () => _showStatusConfirmationDialog(context, userService, 'suspend'),
                  )
                else
                  ActionButton(
                    text: 'Activate User',
                    icon: Icons.play_arrow,
                    color: Colors.green,
                    onPressed: () => _showStatusConfirmationDialog(context, userService, 'activate'),
                  ),

                // Delete Button
                ActionButton(
                  text: 'Delete Account',
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  onPressed: () => _showStatusConfirmationDialog(context, userService, 'delete'),
                ),

                // View Profile Button
                ActionButton(
                  text: 'View Full Profile',
                  icon: Icons.visibility,
                  color: Colors.blue,
                  onPressed: () {
                    // Navigate to full profile page if available
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening full user profile...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets
class _InfoChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _InfoChip({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailSection({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const ActionButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}