import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_providers.dart';
import '../../providers/community_providers.dart';
import '../../providers/chat_providers.dart';
import '../../utils/app_constants.dart';
import '../../models/community_model.dart';
import 'community_detail_screen.dart';

class CommunitiesPage extends ConsumerStatefulWidget {
  const CommunitiesPage({super.key});

  @override
  ConsumerState<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends ConsumerState<CommunitiesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'My Communities'),
              Tab(text: 'Explore'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MyCommunitiesTab(onNavigateToChat: _navigateToCommunityChat),
                _ExploreCommunitiesTab(onNavigateToChat: _navigateToCommunityChat),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () {
                context.push('/ai-chatbot');
              },
              heroTag: 'chatbot',
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Theme.of(context).colorScheme.secondary,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.black87,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/chatbot.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              onPressed: () {
                _showCreateCommunityDialog(context, ref);
              },
              heroTag: 'create-community',
              icon: const Icon(Icons.add),
              label: const Text('Create Community'),
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCommunityDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'General';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Community'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Community Name *',
                  hintText: 'e.g., New Muslims Support',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe your community...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'General', child: Text('General')),
                  DropdownMenuItem(value: 'Support', child: Text('Support')),
                  DropdownMenuItem(value: 'Learning', child: Text('Learning')),
                  DropdownMenuItem(value: 'Events', child: Text('Events')),
                ],
                onChanged: (value) => selectedCategory = value ?? 'General',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  descController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final authState = ref.read(authStateProvider);
              final user = authState.value;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in to create a community')),
                );
                return;
              }

              try {
                final repository = ref.read(communityRepositoryProvider);
                final community = CommunityModel(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  createdBy: user.id,
                  members: [user.id],
                  admins: [user.id],
                  category: selectedCategory,
                  isPublic: true,
                  createdAt: DateTime.now(),
                );

                await repository.createCommunity(community);

                if (context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(userCommunitiesProvider);
                  ref.invalidate(communitiesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Community created successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToCommunityChat(BuildContext context, WidgetRef ref, String communityId, String communityName) async {
    final authState = ref.read(authStateProvider);
    final user = authState.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to chat')),
      );
      return;
    }

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final chatId = await chatRepo.getOrCreateCommunityChat(communityId);
      if (context.mounted) {
        context.push('/chat/$chatId', extra: {
          'isCommunityChat': true,
          'otherUserName': communityName,
        } as Map<String, dynamic>);
      }
    } catch (e) {
      if (context.mounted) {
        final errorMessage = e.toString();
        String userMessage;
        if (errorMessage.contains('permission-denied') || errorMessage.contains('permission')) {
          userMessage = 'You do not have permission to access this chat. Please try again or contact support.';
        } else if (errorMessage.contains('authenticated') || errorMessage.contains('sign in')) {
          userMessage = 'Please sign in to access community chats.';
        } else {
          userMessage = 'Error opening chat: ${errorMessage.contains('Exception:') ? errorMessage.split('Exception:').last.trim() : errorMessage}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _MyCommunitiesTab extends ConsumerWidget {
  final Future<void> Function(BuildContext, WidgetRef, String, String) onNavigateToChat;
  
  const _MyCommunitiesTab({required this.onNavigateToChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCommunitiesAsync = ref.watch(userCommunitiesProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userCommunitiesProvider);
      },
      child: userCommunitiesAsync.when(
        data: (communities) {
          if (communities.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No communities yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a community or join one from Explore',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final community = communities[index];
              final isOwner = currentUser?.id == community.creatorId;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(community.name)),
                      if (isOwner)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Owner',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(community.description),
                      const SizedBox(height: 4),
                      Text('${community.members.length} members'),
                    ],
                  ),
                  trailing: FilledButton(
                    onPressed: () async {
                      await onNavigateToChat(context, ref, community.id, community.name);
                    },
                    child: const Text('Chat'),
                  ),
                  onTap: () async {
                    await onNavigateToChat(context, ref, community.id, community.name);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
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
                'Error loading communities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreCommunitiesTab extends ConsumerWidget {
  final Future<void> Function(BuildContext, WidgetRef, String, String) onNavigateToChat;
  
  const _ExploreCommunitiesTab({required this.onNavigateToChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(communitiesProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(communitiesProvider);
      },
      child: communitiesAsync.when(
        data: (communities) {
          if (communities.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.explore_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No communities to explore',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final community = communities[index];
              final isMember = currentUser != null && community.members.contains(currentUser.id);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(community.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(community.description),
                      const SizedBox(height: 4),
                      Text('${community.members.length} members'),
                    ],
                  ),
                  trailing: isMember
                      ? FilledButton(
                          onPressed: () async {
                            await onNavigateToChat(context, ref, community.id, community.name);
                          },
                          child: const Text('Chat'),
                        )
                      : OutlinedButton(
                          onPressed: () async {
                            if (currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please sign in to join communities')),
                              );
                              return;
                            }

                            try {
                              final repository = ref.read(communityRepositoryProvider);
                              await repository.joinCommunity(community.id, currentUser.id);
                              if (context.mounted) {
                                ref.invalidate(userCommunitiesProvider);
                                ref.invalidate(communitiesProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Joined community successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error joining community: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Join'),
                        ),
                  onTap: () async {
                    if (isMember) {
                      await onNavigateToChat(context, ref, community.id, community.name);
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
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
                'Error loading communities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
