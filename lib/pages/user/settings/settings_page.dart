import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/user/auth_service.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../widgets/admin/dialogs/user_dialogs/change_password_dialog.dart';
import '../authentication/login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final email = currentUser?.email ?? 'Not available';
    final emailVerified = currentUser?.emailVerified ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_circle, size: 24, color: const Color(0xFF00C8A0)),
                    const SizedBox(width: 12),
                    const Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow(
                  icon: Icons.email,
                  label: 'Email Address',
                  value: email,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.verified_user, size: 20, color: emailVerified ? Colors.green : Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email Verification',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            emailVerified ? 'Verified' : 'Not Verified',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: emailVerified ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!emailVerified)
                      TextButton(
                        onPressed: () async {
                          try {
                            await currentUser?.sendEmailVerification();
                            if (!mounted) return;
                            DialogUtils.showSuccessMessage(
                              context: context,
                              message: 'Verification email sent! Please check your inbox.',
                            );
                          } catch (e) {
                            if (!mounted) return;
                            DialogUtils.showWarningMessage(
                              context: context,
                              message: 'Error sending verification email: $e',
                            );
                          }
                        },
                        child: const Text('Verify'),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications, size: 24, color: const Color(0xFF00C8A0)),
                    const SizedBox(width: 12),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSwitchTile(
                  icon: Icons.email_outlined,
                  title: 'Email Notifications',
                  subtitle: 'Receive updates via email',
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() {
                      _emailNotifications = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  icon: Icons.notifications_active,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  icon: Icons.sms,
                  title: 'SMS Notifications',
                  subtitle: 'Receive updates via SMS',
                  value: _smsNotifications,
                  onChanged: (value) {
                    setState(() {
                      _smsNotifications = value;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock, size: 24, color: const Color(0xFF00C8A0)),
                    const SizedBox(width: 12),
                    const Text(
                      'Privacy & Security',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildMenuTile(
                  icon: Icons.lock_reset,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () {
                    _showChangePasswordDialog(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuTile(
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  subtitle: 'View our privacy policy',
                  onTap: () {
                    DialogUtils.showInfoMessage(
                      context: context,
                      message: 'Privacy Policy will be available soon.',
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuTile(
                  icon: Icons.security,
                  title: 'Terms of Service',
                  subtitle: 'View terms and conditions',
                  onTap: () {
                    DialogUtils.showInfoMessage(
                      context: context,
                      message: 'Terms of Service will be available soon.',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, size: 24, color: const Color(0xFF00C8A0)),
                    const SizedBox(width: 12),
                    const Text(
                      'App Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildMenuTile(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: _selectedLanguage,
                  onTap: () {
                    _showLanguageDialog(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuTile(
                  icon: Icons.palette,
                  title: 'Appearance',
                  subtitle: 'System default',
                  onTap: () {
                    DialogUtils.showInfoMessage(
                      context: context,
                      message: 'Theme settings will be available soon.',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
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
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00C8A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF00C8A0)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF00C8A0),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C8A0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF00C8A0)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final languages = ['English', 'Bahasa Malaysia', '中文', 'Tamil'];
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            return RadioListTile<String>(
              title: Text(lang),
              value: lang,
              groupValue: _selectedLanguage,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                  Navigator.pop(context);
                  DialogUtils.showInfoMessage(
                    context: context,
                    message: 'Language preference saved. App restart may be required.',
                  );
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearCacheDialog(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Clear Cache',
      message: 'This will clear app cache and temporary files. The app may restart.',
      icon: Icons.delete_outline,
      confirmText: 'Clear',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed == true) {
      if (!mounted) return;
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Cache cleared successfully!',
      );
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await DialogUtils.showDestructiveConfirmation(
      context: context,
      title: 'Logout?',
      message: 'Are you sure you want to logout?',
      icon: Icons.logout,
      confirmText: 'Logout',
      cancelText: 'Cancel',
    );

    if (confirmed == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}
