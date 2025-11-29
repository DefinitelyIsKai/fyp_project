import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fyp_project/models/admin/admin_model.dart';
import 'package:fyp_project/services/admin/role_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RoleService _roleService = RoleService();
  final CollectionReference<Map<String, dynamic>> _logsRef = 
      FirebaseFirestore.instance.collection('logs');

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
  Future<RegisterResult> register(
    String name,
    String email,
    String password, {
    required String role,
    String? originalUserPassword,
    String? location,
    int? age,
    String? phoneNumber,
    String? gender,
    String? imageBase64,
    String? imageFileType,
  }) async {
    // Store the current user's info before creating new user
    final originalUser = _auth.currentUser;
    final originalUserEmail = originalUser?.email;
    final originalAdminId = originalUser?.uid;
    final originalAdminName = _currentAdmin?.name ?? 'Unknown Admin';
    
    
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
        final userData = <String, dynamic>{
          'email': email.trim().toLowerCase(),
          'fullName': name,
          'role': normalizedRole, // Store in lowercase for consistency
          'permissions': permissions,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'status': 'Active',
        };
        
        // Add optional fields if provided
        if (location != null && location.isNotEmpty) {
          userData['location'] = location;
        }
        if (age != null) {
          userData['age'] = age;
        }
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          userData['phoneNumber'] = phoneNumber;
        }
        if (gender != null && gender.isNotEmpty) {
          userData['gender'] = gender;
        }
        if (imageBase64 != null && imageBase64.isNotEmpty && imageFileType != null) {
          userData['image'] = {
            'base64': imageBase64,
            'fileType': imageFileType,
            'uploadedAt': FieldValue.serverTimestamp(),
          };
        }
        
        await _firestore.collection('users').doc(newUserUid).set(userData);
        
        debugPrint('User document created with role: $normalizedRole, permissions: $permissions');
        
        // Create log entry for admin user creation
        // Note: We use the original admin info saved before creating the new user
        // because at this point, the current user is already the newly created user
        try {
          await _logsRef.add({
            'actionType': 'admin_created',
            'newAdminId': newUserUid,
            'newAdminName': name,
            'newAdminEmail': email.trim().toLowerCase(),
            'newAdminRole': normalizedRole,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': originalAdminId,
            'createdByName': originalAdminName,
          });
        } catch (logError) {
          debugPrint('Error creating admin creation log entry: $logError');
          // Don't fail the operation if logging fails
        }
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

      // CRITICAL: Firebase Auth's createUserWithEmailAndPassword automatically signs in the new user
      // We need to sign out the new user and restore the original user's session
      // The key is to ALWAYS sign out the new user, then restore the original user's session
      
      // Check if we're currently logged in as the new user (we should be)
      final currentUserAfterCreation = _auth.currentUser;
      if (currentUserAfterCreation != null && currentUserAfterCreation.uid == newUserUid) {
        // Yes, we're logged in as the new user - MUST sign out
        try {
          await _auth.signOut();
          debugPrint('Signed out newly created user');
        } catch (signOutError) {
          debugPrint('Error signing out new user: $signOutError');
        }
      } else if (currentUserAfterCreation != null) {
        // We're logged in as someone else - this could be the original user
        // But we should still sign out to be safe, then restore
        debugPrint('Warning: Current user is not the newly created user. Current: ${currentUserAfterCreation.email}, New: $email');
        try {
          await _auth.signOut();
          debugPrint('Signed out current user to ensure clean state');
        } catch (signOutError) {
          debugPrint('Error signing out current user: $signOutError');
        }
      }
      
      // Small delay to ensure sign out completes
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Verify we're signed out
      final userAfterSignOut = _auth.currentUser;
      if (userAfterSignOut != null) {
        debugPrint('Warning: Still logged in after signOut. Current user: ${userAfterSignOut.email}');
        // Force sign out again
        try {
          await _auth.signOut();
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          debugPrint('Error in second signOut attempt: $e');
        }
      }
      
      // Now try to restore the original user's session
      if (originalUserEmail != null && originalUserPassword != null && originalUserPassword.isNotEmpty) {
        // Password provided - use it to restore session
        try {
          final loginResult = await login(originalUserEmail, originalUserPassword).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Login timeout during session restoration');
              return LoginResult(success: false, error: 'Session restoration timed out');
            },
          );
          
          if (loginResult.success) {
            debugPrint('Original user session restored: $originalUserEmail');
            await Future.delayed(const Duration(milliseconds: 300));
            
            // Verify we're logged in as the original user
            final restoredUser = _auth.currentUser;
            if (restoredUser != null && restoredUser.email == originalUserEmail) {
              return RegisterResult(
                success: true,
                requiresReauth: false,
                message: 'Admin user "$name" created successfully.',
                originalUserEmail: originalUserEmail,
              );
            } else {
              debugPrint('ERROR: Restored user is not the original user! Current: ${restoredUser?.email}');
              // Force sign out and clear state
              try {
                await _auth.signOut();
              } catch (e) {
                debugPrint('Error signing out wrong user: $e');
              }
              _currentAdmin = null;
              _isAuthenticated = false;
              notifyListeners();
              
              return RegisterResult(
                success: true,
                requiresReauth: true,
                message: 'Admin user "$name" created successfully.\n\nSession restoration failed. Please log in again.',
                originalUserEmail: originalUserEmail,
              );
            }
          } else {
            debugPrint('Failed to restore original user session: ${loginResult.error}');
            _currentAdmin = null;
            _isAuthenticated = false;
            notifyListeners();
            
            return RegisterResult(
              success: true,
              requiresReauth: true,
              message: 'Admin user "$name" created successfully.\n\nSession restoration failed: ${loginResult.error}. Please log in again.',
              originalUserEmail: originalUserEmail,
            );
          }
        } catch (e) {
          debugPrint('Failed to restore original user session: $e');
          _currentAdmin = null;
          _isAuthenticated = false;
          notifyListeners();
          
          return RegisterResult(
            success: true,
            requiresReauth: true,
            message: 'Admin user "$name" created successfully.\n\nSession restoration failed. Please log in again.',
            originalUserEmail: originalUserEmail,
          );
        }
      } else {
        // No password provided - cannot restore session automatically
        // We've already signed out, so we're logged out
        debugPrint('New admin user created: $email (UID: $newUserUid)');
        debugPrint('Original user was: $originalUserEmail');
        debugPrint('No password provided - cannot restore session automatically');
        
        // Verify we're signed out (not logged in as the new user)
        final finalCheck = _auth.currentUser;
        if (finalCheck != null) {
          // Still logged in - this shouldn't happen, but if it does, sign out
          debugPrint('ERROR: Still logged in after signOut! Current user: ${finalCheck.email}');
          if (finalCheck.uid == newUserUid) {
            debugPrint('ERROR: Still logged in as the new user! Force signing out...');
            try {
              await _auth.signOut();
              await Future.delayed(const Duration(milliseconds: 200));
            } catch (e) {
              debugPrint('Error force signing out: $e');
            }
          }
        }
        
        // Clear state since we can't restore
        _currentAdmin = null;
        _isAuthenticated = false;
        notifyListeners();
        
        if (originalUserEmail != null) {
          return RegisterResult(
            success: true,
            requiresReauth: true,
            message: 'Admin user "$name" created successfully.\n\nPlease log in again to continue.',
            originalUserEmail: originalUserEmail,
          );
        }
        
        return RegisterResult(
          success: true,
          requiresReauth: false,
          message: 'Admin user "$name" created successfully.',
        );
      }
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

      // Try to check if the email exists in Firestore and has admin role
      // This may fail due to permissions, so we'll handle it gracefully
      try {
        final querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          final role = (userData['role'] ?? '').toString().toLowerCase();
          final allowedRoles = ['manager', 'hr', 'staff', 'admin'];

          // Check if it's an admin role (case-insensitive)
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
        }
      } catch (firestoreError) {
        // If Firestore query fails due to permissions, log it but continue
        // Firebase Auth will still validate if the email exists
        debugPrint('Could not verify admin status via Firestore (this is expected if security rules restrict access): $firestoreError');
        // Continue to send reset email anyway - Firebase Auth will handle validation
      }

      // Send password reset email via Firebase Auth
      // Firebase Auth will only send if the email exists in Auth system
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
