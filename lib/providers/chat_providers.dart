import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/repositories/chat_repository.dart';
import '../models/chat_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  final repository = ref.read(chatRepositoryProvider);
  return repository.getMessages(chatId);
});

