import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;


  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      conversationId: data['conversationId'] as String,
      senderId: data['senderId'] as String,
      receiverId: data['receiverId'] as String,
      content: data['content'] as String,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}

class Conversation {
  final String id;
  final String participant1Id; 
  final String participant2Id; 
  final String lastMessage;
  final DateTime lastMessageTime;
  final String? matchId;
  final Map<String, String> participantNames; 
  final Map<String, String> participantRoles; 

  Conversation({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    required this.lastMessage,
    required this.lastMessageTime,
    this.matchId,
    required this.participantNames,
    required this.participantRoles,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participant1Id: data['participant1Id'] as String,
      participant2Id: data['participant2Id'] as String,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      matchId: data['matchId'] as String?,
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantRoles: Map<String, String>.from(data['participantRoles'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participant1Id': participant1Id,
      'participant2Id': participant2Id,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      if (matchId != null) 'matchId': matchId,
      'participantNames': participantNames,
      'participantRoles': participantRoles,
    };
  }

  String getOtherParticipantId(String currentUserId) {
    return currentUserId == participant1Id ? participant2Id : participant1Id;
  }

  String getOtherParticipantName(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantNames[otherId] ?? 'Unknown';
  }

  String getOtherParticipantRole(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantRoles[otherId] ?? 'Unknown';
  }
}

