import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/storage_service.dart';
import '../../../services/user/notification_service.dart';
import '../../../utils/user/dialog_utils.dart';
import 'edit_profile_page.dart';
import 'verification_page.dart';
import '../settings/settings_page.dart';
import '../settings/notifications_page.dart';
import '../settings/help_support_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();
  final NotificationService _notificationService = NotificationService();
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _authService.getUserDoc();
  }

  String? _getUserStatus(Map<String, dynamic>? data) {
    return data?['status'] as String?;
  }

  bool _isSuspended(String? status) {
    if (status == null) return false;
    return status.toLowerCase() == 'suspended' || status.toLowerCase() == 'suspend';
  }

  Future<void> _handleLogout(BuildContext context) async {
    await DialogUtils.showLogoutConfirmation(
      context: context,
      authService: _authService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AbsorbPointer(
        absorbing: _uploadingPhoto,
        child: Stack(
          children: [
            FutureBuilder(
              future: _userFuture,
              builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final data = snapshot.data?.data();
          final String fullName = (data?['fullName'] as String?)?.trim().isNotEmpty == true
              ? data!['fullName'] as String
              : 'Unknown User';
          final String email = (FirebaseAuth.instance.currentUser?.email ?? '').isNotEmpty
              ? (FirebaseAuth.instance.currentUser?.email ?? '')
              : ((data?['email'] as String?) ?? '');
          final bool isRecruiter = (data?['role'] as String?)?.toLowerCase() == 'recruiter';
          final String? userStatus = _getUserStatus(data);
          final bool isSuspended = _isSuspended(userStatus);
          final bool isVerified = (data?['isVerified'] as bool? ?? false);
          final Map<String, dynamic>? imageData = (data?['image'] as Map<String, dynamic>?);
          final String? base64Image = (imageData?['base64'] as String?);
          final Uint8List? imageBytes = _decodeBase64(base64Image);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _userFuture = _authService.getUserDoc();
              });
              await _userFuture;
            },
            color: const Color(0xFF00C8A0),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 65,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF00C8A0).withOpacity(0.8),
                          const Color(0xFF00C8A0).withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
                backgroundColor: const Color(0xFF00C8A0),
                elevation: 0,
                automaticallyImplyLeading: false,
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16, top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isRecruiter ? 'RECRUITER' : 'JOBSEEKER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Switch.adaptive(
                          value: isRecruiter,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.white.withOpacity(0.5),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.white.withOpacity(0.3),
                          onChanged: _uploadingPhoto ? null : (val) async {
                            if (_uploadingPhoto) {
                              DialogUtils.showInfoMessage(
                                context: context,
                                message: 'Please wait for photo upload to complete.',
                              );
                              return;
                            }
                            try {
                              await _authService.updateUserProfile({
                                'role': val ? 'recruiter' : 'jobseeker',
                              });
                              if (!mounted) return;
                              setState(() {
                                _userFuture = _authService.getUserDoc();
                              });
                              DialogUtils.showSuccessMessage(
                                context: context,
                                message: 'Role set to ${val ? 'Recruiter' : 'Jobseeker'}',
                              );
                            } catch (e) {
                              if (!mounted) return;
                              DialogUtils.showWarningMessage(
                                context: context,
                                message: 'Failed to update role: $e',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _uploadingPhoto ? null : _handlePhotoUpdate,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00C8A0),
                                    width: 3,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: Colors.grey[100],
                                  backgroundImage: imageBytes != null
                                      ? MemoryImage(imageBytes)
                                      : null,
                                  child: imageBytes == null
                                      ? Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey[400],
                                        )
                                      : null,
                                ),
                              ),
                              if (_uploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _uploadingPhoto 
                                        ? Colors.grey 
                                        : const Color(0xFF00C8A0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: _uploadingPhoto
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                ),
                              ),
                              if (isVerified)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.blue[700],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        Text(
                          isLoading ? 'Loading...' : fullName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                      
                        Text(
                          isLoading ? '' : email,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Verify Account Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_uploadingPhoto || isSuspended || isVerified)
                                ? () {
                                    if (_uploadingPhoto) {
                                      DialogUtils.showInfoMessage(
                                        context: context,
                                        message: 'Please wait for photo upload to complete.',
                                      );
                                    } else if (isSuspended) {
                                      DialogUtils.showWarningMessage(
                                        context: context,
                                        message: 'Your account has been suspended. You can only access your profile page.',
                                      );
                                    } else if (isVerified) {
                                      DialogUtils.showInfoMessage(
                                        context: context,
                                        message: 'Your account is already verified.',
                                      );
                                    }
                                  }
                                : () async {
                                    final changed = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const VerificationPage(),
                                      ),
                                    );
                                    if (!mounted) return;
                                    if (changed == true) {
                                      setState(() {
                                        _userFuture = _authService.getUserDoc();
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isVerified 
                                  ? Colors.grey[400] 
                                  : Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: Colors.grey[400],
                              disabledForegroundColor: Colors.white,
                            ),
                            icon: Icon(
                              isVerified ? Icons.verified : Icons.verified_user, 
                              size: 18,
                            ),
                            label: Text(
                              isVerified ? 'Account Verified' : 'Verify Account',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Edit Profile Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (_uploadingPhoto || isSuspended)
                                ? () {
                                    if (_uploadingPhoto) {
                                      DialogUtils.showInfoMessage(
                                        context: context,
                                        message: 'Please wait for photo upload to complete.',
                                      );
                                    } else {
                                      DialogUtils.showWarningMessage(
                                        context: context,
                                        message: 'Your account has been suspended. You can only access your profile page.',
                                      );
                                    }
                                  }
                                : () async {
                                    final changed = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EditProfilePage(),
                                      ),
                                    );
                                    if (!mounted) return;
                                    if (changed == true) {
                                      setState(() {
                                        _userFuture = _authService.getUserDoc();
                                      });
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00C8A0),
                              side: const BorderSide(color: Color(0xFF00C8A0)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'App preferences and configurations',
                          onTap: (_uploadingPhoto || isSuspended)
                              ? () {
                                  if (_uploadingPhoto) {
                                    DialogUtils.showInfoMessage(
                                      context: context,
                                      message: 'Please wait for photo upload to complete.',
                                    );
                                  } else {
                                    DialogUtils.showWarningMessage(
                                      context: context,
                                      message: 'Your account has been suspended. You can only access your profile page.',
                                    );
                                  }
                                }
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                                  );
                                },
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildMenuItem(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Manage your alerts and messages',
                          badge: _buildNotificationBadge(),
                          onTap: (_uploadingPhoto || isSuspended)
                              ? () {
                                  if (_uploadingPhoto) {
                                    DialogUtils.showInfoMessage(
                                      context: context,
                                      message: 'Please wait for photo upload to complete.',
                                    );
                                  } else {
                                    DialogUtils.showWarningMessage(
                                      context: context,
                                      message: 'Your account has been suspended. You can only access your profile page.',
                                    );
                                  }
                                }
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => NotificationsPage()),
                                  );
                                },
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          subtitle: 'Get help and contact support',
                          onTap: (_uploadingPhoto || isSuspended)
                              ? () {
                                  if (_uploadingPhoto) {
                                    DialogUtils.showInfoMessage(
                                      context: context,
                                      message: 'Please wait for photo upload to complete.',
                                    );
                                  } else {
                                    DialogUtils.showWarningMessage(
                                      context: context,
                                      message: 'Your account has been suspended. You can only access your profile page.',
                                    );
                                  }
                                }
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const HelpSupportPage(),
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: ElevatedButton(
                      onPressed: _uploadingPhoto
                          ? () {
                              DialogUtils.showInfoMessage(
                                context: context,
                                message: 'Please wait for photo upload to complete.',
                              );
                            }
                          : () => _handleLogout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ],
            ),
          );
        },
      ),
            if (_uploadingPhoto)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF00C8A0),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Uploading photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? badge,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF00C8A0).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF00C8A0),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) badge,
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildNotificationBadge() {
    return StreamBuilder<int>(
      stream: _notificationService.streamUnreadCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count <= 0) return const SizedBox.shrink();
        final display = count > 99 ? '99+' : '$count';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            display,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to Load Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {
                _userFuture = _authService.getUserDoc();
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C8A0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePhotoUpdate() async {
    //check photo exists
    final currentDoc = await _authService.getUserDoc();
    final currentData = currentDoc.data();
    final Map<String, dynamic>? currentImageData = (currentData?['image'] as Map<String, dynamic>?);
    final bool hasPhoto = currentImageData != null && 
                         (currentImageData['base64'] != null || currentImageData['downloadUrl'] != null);
    
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_camera, color: const Color(0xFF00C8A0)),
                ),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library, color: const Color(0xFF00C8A0)),
                ),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              if (hasPhoto) ...[
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    
    if (source == null) return;
    
    //remove 
    if (source == 'remove') {
      await _removeProfilePhoto();
      return;
    }
    
    //upload 
    if (!mounted) return;
    setState(() => _uploadingPhoto = true);
    
    try {
      final url = await _storage.pickAndUploadImage(fromCamera: source == 'camera');
      if (!mounted) return;
      
      if (url != null) {
        setState(() {
          _userFuture = _authService.getUserDoc();
          _uploadingPhoto = false;
        });
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Profile photo updated successfully',
        );
      } else {
        setState(() => _uploadingPhoto = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      
      //extract error 
      String errorMessage = 'Failed to upload profile photo';
      if (e is Exception) {
        final errorStr = e.toString();
        errorMessage = errorStr.replaceFirst(RegExp(r'^Exception:\s*'), '');
      }
      
      DialogUtils.showWarningMessage(
        context: context,
        message: errorMessage,
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Remove Profile Photo',
      message: 'Are you sure you want to remove your profile photo? This action cannot be undone.',
      icon: Icons.delete_outline,
      confirmText: 'Remove',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    
    if (confirmed != true || !mounted) return;
    
    try {
      await _authService.updateUserProfile({
        'image': FieldValue.delete(),
      });
      

      if (mounted) {
        setState(() {
          _userFuture = _authService.getUserDoc();
        });
        
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Profile photo removed successfully',
        );
      }
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to remove profile photo: $e',
      );
    }
  }

  Uint8List? _decodeBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      String padded = base64String;
      final int remainder = padded.length % 4;
      if (remainder != 0) {
        padded += '=' * (4 - remainder);
      }
      return base64Decode(padded);
    } catch (e) {
      print('Error decoding base64 image: $e');
      return null;
    }
  }
}