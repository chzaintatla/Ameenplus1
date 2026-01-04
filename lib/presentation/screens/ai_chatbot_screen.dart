import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/groq_api_service.dart';
import '../../services/ai_validation_service.dart';
import '../../services/chat_database_service.dart';
import '../../providers/profile_providers.dart';

class AIChatbotScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  final String? mediaPath;
  final String? mediaType;
  
  const AIChatbotScreen({
    super.key, 
    this.initialMessage,
    this.mediaPath,
    this.mediaType,
  });

  @override
  ConsumerState<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends ConsumerState<AIChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final GroqApiService _groqService = GroqApiService();
  final AIContentValidationService _validationService = AIContentValidationService();
  final ChatDatabaseService _chatDb = ChatDatabaseService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  File? _selectedMediaFile;
  String? _selectedMediaType;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final savedMessages = await _chatDb.getRecentMessages(limit: 100);
      
      if (savedMessages.isEmpty) {
        _addWelcomeMessage();
      } else {
        setState(() {
          _messages.addAll(savedMessages);
        });
        _scrollToBottom();
      }

      // Handle initial message and media from navigation
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        _messageController.text = widget.initialMessage!;
        if (widget.mediaPath != null) {
          _selectedMediaFile = File(widget.mediaPath!);
          _selectedMediaType = widget.mediaType ?? 'file';
        }
        await _sendMessage();
      }
    } catch (e) {
      _addWelcomeMessage();
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  void _addWelcomeMessage() {
    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
        text: 'Assalamu Alaikum! I\'m your Islamic AI assistant. I can help you with:\n\n'
            '• Islamic questions and guidance\n'
            '• Quran and Hadith references\n'
            '• Daily motivation and reminders\n'
            '• App feature explanations\n\n'
            'Please note: I only discuss Islamic topics. How can I help you today?',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if ((text.isEmpty && _selectedMediaFile == null) || _isLoading) return;

    // Build message text with media info
    String messageText = text;
    if (_selectedMediaFile != null) {
      final mediaInfo = 'I have attached a ${_selectedMediaType ?? 'file'} for validation/analysis.';
      messageText = text.isEmpty ? mediaInfo : '$text\n\n$mediaInfo';
    }

    // Validate message is Islamic (skip if only media)
    if (text.isNotEmpty) {
      final validation = await _validationService.validateChatMessage(text);
      if (!validation.isIslamic) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please ask only about Islamic topics. ${validation.reason}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
    }

    final userMessage = ChatMessage(
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Insert message and get the ID
    final messageId = await _chatDb.insertMessage(userMessage);
    final userMessageWithId = ChatMessage(
      id: messageId,
      text: messageText,
      isUser: true,
      timestamp: userMessage.timestamp,
    );

    setState(() {
      _messages.add(userMessageWithId);
      _isLoading = true;
      _selectedMediaFile = null;
      _selectedMediaType = null;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final conversationHistory = _messages
          .where((m) => !m.isUser || m.text != messageText)
          .take(20)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      // Detect language
      final detectedLanguage = _detectLanguage(messageText);
      final languageInstruction = detectedLanguage == 'urdu' 
          ? ' Please respond in Urdu (اردو).'
          : ' Please respond in English.';
      
      final messageWithLanguage = messageText + languageInstruction;

      // Get user profile for personalization
      final profileAsync = ref.read(currentUserProfileProvider);
      final userProfile = profileAsync.value;
      
      final response = await _groqService.chat(
        message: messageWithLanguage,
        conversationHistory: conversationHistory,
        profession: userProfile?.profession,
        interests: userProfile?.interests,
        language: detectedLanguage,
      );

      // Insert assistant message and get the ID
      final assistantMessage = ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      final assistantMessageId = await _chatDb.insertMessage(assistantMessage);
      final assistantMessageWithId = ChatMessage(
        id: assistantMessageId,
        text: response,
        isUser: false,
        timestamp: assistantMessage.timestamp,
      );

      if (mounted) {
        setState(() {
          _messages.add(assistantMessageWithId);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        text: 'I apologize, but I encountered an error. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      
      // Insert error message and get the ID
      final errorMessageId = await _chatDb.insertMessage(errorMessage);
      final errorMessageWithId = ChatMessage(
        id: errorMessageId,
        text: errorMessage.text,
        isUser: false,
        timestamp: errorMessage.timestamp,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(errorMessageWithId);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _detectLanguage(String text) {
    // Simple Urdu detection - check for Urdu characters
    final urduPattern = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    if (urduPattern.hasMatch(text)) {
      return 'urdu';
    }
    return 'english';
  }

  Future<void> _pickMedia() async {
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Video'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: const Text('Audio'),
                onTap: () => Navigator.pop(context, 'audio'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (result == null) return;

      if (result == 'image') {
        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          setState(() {
            _selectedMediaFile = File(image.path);
            _selectedMediaType = 'image';
          });
        }
      } else if (result == 'video') {
        final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          setState(() {
            _selectedMediaFile = File(video.path);
            _selectedMediaType = 'video';
          });
        }
      } else if (result == 'audio') {
        final fileResult = await FilePicker.platform.pickFiles(
          type: FileType.audio,
        );
        if (fileResult != null && fileResult.files.single.path != null) {
          setState(() {
            _selectedMediaFile = File(fileResult.files.single.path!);
            _selectedMediaType = 'audio';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking media: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.mosque, color: Colors.green),
            SizedBox(width: 8),
            Text('Islamic AI Assistant'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete_all') {
                _showDeleteAllDialog();
              } else if (value == 'help') {
                _showHelpDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline),
                    SizedBox(width: 8),
                    Text('Help'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete All Messages', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _ChatBubble(
                        message: _messages[index],
                        onDelete: _messages[index].id != null
                            ? () => _deleteMessage(_messages[index].id!)
                            : null,
                      );
                    },
                  ),
                ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedMediaFile != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedMediaType == 'image'
                                ? Icons.image
                                : _selectedMediaType == 'video'
                                    ? Icons.video_library
                                    : Icons.audiotrack,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedMediaFile!.path.split('/').last,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _selectedMediaFile = null;
                                _selectedMediaType = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about Islamic topics...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
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
                  onPressed: _isLoading ? null : _pickMedia,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Attach Media',
                ),
                IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await _chatDb.deleteMessage(messageId);
      setState(() {
        _messages.removeWhere((m) => m.id == messageId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            duration: Duration(seconds: 2),
          ),
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
  }

  void _showDeleteAllDialog() {
    if (_messages.isEmpty || _messages.every((m) => m.id == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to delete')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Messages'),
        content: const Text(
          'Are you sure you want to delete all chat messages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllMessages();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllMessages() async {
    try {
      await _chatDb.deleteAllMessages();
      setState(() {
        _messages.clear();
        _addWelcomeMessage();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All messages deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting messages: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Use'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This AI assistant helps you with:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Islamic questions and guidance'),
              Text('• Quran and Hadith references'),
              Text('• Daily motivation'),
              Text('• App feature explanations'),
              SizedBox(height: 16),
              Text(
                'Important:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('This chatbot only discusses Islamic topics. Non-Islamic questions will be redirected.'),
              SizedBox(height: 16),
              Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Long press on any message to delete it'),
              Text('• Use the menu to delete all messages'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}


class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onDelete;

  const _ChatBubble({
    required this.message,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mosque, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onDelete != null
                  ? () {
                      _showDeleteMessageDialog(context);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: message.isUser
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteMessageDialog(BuildContext context) {
    if (onDelete == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete!();
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
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mosque, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Thinking...'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

