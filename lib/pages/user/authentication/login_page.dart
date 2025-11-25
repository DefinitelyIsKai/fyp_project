import 'package:flutter/material.dart';
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
        // User login flow
        final credential = await _authService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        // Block access if email not verified
        await credential.user?.reload();
        if (!(credential.user?.emailVerified ?? false)) {
          DialogUtils.showWarningMessage(
            context: context,
            message: 'Please verify your email before logging in.',
          );
          return;
        }
        // Decide destination based on profileCompleted; default to home if unknown
        bool goToSetup = false;
        try {
          final completed = await _authService.isProfileCompleted();
          goToSetup = completed == false;
        } catch (_) {
          // If we cannot determine, prefer not to block the user
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
        // Admin login flow
        admin_auth.AuthService adminAuthService;
        try {
          // Try to get from Provider first (if available in widget tree)
          adminAuthService = Provider.of<admin_auth.AuthService>(context, listen: false);
        } catch (e) {
          // If Provider is not available, create a new instance
          // Note: This instance won't be available to other widgets via Provider
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
          // Navigate to admin dashboard
          // Try named route first, fallback to direct navigation
          try {
            Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
          } catch (e) {
            // If named route doesn't work, navigate directly
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
      final message = e.message ?? 'Login failed';
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: message,
      );
    } catch (e) {
      if (!mounted) return;
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

    return Scaffold(
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
                  // Logo
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
                  // Email Field
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
                  // Password Field
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
                  // Login Button
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
                  // Only show sign up link for user mode
                  if (_loginMode == LoginMode.user) ...[
                    const SizedBox(height: 24),
                    // Sign Up Link
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
                    // Switch to Admin Login
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
                  // Admin info message
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
    );
  }
}

