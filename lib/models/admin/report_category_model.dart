class ReportCategoryModel {
  final String id;
  final String name;
  final String description;
  final bool isEnabled;
  final int creditDeduction;
  final DateTime updatedAt;
  final String? updatedBy;

  ReportCategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.creditDeduction,
    required this.updatedAt,
    this.updatedBy,
  });

  factory ReportCategoryModel.fromJson(Map<String, dynamic> json, String docId) {
    return ReportCategoryModel(
      id: docId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isEnabled: json['isEnabled'] ?? true,
      creditDeduction: (json['creditDeduction'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as dynamic).toDate()
          : DateTime.now(),
      updatedBy: json['updatedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'isEnabled': isEnabled,
      'creditDeduction': creditDeduction,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }

  ReportCategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isEnabled,
    int? creditDeduction,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return ReportCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      creditDeduction: creditDeduction ?? this.creditDeduction,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

