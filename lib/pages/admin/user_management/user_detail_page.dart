import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/models/user/resume_attachment.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/services/admin/profile_pic_service.dart';
import 'package:fyp_project/utils/user/resume_utils.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/widgets/admin/common/info_chip.dart';
import 'package:fyp_project/widgets/admin/cards/user_stat_card.dart';
import 'package:fyp_project/widgets/admin/common/user_detail_row.dart';
import 'package:fyp_project/widgets/admin/common/user_detail_section.dart';
import 'package:fyp_project/widgets/admin/common/editable_detail_row.dart';
import 'package:fyp_project/widgets/admin/common/editable_detail_section.dart';
import 'package:fyp_project/widgets/admin/tabs/credit_logs_tab.dart';
import 'package:fyp_project/widgets/user/location_autocomplete_field.dart';
import 'package:fyp_project/utils/admin/phone_number_formatter.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class UserDetailPage extends StatefulWidget {
  final UserModel user;

  const UserDetailPage({super.key, required this.user});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> with SingleTickerProviderStateMixin {
  bool _isEditing = false;
  bool _isSaving = false;
  late UserModel _user;
  late TabController _tabController;
  
  late TextEditingController _fullNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _locationController;
  late TextEditingController _ageController;
  late TextEditingController _professionalSummaryController;
  late TextEditingController _professionalProfileController;
  late TextEditingController _workExperienceController;
  late TextEditingController _seekingController;
  
  String? _selectedGender;
  double? _latitude;
  double? _longitude;
  
  Map<String, dynamic>? _newImageData;
  Map<String, dynamic>? _newResumeData;
  bool _isUploadingImage = false;
  bool _isUploadingResume = false;
  
  final ProfilePicService _profilePicService = ProfilePicService();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initializeControllers();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController(text: _user.fullName);
    _phoneNumberController = TextEditingController(text: _user.phoneNumber ?? '');
    _locationController = TextEditingController(text: _user.location);
    _ageController = TextEditingController(text: _user.age?.toString() ?? '');
    _professionalSummaryController = TextEditingController(text: _user.professionalSummary);
    _professionalProfileController = TextEditingController(text: _user.professionalProfile);
    _workExperienceController = TextEditingController(text: _user.workExperience);
    _seekingController = TextEditingController(text: _user.seeking);
    _selectedGender = _user.gender;
    _latitude = _user.latitude;
    _longitude = _user.longitude;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _professionalSummaryController.dispose();
    _professionalProfileController.dispose();
    _workExperienceController.dispose();
    _seekingController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  UserModel get user => _user;

  bool _canEditUser() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentAdmin = authService.currentAdmin;
    
    if (currentAdmin == null) return false;
    
    final currentRole = currentAdmin.role.toLowerCase();
    final targetRole = _user.role.toLowerCase();
    
    // Manager can edit their own profile and other managers
    if (currentRole == 'manager') {
      return true;
    }
    
    // Staff and HR cannot edit managers
    if ((currentRole == 'staff' || currentRole == 'hr') && targetRole == 'manager') {
      return false;
    }
    
    // Staff and HR cannot edit their own profile
    if ((currentRole == 'staff' || currentRole == 'hr') && currentAdmin.id == _user.id) {
      return false;
    }
    
    return true;
  }

  bool _canAccessAccountManagement() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentAdmin = authService.currentAdmin;
    
    if (currentAdmin == null) return false;
    
    final currentRole = currentAdmin.role.toLowerCase();
    
    // Only managers can access account management
    if (currentRole != 'manager') {
      return false;
    }
    
    // Managers cannot manage their own account (cannot delete/suspend themselves)
    if (currentAdmin.id == _user.id) {
      return false;
    }
    
    return true;
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
    final imageData = _newImageData ?? user.image;
    String? base64String;
    
    if (imageData != null && imageData['base64'] != null) {
      base64String = imageData['base64'] as String?;
    }
    
    Widget avatarWidget = Container(
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
    
    if (_isEditing && _canEditUser()) {
      return GestureDetector(
        onTap: _isUploadingImage ? null : _pickProfileImage,
        child: Stack(
          children: [
            avatarWidget,
            if (_isUploadingImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    return avatarWidget;
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
    if (_isEditing || _isSaving) {
      return;
    }
    
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
    
    if (!mounted) return;
    
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    if (_isSaving) {
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isEditing = false;
      _initializeControllers();
      _newImageData = null;
      _newResumeData = null;
    });
  }

  Future<void> _saveUserInfo() async {
    if (_isSaving) {
      return;
    }
    
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

    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final userService = UserService();
      
      final ageText = _ageController.text.trim();
      final age = ageText.isEmpty ? null : int.tryParse(ageText);
      
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
        age: age,
        gender: _selectedGender,
        latitude: _latitude,
        longitude: _longitude,
        image: _newImageData,
        resume: _newResumeData,
      );

      if (!mounted) {
        _isSaving = false;
        return;
      }

      if (result['success'] == true) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user.id)
            .get();
        
        if (userDoc.exists && mounted) {
          setState(() {
            _user = UserModel.fromJson(userDoc.data()!, userDoc.id);
            _isEditing = false;
            _isSaving = false;
            _newImageData = null;
            _newResumeData = null;
          });
          _initializeControllers();
        } else if (!mounted) {
          _isSaving = false;
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User information updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating user: ${result['error']}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          _isSaving = false;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _isSaving = false;
      }
    }
  }

  void _showStatusConfirmationDialog(BuildContext context, UserService userService, String action) {
    if (action == 'delete') {
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
      Navigator.pop(context); 

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
        Navigator.pop(context); 
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
              onPressed: (_isEditing || _isSaving) ? null : _enterEditMode,
              tooltip: 'Edit',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Credit Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(context),
                const SizedBox(height: 20),

                _buildQuickStats(),
                const SizedBox(height: 20),

                _buildWalletCard(),
                const SizedBox(height: 20),

                _buildUserInfoCard(),
                const SizedBox(height: 20),

                if (user.professionalSummary.isNotEmpty || user.workExperience.isNotEmpty || user.seeking.isNotEmpty || user.professionalProfile.isNotEmpty)
                  _buildProfessionalInfoCard(),
                if (user.professionalSummary.isNotEmpty || user.workExperience.isNotEmpty || user.seeking.isNotEmpty || user.professionalProfile.isNotEmpty)
                  const SizedBox(height: 20),

                if (user.tags != null && user.tags!.isNotEmpty)
                  _buildTagsCard(),
                if (user.tags != null && user.tags!.isNotEmpty)
                  const SizedBox(height: 20),

                if ((user.resume != null || _newResumeData != null) || _isEditing)
                  _buildResumeCard(),
                if ((user.resume != null || _newResumeData != null) || _isEditing)
                  const SizedBox(height: 20),

                if (!_isEditing && _canAccessAccountManagement())
                  _buildActionsCard(context, userService, statusColor, statusText),
                const SizedBox(height: 20),
              ],
            ),
          ),
          CreditLogsTab(userId: _user.id),
        ],
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
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                _buildProfileAvatar(),
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

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    InfoChip(
                      text: _getStatusText(user.isActive, user.isSuspended),
                      color: _getStatusColor(user.isActive, user.isSuspended),
                      icon: _getStatusIcon(user.isActive, user.isSuspended),
                    ),
                    InfoChip(
                      text: _getRoleDisplayName(user.role),
                      color: _getRoleColor(user.role),
                      icon: Icons.work,
                    ),
                    if (user.reportCount > 0)
                      InfoChip(
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
          child: UserStatCard(
            title: 'Joined',
            value: _formatDate(user.createdAt),
            icon: Icons.calendar_today,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: UserStatCard(
            title: 'Status',
            value: _getStatusText(user.isActive, user.isSuspended),
            icon: _getStatusIcon(user.isActive, user.isSuspended),
            color: _getStatusColor(user.isActive, user.isSuspended),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: UserStatCard(
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
              EditableDetailRow(
                label: 'Full Name',
                controller: _fullNameController,
                icon: Icons.person,
                enabled: !_isSaving,
              ),
              UserDetailRow(
                label: 'Email Address',
                value: user.email,
                icon: Icons.email,
              ),
              UserDetailRow(
                label: 'User Role',
                value: _getRoleDisplayName(user.role),
                icon: Icons.work,
                valueColor: _getRoleColor(user.role),
              ),
              EditableDetailRow(
                label: 'Phone Number',
                controller: _phoneNumberController,
                icon: Icons.phone,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  PhoneNumberFormatter(),
                ],
                maxLength: 13,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: LocationAutocompleteField(
                  controller: _locationController,
                  label: 'Location',
                  hintText: 'Search location... (e.g., Kuala Lumpur)',
                  restrictToCountry: 'my',
                  onLocationSelected: (description, latitude, longitude) {
                    setState(() {
                      _latitude = latitude;
                      _longitude = longitude;
                    });
                  },
                ),
              ),
              EditableDetailRow(
                label: 'Age',
                controller: _ageController,
                icon: Icons.cake,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              const Text(
                'Gender',
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
                    value: _selectedGender,
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
                    ],
                    onChanged: _isSaving ? null : (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                ),
              ),
            ] else ...[
              UserDetailRow(
                label: 'Full Name',
                value: user.fullName,
                icon: Icons.person,
              ),
              UserDetailRow(
                label: 'Email Address',
                value: user.email,
                icon: Icons.email,
              ),
              UserDetailRow(
                label: 'User Role',
                value: _getRoleDisplayName(user.role),
                icon: Icons.work,
                valueColor: _getRoleColor(user.role),
              ),
              if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                UserDetailRow(
                  label: 'Phone Number',
                  value: user.phoneNumber!,
                  icon: Icons.phone,
                ),
              Padding(
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
                        Icons.location_on,
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
                            'Location',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.location.isNotEmpty ? user.location : 'Not specified',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: null,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (user.age != null)
              UserDetailRow(
                label: 'Age',
                value: user.age.toString(),
                icon: Icons.cake,
              ),
            if (user.gender != null && user.gender!.isNotEmpty)
              UserDetailRow(
                label: 'Gender',
                value: user.gender![0].toUpperCase() + user.gender!.substring(1).toLowerCase(),
                icon: Icons.person,
              ),
            UserDetailRow(
              label: 'Email Verified',
              value: user.emailVerified ? 'Yes' : 'No',
              icon: Icons.verified,
              valueColor: user.emailVerified ? Colors.green : Colors.orange,
            ),
            if (user.latitude != null && user.longitude != null)
              UserDetailRow(
                label: 'Coordinates',
                value: '${user.latitude!.toStringAsFixed(6)}, ${user.longitude!.toStringAsFixed(6)}',
                icon: Icons.map,
              ),
            UserDetailRow(
              label: 'Account Created',
              value: _formatDateTime(user.createdAt),
              icon: Icons.calendar_today,
            ),
            UserDetailRow(
              label: 'Profile Completed',
              value: user.profileCompleted ? 'Yes' : 'No',
              icon: Icons.check_circle,
              valueColor: user.profileCompleted ? Colors.green : Colors.orange,
            ),
            UserDetailRow(
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
              EditableDetailSection(
                label: 'Professional Summary',
                controller: _professionalSummaryController,
                icon: Icons.description,
                enabled: !_isSaving,
                maxLines: 5,
              ),
              EditableDetailSection(
                label: 'Professional Profile',
                controller: _professionalProfileController,
                icon: Icons.description,
                enabled: !_isSaving,
                maxLines: 5,
              ),
              EditableDetailSection(
                label: 'Work Experience',
                controller: _workExperienceController,
                icon: Icons.business_center,
                enabled: !_isSaving,
                maxLines: 5,
              ),
              EditableDetailSection(
                label: 'Currently Seeking',
                controller: _seekingController,
                icon: Icons.search,
                enabled: !_isSaving,
                maxLines: 3,
              ),
            ] else ...[
              if (user.professionalSummary.isNotEmpty)
                UserDetailSection(
                  label: 'Professional Summary',
                  value: user.professionalSummary,
                  icon: Icons.description,
                ),
              if (user.professionalProfile.isNotEmpty)
                UserDetailSection(
                  label: 'Professional Profile',
                  value: user.professionalProfile,
                  icon: Icons.description,
                ),
              if (user.workExperience.isNotEmpty)
                UserDetailSection(
                  label: 'Work Experience',
                  value: user.workExperience,
                  icon: Icons.business_center,
                ),
              if (user.seeking.isNotEmpty)
                UserDetailSection(
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

  Widget _buildResumeCard() {
    final resumeData = _newResumeData ?? user.resume;
    final attachment = resumeData != null ? ResumeAttachment.fromMap(resumeData) : null;
    
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
                Icon(Icons.description_outlined, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Resume',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEditing && _canEditUser()) ...[
              if (attachment != null) ...[
                Row(
                  children: [
                    Icon(Icons.insert_drive_file, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.fileName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${attachment.fileType.toUpperCase()} • ${resumeData != null ? _formatResumeUploadDate(resumeData) : 'Unknown date'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isUploadingResume)
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: _viewResume,
                        tooltip: 'View Resume',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _isUploadingResume || _isSaving ? null : _pickResume,
                icon: _isUploadingResume
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isUploadingResume
                    ? 'Uploading...'
                    : attachment != null
                        ? 'Change Resume'
                        : 'Upload Resume'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ] else if (attachment != null) ...[
              InkWell(
                onTap: _viewResume,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.fileName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${attachment.fileType.toUpperCase()} • ${resumeData != null ? _formatResumeUploadDate(resumeData) : 'Unknown date'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(
                'No resume uploaded',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _formatResumeUploadDate(Map<String, dynamic> resumeData) {
    try {
      final uploadedAt = resumeData['uploadedAt'];
      if (uploadedAt == null) return 'Unknown date';
      
      if (uploadedAt is String) {
        final date = DateTime.tryParse(uploadedAt);
        if (date != null) {
          return _formatDate(date);
        }
      } else if (uploadedAt is Timestamp) {
        return _formatDate(uploadedAt.toDate());
      }
      
      return 'Unknown date';
    } catch (e) {
      return 'Unknown date';
    }
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
              
              if (tagsList is! List) {
                return const SizedBox.shrink();
              }
              
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

  Future<void> _pickProfileImage() async {
    if (!_canEditUser()) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _selectImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _selectImageFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectImageFromGallery() async {
    try {
      setState(() => _isUploadingImage = true);
      
      final result = await _profilePicService.pickImageBase64(fromCamera: false);
      
      if (result != null && mounted) {
        setState(() {
          _newImageData = {
            'base64': result['base64'],
            'fileType': result['fileType'],
            'uploadedAt': DateTime.now().toIso8601String(),
          };
          _isUploadingImage = false;
        });
      } else {
        if (mounted) {
          setState(() => _isUploadingImage = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _selectImageFromCamera() async {
    try {
      setState(() => _isUploadingImage = true);
      
      final result = await _profilePicService.pickImageBase64(fromCamera: true);
      
      if (result != null && mounted) {
        setState(() {
          _newImageData = {
            'base64': result['base64'],
            'fileType': result['fileType'],
            'uploadedAt': DateTime.now().toIso8601String(),
          };
          _isUploadingImage = false;
        });
      } else {
        if (mounted) {
          setState(() => _isUploadingImage = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _pickResume() async {
    if (!_canEditUser()) return;
    
    try {
      setState(() => _isUploadingResume = true);
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) {
        setState(() => _isUploadingResume = false);
        return;
      }
      
      final file = result.files.single;
      if (file.bytes == null) {
        setState(() => _isUploadingResume = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to read file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      const int maxOriginalSize = 650 * 1024;
      if (file.bytes!.length > maxOriginalSize) {
        setState(() => _isUploadingResume = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File is too large (${(file.bytes!.length / 1024 / 1024).toStringAsFixed(2)}MB). Maximum size is 650KB.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final base64String = base64Encode(file.bytes!);
      String fileName = file.name.trim();
      if (fileName.isEmpty) {
        fileName = 'Resume.pdf';
      }
      
      if (mounted) {
        setState(() {
          _newResumeData = {
            'base64': base64String,
            'fileName': fileName,
            'fileType': 'pdf',
            'uploadedAt': DateTime.now().toIso8601String(),
          };
          _isUploadingResume = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resume selected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingResume = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting resume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _viewResume() async {
    final resumeData = _newResumeData ?? user.resume;
    if (resumeData == null) return;
    
    final attachment = ResumeAttachment.fromMap(resumeData);
    if (attachment == null) return;
    
    final success = await openResumeAttachment(attachment);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open resume file'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  String _getTagCategoryName(String categoryId, List<dynamic> tagsList) {
    if (tagsList.isEmpty) return 'Tags';
    
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

                  if (!user.isSuspended) ...[
                    const SizedBox(width: 8),
                    ActionButton(
                      text: 'Suspend',
                      color: Colors.red,
                      onPressed: () => _showSuspendDialog(context, userService),
                    ),
                  ],

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
    final durationController = TextEditingController(text: '30'); 

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

                    reasonError = null;
                    durationError = null;

                    if (suspensionReason.isEmpty) {
                      setDialogState(() {
                        reasonError = 'Please provide a suspension reason';
                      });
                      return;
                    }

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

                      reasonError = null;

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
                          Navigator.pop(context); 

                          if (result['success'] == true) {
                            final userName = result['userName'];
                            
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                            
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
