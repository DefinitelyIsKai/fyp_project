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
  final String? reviewAction; // 'approved', 'removed', 'warning'

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
    return MessageModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => MessageStatus.normal,
      ),
      reportReason: json['reportReason'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'] as String)
          : null,
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

