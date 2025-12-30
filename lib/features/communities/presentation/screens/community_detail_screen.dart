import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../chat/data/chat_repository.dart';
import '../../data/community_repository.dart';
import '../../models/community_model.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final communityProvider = FutureProvider.family<CommunityModel?, String>((ref, communityId) async {
  final repository = ref.read(communityRepositoryProvider);
  return await repository.getCommunity(communityId);
});

final isCommunityMemberProvider = FutureProvider.family<bool, String>((ref, communityId) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return false;
  
  final repository = ref.read(communityRepositoryProvider);
  return await repository.isMember(communityId, user.uid);
});

class CommunityDetailScreen extends ConsumerWidget {
  final String communityId;
  
  const CommunityDetailScreen({
    super.key,
    required this.communityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityAsync = ref.watch(communityProvider(communityId));
    final isMemberAsync = ref.watch(isCommunityMemberProvider(communityId));
    final currentUser = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
      ),
      body: communityAsync.when(
        data: (community) {
          if (community == null) {
            return const Center(child: Text('Community not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Community Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.groups,
                                size: 30,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    community.name,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${community.members.length} members',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          community.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Actions
                isMemberAsync.when(
                  data: (isMember) {
                    if (isMember) {
                      return Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final user = currentUser.value;
                              if (user != null) {
                                try {
                                  final chatRepo = ref.read(chatRepositoryProvider);
                                  // Show loading indicator
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Opening chat...'),
                                          ],
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                  
                                  final chatId = await chatRepo.getOrCreateCommunityChat(communityId);
                                  if (context.mounted) {
                                    // Refresh member status after joining chat
                                    ref.invalidate(isCommunityMemberProvider(communityId));
                                    context.push('/chat/$chatId', extra: {
                                      'isCommunityChat': true,
                                      'otherUserName': community.name,
                                    } as Map<String, dynamic>);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to open chat: ${e.toString()}'),
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                        action: SnackBarAction(
                                          label: 'Retry',
                                          onPressed: () {
                                            // Retry logic would go here
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.chat),
                            label: const Text('Open Chat'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final user = currentUser.value;
                              if (user != null) {
                                await ref.read(communityRepositoryProvider).leaveCommunity(
                                  communityId,
                                  user.uid,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Left community')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Leave Community'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return ElevatedButton.icon(
                        onPressed: () async {
                          final user = currentUser.value;
                          if (user != null) {
                            await ref.read(communityRepositoryProvider).joinCommunity(
                              communityId,
                              user.uid,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Joined community!')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Join Community'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      );
                    }
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                const SizedBox(height: 24),
                
                // Make Friends Section
                isMemberAsync.when(
                  data: (isMember) {
                    if (!isMember) return const SizedBox.shrink();
                    
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Make Friends',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connect with other members of this community',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Show members list to add as friends
                                context.push('/communities/$communityId/members');
                              },
                              icon: const Icon(Icons.people),
                              label: const Text('View Members'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

