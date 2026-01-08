import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/follow_providers.dart';

class FollowersFollowingScreen extends ConsumerStatefulWidget {
  final String userId;
  final int initialTab;

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends ConsumerState<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Followers & Following'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowersTab(context, mediaQuery, currentUser?.id),
          _buildFollowingTab(context, mediaQuery, currentUser?.id),
        ],
      ),
    );
  }

  Widget _buildFollowersTab(BuildContext context, MediaQueryData mediaQuery, String? currentUserId) {
    final followersAsync = ref.watch(followersListProvider(widget.userId));

    return followersAsync.when(
      data: (followers) {
        if (followers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: mediaQuery.size.height * 0.02),
                const Text('No followers yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
          itemCount: followers.length,
          itemBuilder: (context, index) {
            final user = followers[index];
            final userId = user['id'] as String; // Supabase uses 'id'
            final displayName = user['display_name'] as String? ?? 'User';
            final photoUrl = user['photo_url'] as String?;
            final isCurrentUser = userId == currentUserId;

            return Card(
              margin: EdgeInsets.only(bottom: mediaQuery.size.height * 0.01),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(displayName),
                subtitle: Text(_getSafeEmail(user, currentUserId)),
                trailing: isCurrentUser
                    ? null
                    : _buildFollowButton(context, currentUserId ?? '', userId),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
    );
  }

  Widget _buildFollowingTab(BuildContext context, MediaQueryData mediaQuery, String? currentUserId) {
    final followingAsync = ref.watch(followingListProvider(widget.userId));

    return followingAsync.when(
      data: (following) {
        if (following.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: mediaQuery.size.height * 0.02),
                const Text('Not following anyone yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
          itemCount: following.length,
          itemBuilder: (context, index) {
            final user = following[index];
            final userId = user['id'] as String; // Supabase uses 'id'
            final displayName = user['display_name'] as String? ?? 'User';
            final photoUrl = user['photo_url'] as String?;
            final isCurrentUser = userId == currentUserId;

            return Card(
              margin: EdgeInsets.only(bottom: mediaQuery.size.height * 0.01),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(displayName),
                subtitle: Text(_getSafeEmail(user, currentUserId)),
                trailing: isCurrentUser
                    ? null
                    : _buildFollowButton(context, currentUserId ?? '', userId),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
    );
  }

  Widget _buildFollowButton(BuildContext context, String currentUserId, String targetUserId) {
    if (currentUserId.isEmpty) return const SizedBox.shrink();

    final isFollowingAsync = ref.watch(isFollowingProvider({
      'followerId': currentUserId,
      'followingId': targetUserId,
    }));

    return isFollowingAsync.when(
      data: (isFollowing) => TextButton(
        onPressed: () async {
          try {
            final repository = ref.read(followRepositoryProvider);
            if (isFollowing) {
              await repository.unfollowUser(currentUserId, targetUserId);
            } else {
              await repository.followUser(currentUserId, targetUserId);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            }
          }
        },
        child: Text(isFollowing ? 'Following' : 'Follow'),
      ),
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _getSafeEmail(Map<String, dynamic> user, String? currentUserId) {
    final userId = user['id'] as String?;
    final email = user['email'] as String?;
    final isEmailPublic = (user['is_email_public'] ?? user['isEmailPublic']) as bool? ?? false;
    
    if (email == null || email.isEmpty) return '';
    if (currentUserId == null) return 'Email hidden';
    if (userId == currentUserId) return email;
    if (!isEmailPublic) return 'Email hidden';
    return email;
  }
}
