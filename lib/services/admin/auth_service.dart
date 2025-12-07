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
    
    final originalUser = _auth.currentUser;
    final originalUserEmail = originalUser?.email;
    final originalAdminId = originalUser?.uid;
    final originalAdminName = _currentAdmin?.name ?? 'Unknown Admin';
    
    if (originalUserEmail != null && originalUserPassword != null && originalUserPassword.isNotEmpty) {
      try {
        
        final testEmail = originalUserEmail;
        final testPassword = originalUserPassword;
        
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
      
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final newUserUid = userCredential.user!.uid;

      final normalizedRole = role.toLowerCase();
      
      List<String> permissions;
      final systemRoles = ['manager', 'hr', 'staff'];
      if (systemRoles.contains(normalizedRole)) {
        permissions = _getSystemRolePermissions(normalizedRole);
        debugPrint('Using system role permissions for "$normalizedRole": $permissions');
      } else {
        permissions = await _getPermissionsByRole(normalizedRole);
      }
      
      if (permissions.isEmpty) {
        
        final systemRoles = ['manager', 'hr', 'staff'];
        if (systemRoles.contains(normalizedRole)) {
          debugPrint('WARNING: System role "$normalizedRole" not found in roles collection. This should not happen.');
          debugPrint('Please ensure system roles are initialized in the roles collection.');
        } else {
          debugPrint('ERROR: Custom role "$normalizedRole" not found in roles collection.');
          debugPrint('User will be created but login will fail. Please ensure the role exists before creating users.');
        }
        
      } else {
        debugPrint('Successfully fetched ${permissions.length} permissions for role "$normalizedRole": $permissions');
      }

      try {
        final userData = <String, dynamic>{
          'email': email.trim().toLowerCase(),
          'fullName': name,
          'role': normalizedRole, 
          'permissions': permissions,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'status': 'Active',
          'isLogin': false, // New admin user starts with isLogin: false
        };
        
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
          
        }
      } catch (firestoreError) {
        
        debugPrint('Error creating user document in Firestore: $firestoreError');
        try {
          await userCredential.user?.delete();
          debugPrint('Deleted Firebase Auth user due to Firestore creation failure');
        } catch (deleteError) {
          debugPrint('Error deleting Firebase Auth user: $deleteError');
        }
        
        throw firestoreError;
      }

      final currentUserAfterCreation = _auth.currentUser;
      if (currentUserAfterCreation != null && currentUserAfterCreation.uid == newUserUid) {
        
        try {
          await _auth.signOut();
          debugPrint('Signed out newly created user');
        } catch (signOutError) {
          debugPrint('Error signing out new user: $signOutError');
        }
      } else if (currentUserAfterCreation != null) {
        
        debugPrint('Warning: Current user is not the newly created user. Current: ${currentUserAfterCreation.email}, New: $email');
        try {
          await _auth.signOut();
          debugPrint('Signed out current user to ensure clean state');
        } catch (signOutError) {
          debugPrint('Error signing out current user: $signOutError');
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 400));
      
      final userAfterSignOut = _auth.currentUser;
      if (userAfterSignOut != null) {
        debugPrint('Warning: Still logged in after signOut. Current user: ${userAfterSignOut.email}');
        
        try {
          await _auth.signOut();
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          debugPrint('Error in second signOut attempt: $e');
        }
      }
      
      if (originalUserEmail != null && originalUserPassword != null && originalUserPassword.isNotEmpty) {
        
        try {
          final loginResult = await login(originalUserEmail, originalUserPassword, skipIsLoginCheck: true).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Login timeout during session restoration');
              return LoginResult(success: false, error: 'Session restoration timed out');
            },
          );
          
          if (loginResult.success) {
            debugPrint('Original user session restored: $originalUserEmail');
            
            await setLoginStatus(true);
            
            await Future.delayed(const Duration(milliseconds: 300));
            
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
        
        debugPrint('New admin user created: $email (UID: $newUserUid)');
        debugPrint('Original user was: $originalUserEmail');
        debugPrint('No password provided - cannot restore session automatically');
        
        final finalCheck = _auth.currentUser;
        if (finalCheck != null) {
          
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

  Future<LoginResult> login(String email, String password, {bool skipIsLoginCheck = false}) async {
    try {
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        return LoginResult(success: false, error: 'Authentication failed. Please try again.');
      }

      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        await _auth.signOut(); 
        return LoginResult(
          success: false,
          error: 'Admin account not found. Please contact system administrator.',
        );
      }

      final data = doc.data()!;
      
      if (!skipIsLoginCheck) {
        final isLoginValue = data['isLogin'];
        bool isLoggedIn = false;
        if (isLoginValue is bool) {
          isLoggedIn = isLoginValue;
        } else if (isLoginValue == null) {
          isLoggedIn = false;
          debugPrint('Admin login check: isLogin field is null, treating as false');
        } else if (isLoginValue is String) {
          isLoggedIn = isLoginValue.toLowerCase() == 'true';
          debugPrint('Admin login check: isLogin field is string "$isLoginValue", converted to $isLoggedIn');
        }
        
        debugPrint('Admin login check: userId=$uid, isLogin field=$isLoginValue (type: ${isLoginValue.runtimeType}), isLoggedIn=$isLoggedIn');
        
        if (isLoggedIn == true) {
          debugPrint('BLOCKING ADMIN LOGIN: User is already logged in on another device (isLogin=$isLoginValue)');
          await _auth.signOut();
          return LoginResult(
            success: false,
            error: 'This account is already logged in on another device. Please logout from the other device first.',
          );
        }
      } else {
        debugPrint('Admin login: Skipping isLogin check (session restoration)');
      }

      if (data['isActive'] == false) {
        await _auth.signOut();
        return LoginResult(
          success: false,
          error: 'Your account has been deactivated. Please contact system administrator.',
        );
      }

      final role = (data['role'] ?? '').toLowerCase();
      final allowedRoles = ['manager', 'hr', 'staff'];
      
      debugPrint('Login validation - Role: "$role", Stored permissions: ${data['permissions']}');
      
      bool isAdminRole = allowedRoles.contains(role);
      
      if (!isAdminRole) {
        final storedPermissions = List<String>.from(data['permissions'] ?? []);
        debugPrint('Not a system role. Checking stored permissions: $storedPermissions');
        
        isAdminRole = storedPermissions.contains('all') || 
                     storedPermissions.any((p) => ['user_management', 'post_moderation', 'analytics', 'monitoring'].contains(p));
        
        debugPrint('Admin role check from stored permissions: $isAdminRole');
        
        if (!isAdminRole) {
          debugPrint('No admin permissions in stored data. Checking role definition in Firestore...');
          try {
            
            var roleDoc = await _firestore.collection('roles').where('name', isEqualTo: role).limit(1).get();
            debugPrint('Role query (exact match) result: ${roleDoc.docs.length} documents found for role "$role"');
            
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
            
            final docToUse = matchedDoc ?? (roleDoc.docs.isNotEmpty ? roleDoc.docs.first : null);
            
            if (docToUse != null) {
              final roleData = docToUse.data() as Map<String, dynamic>;
              final rolePermissions = List<String>.from(roleData['permissions'] ?? []);
              debugPrint('Role permissions from Firestore: $rolePermissions');
              
              isAdminRole = rolePermissions.contains('all') || 
                           rolePermissions.any((p) => ['user_management', 'post_moderation', 'analytics', 'monitoring'].contains(p));
              
              debugPrint('Admin role check from role definition: $isAdminRole');
              
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

      List<String> permissions;
      final normalizedRole = role.toLowerCase();
      final systemRoles = ['manager', 'hr', 'staff'];
      if (systemRoles.contains(normalizedRole)) {
        permissions = _getSystemRolePermissions(normalizedRole);
        debugPrint('Login: Using system role permissions for "$normalizedRole": $permissions');
      } else {
        permissions = await _getPermissionsByRole(normalizedRole);
      }
      
      final currentPermissions = List<String>.from(data['permissions'] ?? []);
      if (!_listsEqual(permissions, currentPermissions)) {
        await _firestore.collection('users').doc(uid).update({
          'permissions': permissions,
        });
        debugPrint('Login: Updated permissions from $currentPermissions to $permissions');
      }

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

// Check profileCompleted before setting login to true
      final profileCompleted = data['profileCompleted'];
      bool isProfileCompleted = false;
      if (profileCompleted is bool) {
        isProfileCompleted = profileCompleted;
      } else if (profileCompleted is String) {
        isProfileCompleted = profileCompleted.toLowerCase() == 'true';
      }

      final updateData = <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      if (isProfileCompleted) {
        updateData['login'] = true; 
      }

      await _firestore.collection('users').doc(uid).update(updateData);
      if (isProfileCompleted) {
        debugPrint('Admin login: Successfully set login=true for userId=$uid (profileCompleted=true)');
      } else {
        debugPrint('Admin login: NOT set login=true for userId=$uid (profileCompleted=$profileCompleted)');
      }

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

  Future<void> logout() async {
    try {
      final userId = _auth.currentUser?.uid;
      debugPrint('Admin logout: userId=$userId');
      
      if (userId != null && userId.isNotEmpty) {
        try {
          await _firestore.collection('users').doc(userId).update({
            'isLogin': false, // Set isLogin status to false on logout
          });
          debugPrint('Admin logout: Successfully set isLogin=false for userId=$userId');
        } catch (e) {
          debugPrint('Error updating isLogin status during admin logout: $e');
        }
      } else {
        debugPrint('Admin logout: No userId found, skipping isLogin status update');
      }
      
      _currentAdmin = null;
      _isAuthenticated = false;
      notifyListeners();
      
      await _auth.signOut().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Logout timeout - forcing state clear');
        },
      );
      
      _currentAdmin = null;
      _isAuthenticated = false;
      notifyListeners();
      
      debugPrint('Admin logout: Firebase Auth signOut completed');
    } catch (e) {
      debugPrint('Error during admin logout: $e');
      
      _currentAdmin = null;
      _isAuthenticated = false;
      notifyListeners();
      
    }
  }

  Future<PasswordResetResult> resetPassword(String email) async {
    try {
      
      final normalizedEmail = email.trim().toLowerCase();

      try {
        final querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          final role = (userData['role'] ?? '').toString().toLowerCase();
          final allowedRoles = ['manager', 'hr', 'staff'];

          if (!allowedRoles.contains(role)) {
            return PasswordResetResult(
              success: false,
              error: 'This email is not associated with an admin account.',
            );
          }

          if (userData['isActive'] == false) {
            return PasswordResetResult(
              success: false,
              error: 'This account has been deactivated. Please contact system administrator.',
            );
          }
        }
      } catch (firestoreError) {
        
        debugPrint('Could not verify admin status via Firestore (this is expected if security rules restrict access): $firestoreError');
        
      }

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

  List<String> _getSystemRolePermissions(String role) {
    final normalizedRole = role.toLowerCase();
    switch (normalizedRole) {
      case 'manager':
        return ['all'];
      case 'hr':
        return ['post_moderation', 'user_management', 'analytics', 'monitoring', 'message_oversight', 'report_management'];
      case 'staff':
        return ['post_moderation', 'user_management', 'message_oversight'];
      default:
        return [];
    }
  }

  Future<List<String>> _getPermissionsByRole(String? role) async {
    if (role == null || role.isEmpty) {
      debugPrint('_getPermissionsByRole: Role is null or empty');
      return [];
    }

    try {
      
      final normalizedRole = role.toLowerCase();
      debugPrint('_getPermissionsByRole: Fetching permissions for role "$normalizedRole"');
      
      final roleModel = await _roleService.getRoleByName(normalizedRole);
      if (roleModel != null) {
        debugPrint('_getPermissionsByRole: Found role "$normalizedRole" with permissions: ${roleModel.permissions}');
        return roleModel.permissions;
      }
      
      debugPrint('WARNING: Role "$normalizedRole" not found in Firestore. Returning empty permissions.');
      debugPrint('This will cause login to fail for users with this role. Please ensure the role exists in the roles collection.');
      return [];
    } catch (e) {
      debugPrint('Error fetching permissions for role "$role": $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

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

  Future<void> setLoginStatus(bool isLoggedIn) async {
    final userId = _auth.currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'isLogin': isLoggedIn,
          if (isLoggedIn) 'lastLoginAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Admin setLoginStatus: Successfully set isLogin=$isLoggedIn for userId=$userId');
      } catch (e) {
        debugPrint('Error updating isLogin status: $e');
      }
    } else {
      debugPrint('Admin setLoginStatus: No userId found, skipping isLogin status update');
    }
  }

  Future<void> refreshPermissions() async {
    final user = _auth.currentUser;
    if (user != null && _currentAdmin != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final role = data['role'] ?? 'staff';
          final normalizedRole = role.toLowerCase();
          
          List<String> permissions;
          final systemRoles = ['manager', 'hr', 'staff'];
          if (systemRoles.contains(normalizedRole)) {
            permissions = _getSystemRolePermissions(normalizedRole);
            debugPrint('refreshPermissions: Using system role permissions for "$normalizedRole": $permissions');
          } else {
            permissions = await _getPermissionsByRole(normalizedRole);
          }
          
          final currentPermissions = List<String>.from(data['permissions'] ?? []);
          if (!_listsEqual(permissions, currentPermissions)) {
            await _firestore.collection('users').doc(user.uid).update({
              'permissions': permissions,
            });
            debugPrint('refreshPermissions: Updated permissions from $currentPermissions to $permissions');
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
          notifyListeners();
          debugPrint('refreshPermissions: Permissions refreshed - Role: $role, Permissions: $permissions');
        }
      } catch (e) {
        debugPrint('Error refreshing permissions: $e');
      }
    }
  }

  Future<void> checkAuthState() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data['isActive'] == true) {
            final role = data['role'] ?? 'staff';
            final normalizedRole = role.toLowerCase();
            
            List<String> permissions;
            final systemRoles = ['manager', 'hr', 'staff'];
            if (systemRoles.contains(normalizedRole)) {
              permissions = _getSystemRolePermissions(normalizedRole);
              debugPrint('checkAuthState: Using system role permissions for "$normalizedRole": $permissions');
            } else {
              permissions = await _getPermissionsByRole(normalizedRole);
            }
            
            final currentPermissions = List<String>.from(data['permissions'] ?? []);
            if (!_listsEqual(permissions, currentPermissions)) {
              await _firestore.collection('users').doc(user.uid).update({
                'permissions': permissions,
              });
              debugPrint('checkAuthState: Updated permissions from $currentPermissions to $permissions');
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
            debugPrint('checkAuthState: Admin loaded - Role: $role, Permissions: $permissions');
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

class LoginResult {
  final bool success;
  final String? error;

  LoginResult({required this.success, this.error});
}

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

class RegisterResult {
  final bool success;
  final bool requiresReauth; 
  final String? error;
  final String? message;
  final String? originalUserEmail; 

  RegisterResult({
    required this.success,
    required this.requiresReauth,
    this.error,
    this.message,
    this.originalUserEmail,
  });
}
