import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationCategory { message, wallet, post, application, booking, system, account_warning, account_suspension, account_unsuspension }

class AppNotification {
  AppNotification({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.metadata = const {},
  });

  final String id;
  final String userId;
  final NotificationCategory category;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      category: _categoryFromString(data['category'] as String?),
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'category': category.name,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  static NotificationCategory _categoryFromString(String? value) {
    return NotificationCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => NotificationCategory.system,
    );
  }
}











