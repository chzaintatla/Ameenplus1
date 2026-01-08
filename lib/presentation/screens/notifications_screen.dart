import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final currentUser = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notificationsAsync.maybeWhen(
            data: (notifications) {
              final hasUnread = notifications.any((n) => !n.read);
              if (!hasUnread) return const SizedBox.shrink();

              return TextButton.icon(
                onPressed: () async {
                  final user = currentUser.value;
                  if (user != null) {
                    await ref.read(notificationRepositoryProvider).markAllAsRead(user.id);
                  }
                },
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Mark all read'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
            },
            child: ListView.builder(
              itemCount: notifications.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(notification: notification);
              },
            ),
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
                        ? 'Setting up notifications...'
                        : 'Error loading notifications',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      isIndexBuilding
                          ? 'Notifications are being set up. This may take a few minutes. Please try again later.'
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
                    onPressed: () => ref.invalidate(notificationsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  IconData _getIconForType(String type) {
    switch (type) {
      case 'deed_like':
        return Icons.favorite;
      case 'deed_comment':
        return Icons.comment;
      case 'friend_request':
        return Icons.person_add;
      case 'friend_accepted':
        return Icons.person_add_alt_1;
      case 'community_post':
        return Icons.groups;
      case 'community_join':
        return Icons.group_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type, BuildContext context) {
    switch (type) {
      case 'deed_like':
        return Colors.red;
      case 'deed_comment':
        return Colors.blue;
      case 'friend_request':
      case 'friend_accepted':
        return Colors.green;
      case 'community_post':
      case 'community_join':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _getIconForType(notification.type);
    final color = _getColorForType(notification.type, context);
    final isUnread = !notification.read;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isUnread
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeago.format(notification.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: isUnread
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () async {
          if (!notification.read) {
            await ref.read(notificationRepositoryProvider).markAsRead(notification.id);
          }

          if (notification.actionId != null) {
            switch (notification.type) {
              case 'deed_like':
              case 'deed_comment':
                break;
              case 'friend_request':
                break;
              case 'community_post':
              case 'community_join':
                break;
            }
          }
        },
      ),
    );
  }
}
