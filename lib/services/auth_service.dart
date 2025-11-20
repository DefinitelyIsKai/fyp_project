import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fyp_project/models/admin_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdminModel? _currentAdmin;
  bool _isAuthenticated = false;

  AdminModel? get currentAdmin => _currentAdmin;
  bool get isAuthenticated => _isAuthenticated;

  /// --------------------
  /// Register User
  /// --------------------
Future<bool> register(String name, String email, String password, {required String role}) async{
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final uid = userCredential.user!.uid;

        await _firestore.collection('users').doc(uid).set({
        'email': email.trim().toLowerCase(),
        'fullName': name,
        'role': role,
        'permissions': _getPermissionsByRole(role),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // 3️⃣ Set current admin
      _currentAdmin = AdminModel(
        id: uid,
        email: email,
        name: name,
        role: role,
        permissions: _getPermissionsByRole(role),
        createdAt: DateTime.now(),
        isActive: true,
        lastLoginAt: DateTime.now(),
      );

      _isAuthenticated = true;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth register error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  /// --------------------
  /// Login User
  /// --------------------
  Future<LoginResult> login(String email, String password) async {
    try {
      // 1️⃣ Sign in via Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        return LoginResult(success: false, error: 'Authentication failed. Please try again.');
      }

      // 2️⃣ Fetch user details from Firestore
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        await _auth.signOut(); // Sign out if user doc doesn't exist
        return LoginResult(
          success: false,
          error: 'Admin account not found. Please contact system administrator.',
        );
      }

      final data = doc.data()!;

      // 3️⃣ Check if user is active
      if (data['isActive'] == false) {
        await _auth.signOut();
        return LoginResult(
          success: false,
          error: 'Your account has been deactivated. Please contact system administrator.',
        );
      }

      // 4️⃣ Validate role (only admin roles allowed)
      final role = data['role'] ?? '';
      final allowedRoles = ['manager', 'HR', 'staff', 'admin'];
      if (!allowedRoles.contains(role)) {
        await _auth.signOut();
        return LoginResult(
          success: false,
          error: 'Access denied. Admin access required.',
        );
      }

      // 5️⃣ Set current admin
      _currentAdmin = AdminModel(
        id: doc.id,
        email: data['email'] ?? '',
        name: data['fullName'] ?? '',
        role: role,
        permissions: List<String>.from(data['permissions'] ?? []),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
      );

      // 6️⃣ Update last login time in Firestore
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      _isAuthenticated = true;
      notifyListeners();
      return LoginResult(success: true);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed. Please check your credentials.';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
      }
      debugPrint('FirebaseAuth login error: ${e.code}');
      return LoginResult(success: false, error: errorMessage);
    } catch (e) {
      debugPrint('Login error: $e');
      return LoginResult(
        success: false,
        error: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// --------------------
  /// Logout
  /// --------------------
  Future<void> logout() async {
    await _auth.signOut();
    _currentAdmin = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// --------------------
  /// Reset Password
  /// --------------------
  Future<PasswordResetResult> resetPassword(String email) async {
    try {
      // Normalize email
      final normalizedEmail = email.trim().toLowerCase();

      // Check if the email exists in Firestore and has admin role
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return PasswordResetResult(
          success: false,
          error: 'No admin account found with this email address.',
        );
      }

      final userData = querySnapshot.docs.first.data();
      final role = userData['role'] ?? '';
      final allowedRoles = ['manager', 'HR', 'staff', 'admin'];

      if (!allowedRoles.contains(role)) {
        return PasswordResetResult(
          success: false,
          error: 'This email is not associated with an admin account.',
        );
      }

      // Check if account is active
      if (userData['isActive'] == false) {
        return PasswordResetResult(
          success: false,
          error: 'This account has been deactivated. Please contact system administrator.',
        );
      }

      // Send password reset email via Firebase Auth
      await _auth.sendPasswordResetEmail(email: normalizedEmail);

      return PasswordResetResult(
        success: true,
        message: 'Password reset email sent! Please check your inbox and follow the instructions to reset your password.',
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send password reset email. Please try again.';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
      }
      debugPrint('FirebaseAuth reset password error: ${e.code}');
      return PasswordResetResult(success: false, error: errorMessage);
    } catch (e) {
      debugPrint('Reset password error: $e');
      return PasswordResetResult(
        success: false,
        error: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// --------------------
  /// Permissions
  /// --------------------
  List<String> _getPermissionsByRole(String? role) {
    switch (role) {
      case 'manager':
        return ['all'];
      case 'HR':
        return ['post', 'user', 'analytics', 'messages'];
      case 'staff':
        return ['post', 'user'];
      default:
        return [];
    }
  }

  bool get isManager => _currentAdmin?.role == 'manager';
  bool get isHR => _currentAdmin?.role == 'HR';
  bool get isStaff => _currentAdmin?.role == 'staff';

  bool canAccess(String feature) {
    if (_currentAdmin == null) return false;
    if (_currentAdmin!.permissions.contains('all')) return true;
    return _currentAdmin!.permissions.contains(feature);
  }

  /// Check if user is authenticated and has valid admin role
  Future<void> checkAuthState() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data['isActive'] == true) {
            _currentAdmin = AdminModel(
              id: doc.id,
              email: data['email'] ?? '',
              name: data['fullName'] ?? '',
              role: data['role'] ?? 'staff',
              permissions: List<String>.from(data['permissions'] ?? []),
              createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
              isActive: true,
            );
            _isAuthenticated = true;
            notifyListeners();
          } else {
            await logout();
          }
        } else {
          await logout();
        }
      } catch (e) {
        debugPrint('Error checking auth state: $e');
        await logout();
      }
    }
  }
}

/// Login result class for better error handling
class LoginResult {
  final bool success;
  final String? error;

  LoginResult({required this.success, this.error});
}

/// Password reset result class
class PasswordResetResult {
  final bool success;
  final String? error;
  final String? message;

  PasswordResetResult({
    required this.success,
    this.error,
    this.message,
  });
}
