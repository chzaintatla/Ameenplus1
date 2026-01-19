import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../network/repositories/notification_repository.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _notificationRepo = NotificationRepository();
  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _notifications = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _notificationsSubscription?.cancel();
      _notificationsSubscription = _notificationRepo.getUserNotifications(currentUser.uid).listen(
        (notifications) {
          if (mounted) {
            setState(() {
              _notifications = notifications;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _errorMessage = error.toString();
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton.icon(
              onPressed: () async {
                if (currentUser != null) {
                  await _notificationRepo.markAllAsRead(currentUser.uid);
                  _loadNotifications();
                }
              },
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      final errorMessage = _errorMessage!;
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
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
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
      onRefresh: _loadNotifications,
      child: ListView.builder(
        itemCount: _notifications.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _NotificationTile(notification: notification, notificationRepo: _notificationRepo);
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final NotificationRepository notificationRepo;

  const _NotificationTile({required this.notification, required this.notificationRepo});

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
      case 'community_message':
        return Icons.groups;
      case 'community_join':
        return Icons.group_add;
      case 'chat_message':
        return Icons.chat;
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
      case 'community_message':
      case 'community_join':
        return Colors.orange;
      case 'chat_message':
        return Colors.green.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            await notificationRepo.markAsRead(notification.id);
          }

          if (notification.actionId != null) {
            final actionId = notification.actionId!;
            switch (notification.type) {
              case 'deed_like':
              case 'deed_comment':
                break;
              case 'friend_request':
                break;
              case 'community_post':
              case 'community_join':
                break;
              case 'community_message':
              case 'chat_message':
                // Navigate to chat screen when notification is tapped
                if (context.mounted) {
                  context.push('/chat/$actionId', extra: {
                    'isCommunityChat': notification.type == 'community_message',
                  } as Map<String, dynamic>);
                }
                break;
            }
          }
        },
      ),
    );
  }
}
