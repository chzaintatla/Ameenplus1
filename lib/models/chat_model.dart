import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat conversation model
class ChatModel {
  final String id;
  final List<String> participants;
  final Map<String, dynamic>? lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCounts; // userId : unreadCount
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCounts = const {},
    required this.createdAt,
    this.updatedAt,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unreadCounts': unreadCounts,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }

  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }
}

/// Message model
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final String type; // text, image, voice, dua, islamic_card
  final String? mediaUrl;
  final Map<String, dynamic>? metadata; // For extra data like dua text, card info
  final bool read;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.content,
    this.type = 'text',
    this.mediaUrl,
    this.metadata,
    this.read = false,
    required this.timestamp,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Anonymous',
      senderPhotoUrl: data['senderPhotoUrl'],
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      mediaUrl: data['mediaUrl'],
      metadata: data['metadata'],
      read: data['read'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'content': content,
      'type': type,
      'mediaUrl': mediaUrl,
      'metadata': metadata,
      'read': read,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  MessageModel markAsRead() {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      metadata: metadata,
      read: true,
      timestamp: timestamp,
    );
  }

  bool get isTextMessage => type == 'text';
  bool get isImageMessage => type == 'image';
  bool get isVoiceMessage => type == 'voice';
  bool get isDuaMessage => type == 'dua';
  bool get isIslamicCard => type == 'islamic_card';
}

