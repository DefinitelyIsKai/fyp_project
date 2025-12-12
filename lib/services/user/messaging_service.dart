import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/message.dart';
import 'auth_service.dart';
import 'application_service.dart';
import 'notification_service.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final ApplicationService _applicationService = ApplicationService();
  final NotificationService _notificationService = NotificationService();

  //conversation id from two user  
  String _generateConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  //create conversation
  Future<String> getOrCreateConversation({
    required String otherUserId,
    String? matchId,
  }) async {
    final currentUserId = _authService.currentUserId;
    final conversationId = _generateConversationId(currentUserId, otherUserId);

   
    // not overwrite existing lastMessage data 
    final currentUserDoc = await _authService.getUserDoc();
    final otherUserDoc = await _firestore
        .collection('users')
        .doc(otherUserId)
        .get();

    final currentUserName =
        currentUserDoc.data()?['fullName'] as String? ?? 'Unknown';
    final otherUserName =
        otherUserDoc.data()?['fullName'] as String? ?? 'Unknown';
    final currentUserRole =
        currentUserDoc.data()?['role'] as String? ?? 'jobseeker';
    final otherUserRole = otherUserDoc.data()?['role'] as String? ?? 'jobseeker';

    //conversation exists with proper structure
    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    
    //check  conversation  exists
    final existing = await conversationRef.get();
    if (!existing.exists) {
      //create conversation
      await conversationRef.set({
        'participant1Id': currentUserId,
        'participant2Id': otherUserId,
        if (matchId != null) 'matchId': matchId,
        'participantNames': {
          currentUserId: currentUserName,
          otherUserId: otherUserName,
        },
        'participantRoles': {
          currentUserId: currentUserRole,
          otherUserId: otherUserRole,
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } else {
      //update latest names
      await conversationRef.set({
        'participant1Id': currentUserId,
        'participant2Id': otherUserId,
        if (matchId != null) 'matchId': matchId,
        'participantNames': {
          currentUserId: currentUserName,
          otherUserId: otherUserName,
        },
        'participantRoles': {
          currentUserId: currentUserRole,
          otherUserId: otherUserRole,
        },
      }, SetOptions(merge: true));
    }

    return conversationId;
  }

 
  Stream<List<Conversation>> streamConversations() {
    //check user authenticated
    if (_auth.currentUser == null) {
      return Stream.value(<Conversation>[]);
    }
    
    final userId = _authService.currentUserId;
    final conversationMap = <String, Conversation>{};
    final controller = StreamController<List<Conversation>>();
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    void emitConversations() {
      if (_auth.currentUser == null) {
        controller.add(<Conversation>[]);
        return;
      }

      //filter out conversations with no messages and sort in memory lastmessagetime 
      final conversations = conversationMap.values
          .where((conv) => conv.lastMessage.isNotEmpty)
          .toList();
      conversations.sort(
        (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
      );
      
      if (!controller.isClosed) {
        controller.add(conversations);
      }
    }

    //conversations participant1
    final stream1 = _firestore
        .collection('conversations')
        .where('participant1Id', isEqualTo: userId)
        .snapshots();

    //conversations participant2
    final stream2 = _firestore
        .collection('conversations')
        .where('participant2Id', isEqualTo: userId)
        .snapshots();

    sub1 = stream1.listen(
      (snapshot1) {
        if (_auth.currentUser == null || controller.isClosed) return;

        //pdate conversations first query
        for (final doc in snapshot1.docs) {
          try {
            final conversation = Conversation.fromFirestore(doc);
            conversationMap[conversation.id] = conversation;
          } catch (e) {
            debugPrint('Error parsing conversation ${doc.id}: $e');
          }
        }
        emitConversations();
      },
      onError: (error) {
        debugPrint('Error in stream1 (participant1Id): $error');
        if (_auth.currentUser == null && !controller.isClosed) {
          controller.add(<Conversation>[]);
        }
      },
    );

    sub2 = stream2.listen(
      (snapshot2) {
        if (_auth.currentUser == null || controller.isClosed) return;

        //update second query
        for (final doc in snapshot2.docs) {
          try {
            final conversation = Conversation.fromFirestore(doc);
            conversationMap[conversation.id] = conversation;
          } catch (e) {
            debugPrint('Error parsing conversation ${doc.id}: $e');
          }
        }
        emitConversations();
      },
      onError: (error) {
        debugPrint('Error in stream2 (participant2Id): $error');
        if (_auth.currentUser == null && !controller.isClosed) {
          controller.add(<Conversation>[]);
        }
      },
    );

    //clean up 
    controller.onCancel = () async {
      await sub1?.cancel();
      await sub2?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  //message for a conversation
  Stream<List<Message>> streamMessages(String conversationId) async* {
 
    if (_auth.currentUser == null) {
      yield <Message>[];
      return;
    }

    try {
      //check conversation exists 
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (!conversationDoc.exists) {
        yield <Message>[];
        return;
      }

      final conversationData = conversationDoc.data();
      final userId = _authService.currentUserId;
      
      //check participant
      if (conversationData?['participant1Id'] != userId &&
          conversationData?['participant2Id'] != userId) {
        yield <Message>[];
        return;
      }

      try {
        await for (final snapshot in _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .snapshots()) {
          if (_auth.currentUser == null) {
            yield <Message>[];
            return;
          }
          
          try {
            final messages = snapshot.docs
                .map((doc) => Message.fromFirestore(doc))
                .toList();
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            yield messages;
          } catch (e) {
            if (e.toString().contains('PERMISSION_DENIED')) {
              debugPrint('Error processing messages (likely during logout): $e');
              yield <Message>[];
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Error in streamMessages (likely during logout): $e');
        yield <Message>[];
        return;
      }
    } catch (e) {
    
      if (e.toString().contains('PERMISSION_DENIED')) {
        yield <Message>[];
        return;
      }
      yield <Message>[];
    }
  }


  Future<void> sendMessage({
    required String receiverId,
    required String content,
    String? matchId,
    String? postId,
  }) async {
    final senderId = _authService.currentUserId;

  
    if (postId != null) {
      final userDoc = await _authService.getUserDoc();
      final userRole = userDoc.data()?['role'] as String? ?? 'jobseeker';

      if (userRole == 'jobseeker') {
        final isApproved = await _applicationService.isApplicationApproved(
          postId,
          senderId,
        );
        if (!isApproved) {
          throw StateError(
            'APPLICATION_NOT_APPROVED: You can only message the recruiter after your application is approved.',
          );
        }
      }
    }

    final conversationId = await getOrCreateConversation(
      otherUserId: receiverId,
      matchId: matchId,
    );

    final message = Message(
      id: '',
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      timestamp: DateTime.now(),
    );

    //addmessage  
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toFirestore());

    //update last message
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageTime': Timestamp.fromDate(DateTime.now()),
    });

    await _notificationService.notifyMessageReceived(
      receiverId: receiverId,
      conversationId: conversationId,
      preview: content.length > 80 ? '${content.substring(0, 77)}...' : content,
    );
  }

  //mark  read
  Future<void> markMessagesAsRead(String conversationId) async {
    final userId = _authService.currentUserId;
    final messagesSnapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    await _notificationService.markMessageNotificationsAsRead(conversationId);
  }
}

