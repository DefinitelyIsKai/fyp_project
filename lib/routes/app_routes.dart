import 'package:flutter/material.dart';
import 'package:fyp_project/pages/admin/authentication/login_page.dart' as admin_login;
import 'package:fyp_project/pages/admin/authentication/forgot_password_page.dart' as admin_forgot;
import 'package:fyp_project/pages/admin/dashboard/dashboard_page.dart';
import 'package:fyp_project/pages/user/authentication/login_page.dart' as user_login;

class AppRoutes {
  // User routes
  static const String userLogin = '/user-login';
  
  // Admin routes
  static const String adminLogin = '/admin-login';
  static const String adminForgotPassword = '/admin-forgot-password';
  static const String dashboard = '/dashboard';
  
  // Legacy route (defaults to user login)
  static const String login = '/login';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case userLogin:
      case login: // Default route now points to user login
        return MaterialPageRoute(builder: (_) => const user_login.LoginPage());
      case adminLogin:
        return MaterialPageRoute(builder: (_) => const admin_login.LoginPage());
      case adminForgotPassword:
        return MaterialPageRoute(builder: (_) => const admin_forgot.ForgotPasswordPage());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

