import 'package:flutter/foundation.dart';
import 'package:fyp_project/models/admin_model.dart';

class AuthService extends ChangeNotifier {
  AdminModel? _currentAdmin;
  bool _isAuthenticated = false;

  // Dummy users for authentication
  final List<Map<String, String>> _dummyUsers = [
    {'email': 'admin@jobseek.com', 'password': '123456'},
    {'email': 'user@jobseek.com', 'password': 'password'},
  ];

  AdminModel? get currentAdmin => _currentAdmin;
  bool get isAuthenticated => _isAuthenticated;

  Future<bool> login(String email, String password) async {
    try {
      // TODO: Implement actual API call
      // For now, simulate login with validation
      await Future.delayed(const Duration(seconds: 1));
      
      // Validate credentials against dummy users
      bool isValid = false;
      for (var user in _dummyUsers) {
        if (user['email'] == email && user['password'] == password) {
          isValid = true;
          break;
        }
      }
      
      if (!isValid) {
        return false;
      }
      
      // Mock admin data
      _currentAdmin = AdminModel(
        id: '1',
        email: email,
        name: 'Admin User',
        role: 'admin',
        permissions: ['all'],
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
      );
      
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      // TODO: Implement actual API call
      await Future.delayed(const Duration(seconds: 1));
      
      _currentAdmin = AdminModel(
        id: '1',
        email: email,
        name: name,
        role: 'admin',
        permissions: ['all'],
        createdAt: DateTime.now(),
        isActive: true,
      );
      
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _currentAdmin = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

