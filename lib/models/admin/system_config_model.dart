class SystemConfigModel {
  final String id;
  final String key;
  final dynamic value;
  final String? description;
  final String? dataType;
  final DateTime updatedAt;
  final String? updatedBy;

  SystemConfigModel({
    required this.id,
    required this.key,
    required this.value,
    this.description,
    this.dataType,
    required this.updatedAt,
    this.updatedBy,
  });

  factory SystemConfigModel.fromJson(Map<String, dynamic> json) {
    return SystemConfigModel(
      id: json['id'] as String,
      key: json['key'] as String,
      value: json['value'],
      description: json['description'] as String?,
      dataType: json['dataType'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'value': value,
      'description': description,
      'dataType': dataType,
      'updatedAt': updatedAt.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }
}

