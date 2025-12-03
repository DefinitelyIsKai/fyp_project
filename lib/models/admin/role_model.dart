import 'package:cloud_firestore/cloud_firestore.dart';

class RoleModel {
  final String id;
  final String name;
  final String description;
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isSystemRole;
  final int userCount;

  RoleModel({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    required this.createdAt,
    this.updatedAt,
    this.isSystemRole = false,
    this.userCount = 0,
  });

  factory RoleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoleModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      permissions: List<String>.from(data['permissions'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isSystemRole: data['isSystemRole'] ?? false,
      userCount: data['userCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'permissions': permissions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isSystemRole': isSystemRole,
    };
  }

  RoleModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSystemRole,
    int? userCount,
  }) {
    return RoleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSystemRole: isSystemRole ?? this.isSystemRole,
      userCount: userCount ?? this.userCount,
    );
  }
}
