import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/follow_providers.dart';
import '../../network/repositories/follow_repository.dart';

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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
          _buildFollowersTab(context, mediaQuery, currentUser?.uid),
          _buildFollowingTab(context, mediaQuery, currentUser?.uid),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: mediaQuery.size.height * 0.02),
                Text(
                  'No followers yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
          itemCount: followers.length,
          itemBuilder: (context, index) {
            final user = followers[index];
            final userId = user['uid'] as String;
            final displayName = user['displayName'] as String? ?? 'User';
            final photoUrl = user['photoUrl'] as String? ?? user['profilePicture'] as String?;
            final isCurrentUser = userId == currentUserId;

            return Card(
              margin: EdgeInsets.only(bottom: mediaQuery.size.height * 0.01),
              child: ListTile(
                leading: CircleAvatar(
                  radius: mediaQuery.size.width * 0.06,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                title: Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _getSafeEmail(user, currentUserId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isCurrentUser
                    ? null
                    : _buildFollowButton(context, currentUserId ?? '', userId),
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
            SizedBox(height: mediaQuery.size.height * 0.02),
            Text(
              'Error loading followers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(followersListProvider(widget.userId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: mediaQuery.size.height * 0.02),
                Text(
                  'Not following anyone yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
          itemCount: following.length,
          itemBuilder: (context, index) {
            final user = following[index];
            final userId = user['uid'] as String;
            final displayName = user['displayName'] as String? ?? 'User';
            final photoUrl = user['photoUrl'] as String? ?? user['profilePicture'] as String?;
            final isCurrentUser = userId == currentUserId;

            return Card(
              margin: EdgeInsets.only(bottom: mediaQuery.size.height * 0.01),
              child: ListTile(
                leading: CircleAvatar(
                  radius: mediaQuery.size.width * 0.06,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                title: Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _getSafeEmail(user, currentUserId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isCurrentUser
                    ? null
                    : _buildFollowButton(context, currentUserId ?? '', userId),
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
            SizedBox(height: mediaQuery.size.height * 0.02),
            Text(
              'Error loading following',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(followingListProvider(widget.userId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(BuildContext context, String currentUserId, String targetUserId) {
    if (currentUserId.isEmpty) {
      return const SizedBox.shrink();
    }

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
              await repository.unfollowUser(
                followerId: currentUserId,
                followingId: targetUserId,
              );
            } else {
              await repository.followUser(
                followerId: currentUserId,
                followingId: targetUserId,
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
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
    final userId = user['uid'] as String?;
    final email = user['email'] as String?;
    final isEmailPublic = user['isEmailPublic'] as bool? ?? false;
    
    if (email == null || email.isEmpty) return '';
    if (currentUserId == null) return 'Email hidden';
    if (userId == currentUserId) return email;
    if (!isEmailPublic) return 'Email hidden';
    return email;
  }
}

