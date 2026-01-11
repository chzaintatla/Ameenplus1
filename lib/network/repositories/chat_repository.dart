import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../utils/app_constants.dart';
import '../../models/chat_model.dart';
import 'notification_repository.dart';

class ChatRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationRepository _notificationRepo = NotificationRepository();

  /// Get or create a chat between two users
  Future<String> getOrCreateChat(String userId1, String userId2) async {
    // Check if chat already exists
    final existingChats = await _supabase
        .from(AppConstants.collectionChats)
        .select()
        .contains('participants', [userId1]);

    for (var chat in existingChats) {
      final participants = List<String>.from(chat['participants'] ?? []);
      if (participants.contains(userId2) && participants.length == 2) {
        return chat['id'].toString();
      }
    }

    // Create new chat
    final chatData = {
      'participants': [userId1, userId2],
      'created_at': DateTime.now().toIso8601String(),
      'unread_counts': {userId1: 0, userId2: 0},
    };

    final response = await _supabase
        .from(AppConstants.collectionChats)
        .insert(chatData)
        .select()
        .single();

    return response['id'].toString();
  }

  /// Get or create a community chat
  /// [userId] - Firebase Auth user ID
  Future<String> getOrCreateCommunityChat(String communityId, String userId) async {

    // Get community document
    final communityDoc = await _supabase
        .from(AppConstants.collectionCommunities)
        .select()
        .eq('id', communityId)
        .maybeSingle();

    if (communityDoc == null) {
      throw Exception('Community not found');
    }

    // Ensure user is a member of the community
    final members = List<String>.from(communityDoc['members'] ?? []);
    
    if (!members.contains(userId)) {
      // Add user to community members
      members.add(userId);
      await _supabase
          .from(AppConstants.collectionCommunities)
          .update({
            'members': members,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', communityId);
      
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return communityId;
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
    bool isCommunityChat = false,
  }) async {
    final message = {
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_photo_url': senderPhotoUrl,
      'content': content,
      'type': type,
      'media_url': mediaUrl,
      'metadata': metadata,
      'read': false,
      'timestamp': DateTime.now().toIso8601String(),
      'is_community_message': isCommunityChat,
    };

    // Insert message
    await _supabase
        .from('messages')
        .insert(message);

    // Update chat's last message
    final tableName = isCommunityChat 
        ? AppConstants.collectionCommunities 
        : AppConstants.collectionChats;
    
    final chatDoc = await _supabase
        .from(tableName)
        .select()
        .eq('id', chatId)
        .maybeSingle();

    if (chatDoc != null) {
      if (isCommunityChat) {
        final members = List<String>.from(chatDoc['members'] ?? []);
        
        await _supabase
            .from(tableName)
            .update({
              'last_message': {
                'content': content,
                'sender_id': senderId,
                'sender_name': senderName,
              },
              'last_message_time': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', chatId);

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
        final participants = List<String>.from(chatDoc['participants'] ?? []);
        final unreadCounts = Map<String, int>.from(
          (chatDoc['unread_counts'] as Map?)?.cast<String, int>() ?? {}
        );
        
        for (var participantId in participants) {
          if (participantId != senderId) {
            unreadCounts[participantId] = (unreadCounts[participantId] ?? 0) + 1;
          }
        }

        await _supabase
            .from(tableName)
            .update({
              'last_message': {
                'content': content,
                'sender_id': senderId,
                'sender_name': senderName,
              },
              'last_message_time': DateTime.now().toIso8601String(),
              'unread_counts': unreadCounts,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', chatId);
            
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
    try {
      final stream = _supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('chat_id', chatId)
          .order('timestamp', ascending: true)
          .limit(50);

      await for (final data in stream) {
        final messages = data
            .map((doc) {
              try {
                return MessageModel.fromMap(doc);
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('Error parsing message document: $e');
                }
                return null;
              }
            })
            .whereType<MessageModel>()
            .toList();
        
        yield messages;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in getMessages stream: $e');
      }
      yield <MessageModel>[];
    }
  }

  Stream<List<ChatModel>> getUserChats(String userId) async* {
    try {
      final stream = _supabase
          .from(AppConstants.collectionChats)
          .stream(primaryKey: ['id']);

      await for (final data in stream) {
        final chats = data
            .where((doc) => (doc['participants'] as List?)?.contains(userId) ?? false)
            .map((doc) => ChatModel.fromMap(doc))
            .toList();
        
        chats.sort((a, b) {
          final timeA = a.lastMessageTime ?? a.createdAt;
          final timeB = b.lastMessageTime ?? b.createdAt;
          return timeB.compareTo(timeA);
        });
        
        yield chats;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in getUserChats stream: $e');
      }
      yield <ChatModel>[];
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId, {bool isCommunityChat = false}) async {
    try {
      // Update all unread messages
      await _supabase
          .from('messages')
          .update({'read': true})
          .eq('chat_id', chatId)
          .eq('read', true)
          .neq('sender_id', userId);

      // Reset unread count
      final tableName = isCommunityChat 
          ? AppConstants.collectionCommunities 
          : AppConstants.collectionChats;
          
      final chatDoc = await _supabase
          .from(tableName)
          .select()
          .eq('id', chatId)
          .maybeSingle();
          
      if (chatDoc != null && !isCommunityChat) {
        final unreadCounts = Map<String, int>.from(
          (chatDoc['unread_counts'] as Map?)?.cast<String, int>() ?? {}
        );
        unreadCounts[userId] = 0;
        
        await _supabase
            .from(tableName)
            .update({'unread_counts': unreadCounts})
            .eq('id', chatId);
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }
}
