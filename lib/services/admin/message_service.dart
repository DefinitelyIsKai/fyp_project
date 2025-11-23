import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/message_model.dart';

class MessageService {
  final CollectionReference _messagesCollection =
      FirebaseFirestore.instance.collection('messages');

  /// Get all reported/flagged messages
  Future<List<MessageModel>> getReportedMessages() async {
    try {
      final snapshot = await _messagesCollection
          .where('status', isEqualTo: 'reported')
          .orderBy('sentAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MessageModel(
          id: doc.id,
          senderId: data['senderId'] ?? '',
          receiverId: data['receiverId'] ?? '',
          content: data['content'] ?? '',
          sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: MessageStatus.reported,
          reportReason: data['reportReason'],
          reviewedBy: data['reviewedBy'],
          reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
          reviewAction: data['reviewAction'],
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get messages by status
  Future<List<MessageModel>> getMessagesByStatus(MessageStatus status) async {
    try {
      final snapshot = await _messagesCollection
          .where('status', isEqualTo: status.toString().split('.').last)
          .orderBy('sentAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MessageModel(
          id: doc.id,
          senderId: data['senderId'] ?? '',
          receiverId: data['receiverId'] ?? '',
          content: data['content'] ?? '',
          sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: status,
          reportReason: data['reportReason'],
          reviewedBy: data['reviewedBy'],
          reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
          reviewAction: data['reviewAction'],
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Review a flagged message
  Future<void> reviewMessage({
    required String messageId,
    required String action, // 'approved', 'removed', 'warning'
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    final status = action == 'approved' ? 'reviewed' : 'removed';
    
    await _messagesCollection.doc(messageId).update({
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewAction': action,
      'reviewNotes': reviewNotes,
    });
  }

  /// Remove a message
  Future<void> removeMessage(String messageId, {String? reason}) async {
    await _messagesCollection.doc(messageId).update({
      'status': 'removed',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewAction': 'removed',
      'reviewNotes': reason,
    });
  }

  /// Flag a message for review
  Future<void> flagMessage(String messageId, String reason) async {
    await _messagesCollection.doc(messageId).update({
      'status': 'reported',
      'reportReason': reason,
      'reportedAt': FieldValue.serverTimestamp(),
    });
  }
}

