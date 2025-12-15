import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/admin/auth_service.dart' as admin_auth;
import '../../../utils/user/dialog_utils.dart';
import '../../../utils/user/input_validators.dart';
import '../../../routes/app_routes.dart';
import 'package:fyp_project/pages/admin/dashboard/dashboard_page.dart';
import 'package:fyp_project/pages/admin/authentication/login_page.dart' as admin_login;
import '../home_page.dart';
import '../profile/profile_setup_flow.dart';
import 'sign_up_page.dart';
import 'forgot_password_page.dart';
import 'email_verification_loading_page.dart';

enum LoginMode { user, admin }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  LoginMode _loginMode = LoginMode.user;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_loginMode == LoginMode.user) {
        final credential = await _authService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        await credential.user?.reload();
        if (!(credential.user?.emailVerified ?? false)) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          if (mounted) {
            final confirmed = await DialogUtils.showConfirmationDialog(
              context: context,
              title: 'Email Not Verified',
              message: 'Please verify your email before logging in. Would you like to resend the verification email?',
              icon: Icons.email_outlined,
              iconColor: const Color(0xFF00C8A0),
              confirmText: 'Resend Email',
              cancelText: 'Cancel',
            );
            
            if (confirmed == true) {
              try {
                await _authService.resendVerificationEmail();
                if (mounted) {
                  DialogUtils.showSuccessMessage(
                    context: context,
                    message: 'Verification email sent. Please check your inbox.',
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const EmailVerificationLoadingPage()),
                  );
                }
              } catch (e) {
                if (mounted) {
                  DialogUtils.showWarningMessage(
                    context: context,
                    message: 'Failed to resend verification email: $e',
                  );
                }
              }
            }
          }
          return;
        }
        bool goToSetup = false;
        try {
          final completed = await _authService.isProfileCompleted();
          goToSetup = completed == false;
        } catch (_) {
      
        }
        
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Login successful',
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => goToSetup ? const ProfileSetupFlow() : const HomePage()),
        );
      } else {
        admin_auth.AuthService adminAuthService;
        try {
          adminAuthService = Provider.of<admin_auth.AuthService>(context, listen: false);
        } catch (e) {
          adminAuthService = admin_auth.AuthService();
        }

        final result = await adminAuthService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (!mounted) return;

        if (result.success) {
          DialogUtils.showSuccessMessage(
            context: context,
            message: 'Admin login successful',
          );
          try {
            Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
          } catch (e) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            );
          }
        } else {
          DialogUtils.showWarningMessage(
            context: context,
            message: result.error ?? 'Admin login failed. Please try again.',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.message ?? 'Login failed';
      debugPrint('FirebaseAuthException during login: code=${e.code}, message=$message');
      DialogUtils.showWarningMessage(
        context: context,
        message: message,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected error during login: $e');
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Unexpected error during login: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _loginMode == LoginMode.user
        ? const Color(0xFF00C8A0)
        : const Color(0xFF1E3A5F);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _loginMode == LoginMode.user
                          ? Icons.work_outline
                          : Icons.admin_panel_settings,
                      color: primaryColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loginMode == LoginMode.user
                        ? 'Welcome Back to JobSeek'
                        : 'Admin Login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loginMode == LoginMode.user
                        ? 'Log in to your account to continue\nyour job search request'
                        : 'JobSeek Administration Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: InputValidators.requiredEmail,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: InputValidators.required,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  if (_loginMode == LoginMode.user) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignUpPage()),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(thickness: 1, color: Colors.grey[300]),
                    const SizedBox(height: 16),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.admin_panel_settings, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Are you an administrator?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => const admin_login.LoginPage(),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.admin_panel_settings, size: 18),
                            label: const Text(
                              'Switch to Admin Login',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E3A5F),
                              side: const BorderSide(color: Color(0xFF1E3A5F)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_loginMode == LoginMode.admin) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Only authorized admin users can access this portal',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

