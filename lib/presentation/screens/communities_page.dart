import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/community_model.dart';
import '../../network/repositories/community_repository.dart';
import '../../network/repositories/chat_repository.dart';

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({super.key});

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CommunityRepository _communityRepo = CommunityRepository();
  final ChatRepository _chatRepo = ChatRepository();

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

  Future<void> _navigateToCommunityChat(BuildContext context, String communityId, String communityName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to chat')),
      );
      return;
    }

    try {
      final chatId = await _chatRepo.getOrCreateCommunityChat(communityId, user.uid);
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
                _MyCommunitiesTab(onNavigateToChat: _navigateToCommunityChat, communityRepo: _communityRepo),
                _ExploreCommunitiesTab(onNavigateToChat: _navigateToCommunityChat, communityRepo: _communityRepo),
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
                _showCreateCommunityDialog(context);
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

  void _showCreateCommunityDialog(BuildContext context) {
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
                initialValue: selectedCategory,
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

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in to create a community')),
                );
                return;
              }

              try {
                final community = CommunityModel(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  createdBy: user.uid,
                  members: [user.uid],
                  admins: [user.uid],
                  category: selectedCategory,
                  isPublic: true,
                  createdAt: DateTime.now(),
                );

                await _communityRepo.createCommunity(community);

                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {}); // Trigger rebuild to refresh streams
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

}

class _MyCommunitiesTab extends StatefulWidget {
  final Future<void> Function(BuildContext, String, String) onNavigateToChat;
  final CommunityRepository communityRepo;
  
  const _MyCommunitiesTab({
    required this.onNavigateToChat,
    required this.communityRepo,
  });

  @override
  State<_MyCommunitiesTab> createState() => _MyCommunitiesTabState();
}

class _MyCommunitiesTabState extends State<_MyCommunitiesTab> {
  Stream<List<CommunityModel>>? _communitiesStream;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _communitiesStream = widget.communityRepo.getUserCommunities(currentUser.uid);
    }
  }

  void _reloadCommunities() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _communitiesStream = widget.communityRepo.getUserCommunities(currentUser.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final communitiesStream = _communitiesStream ?? (currentUser != null ? widget.communityRepo.getUserCommunities(currentUser.uid) : null);

    if (communitiesStream == null) {
      return const Center(child: Text('Please sign in to view communities'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        _reloadCommunities();
      },
      child: StreamBuilder<List<CommunityModel>>(
        stream: communitiesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final errorMessage = snapshot.error.toString();
            final isRateLimit = errorMessage.contains('ChannelRateLimitReached') ||
                               errorMessage.contains('Too many channels') ||
                               errorMessage.contains('Too many active connections');
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isRateLimit ? Icons.hourglass_empty : Icons.error_outline,
                      size: 64,
                      color: isRateLimit 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isRateLimit 
                          ? 'Connection Limit Reached'
                          : 'Error loading communities',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        isRateLimit
                            ? 'Too many active connections. Please wait a moment and try again.'
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
                      onPressed: _reloadCommunities,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final communities = snapshot.data ?? [];
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
              final isOwner = currentUser?.uid == community.creatorId;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: community.imageUrl != null && community.imageUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(community.imageUrl!)
                        : null,
                    child: community.imageUrl == null || community.imageUrl!.isEmpty
                        ? Icon(
                            Icons.groups_rounded,
                            color: Colors.white,
                          )
                        : null,
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
                      await widget.onNavigateToChat(context, community.id, community.name);
                    },
                    child: const Text('Chat'),
                  ),
                  onTap: () async {
                    await widget.onNavigateToChat(context, community.id, community.name);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ExploreCommunitiesTab extends StatefulWidget {
  final Future<void> Function(BuildContext, String, String) onNavigateToChat;
  final CommunityRepository communityRepo;
  
  const _ExploreCommunitiesTab({
    required this.onNavigateToChat,
    required this.communityRepo,
  });

  @override
  State<_ExploreCommunitiesTab> createState() => _ExploreCommunitiesTabState();
}

class _ExploreCommunitiesTabState extends State<_ExploreCommunitiesTab> {
  Stream<List<CommunityModel>>? _communitiesStream;

  @override
  void initState() {
    super.initState();
    _communitiesStream = widget.communityRepo.getCommunities();
  }

  void _reloadCommunities() {
    setState(() {
      _communitiesStream = widget.communityRepo.getCommunities();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final communitiesStream = _communitiesStream ?? widget.communityRepo.getCommunities();

    return RefreshIndicator(
      onRefresh: () async {
        _reloadCommunities();
      },
      child: StreamBuilder<List<CommunityModel>>(
        stream: communitiesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final errorMessage = snapshot.error.toString();
            final isRateLimit = errorMessage.contains('ChannelRateLimitReached') ||
                               errorMessage.contains('Too many channels') ||
                               errorMessage.contains('Too many active connections');
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isRateLimit ? Icons.hourglass_empty : Icons.error_outline,
                      size: 64,
                      color: isRateLimit 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isRateLimit 
                          ? 'Connection Limit Reached'
                          : 'Error loading communities',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        isRateLimit
                            ? 'Too many active connections. Please wait a moment and try again.'
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
                      onPressed: _reloadCommunities,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final communities = snapshot.data ?? [];
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
              final isMember = currentUser != null && community.members.contains(currentUser.uid);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: community.imageUrl != null && community.imageUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(community.imageUrl!)
                        : null,
                    child: community.imageUrl == null || community.imageUrl!.isEmpty
                        ? Icon(
                            Icons.groups_rounded,
                            color: Colors.white,
                          )
                        : null,
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
                            await widget.onNavigateToChat(context, community.id, community.name);
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
                              await widget.communityRepo.joinCommunity(community.id, currentUser.uid);
                              if (context.mounted) {
                                setState(() {}); // Trigger rebuild to refresh streams
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
                      await widget.onNavigateToChat(context, community.id, community.name);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
