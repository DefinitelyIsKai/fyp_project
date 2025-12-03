import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/role_model.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _rolesCollection = FirebaseFirestore.instance.collection('roles');
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  static const List<String> availablePermissions = [
    'all', 
    'post_moderation', 
    'user_management', 
    'monitoring', 
    'system_config', 
    'message_oversight', 
    'analytics', 
  ];

  static const Map<String, String> permissionLabels = {
    'all': 'Full Access (All Modules)',
    'post_moderation': 'Post Moderation',
    'user_management': 'User Management',
    'monitoring': 'Monitoring & Search',
    'system_config': 'System Configuration',
    'message_oversight': 'Message Oversight',
    'analytics': 'Analytics & Reporting',
  };

  Future<List<RoleModel>> getAllRoles() async {
    final snapshot = await _rolesCollection.get();
    return snapshot.docs.map((doc) => RoleModel.fromFirestore(doc)).toList();
  }

  Stream<List<RoleModel>> streamAllRoles() {
    return _rolesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RoleModel.fromFirestore(doc)).toList();
    });
  }

  Future<RoleModel?> getRoleById(String roleId) async {
    final doc = await _rolesCollection.doc(roleId).get();
    if (doc.exists) {
      return RoleModel.fromFirestore(doc);
    }
    return null;
  }

  Future<RoleModel?> getRoleByName(String roleName) async {
    final snapshot = await _rolesCollection.where('name', isEqualTo: roleName).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return RoleModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  Future<String> createRole({
    required String name,
    required String description,
    required List<String> permissions,
    bool isSystemRole = false,
  }) async {
    
    final normalizedName = name.trim().toLowerCase();
    
    final existingRole = await getRoleByName(normalizedName);
    if (existingRole != null) {
      throw Exception('Role with name "$name" already exists');
    }

    final roleData = {
      'name': normalizedName, 
      'description': description,
      'permissions': permissions,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isSystemRole': isSystemRole,
    };

    final docRef = await _rolesCollection.add(roleData);
    return docRef.id;
  }

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

    if (name != null) {
      final normalizedName = name.trim().toLowerCase();
      if (normalizedName != role.name) {
        final existingRole = await getRoleByName(normalizedName);
        if (existingRole != null) {
          throw Exception('Role with name "$name" already exists');
        }
      }
      updateData['name'] = normalizedName; 
    }
    if (description != null) updateData['description'] = description;
    if (permissions != null) updateData['permissions'] = permissions;

    await _rolesCollection.doc(roleId).update(updateData);

    if (name != null && name != role.name) {
      await _updateUsersRoleName(role.name, name);
    }

    if (permissions != null) {
      await _updateUsersPermissions(role.name, permissions);
    }
  }

  Future<void> deleteRole(String roleId) async {
    final role = await getRoleById(roleId);
    if (role == null) {
      throw Exception('Role not found');
    }

    if (role.isSystemRole) {
      throw Exception('Cannot delete system roles');
    }

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
        'permissions': ['post_moderation', 'user_management', 'analytics', 'monitoring', 'message_oversight'],
        'isSystemRole': true,
      },
      {
        'name': 'staff',
        'description': 'Staff member with limited access to posts and users',
        'permissions': ['post_moderation', 'user_management'],
        'isSystemRole': true,
      },
    ];

    await _cleanupDuplicateRoles();
    
    await _normalizeUserRoles();

    for (final roleData in systemRoles) {
      
      final roleName = (roleData['name'] as String).toLowerCase();
      
      final existingRole = await _getRoleByNameCaseInsensitive(roleName);
      
      if (existingRole == null) {
        
        await _rolesCollection.add({
          ...roleData,
          'name': roleName, 
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        
        await _rolesCollection.doc(existingRole.id).update({
          'permissions': roleData['permissions'],
          'isSystemRole': true,
          'description': roleData['description'],
          'name': roleName, 
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> _normalizeUserRoles() async {
    final snapshot = await _usersCollection.get();
    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final currentRole = data['role'] as String? ?? '';
      final normalizedRole = currentRole.toLowerCase();
      
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

  Future<void> _cleanupDuplicateRoles() async {
    final snapshot = await _rolesCollection.get();
    final roleMap = <String, List<String>>{}; 
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final roleName = (data['name'] as String? ?? '').toLowerCase();
      if (!roleMap.containsKey(roleName)) {
        roleMap[roleName] = [];
      }
      roleMap[roleName]!.add(doc.id);
    }
    
    final batch = _firestore.batch();
    bool hasDeletes = false;
    
    for (final entry in roleMap.entries) {
      if (entry.value.length > 1) {
        
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

  Future<int> getUserCountForRole(String roleName) async {
    final normalizedRoleName = roleName.toLowerCase();
    
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

  Future<void> updateRoleUserCounts() async {
    final roles = await getAllRoles();
    for (final role in roles) {
      final userCount = await getUserCountForRole(role.name);
      await _rolesCollection.doc(role.id).update({
        'userCount': userCount,
      });
    }
  }

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

    await updateRoleUserCounts();
  }
}
