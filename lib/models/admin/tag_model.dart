import 'package:cloud_firestore/cloud_firestore.dart';

class TagModel {
  final String id;
  final String categoryId;
  String name;
  bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TagModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: json['id'] ?? '',
      categoryId: json['categoryId'] ?? '',
      name: json['name'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  TagModel copyWith({
    String? id,
    String? categoryId,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TagModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TagModel(id: $id, name: $name, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TagModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class TagCategoryModel {
  final String id;
  String title;
  String description;
  bool allowMultiple;
  bool isActive;
  List<TagModel> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TagCategoryModel({
    required this.id,
    required this.title,
    required this.description,
    this.allowMultiple = true,
    this.isActive = true,
    this.tags = const [],
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TagCategoryModel.fromJson(Map<String, dynamic> json) {
    return TagCategoryModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      allowMultiple: json['allowMultiple'] ?? true,
      isActive: json['isActive'] ?? true,
      tags: json['tags'] != null
          ? List<TagModel>.from(
          (json['tags'] as List).map((x) => TagModel.fromJson(x)))
          : <TagModel>[],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'allowMultiple': allowMultiple,
      'isActive': isActive,
      'tags': tags.map((tag) => tag.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  TagCategoryModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? allowMultiple,
    bool? isActive,
    List<TagModel>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TagCategoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get activeTagsCount => tags.where((tag) => tag.isActive).length;

  int get totalTagsCount => tags.length;

  bool get hasTags => tags.isNotEmpty;

  List<TagModel> get activeTags => tags.where((tag) => tag.isActive).toList();

  void addTag(TagModel tag) {
    tags.add(tag);
  }

  void removeTag(String tagId) {
    tags.removeWhere((tag) => tag.id == tagId);
  }

  void updateTag(String tagId, String newName) {
    final index = tags.indexWhere((tag) => tag.id == tagId);
    if (index != -1) {
      tags[index] = tags[index].copyWith(name: newName);
    }
  }

  void toggleTagStatus(String tagId) {
    final index = tags.indexWhere((tag) => tag.id == tagId);
    if (index != -1) {
      tags[index] = tags[index].copyWith(isActive: !tags[index].isActive);
    }
  }

  @override
  String toString() {
    return 'TagCategoryModel(id: $id, title: $title, tags: ${tags.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TagCategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}