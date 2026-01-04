import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../utils/app_constants.dart';
import '../../models/chat_model.dart';
import 'notification_repository.dart';

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
  /// Returns the communityId directly since messages are stored in communities/{communityId}/messages
  Future<String> getOrCreateCommunityChat(String communityId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated to access community chat');
    }

    // For community chats, we use the community document itself
    // Messages are stored in communities/{communityId}/messages subcollection
    final communityDoc = await _firestore
        .collection(AppConstants.collectionCommunities)
        .doc(communityId)
        .get();

    if (!communityDoc.exists) {
      throw Exception('Community not found');
    }

    // Ensure user is a member of the community
    final communityData = communityDoc.data()!;
    final members = List<String>.from(communityData['members'] ?? []);
    
    if (!members.contains(currentUser.uid)) {
      // Add user to community members
      await communityDoc.reference.update({
        'members': FieldValue.arrayUnion([currentUser.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Wait a bit to ensure the update is propagated
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Return communityId - this will be used to access communities/{communityId}/messages
    return communityId;
  }

  /// Send a message
  /// chatId can be either a regular chat ID or a communityId for community chats
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
    String type = 'text',
    String? mediaUrl,
    Map<String, dynamic>? metadata,
    bool isCommunityChat = false,
  }) async {
    DocumentReference messageRef;
    DocumentReference chatDocRef;
    
    if (isCommunityChat) {
      // Community chat: use communities/{communityId}/messages
      messageRef = _firestore
          .collection(AppConstants.collectionCommunities)
          .doc(chatId)
          .collection('messages')
          .doc();
      
      chatDocRef = _firestore
          .collection(AppConstants.collectionCommunities)
          .doc(chatId);
    } else {
      // Regular chat: use chats/{chatId}/messages
      messageRef = _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection('messages')
          .doc();
      
      chatDocRef = _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId);
    }

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
    final chatDoc = await chatDocRef.get();

    if (chatDoc.exists) {
      final chatData = chatDoc.data()! as Map<String, dynamic>;
      
      if (isCommunityChat) {
        // For community chats, update the community document
        final members = List<String>.from(chatData['members'] ?? []);
        
        await chatDocRef.update({
          'lastMessage': {
            'content': content,
            'senderId': senderId,
            'senderName': senderName,
          },
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Send notifications to other members
        for (var memberId in members) {
          if (memberId != senderId) {
            await _notificationRepo.createNotification(
              userId: memberId,
              type: 'chat_message',
              title: senderName,
              body: content,
              actionId: chatId,
            );
          }
        }
      } else {
        final participants = List<String>.from(chatData['participants'] ?? []);
        final unreadCountsData = chatData['unreadCounts'];
        final unreadCounts = unreadCountsData != null 
            ? Map<String, int>.from((unreadCountsData as Map).cast<String, int>())
            : <String, int>{};
        for (var participantId in participants) {
          if (participantId != senderId) {
            unreadCounts[participantId] = (unreadCounts[participantId] ?? 0) + 1;
          }
        }

        await chatDocRef.update({
          'lastMessage': {
            'content': content,
            'senderId': senderId,
            'senderName': senderName,
          },
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCounts': unreadCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
  }

  Stream<List<MessageModel>> getMessages(String chatId, {bool isCommunityChat = false}) async* {
    CollectionReference messagesRef;
    
    if (isCommunityChat) {
      messagesRef = _firestore
          .collection(AppConstants.collectionCommunities)
          .doc(chatId)
          .collection('messages');
    }
    else {
      messagesRef = _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection('messages');
    }
    
    try {
      await for (final snapshot in messagesRef
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()) {
        final messages = snapshot.docs
            .map((doc) {
              try {
                return MessageModel.fromFirestore(doc);
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('Error parsing message document: $e');
                }
                return null;
              }
            })
            .whereType<MessageModel>()
            .toList();
        
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        yield messages;
      }
    } catch (e) {
      if (e.toString().contains('index') || e.toString().contains('FAILED_PRECONDITION')) {
        try {
          await for (final snapshot in messagesRef
              .limit(50)
              .snapshots()) {
            final messages = snapshot.docs
                .map((doc) {
                  try {
                    return MessageModel.fromFirestore(doc);
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint('Error parsing message document: $e');
                    }
                    return null;
                  }
                })
                .whereType<MessageModel>()
                .toList();
            
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            yield messages;
          }
        } catch (e2) {
          if (kDebugMode) {
            debugPrint('Error in getMessages fallback: $e2');
          }
          yield <MessageModel>[];
        }
      } else {
        if (kDebugMode) {
          debugPrint('Error in getMessages stream: $e');
        }
        yield <MessageModel>[];
      }
    }
  }

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
  Future<void> markMessagesAsRead(String chatId, String userId, {bool isCommunityChat = false}) async {
    try {
      final batch = _firestore.batch();
      
      // Get messages collection reference based on chat type
      CollectionReference messagesRef;
      DocumentReference chatDocRef;
      
      if (isCommunityChat) {
        messagesRef = _firestore
            .collection(AppConstants.collectionCommunities)
            .doc(chatId)
            .collection('messages');
        chatDocRef = _firestore
            .collection(AppConstants.collectionCommunities)
            .doc(chatId);
      } else {
        messagesRef = _firestore
            .collection(AppConstants.collectionChats)
            .doc(chatId)
            .collection('messages');
        chatDocRef = _firestore
            .collection(AppConstants.collectionChats)
            .doc(chatId);
      }

      final allMessages = await messagesRef
          .where('read', isEqualTo: false)
          .get();

      // Filter messages that are not from the current user
      final unreadMessages = allMessages.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['senderId'] != userId;
      });

      for (var doc in unreadMessages) {
        batch.update(doc.reference, {'read': true});
      }

      // Reset unread count
      final chatDoc = await chatDocRef.get();
      if (chatDoc.exists) {
        final chatData = chatDoc.data()! as Map<String, dynamic>;
        final unreadCountsData = chatData['unreadCounts'];
        final unreadCounts = unreadCountsData != null 
            ? Map<String, int>.from((unreadCountsData as Map).cast<String, int>())
            : <String, int>{};
        unreadCounts[userId] = 0;
        
        batch.update(chatDocRef, {'unreadCounts': unreadCounts});
      }

      if (unreadMessages.isNotEmpty || chatDoc.exists) {
        await batch.commit();
      }
    }
    catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }
}

