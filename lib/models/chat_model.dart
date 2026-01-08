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

  factory ChatModel.fromMap(Map<String, dynamic> data) {
    return ChatModel(
      id: data['id']?.toString() ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['last_message'] ?? data['lastMessage'],
      lastMessageTime: data['last_message_time'] != null
          ? (data['last_message_time'] is String
              ? DateTime.parse(data['last_message_time'])
              : data['last_message_time'] as DateTime?)
          : (data['lastMessageTime'] != null
              ? (data['lastMessageTime'] is String
                  ? DateTime.parse(data['lastMessageTime'])
                  : data['lastMessageTime'] as DateTime?)
              : null),
      unreadCounts: Map<String, int>.from(data['unread_counts'] ?? data['unreadCounts'] ?? {}),
      createdAt: data['created_at'] != null
          ? (data['created_at'] is String ? DateTime.parse(data['created_at']) : data['created_at'] as DateTime)
          : (data['createdAt'] is String ? DateTime.parse(data['createdAt']) : DateTime.now()),
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] is String ? DateTime.parse(data['updated_at']) : data['updated_at'] as DateTime?)
          : (data['updatedAt'] != null 
              ? (data['updatedAt'] is String ? DateTime.parse(data['updatedAt']) : data['updatedAt'] as DateTime?)
              : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_counts': unreadCounts,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }

  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final String type;
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;
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

  factory MessageModel.fromMap(Map<String, dynamic> data) {
    return MessageModel(
      id: data['id']?.toString() ?? '',
      chatId: data['chat_id'] ?? data['chatId'] ?? '',
      senderId: data['sender_id'] ?? data['senderId'] ?? '',
      senderName: data['sender_name'] ?? data['senderName'] ?? 'Anonymous',
      senderPhotoUrl: data['sender_photo_url'] ?? data['senderPhotoUrl'],
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      mediaUrl: data['media_url'] ?? data['mediaUrl'],
      metadata: data['metadata'],
      read: data['read'] ?? false,
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] is String ? DateTime.parse(data['timestamp']) : data['timestamp'] as DateTime)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_photo_url': senderPhotoUrl,
      'content': content,
      'type': type,
      'media_url': mediaUrl,
      'metadata': metadata,
      'read': read,
      'timestamp': timestamp.toIso8601String(),
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

