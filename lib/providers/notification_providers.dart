import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import '../network/repositories/notification_repository.dart';
import '../models/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationsProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  
  if (user == null) {
    return Stream.value([]);
  }
  
  final repository = ref.read(notificationRepositoryProvider);
  return repository.getUserNotifications(user.id);
});

final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  
  if (user == null) {
    return Stream.value(0);
  }
  
  final repository = ref.read(notificationRepositoryProvider);
  return repository.watchUnreadCount(user.id);
});
