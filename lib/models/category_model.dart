class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final bool isActive;
  final int jobCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.isActive = true,
    this.jobCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      jobCount: json['jobCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'isActive': isActive,
      'jobCount': jobCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

