import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_providers.dart';
import '../../models/chat_model.dart';

final messagesProvider = StreamProvider.family<List<MessageModel>, Map<String, dynamic>>((ref, params) async* {
  final repository = ref.read(chatRepositoryProvider);
  final chatId = params['chatId'] as String;
  final isCommunityChat = params['isCommunityChat'] as bool? ?? false;
  
  try {
    await for (final messages in repository.getMessages(chatId, isCommunityChat: isCommunityChat)) {
      yield messages;
    }
  } catch (e, stackTrace) {
    // Re-throw error so StreamProvider can handle it
    throw e;
  }
});

class ChatScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? mediaUrl, String? messageType, Map<String, dynamic>? metadata}) async {
    final content = _messageController.text.trim();
    if (content.isEmpty && mediaUrl == null) return;

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        chatId: widget.chatId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'User',
        senderPhotoUrl: currentUser.photoURL,
        content: content.isEmpty ? (messageType == 'image' ? '📷 Image' : messageType == 'video' ? '🎥 Video' : '📄 Document') : content,
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
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading...')),
    );

    try {
      final storage = FirebaseStorage.instance;
      final fileExtension = fileName?.split('.').last ?? file.path.split('.').last;
      final storageRef = storage
          .ref()
          .child('chat_media')
          .child(widget.chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}.$fileExtension');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

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

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider({
      'chatId': widget.chatId,
      'isCommunityChat': widget.isCommunityChat,
    }));
    final currentUser = ref.watch(authStateProvider);
    
    // Debug logging
    if (kDebugMode) {
      messagesAsync.when(
        data: (messages) => debugPrint('✅ Chat messages loaded: ${messages.length} for chatId: ${widget.chatId}, isCommunity: ${widget.isCommunityChat}'),
        loading: () => debugPrint('⏳ Chat messages loading... chatId: ${widget.chatId}, isCommunity: ${widget.isCommunityChat}'),
        error: (error, stack) => debugPrint('❌ Chat messages error: $error for chatId: ${widget.chatId}, isCommunity: ${widget.isCommunityChat}'),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = currentUser.value;
      if (user != null) {
        ref.read(chatRepositoryProvider).markMessagesAsRead(
          widget.chatId, 
          user.uid,
          isCommunityChat: widget.isCommunityChat,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: widget.isCommunityChat
            ? InkWell(
                onTap: () {
                  // Navigate to community detail screen
                  // chatId is the communityId for community chats
                  context.push('/communities/${widget.chatId}');
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUserName ?? 'Community Chat',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
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
            child: messagesAsync.when(
              data: (messages) {
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

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser.value?.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  message.senderName,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceVariant,
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
                                            : Text(
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
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeago.format(message.timestamp),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                final errorMessage = error.toString();
                final isIndexBuilding = errorMessage.contains('index') &&
                                       (errorMessage.contains('building') ||
                                        errorMessage.contains('FAILED_PRECONDITION'));
                
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isIndexBuilding ? Icons.hourglass_empty : Icons.error_outline,
                          size: 64,
                          color: isIndexBuilding
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isIndexBuilding
                              ? 'Setting up messages...'
                              : 'Error loading messages',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            isIndexBuilding
                                ? 'Messages are being set up. This may take a few minutes. Please try again later.'
                                : errorMessage.contains('Exception:')
                                    ? errorMessage.split('Exception:').last.trim()
                                    : errorMessage,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(messagesProvider({
                            'chatId': widget.chatId,
                            'isCommunityChat': widget.isCommunityChat,
                          })),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
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
