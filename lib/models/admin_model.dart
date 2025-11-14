class AdminModel {
  final String id;
  final String email;
  final String name;
  final String role; // 'super_admin', 'admin', 'moderator'
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  AdminModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.permissions,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      permissions: List<String>.from(json['permissions'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'permissions': permissions,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
    };
  }
}

