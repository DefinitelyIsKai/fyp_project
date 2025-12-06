class MatchingRuleModel {
  final String id;
  final String name;
  final String description;
  final bool isEnabled;
  final double weight; 
  final Map<String, dynamic> parameters;
  final DateTime updatedAt;
  final String? updatedBy;

  MatchingRuleModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.weight,
    required this.parameters,
    required this.updatedAt,
    this.updatedBy,
  });

  factory MatchingRuleModel.fromJson(Map<String, dynamic> json, String docId) {
    return MatchingRuleModel(
      id: docId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isEnabled: json['isEnabled'] ?? true,
      weight: (json['weight'] ?? 0.5).toDouble(),
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
      'weight': weight,
      'parameters': parameters,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }

  MatchingRuleModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isEnabled,
    double? weight,
    Map<String, dynamic>? parameters,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return MatchingRuleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      weight: weight ?? this.weight,
      parameters: parameters ?? this.parameters,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
