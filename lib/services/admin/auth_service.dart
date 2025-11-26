import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fyp_project/models/admin/admin_model.dart';
import 'package:fyp_project/services/admin/role_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RoleService _roleService = RoleService();

  AdminModel? _currentAdmin;
  bool _isAuthenticated = false;

  AdminModel? get currentAdmin => _currentAdmin;
  bool get isAuthenticated => _isAuthenticated;

  /// --------------------
  /// Register User (for creating new admin users)
  /// IMPORTANT: This method creates a new user but does NOT automatically log them in.
  /// However, Firebase Auth's createUserWithEmailAndPassword automatically signs in
  /// the newly created user, so we immediately sign them out and restore the original user's session.
  /// 
  /// If originalUserPassword is provided, the original user's session will be restored.
  /// If not provided, the user will need to log in again.
  /// --------------------
  Future<RegisterResult> register(String name, String email, String password, {required String role, String? originalUserPassword}) async{
    // Store the current user's info before creating new user
    final originalUser = _auth.currentUser;
    final originalUserEmail = originalUser?.email;
    
    // CRITICAL: Validate original user password BEFORE creating new user
    // This prevents creating a user if password is wrong
    if (originalUserEmail != null && originalUserPassword != null && originalUserPassword.isNotEmpty) {
      try {
        // Test the password by trying to sign in
        // We'll sign out first, test the password, then sign back in
        final testEmail = originalUserEmail;
        final testPassword = originalUserPassword;
        
        // Create a temporary auth instance to test password without affecting current session
        // Actually, we need to test with the current user - let's use reauthenticate
        try {
          final credential = EmailAuthProvider.credential(
            email: testEmail,
            password: testPassword,
          );
          await originalUser!.reauthenticateWithCredential(credential);
          debugPrint('Password validation successful');
        } catch (e) {
          debugPrint('Password validation failed: $e');
          return RegisterResult(
            success: false,
            requiresReauth: false,
            error: 'Your current password is incorrect. Please enter the correct password to create a new admin user.',
          );
        }
      } catch (e) {
        debugPrint('Error validating password: $e');
        return RegisterResult(
          success: false,
          requiresReauth: false,
          error: 'Failed to validate your password. Please try again.',
        );
      }
    }
    
    try {
      // Create the new user (this will automatically sign them in)
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final newUserUid = userCredential.user!.uid;

      // Fetch permissions from Firestore role (use lowercase for consistency)
      final normalizedRole = role.toLowerCase();
      final permissions = await _getPermissionsByRole(normalizedRole);
      
      // Validate that permissions were found - this is critical for login to work
      if (permissions.isEmpty) {
        // Check if it's a system role that should have default permissions
        final systemRoles = ['manager', 'hr', 'staff', 'admin'];
        if (systemRoles.contains(normalizedRole)) {
          debugPrint('WARNING: System role "$normalizedRole" not found in roles collection. This should not happen.');
          debugPrint('Please ensure system roles are initialized in the roles collection.');
        } else {
          debugPrint('ERROR: Custom role "$normalizedRole" not found in roles collection.');
          debugPrint('User will be created but login will fail. Please ensure the role exists before creating users.');
        }
        // Don't fail creation here - let login validation handle it with better error message
      } else {
        debugPrint('Successfully fetched ${permissions.length} permissions for role "$normalizedRole": $permissions');
      }

      // Create user document in Firestore
      // Store role in lowercase for consistency
      try {
        await _firestore.collection('users').doc(newUserUid).set({
          'email': email.trim().toLowerCase(),
          'fullName': name,
          'role': normalizedRole, // Store in lowercase for consistency
          'permissions': permissions,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'status': 'Active',
        });
        
        debugPrint('User document created with role: $normalizedRole, permissions: $permissions');
      } catch (firestoreError) {
        // If Firestore creation fails, delete the Firebase Auth user to prevent orphaned accounts
        debugPrint('Error creating user document in Firestore: $firestoreError');
        try {
          await userCredential.user?.delete();
          debugPrint('Deleted Firebase Auth user due to Firestore creation failure');
        } catch (deleteError) {
          debugPrint('Error deleting Firebase Auth user: $deleteError');
        }
        
        // Re-throw to be caught by outer catch block
        throw firestoreError;
      }

      // Sign out the newly created user immediately
      // (since createUserWithEmailAndPassword automatically signed them in)
      try {
        await _auth.signOut();
      } catch (signOutError) {
        debugPrint('Error signing out new user: $signOutError');
        // Continue anyway - we'll try to restore session
      }
      
      // Clear state before restoring session to prevent listener issues
      _currentAdmin = null;
      _isAuthenticated = false;
      notifyListeners();
      
      // Small delay to ensure sign out completes
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Try to restore the original user's session if password is provided
      // Password was already validated above, so this should succeed
      if (originalUserEmail != null && originalUserPassword != null && originalUserPassword.isNotEmpty) {
        try {
          // Sign back in as the original user using the login method
          // This will properly restore the admin state
          final loginResult = await login(originalUserEmail, originalUserPassword).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Login timeout during session restoration');
              return LoginResult(success: false, error: 'Session restoration timed out');
            },
          );
          
          if (loginResult.success) {
            debugPrint('Original user session restored: $originalUserEmail');
            
            // Small delay to ensure session is fully established
            await Future.delayed(const Duration(milliseconds: 300));
            
            return RegisterResult(
              success: true,
              requiresReauth: false,
              message: 'Admin user "$name" created successfully.',
              originalUserEmail: originalUserEmail,
            );
          } else {
            debugPrint('Failed to restore original user session: ${loginResult.error}');
            // This shouldn't happen since we validated the password, but handle it gracefully
            // State is already cleared above
            
            return RegisterResult(
              success: true,
              requiresReauth: true,
              message: 'Admin user "$name" created successfully.\n\nSession restoration failed: ${loginResult.error}. Please log in again.',
              originalUserEmail: originalUserEmail,
            );
          }
        } catch (e) {
          debugPrint('Failed to restore original user session: $e');
          // State is already cleared above
          
          return RegisterResult(
            success: true,
            requiresReauth: true,
            message: 'Admin user "$name" created successfully.\n\nSession restoration failed. Please log in again.',
            originalUserEmail: originalUserEmail,
          );
        }
      }
      
      // If we couldn't restore the session, clear the admin state
      _currentAdmin = null;
      _isAuthenticated = false;
      notifyListeners();
      
      debugPrint('New admin user created: $email (UID: $newUserUid)');
      debugPrint('Original user was: $originalUserEmail');
      debugPrint('Note: Current session has been signed out. User needs to log in again.');
      
      return RegisterResult(
        success: true,
        requiresReauth: true,
        message: 'Admin user "$name" created successfully.\n\nYou have been signed out. Please log in again to continue.',
        originalUserEmail: originalUserEmail,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth register error: ${e.code}');
      String errorMessage = 'Failed to create admin user.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address.';
      }
      return RegisterResult(
        success: false,
        requiresReauth: false,
        error: errorMessage,
      );
    } catch (e) {
      debugPrint('Registration error: $e');
      return RegisterResult(
        success: false,
        requiresReauth: false,
        error: 'An error occurred while creating the admin user.',
      );
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
      final role = (data['role'] ?? '').toLowerCase();
      final allowedRoles = ['manager', 'hr', 'staff', 'admin'];
      
      debugPrint('Login validation - Role: "$role", Stored permissions: ${data['permissions']}');
      
      // Check if it's a system admin role
      bool isAdminRole = allowedRoles.contains(role);
      
      // If not a system role, check stored permissions first (faster and doesn't require roles collection access)
      if (!isAdminRole) {
        final storedPermissions = List<String>.from(data['permissions'] ?? []);
        debugPrint('Not a system role. Checking stored permissions: $storedPermissions');
        
        // Check if user has any admin permissions stored
        isAdminRole = storedPermissions.contains('all') || 
                     storedPermissions.any((p) => ['user_management', 'post_moderation', 'analytics', 'monitoring', 'role_management'].contains(p));
        
        debugPrint('Admin role check from stored permissions: $isAdminRole');
        
        // If no admin permissions found in stored data, try to check the role definition
        // This is a fallback for cases where permissions might not be stored yet
        if (!isAdminRole) {
          debugPrint('No admin permissions in stored data. Checking role definition in Firestore...');
          try {
            // Try exact match first
            var roleDoc = await _firestore.collection('roles').where('name', isEqualTo: role).limit(1).get();
            debugPrint('Role query (exact match) result: ${roleDoc.docs.length} documents found for role "$role"');
            
            // If not found, try to get all roles and find a case-insensitive match
            DocumentSnapshot? matchedDoc;
            if (roleDoc.docs.isEmpty) {
              debugPrint('Role not found with exact match. Trying to find case-insensitive match...');
              final allRoles = await _firestore.collection('roles').get();
              debugPrint('Total roles in collection: ${allRoles.docs.length}');
              
              for (var doc in allRoles.docs) {
                final roleData = doc.data();
                final roleName = (roleData['name'] ?? '').toString().toLowerCase();
                debugPrint('  - Found role: "$roleName" (original: "${roleData['name']}")');
                if (roleName == role) {
                  debugPrint('  ✓ Matched role "$role" with document "${doc.id}"');
                  matchedDoc = doc;
                  break;
                }
              }
            }
            
            // Use matchedDoc if found, otherwise use first doc from roleDoc
            final docToUse = matchedDoc ?? (roleDoc.docs.isNotEmpty ? roleDoc.docs.first : null);
            
            if (docToUse != null) {
              final roleData = docToUse.data() as Map<String, dynamic>;
              final rolePermissions = List<String>.from(roleData['permissions'] ?? []);
              debugPrint('Role permissions from Firestore: $rolePermissions');
              
              // Check if role has any admin permissions
              isAdminRole = rolePermissions.contains('all') || 
                           rolePermissions.any((p) => ['user_management', 'post_moderation', 'analytics', 'monitoring', 'role_management'].contains(p));
              
              debugPrint('Admin role check from role definition: $isAdminRole');
              
              // If role has admin permissions but user doesn't have them stored, update the user document
              if (isAdminRole && storedPermissions.isEmpty) {
                debugPrint('Updating user permissions from role definition...');
                await _firestore.collection('users').doc(uid).update({
                  'permissions': rolePermissions,
                });
                debugPrint('User permissions updated successfully');
              }
            } else {
              debugPrint('ERROR: Role "$role" not found in roles collection.');
              debugPrint('Available roles in collection:');
              final allRoles = await _firestore.collection('roles').get();
              for (var doc in allRoles.docs) {
                final roleData = doc.data();
                debugPrint('  - ${roleData['name']} (permissions: ${roleData['permissions']})');
              }
            }
          } catch (e) {
            debugPrint('Error checking custom role: $e');
            debugPrint('Stack trace: ${StackTrace.current}');
            // If we can't check the role, deny access to be safe
            isAdminRole = false;
          }
        }
      }
      
      debugPrint('Final admin role validation result: $isAdminRole');
      
      if (!isAdminRole) {
        await _auth.signOut();
        return LoginResult(
          success: false,
          error: 'Access denied. Admin access required. Role "$role" does not have admin permissions.',
        );
      }

      // 5️⃣ Fetch fresh permissions from role (in case role permissions were updated)
      final permissions = await _getPermissionsByRole(role.toLowerCase());
      
      // Update user permissions in Firestore if they differ from role
      final currentPermissions = List<String>.from(data['permissions'] ?? []);
      if (!_listsEqual(permissions, currentPermissions)) {
        await _firestore.collection('users').doc(uid).update({
          'permissions': permissions,
        });
      }

      // 6️⃣ Set current admin
      _currentAdmin = AdminModel(
        id: doc.id,
        email: data['email'] ?? '',
        name: data['fullName'] ?? '',
        role: role,
        permissions: permissions,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
      );

      // 7️⃣ Update last login time in Firestore
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
    try {
      // Clear admin state first to prevent any UI updates during logout
      _currentAdmin = null;
      _isAuthenticated = false;
      notifyListeners();
      
      // Sign out from Firebase Auth with timeout to prevent ANR
      await _auth.signOut().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Logout timeout - forcing state clear');
        },
      );
      
      // Ensure state is cleared even if signOut fails
      _currentAdmin = null;
      _isAuthenticated = false;
      notifyListeners();
      
      debugPrint('Logout completed successfully');
    } catch (e) {
      debugPrint('Error during logout: $e');
      // Even if there's an error, clear the local state
      _currentAdmin = null;
      _isAuthenticated = false;
      notifyListeners();
      // Don't rethrow - we've cleared state, that's what matters
    }
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
  /// Fetch permissions from Firestore role definition
  /// Falls back to empty list if role not found
  Future<List<String>> _getPermissionsByRole(String? role) async {
    if (role == null || role.isEmpty) {
      debugPrint('_getPermissionsByRole: Role is null or empty');
      return [];
    }

    try {
      // Normalize role name to lowercase for consistency
      final normalizedRole = role.toLowerCase();
      debugPrint('_getPermissionsByRole: Fetching permissions for role "$normalizedRole"');
      
      final roleModel = await _roleService.getRoleByName(normalizedRole);
      if (roleModel != null) {
        debugPrint('_getPermissionsByRole: Found role "$normalizedRole" with permissions: ${roleModel.permissions}');
        return roleModel.permissions;
      }
      
      // If role not found in Firestore, return empty list
      debugPrint('WARNING: Role "$normalizedRole" not found in Firestore. Returning empty permissions.');
      debugPrint('This will cause login to fail for users with this role. Please ensure the role exists in the roles collection.');
      return [];
    } catch (e) {
      debugPrint('Error fetching permissions for role "$role": $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Helper method to compare two lists
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    final sorted1 = List<String>.from(list1)..sort();
    final sorted2 = List<String>.from(list2)..sort();
    return sorted1.toString() == sorted2.toString();
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
            final role = data['role'] ?? 'staff';
            
            // Fetch fresh permissions from role (in case role permissions were updated)
            final permissions = await _getPermissionsByRole(role.toLowerCase());
            
            // Update user permissions in Firestore if they differ from role
            final currentPermissions = List<String>.from(data['permissions'] ?? []);
            if (!_listsEqual(permissions, currentPermissions)) {
              await _firestore.collection('users').doc(user.uid).update({
                'permissions': permissions,
              });
            }
            
            _currentAdmin = AdminModel(
              id: doc.id,
              email: data['email'] ?? '',
              name: data['fullName'] ?? '',
              role: role,
              permissions: permissions,
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

/// Register result class
class RegisterResult {
  final bool success;
  final bool requiresReauth; // Whether the user needs to log in again
  final String? error;
  final String? message;
  final String? originalUserEmail; // Email of the user who was logged in before creating the new admin

  RegisterResult({
    required this.success,
    required this.requiresReauth,
    this.error,
    this.message,
    this.originalUserEmail,
  });
}
