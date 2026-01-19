import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_model.dart';
import '../../models/community_model.dart';
import '../../network/repositories/chat_repository.dart';
import '../../network/repositories/community_repository.dart';
import '../../network/repositories/user_profile_repository.dart';

Stream<List<MessageModel>> _getMessagesStream(String chatId, bool isCommunityChat) {
  final repository = ChatRepository();
  try {
    return repository.getMessages(chatId, isCommunityChat: isCommunityChat).handleError((error) {
      // Handle rate limit errors gracefully
      if (error.toString().contains('ChannelRateLimitReached') ||
          error.toString().contains('Too many channels')) {
        throw Exception('Too many active connections. Please wait a moment and try again.');
      }
      throw error;
    });
  } catch (e) {
    return Stream.value(<MessageModel>[]);
  }
}

// Helper function to format date for day separator (Today, Yesterday, or date)
String _formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final messageDate = DateTime(date.year, date.month, date.day);

  if (messageDate == today) {
    return 'Today';
  } else if (messageDate == yesterday) {
    return 'Yesterday';
  } else {
    // Format as "Mon, Jan 1, 2024" or similar
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }
}

// Helper function to check if two dates are on different days
bool _isDifferentDay(DateTime date1, DateTime date2) {
  return date1.year != date2.year ||
      date1.month != date2.month ||
      date1.day != date2.day;
}

