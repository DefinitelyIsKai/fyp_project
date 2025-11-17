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
      // 1️⃣ Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final uid = userCredential.user!.uid;

      // 2️⃣ Create Firestore user document
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
  Future<bool> login(String email, String password) async {
    try {
      // 1️⃣ Sign in via Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) return false;

      // 2️⃣ Fetch user details from Firestore
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        debugPrint("User document not found in Firestore");
        return false;
      }

      final data = doc.data()!;

      _currentAdmin = AdminModel(
        id: doc.id,
        email: data['email'] ?? '',
        name: data['fullName'] ?? '',
        role: data['role'] ?? 'staff',
        permissions: List<String>.from(data['permissions'] ?? []),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: data['isActive'] ?? true,
      );

      // 3️⃣ Update last login time in Firestore
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      _isAuthenticated = true;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth login error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
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
}
