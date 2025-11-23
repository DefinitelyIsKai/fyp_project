import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/role_model.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _rolesCollection = FirebaseFirestore.instance.collection('roles');
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  // Available permissions/modules
  static const List<String> availablePermissions = [
    'all', // Full access
    'post_moderation', // Post Moderation module
    'user_management', // User Management module
    'monitoring', // Monitoring & Search module
    'system_config', // System Configuration module
    'message_oversight', // Message Oversight module
    'analytics', // Analytics & Reporting module
  ];

  // Permission labels for display
  static const Map<String, String> permissionLabels = {
    'all': 'Full Access (All Modules)',
    'post_moderation': 'Post Moderation',
    'user_management': 'User Management',
    'monitoring': 'Monitoring & Search',
    'system_config': 'System Configuration',
    'message_oversight': 'Message Oversight',
    'analytics': 'Analytics & Reporting',
  };

  /// Get all roles
  Future<List<RoleModel>> getAllRoles() async {
    final snapshot = await _rolesCollection.get();
    return snapshot.docs.map((doc) => RoleModel.fromFirestore(doc)).toList();
  }

  /// Stream all roles in real-time
  Stream<List<RoleModel>> streamAllRoles() {
    return _rolesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RoleModel.fromFirestore(doc)).toList();
    });
  }

  /// Get a single role by ID
  Future<RoleModel?> getRoleById(String roleId) async {
    final doc = await _rolesCollection.doc(roleId).get();
    if (doc.exists) {
      return RoleModel.fromFirestore(doc);
    }
    return null;
  }

  /// Get a role by name
  Future<RoleModel?> getRoleByName(String roleName) async {
    final snapshot = await _rolesCollection.where('name', isEqualTo: roleName).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return RoleModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  /// Create a new role
  Future<String> createRole({
    required String name,
    required String description,
    required List<String> permissions,
    bool isSystemRole = false,
  }) async {
    // Normalize role name to lowercase for consistency
    final normalizedName = name.trim().toLowerCase();
    
    // Check if role name already exists
    final existingRole = await getRoleByName(normalizedName);
    if (existingRole != null) {
      throw Exception('Role with name "$name" already exists');
    }

    final roleData = {
      'name': normalizedName, // Store in lowercase
      'description': description,
      'permissions': permissions,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isSystemRole': isSystemRole,
    };

    final docRef = await _rolesCollection.add(roleData);
    return docRef.id;
  }

  /// Update an existing role
  Future<void> updateRole({
    required String roleId,
    String? name,
    String? description,
    List<String>? permissions,
  }) async {
    final role = await getRoleById(roleId);
    if (role == null) {
      throw Exception('Role not found');
    }

    if (role.isSystemRole) {
      throw Exception('Cannot modify system roles');
    }

    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // If name is being changed, check if new name already exists
    if (name != null) {
      final normalizedName = name.trim().toLowerCase();
      if (normalizedName != role.name) {
        final existingRole = await getRoleByName(normalizedName);
        if (existingRole != null) {
          throw Exception('Role with name "$name" already exists');
        }
      }
      updateData['name'] = normalizedName; // Store in lowercase
    }
    if (description != null) updateData['description'] = description;
    if (permissions != null) updateData['permissions'] = permissions;

    await _rolesCollection.doc(roleId).update(updateData);

    // If role name changed, update all users with this role
    if (name != null && name != role.name) {
      await _updateUsersRoleName(role.name, name);
    }

    // If permissions changed, update all users with this role
    if (permissions != null) {
      await _updateUsersPermissions(role.name, permissions);
    }
  }

  /// Delete a role
  Future<void> deleteRole(String roleId) async {
    final role = await getRoleById(roleId);
    if (role == null) {
      throw Exception('Role not found');
    }

    if (role.isSystemRole) {
      throw Exception('Cannot delete system roles');
    }

    // Check if any users have this role (case-insensitive)
    final normalizedRoleName = role.name.toLowerCase();
    final allUsers = await _usersCollection.get();
    final usersWithRole = allUsers.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      final userRole = (data['role'] as String? ?? '').toLowerCase();
      return userRole == normalizedRoleName;
    }).toList();
    if (usersWithRole.isNotEmpty) {
      throw Exception('Cannot delete role. ${usersWithRole.length} user(s) are assigned this role');
    }

    await _rolesCollection.doc(roleId).delete();
  }

  /// Initialize default system roles if they don't exist
  Future<void> initializeSystemRoles() async {
    final systemRoles = [
      {
        'name': 'manager',
        'description': 'Full system access with all permissions',
        'permissions': ['all'],
        'isSystemRole': true,
      },
      {
        'name': 'hr',
        'description': 'Human Resources with access to user, post, analytics, and monitoring modules',
        'permissions': ['post_moderation', 'user_management', 'analytics', 'monitoring'],
        'isSystemRole': true,
      },
      {
        'name': 'staff',
        'description': 'Staff member with limited access to posts and users',
        'permissions': ['post_moderation', 'user_management'],
        'isSystemRole': true,
      },
    ];

    // First, clean up any duplicate roles (case-insensitive check)
    await _cleanupDuplicateRoles();
    
    // Normalize all existing user roles to lowercase
    await _normalizeUserRoles();

    for (final roleData in systemRoles) {
      // Normalize role name to lowercase for consistency
      final roleName = (roleData['name'] as String).toLowerCase();
      
      // Check for existing role (case-insensitive)
      final existingRole = await _getRoleByNameCaseInsensitive(roleName);
      
      if (existingRole == null) {
        // Role doesn't exist, create it
        await _rolesCollection.add({
          ...roleData,
          'name': roleName, // Store in lowercase
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Role exists, update it to ensure it's marked as system role and has correct permissions
        await _rolesCollection.doc(existingRole.id).update({
          'permissions': roleData['permissions'],
          'isSystemRole': true,
          'description': roleData['description'],
          'name': roleName, // Ensure name is lowercase
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Normalize all user roles to lowercase for consistency
  Future<void> _normalizeUserRoles() async {
    final snapshot = await _usersCollection.get();
    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final currentRole = data['role'] as String? ?? '';
      final normalizedRole = currentRole.toLowerCase();
      
      // Only update if role needs normalization
      if (currentRole != normalizedRole && currentRole.isNotEmpty) {
        batch.update(doc.reference, {
          'role': normalizedRole,
        });
        hasUpdates = true;
      }
    }
    
    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Get role by name (case-insensitive check)
  Future<RoleModel?> _getRoleByNameCaseInsensitive(String roleName) async {
    final normalizedName = roleName.toLowerCase();
    final snapshot = await _rolesCollection.get();
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final existingName = (data['name'] as String? ?? '').toLowerCase();
      if (existingName == normalizedName) {
        return RoleModel.fromFirestore(doc);
      }
    }
    return null;
  }

  /// Clean up duplicate roles (keep the first one, delete others)
  Future<void> _cleanupDuplicateRoles() async {
    final snapshot = await _rolesCollection.get();
    final roleMap = <String, List<String>>{}; // normalized name -> list of doc IDs
    
    // Group roles by normalized name
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final roleName = (data['name'] as String? ?? '').toLowerCase();
      if (!roleMap.containsKey(roleName)) {
        roleMap[roleName] = [];
      }
      roleMap[roleName]!.add(doc.id);
    }
    
    // Delete duplicates (keep the first one)
    final batch = _firestore.batch();
    bool hasDeletes = false;
    
    for (final entry in roleMap.entries) {
      if (entry.value.length > 1) {
        // Multiple roles with same name, keep first, delete rest
        for (int i = 1; i < entry.value.length; i++) {
          batch.delete(_rolesCollection.doc(entry.value[i]));
          hasDeletes = true;
        }
      }
    }
    
    if (hasDeletes) {
      await batch.commit();
    }
  }

  /// Get user count for a role (case-insensitive)
  Future<int> getUserCountForRole(String roleName) async {
    final normalizedRoleName = roleName.toLowerCase();
    // Get all users and filter case-insensitively since Firestore queries are case-sensitive
    final snapshot = await _usersCollection.get();
    int count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userRole = (data['role'] as String? ?? '').toLowerCase();
      if (userRole == normalizedRoleName) {
        count++;
      }
    }
    return count;
  }

  /// Update user count for all roles
  Future<void> updateRoleUserCounts() async {
    final roles = await getAllRoles();
    for (final role in roles) {
      final userCount = await getUserCountForRole(role.name);
      await _rolesCollection.doc(role.id).update({
        'userCount': userCount,
      });
    }
  }

  /// Update users' role name when role name changes (case-insensitive)
  Future<void> _updateUsersRoleName(String oldRoleName, String newRoleName) async {
    final batch = _firestore.batch();
    final normalizedOldRole = oldRoleName.toLowerCase();
    final normalizedNewRole = newRoleName.toLowerCase();
    final allUsers = await _usersCollection.get();
    
    for (final doc in allUsers.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final userRole = (data['role'] as String? ?? '').toLowerCase();
      if (userRole == normalizedOldRole) {
        batch.update(doc.reference, {
          'role': normalizedNewRole,
        });
      }
    }
    
    await batch.commit();
  }

  /// Update users' permissions when role permissions change (case-insensitive)
  Future<void> _updateUsersPermissions(String roleName, List<String> permissions) async {
    final batch = _firestore.batch();
    final normalizedRoleName = roleName.toLowerCase();
    final allUsers = await _usersCollection.get();
    
    for (final doc in allUsers.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final userRole = (data['role'] as String? ?? '').toLowerCase();
      if (userRole == normalizedRoleName) {
        batch.update(doc.reference, {
          'permissions': permissions,
        });
      }
    }
    
    await batch.commit();
  }

  /// Assign role to a user
  Future<void> assignRoleToUser(String userId, String roleName) async {
    final role = await getRoleByName(roleName);
    if (role == null) {
      throw Exception('Role not found');
    }

    await _usersCollection.doc(userId).update({
      'role': roleName,
      'permissions': role.permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update role user count
    await updateRoleUserCounts();
  }
}

