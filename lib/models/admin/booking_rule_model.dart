class BookingRuleModel {
  final String id;
  final String name;
  final String description;
  final bool isEnabled;
  final Map<String, dynamic> parameters;
  final DateTime updatedAt;
  final String? updatedBy;

  BookingRuleModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.parameters,
    required this.updatedAt,
    this.updatedBy,
  });

  factory BookingRuleModel.fromJson(Map<String, dynamic> json, String docId) {
    return BookingRuleModel(
      id: docId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isEnabled: json['isEnabled'] ?? true,
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
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
      'parameters': parameters,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }

  BookingRuleModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isEnabled,
    Map<String, dynamic>? parameters,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return BookingRuleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      parameters: parameters ?? this.parameters,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

