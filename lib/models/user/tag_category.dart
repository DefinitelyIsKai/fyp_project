import 'package:cloud_firestore/cloud_firestore.dart';

class TagCategory {
  TagCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.allowMultiple,
    required this.isActive,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String description;
  final bool allowMultiple;
  final bool isActive;
  final DateTime createdAt;

  factory TagCategory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return TagCategory(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      allowMultiple: data['allowMultiple'] as bool? ?? true,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'allowMultiple': allowMultiple,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

