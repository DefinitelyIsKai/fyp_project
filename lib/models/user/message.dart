import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? matchId; // Optional link to job match

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.matchId,
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
      matchId: data['matchId'] as String?,
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
      if (matchId != null) 'matchId': matchId,
    };
  }
}

class Conversation {
  final String id;
  final String participant1Id; // recruiter or jobseeker
  final String participant2Id; // recruiter or jobseeker
  final String lastMessage;
  final DateTime lastMessageTime;
  final String? matchId;
  final Map<String, String> participantNames; // {userId: name}
  final Map<String, String> participantRoles; // {userId: role}

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

