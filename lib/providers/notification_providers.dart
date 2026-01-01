import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import '../network/repositories/notification_repository.dart';
import '../models/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationsProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) async* {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  
  if (user == null) {
    yield [];
    return;
  }
  
  try {
    final repository = ref.read(notificationRepositoryProvider);
    await for (final notifications in repository.getNotifications(user.uid)) {
      yield notifications;
    }
  } catch (e) {
    // Silently handle errors - return empty list to prevent error dialogs
    // Errors will be shown in the notifications screen itself when explicitly watched
    yield [];
  }
});

final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(0);
      final repository = ref.read(notificationRepositoryProvider);
      return repository.getUnreadCount(user.uid).asyncExpand((count) async* {
        yield count;
      }).handleError((error, stackTrace) {
        // Silently handle errors - errors won't propagate to UI
        // Return empty stream which will be handled by maybeWhen
      });
    },
    orElse: () => Stream.value(0),
  );
});

