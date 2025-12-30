import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../models/chat_model.dart';
import '../../notifications/data/notification_repository.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationRepository _notificationRepo = NotificationRepository();

  /// Get or create a chat between two users
  Future<String> getOrCreateChat(String userId1, String userId2) async {
    // Check if chat already exists
    final existingChats = await _firestore
        .collection(AppConstants.collectionChats)
        .where('participants', arrayContains: userId1)
        .get();

    for (var doc in existingChats.docs) {
      final chat = ChatModel.fromFirestore(doc);
      if (chat.participants.contains(userId2) && chat.participants.length == 2) {
        return chat.id;
      }
    }

    // Create new chat
    final chatRef = await _firestore.collection(AppConstants.collectionChats).add({
      'participants': [userId1, userId2],
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCounts': {userId1: 0, userId2: 0},
    });

    return chatRef.id;
  }

  /// Get or create a community chat
  Future<String> getOrCreateCommunityChat(String communityId) async {
    final chatId = 'community_$communityId';
    
    final chatDoc = await _firestore
        .collection(AppConstants.collectionChats)
        .doc(chatId)
        .get();

    if (!chatDoc.exists) {
      await chatDoc.reference.set({
        'participants': [communityId], // Community ID as participant
        'isCommunityChat': true,
        'communityId': communityId,
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCounts': {},
      });
    }

    return chatId;
  }

  /// Send a message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
    String type = 'text',
    String? mediaUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final messageRef = _firestore
        .collection(AppConstants.collectionChats)
        .doc(chatId)
        .collection('messages')
        .doc();

    final message = {
      'id': messageRef.id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'content': content,
      'type': type,
      'mediaUrl': mediaUrl,
      'metadata': metadata,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await messageRef.set(message);

    // Update chat's last message
    final chatDoc = await _firestore
        .collection(AppConstants.collectionChats)
        .doc(chatId)
        .get();

    if (chatDoc.exists) {
      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participants'] ?? []);
      
      // Update unread counts for other participants
      final unreadCounts = Map<String, int>.from(chatData['unreadCounts'] ?? {});
      for (var participantId in participants) {
        if (participantId != senderId) {
          unreadCounts[participantId] = (unreadCounts[participantId] ?? 0) + 1;
        }
      }

      await chatDoc.reference.update({
        'lastMessage': {
          'content': content,
          'senderId': senderId,
          'senderName': senderName,
        },
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notifications to other participants
      for (var participantId in participants) {
        if (participantId != senderId && !participantId.startsWith('community_')) {
          await _notificationRepo.createNotification(
            userId: participantId,
            type: 'chat_message',
            title: senderName,
            body: content,
            actionId: chatId,
          );
        }
      }
    }
  }

  /// Get messages for a chat
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection(AppConstants.collectionChats)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList()
          .reversed
          .toList();
    });
  }

  /// Get user's chats
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection(AppConstants.collectionChats)
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final batch = _firestore.batch();
    
    // Mark unread messages as read
    final unreadMessages = await _firestore
        .collection(AppConstants.collectionChats)
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }

    // Reset unread count
    final chatDoc = _firestore
        .collection(AppConstants.collectionChats)
        .doc(chatId);
    
    final chatData = (await chatDoc.get()).data()!;
    final unreadCounts = Map<String, int>.from(chatData['unreadCounts'] ?? {});
    unreadCounts[userId] = 0;
    
    batch.update(chatDoc, {'unreadCounts': unreadCounts});

    await batch.commit();
  }
}

