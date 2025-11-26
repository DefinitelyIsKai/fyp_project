import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus {
  normal,
  reported,
  reviewed,
  removed,
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime sentAt;
  final MessageStatus status;
  final String? reportReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewAction;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.sentAt,
    this.status = MessageStatus.normal,
    this.reportReason,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewAction,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    DateTime parseSentAt(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      try {
        return (value as Timestamp).toDate();
      } catch (e) {
        return DateTime.now();
      }
    }

    DateTime? parseReviewedAt(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      try {
        return (value as Timestamp).toDate();
      } catch (e) {
        return null;
      }
    }

    return MessageModel(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      sentAt: parseSentAt(json['sentAt']),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['status'] ?? 'normal'),
        orElse: () => MessageStatus.normal,
      ),
      reportReason: json['reportReason'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: parseReviewedAt(json['reviewedAt']),
      reviewAction: json['reviewAction'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'sentAt': sentAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'reportReason': reportReason,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewAction': reviewAction,
    };
  }
}

