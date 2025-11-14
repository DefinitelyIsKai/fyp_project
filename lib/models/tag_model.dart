class TagModel {
  final String id;
  final String name;
  final String? category;
  final bool isActive;
  final int usageCount;
  final DateTime createdAt;

  TagModel({
    required this.id,
    required this.name,
    this.category,
    this.isActive = true,
    this.usageCount = 0,
    required this.createdAt,
  });

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      usageCount: json['usageCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'isActive': isActive,
      'usageCount': usageCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

