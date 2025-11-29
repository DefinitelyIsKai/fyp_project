import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class UserDetailPage extends StatefulWidget {
  final UserModel user;

  const UserDetailPage({super.key, required this.user});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  bool _isEditing = false;
  bool _isSaving = false;
  late UserModel _user;
  
  // Text editing controllers
  late TextEditingController _fullNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _locationController;
  late TextEditingController _professionalSummaryController;
  late TextEditingController _professionalProfileController;
  late TextEditingController _workExperienceController;
  late TextEditingController _seekingController;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initializeControllers();
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController(text: _user.fullName);
    _phoneNumberController = TextEditingController(text: _user.phoneNumber ?? '');
    _locationController = TextEditingController(text: _user.location);
    _professionalSummaryController = TextEditingController(text: _user.professionalSummary);
    _professionalProfileController = TextEditingController(text: _user.professionalProfile);
    _workExperienceController = TextEditingController(text: _user.workExperience);
    _seekingController = TextEditingController(text: _user.seeking);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _locationController.dispose();
    _professionalSummaryController.dispose();
    _professionalProfileController.dispose();
    _workExperienceController.dispose();
    _seekingController.dispose();
    super.dispose();
  }

  UserModel get user => _user;

  /// Check if current user can edit this user's profile
  bool _canEditUser() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentAdmin = authService.currentAdmin;
    
    if (currentAdmin == null) return false;
    
    // Cannot edit your own profile
    if (currentAdmin.id == _user.id) {
      return false;
    }
    
    final currentRole = currentAdmin.role.toLowerCase();
    final targetRole = _user.role.toLowerCase();
    
    // Staff and HR cannot edit Manager profiles
    if ((currentRole == 'staff' || currentRole == 'hr') && targetRole == 'manager') {
      return false;
    }
    
    // Manager can edit all profiles (except their own)
    if (currentRole == 'manager') {
      return true;
    }
    
    // Staff and HR can edit other roles (except their own)
    return true;
  }

  /// Check if current user can access Account Management actions
  bool _canAccessAccountManagement() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentAdmin = authService.currentAdmin;
    
    if (currentAdmin == null) return false;
    
    // Cannot perform account management on yourself (view only)
    if (currentAdmin.id == _user.id) {
      return false;
    }
    
    final currentRole = currentAdmin.role.toLowerCase();
    
    // Only Manager can access Account Management
    // HR and Staff cannot access Account Management
    return currentRole == 'manager';
  }

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

  Widget _buildProfileAvatar() {
    final imageData = user.image;
    String? base64String;
    
    if (imageData != null && imageData['base64'] != null) {
      base64String = imageData['base64'] as String?;
    }
    
    return Container(
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
      child: ClipOval(
        child: base64String != null && base64String.isNotEmpty
            ? _buildBase64Image(base64String)
            : _buildPlaceholderAvatar(),
      ),
    );
  }

  Widget _buildBase64Image(String base64String) {
    try {
      final cleanBase64 = base64String.trim().replaceAll(RegExp(r'\s+'), '');
      if (cleanBase64.isEmpty) {
        return _buildPlaceholderAvatar();
      }
      
      final bytes = base64Decode(cleanBase64);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error displaying base64 image: $error');
          return _buildPlaceholderAvatar();
        },
      );
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return _buildPlaceholderAvatar();
    }
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: _getRoleColor(user.role).withOpacity(0.1),
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
    );
  }

  void _enterEditMode() {
    if (!_canEditUser()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to edit this user profile'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      // Reset controllers to original values
      _initializeControllers();
    });
  }

  Future<void> _saveUserInfo() async {
    // Check permission before saving
    if (!_canEditUser()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to edit this user profile'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isEditing = false;
        });
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userService = UserService();
      
      final result = await userService.updateUserInfo(
        userId: _user.id,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim().isEmpty 
            ? null 
            : _phoneNumberController.text.trim(),
        location: _locationController.text.trim(),
        professionalSummary: _professionalSummaryController.text.trim(),
        professionalProfile: _professionalProfileController.text.trim(),
        workExperience: _workExperienceController.text.trim(),
        seeking: _seekingController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Fetch updated user data
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user.id)
            .get();
        
        if (userDoc.exists) {
          setState(() {
            _user = UserModel.fromJson(userDoc.data()!, userDoc.id);
            _isEditing = false;
            _isSaving = false;
          });
          // Reinitialize controllers with new data
          _initializeControllers();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User information updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Return true to refresh parent page
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating user: ${result['error']}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showStatusConfirmationDialog(BuildContext context, UserService userService, String action) {
    if (action == 'delete') {
      // For delete, show a dialog with reason input
      _showDeleteDialog(context, userService);
      return;
    }

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
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  action == 'suspend' ? 'Suspending user...' :
                  action == 'activate' ? 'Activating user...' :
                  'Deleting user...',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      if (action == 'suspend') {
        await userService.suspendUser(user.id);
      } else if (action == 'activate') {
        await userService.unsuspendUser(user.id);
      } else if (action == 'delete') {

        return;
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

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
        Navigator.pop(context); // Close loading dialog
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
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _isSaving ? null : _cancelEdit,
              tooltip: 'Cancel',
            ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveUserInfo,
              tooltip: 'Save',
            ),
          ] else if (_canEditUser())
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _enterEditMode,
              tooltip: 'Edit',
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

            // Wallet Balance Card
            _buildWalletCard(),
            const SizedBox(height: 20),

            // User Information Card
            _buildUserInfoCard(),
            const SizedBox(height: 20),

            // Professional Information Card (if available)
            if (user.professionalSummary.isNotEmpty || user.workExperience.isNotEmpty || user.seeking.isNotEmpty || user.professionalProfile.isNotEmpty)
              _buildProfessionalInfoCard(),
            if (user.professionalSummary.isNotEmpty || user.workExperience.isNotEmpty || user.seeking.isNotEmpty || user.professionalProfile.isNotEmpty)
              const SizedBox(height: 20),

            // Tags Card (if available)
            if (user.tags != null && user.tags!.isNotEmpty)
              _buildTagsCard(),
            if (user.tags != null && user.tags!.isNotEmpty)
              const SizedBox(height: 20),

            // Account Actions Card (hidden in edit mode and for HR/Staff roles)
            if (!_isEditing && _canAccessAccountManagement())
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
                _buildProfileAvatar(),
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

  Widget _buildWalletCard() {
    final userService = UserService();
    
    print('UserDetailPage - User ID: ${user.id}');
    
    return FutureBuilder<double>(
      future: userService.getWalletBalance(user.id),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0.0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        
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
                    Icon(Icons.account_balance_wallet, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Wallet Balance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Balance',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            balance.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          size: 40,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
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
            if (_isEditing) ...[
              _EditableDetailRow(
                label: 'Full Name',
                controller: _fullNameController,
                icon: Icons.person,
                enabled: !_isSaving,
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
              _EditableDetailRow(
                label: 'Phone Number',
                controller: _phoneNumberController,
                icon: Icons.phone,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
              ),
              _EditableDetailRow(
                label: 'Location',
                controller: _locationController,
                icon: Icons.location_on,
                enabled: !_isSaving,
              ),
            ] else ...[
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
            ],
            // Age field
            if (user.age != null)
              _DetailRow(
                label: 'Age',
                value: user.age.toString(),
                icon: Icons.cake,
              ),
            // Gender field
            if (user.gender != null && user.gender!.isNotEmpty)
              _DetailRow(
                label: 'Gender',
                value: user.gender![0].toUpperCase() + user.gender!.substring(1).toLowerCase(),
                icon: Icons.person,
              ),
            // Email Verified
            _DetailRow(
              label: 'Email Verified',
              value: user.emailVerified ? 'Yes' : 'No',
              icon: Icons.verified,
              valueColor: user.emailVerified ? Colors.green : Colors.orange,
            ),
            // Coordinates (if available)
            if (user.latitude != null && user.longitude != null)
              _DetailRow(
                label: 'Coordinates',
                value: '${user.latitude!.toStringAsFixed(6)}, ${user.longitude!.toStringAsFixed(6)}',
                icon: Icons.map,
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
            _DetailRow(
              label: 'Accepted Terms',
              value: user.acceptedTerms ? 'Yes' : 'No',
              icon: Icons.description,
              valueColor: user.acceptedTerms ? Colors.green : Colors.grey,
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
            if (_isEditing) ...[
              _EditableDetailSection(
                label: 'Professional Summary',
                controller: _professionalSummaryController,
                icon: Icons.description,
                enabled: !_isSaving,
                maxLines: 5,
              ),
              _EditableDetailSection(
                label: 'Professional Profile',
                controller: _professionalProfileController,
                icon: Icons.description,
                enabled: !_isSaving,
                maxLines: 5,
              ),
              _EditableDetailSection(
                label: 'Work Experience',
                controller: _workExperienceController,
                icon: Icons.business_center,
                enabled: !_isSaving,
                maxLines: 5,
              ),
              _EditableDetailSection(
                label: 'Currently Seeking',
                controller: _seekingController,
                icon: Icons.search,
                enabled: !_isSaving,
                maxLines: 3,
              ),
            ] else ...[
              if (user.professionalSummary.isNotEmpty)
                _DetailSection(
                  label: 'Professional Summary',
                  value: user.professionalSummary,
                  icon: Icons.description,
                ),
              if (user.professionalProfile.isNotEmpty)
                _DetailSection(
                  label: 'Professional Profile',
                  value: user.professionalProfile,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTagsCard() {
    if (user.tags == null || user.tags!.isEmpty) {
      return const SizedBox.shrink();
    }

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
                Icon(Icons.label_outline, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Tags & Skills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...user.tags!.entries.map((entry) {
              final categoryId = entry.key;
              final tagsList = entry.value;
              
              // Skip if not a list
              if (tagsList is! List) {
                return const SizedBox.shrink();
              }
              
              // Get category name (try to infer from tag content)
              String categoryName = _getTagCategoryName(categoryId, tagsList);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tagsList.map((tag) {
                        if (tag is! String) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.purple[200]!),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.purple[700],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  String _getTagCategoryName(String categoryId, List<dynamic> tagsList) {
    // Try to infer category name from tag content
    if (tagsList.isEmpty) return 'Tags';
    
    // Check first few tags to infer category
    final firstTags = tagsList.take(3).join(' ').toLowerCase();
    
    if (firstTags.contains('license') || firstTags.contains('vaccinated') || 
        firstTags.contains('transport') || firstTags.contains('passport')) {
      return 'Qualifications & Certifications';
    }
    if (firstTags.contains('confident') || firstTags.contains('friendly') || 
        firstTags.contains('leadership') || firstTags.contains('polite')) {
      return 'Personal Traits';
    }
    if (firstTags.contains('service') || firstTags.contains('support') || 
        firstTags.contains('learner') || firstTags.contains('teamwork')) {
      return 'Skills';
    }
    
    // Default fallback
    return 'Tags';
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

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Warning Button
                  if (!user.isSuspended)
                    ActionButton(
                      text: 'Warning',
                      color: Colors.orange,
                      onPressed: () => _showWarningDialog(context, userService),
                    )
                  else
                    ActionButton(
                      text: 'Activate',
                      color: Colors.green,
                      onPressed: () => _showStatusConfirmationDialog(context, userService, 'activate'),
                    ),

                  // Suspend Button (only show if not suspended)
                  if (!user.isSuspended) ...[
                    const SizedBox(width: 8),
                    ActionButton(
                      text: 'Suspend',
                      color: Colors.red,
                      onPressed: () => _showSuspendDialog(context, userService),
                    ),
                  ],

                  // Delete Button
                  const SizedBox(width: 8),
                  ActionButton(
                    text: 'Delete',
                    color: Colors.red,
                    onPressed: () => _showStatusConfirmationDialog(context, userService, 'delete'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWarningDialog(BuildContext context, UserService userService) async {
    final violationController = TextEditingController();

    // Get current strike count
    final currentStrikes = await userService.getStrikeCount(user.id);
    final strikesRemaining = 3 - currentStrikes;

    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please provide a violation reason'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    isLoading = true;
                    setDialogState(() {});

                    try {
                      final result = await userService.issueWarning(
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$userName has reached 3 strikes and has been automatically suspended'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Warning issued to $userName (Strike $strikeCount/3)'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to issue warning: ${result['error']}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to issue warning: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
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
      ),
      ),
    );
  }

  Future<void> _showSuspendDialog(BuildContext context, UserService userService) async {
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
                      await userService.suspendUser(
                        user.id,
                        violationReason: suspensionReason,
                        durationDays: durationDays,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${user.fullName}\'s account has been suspended for $durationDays day${durationDays == 1 ? '' : 's'}'),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to suspend user: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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

  Future<void> _showDeleteDialog(BuildContext context, UserService userService) async {
    final reasonController = TextEditingController();

    bool isLoading = false;
    String? reasonError;

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
                  onChanged: (value) {
                    if (reasonError != null) {
                      setDialogState(() => reasonError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Explain why this account is being deleted...',
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

                      // Reset errors
                      reasonError = null;

                      // Validate reason
                      if (deletionReason.isEmpty) {
                        setDialogState(() {
                          reasonError = 'Please provide a deletion reason';
                        });
                        return;
                      }

                      isLoading = true;
                      setDialogState(() {});

                      try {
                        final result = await userService.deleteUserWithNotification(
                          userId: user.id,
                          deletionReason: deletionReason,
                        );

                        if (context.mounted) {
                          Navigator.pop(context); // Close delete dialog

                          if (result['success'] == true) {
                            final userName = result['userName'];
                            
                            // Navigate back to view_users_page first
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                            
                            // Show success message after navigation
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$userName\'s account has been deleted'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete user: ${result['error']}'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete user: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
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
  final Color color;
  final VoidCallback onPressed;

  const ActionButton({
    required this.text,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// Editable Detail Row Widget
class _EditableDetailRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final TextInputType? keyboardType;

  const _EditableDetailRow({
    required this.label,
    required this.controller,
    required this.icon,
    this.enabled = true,
    this.keyboardType,
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
                TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

// Editable Detail Section Widget
class _EditableDetailSection extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final int maxLines;

  const _EditableDetailSection({
    required this.label,
    required this.controller,
    required this.icon,
    this.enabled = true,
    this.maxLines = 3,
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
          TextField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
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