// Helper function to format time (e.g., "10:30 AM")
String _formatTime(DateTime date) {
  return DateFormat('h:mm a').format(date);
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserName;
  final bool isCommunityChat;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.otherUserName,
    this.isCommunityChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final ChatRepository _chatRepo = ChatRepository();
  final CommunityRepository _communityRepo = CommunityRepository();
  final UserProfileRepository _profileRepo = getUserProfileRepository();
  Stream<List<MessageModel>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = _getMessagesStream(widget.chatId, widget.isCommunityChat);
  }

  void _reloadMessages() {
    setState(() {
      _messagesStream = _getMessagesStream(widget.chatId, widget.isCommunityChat);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? mediaUrl, String? messageType, Map<String, dynamic>? metadata}) async {
    final content = _messageController.text.trim();
    if (content.isEmpty && mediaUrl == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await _chatRepo.sendMessage(
        chatId: widget.chatId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'User',
        senderPhotoUrl: currentUser.photoURL,
        content: content,
        type: messageType ?? 'text',
        mediaUrl: mediaUrl,
        metadata: metadata,
        isCommunityChat: widget.isCommunityChat,
      );

      _messageController.clear();

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      await _uploadAndSendFile(File(image.path), 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      await _uploadAndSendFile(File(video.path), 'video');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.single.path == null) return;

      await _uploadAndSendFile(File(result.files.single.path!), 'document', fileName: result.files.single.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking document: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndSendFile(File file, String type, {String? fileName}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading...')),
    );

    try {
      final fileExtension = fileName?.split('.').last ?? file.path.split('.').last;
      final filePath = 'chat_media/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      final downloadUrl = await StorageService.uploadFile(
        bucket: 'media',
        filePath: filePath,
        file: file,
        upsert: true,
      );

      await _sendMessage(
        mediaUrl: downloadUrl,
        messageType: type,
        metadata: fileName != null ? {'fileName': fileName} : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendDocument();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteMessageDialog(BuildContext context, MessageModel message, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatRepo.deleteMessage(message.id, userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting message: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final messagesStream = _messagesStream ?? _getMessagesStream(widget.chatId, widget.isCommunityChat);
    
    // Debug logging
    if (kDebugMode) {
      debugPrint('✅ Chat messages stream created for chatId: ${widget.chatId}, isCommunity: ${widget.isCommunityChat}');
    }



    return Scaffold(
      appBar: AppBar(
        title: widget.isCommunityChat
            ? FutureBuilder<CommunityModel?>(
                future: _communityRepo.getCommunity(widget.chatId),
                builder: (context, communitySnapshot) {
                  final community = communitySnapshot.data;
                  return InkWell(
                    onTap: () {
                      context.push('/communities/${widget.chatId}');
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: community?.imageUrl != null
                              ? CachedNetworkImageProvider(community!.imageUrl!)
                              : null,
                          child: community?.imageUrl == null
                              ? const Icon(Icons.groups, size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.otherUserName ?? community?.name ?? 'Community Chat',
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  );
                },
              )
            : Text(
                widget.otherUserName ?? 'Chat',
              ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _reloadMessages,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                // Messages are already sorted chronologically by timestamp from the stream
                // ListView.reverse=true means newest messages appear at bottom (like WhatsApp)
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mark messages as read when they arrive
                if (currentUser != null) {
                  _chatRepo.markMessagesAsRead(
                    widget.chatId, 
                    currentUser.uid,
                    isCommunityChat: widget.isCommunityChat,
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser?.uid;
                    
                    // Check if we need to show a date separator
                    final showDateSeparator = index == messages.length - 1 ||
                        _isDifferentDay(message.timestamp, messages[index + 1].timestamp);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Date separator
                        if (showDateSeparator)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatDateHeader(message.timestamp),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Message bubble
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: isMe ? () => _showDeleteMessageDialog(context, message, currentUser?.uid ?? '') : null,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // Show user details for all users in community (or if profile is public for direct chat)
                                if (!isMe)
                                  FutureBuilder<bool>(
                                    future: widget.isCommunityChat 
                                        ? Future.value(true) // Always show for community chats
                                        : _profileRepo.getProfile(message.senderId).then((profile) => profile?.isProfilePublic ?? false),
                                    builder: (context, profileSnapshot) {
                                      final shouldShow = widget.isCommunityChat 
                                          ? true 
                                          : (profileSnapshot.data ?? false);
                                      
                                      if (!shouldShow) {
                                        return const SizedBox.shrink();
                                      }
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Avatar
                                            InkWell(
                                              onTap: () {
                                                context.push('/user-profile/${message.senderId}');
                                              },
                                              child: CircleAvatar(
                                                radius: 14,
                                                backgroundImage: message.senderPhotoUrl != null
                                                    ? CachedNetworkImageProvider(message.senderPhotoUrl!)
                                                    : null,
                                                child: message.senderPhotoUrl == null
                                                    ? Text(
                                                        message.senderName.isNotEmpty
                                                            ? message.senderName[0].toUpperCase()
                                                            : '?',
                                                        style: const TextStyle(fontSize: 12),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Name with follow button
                                            if (widget.isCommunityChat)
                                              FutureBuilder<CommunityModel?>(
                                                future: _communityRepo.getCommunity(widget.chatId),
                                                builder: (context, communitySnapshot) {
                                                  if (!communitySnapshot.hasData) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  final community = communitySnapshot.data;
                                                  if (community == null) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  final isOwner = message.senderId == community.creatorId;
                                                  return InkWell(
                                                    onTap: () {
                                                      context.push('/user-profile/${message.senderId}');
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: isOwner ? Colors.green.shade700 : Colors.transparent,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (isOwner) ...[
                                                            const Icon(
                                                              Icons.star,
                                                              size: 14,
                                                              color: Colors.white,
                                                            ),
                                                            const SizedBox(width: 4),
                                                          ],
                                                          Text(
                                                            message.senderName,
                                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                              fontWeight: FontWeight.bold,
                                                              color: isOwner ? Colors.white : null,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            else
                                              InkWell(
                                                onTap: () {
                                                  context.push('/user-profile/${message.senderId}');
                                                },
                                                child: Text(
                                                  message.senderName,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: Theme.of(context).colorScheme.primary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                // Message bubble
                                Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      top: 10,
                                      bottom: message.type != 'text' ? 10 : 10, // Reduced since time is now inline
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: message.type == 'image' && message.mediaUrl != null
                                    ? GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              child: CachedNetworkImage(
                                                imageUrl: message.mediaUrl!,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: message.mediaUrl!,
                                            width: 200,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              width: 200,
                                              height: 200,
                                              color: Colors.grey.shade300,
                                              child: const Center(child: CircularProgressIndicator()),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              width: 200,
                                              height: 200,
                                              color: Colors.grey.shade300,
                                              child: const Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                      )
                                    : message.type == 'video' && message.mediaUrl != null
                                        ? Container(
                                            width: 200,
                                            height: 150,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.play_circle_filled, size: 48),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Video',
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          )
                                        : message.type == 'document' && message.mediaUrl != null
                                            ? InkWell(
                                                onTap: () {
                                                  // TODO: Open document URL
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.insert_drive_file, size: 32),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              message.metadata?['fileName'] ?? 'Document',
                                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            Text(
                                                              'Tap to download',
                                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                    fontSize: 10,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                constraints: const BoxConstraints(
                                                  minHeight: 20, // Ensure minimum height for short messages
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        message.content,
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          color: isMe
                                                              ? Theme.of(context).colorScheme.onPrimary
                                                              : Theme.of(context).colorScheme.onSurface,
                                                        ),
                                                        maxLines: null,
                                                        softWrap: true,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 2),
                                                      child: Text(
                                                        _formatTime(message.timestamp),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isMe
                                                              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                                                              : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                  ),
                                ],
                              ),
                              // Time below media messages
                              if (message.type != 'text')
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _formatTime(message.timestamp),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                    textAlign: isMe ? TextAlign.right : TextAlign.left,
                                  ),
                                ),
                            ],
                          ),
                        ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _showMediaOptions,
                  icon: const Icon(Icons.attach_file),
                  color: Theme.of(context).colorScheme.primary,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _sendMessage(),
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
