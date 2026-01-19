import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
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
      'id': const Uuid().v4(),
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'message_type': type,
      'media_url': mediaUrl,
      'read': false,
      'created_at': DateTime.now().toIso8601String(),
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
        
        // Update community with last message info (if columns exist)
        try {
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
        } catch (e) {
          // If last_message columns don't exist, just update updated_at
          try {
            await _supabase
                .from(tableName)
                .update({
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', chatId);
          } catch (e2) {
            // Silently ignore if update fails
            debugPrint('Warning: Could not update community: $e2');
          }
        }

        // Get community name for notification
        final communityName = chatDoc['name'] ?? 'Community';
        
        // Prepare notification body based on message type
        String notificationBody;
        if (mediaUrl != null) {
          switch (type) {
            case 'image':
              notificationBody = 'Sent an image';
              break;
            case 'video':
              notificationBody = 'Sent a video';
              break;
            case 'document':
              notificationBody = metadata?['fileName'] != null 
                  ? 'Sent ${metadata!['fileName']}' 
                  : 'Sent a document';
              break;
            default:
              notificationBody = 'Sent media';
          }
        } else {
          notificationBody = content;
        }
        
        // Send notifications to other members
        for (var memberId in members) {
          if (memberId != senderId) {
            try {
              await _notificationRepo.createNotification(
                userId: memberId,
                type: 'community_message',
                title: '$communityName: $senderName',
                body: notificationBody,
                actionId: chatId,
              );
            } catch (e) {
              debugPrint('Error sending notification to $memberId: $e');
            }
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
          .order('created_at', ascending: false)
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
          .eq('read', false)
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

  /// Delete a message
  /// Only the sender can delete their own message
  Future<void> deleteMessage(String messageId, String userId) async {
    try {
      // Verify message belongs to user
      final message = await _supabase
          .from('messages')
          .select('sender_id')
          .eq('id', messageId)
          .maybeSingle();

      if (message == null) {
        throw Exception('Message not found');
      }

      if (message['sender_id'] != userId) {
        throw Exception('Unauthorized: Can only delete your own messages');
      }

      // Delete the message
      await _supabase
          .from('messages')
          .delete()
          .eq('id', messageId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting message: $e');
      }
      rethrow;
    }
  }
}
