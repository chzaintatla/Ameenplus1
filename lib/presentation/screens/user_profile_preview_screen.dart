import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/follow_providers.dart';
import '../../providers/deeds_providers.dart';
import '../../network/repositories/user_profile_repository.dart';
import '../../models/deed_model.dart';
import '../../widgets/deed_card.dart';

final userProfilePreviewProvider = FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final repository = ref.read(userProfileRepositoryProvider);
  return await repository.getProfile(userId);
});

final followersCountProvider = StreamProvider.family<int, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => (doc.data()?['followersCount'] as num?)?.toInt() ?? 0);
});

final followingCountProvider = StreamProvider.family<int, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => (doc.data()?['followingCount'] as num?)?.toInt() ?? 0);
});

class UserProfilePreviewScreen extends ConsumerWidget {
  final String userId;

  const UserProfilePreviewScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = ref.watch(authStateProvider).value;
    final profileAsync = ref.watch(userProfilePreviewProvider(userId));
    final isOwnProfile = currentUser?.uid == userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'User not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: mediaQuery.size.width * 0.15,
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            backgroundImage: profile.photoUrl != null
                                ? CachedNetworkImageProvider(profile.photoUrl!)
                                : null,
                            child: profile.photoUrl == null
                                ? Icon(
                                    Icons.person_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: mediaQuery.size.width * 0.15,
                                  )
                                : null,
                          ),
                          SizedBox(height: mediaQuery.size.height * 0.02),
                          Text(
                            profile.displayName ?? 'User',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isOwnProfile) ...[
                            SizedBox(height: mediaQuery.size.height * 0.015),
                            _buildFollowButton(context, ref, currentUser?.uid ?? '', userId),
                          ],
                          SizedBox(height: mediaQuery.size.height * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildFollowerCount(context, ref, userId, true, mediaQuery),
                              SizedBox(width: mediaQuery.size.width * 0.08),
                              _buildFollowerCount(context, ref, userId, false, mediaQuery),
                            ],
                          ),
                          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                            SizedBox(height: mediaQuery.size.height * 0.02),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                profile.bio!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          if (profile.interests.isNotEmpty) ...[
                            SizedBox(height: mediaQuery.size.height * 0.015),
                            Wrap(
                              spacing: mediaQuery.size.width * 0.02,
                              runSpacing: mediaQuery.size.width * 0.02,
                              alignment: WrapAlignment.center,
                              children: profile.interests.map((interest) {
                                return Chip(
                                  label: Text(
                                    interest,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
                  child: _buildPostsSection(context, ref, userId, mediaQuery),
                ),
              ),
            ],
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
                'Error loading profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton(BuildContext context, WidgetRef ref, String currentUserId, String targetUserId) {
    if (currentUserId.isEmpty || currentUserId == targetUserId) {
      return const SizedBox.shrink();
    }

    final isFollowingAsync = ref.watch(isFollowingProvider({
      'followerId': currentUserId,
      'followingId': targetUserId,
    }));

    return isFollowingAsync.when(
      data: (isFollowing) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final repository = ref.read(followRepositoryProvider);
            try {
              if (isFollowing) {
                await repository.unfollowUser(
                  followerId: currentUserId,
                  followingId: targetUserId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unfollowed')),
                  );
                }
              } else {
                await repository.followUser(
                  followerId: currentUserId,
                  followingId: targetUserId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Following')),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
          icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add),
          label: Text(isFollowing ? 'Following' : 'Follow'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing
                ? Theme.of(context).colorScheme.surfaceVariant
                : Theme.of(context).colorScheme.primary,
            foregroundColor: isFollowing
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
      loading: () => const SizedBox(
        width: double.infinity,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFollowerCount(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool isFollowers,
    MediaQueryData mediaQuery,
  ) {
    final countAsync = isFollowers
        ? ref.watch(followersCountProvider(userId))
        : ref.watch(followingCountProvider(userId));

    return InkWell(
      onTap: () {
        context.push('/followers-following/$userId', extra: {
          'initialTab': isFollowers ? 0 : 1,
        } as Map<String, dynamic>);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: countAsync.when(
          data: (count) => Column(
            children: [
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Text(
                isFollowers ? 'Followers' : 'Following',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          loading: () => Column(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 4),
              Text(
                isFollowers ? 'Followers' : 'Following',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          error: (_, __) => Column(
            children: [
              const Text('0'),
              Text(
                isFollowers ? 'Followers' : 'Following',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsSection(BuildContext context, WidgetRef ref, String userId, MediaQueryData mediaQuery) {
    final userDeedsAsync = ref.watch(userDeedsProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: mediaQuery.size.height * 0.02),
        Row(
          children: [
            Icon(
              Icons.grid_on,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: mediaQuery.size.width * 0.02),
            Text(
              'Posts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        SizedBox(height: mediaQuery.size.height * 0.015),
        userDeedsAsync.when(
          data: (deeds) {
            if (deeds.isEmpty) {
              return Container(
                padding: EdgeInsets.all(mediaQuery.size.width * 0.08),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_outlined,
                      size: mediaQuery.size.width * 0.15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.02),
                    Text(
                      'No posts yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: mediaQuery.size.width * 0.02,
                mainAxisSpacing: mediaQuery.size.width * 0.02,
                childAspectRatio: 1,
              ),
              itemCount: deeds.length,
              itemBuilder: (context, index) {
                final deed = deeds[index];
                return GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(mediaQuery.size.width * 0.05),
                        ),
                      ),
                      builder: (context) => DraggableScrollableSheet(
                        initialChildSize: 0.9,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        expand: false,
                        builder: (context, scrollController) => SingleChildScrollView(
                          controller: scrollController,
                          child: Padding(
                            padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                            child: DeedCard(
                              deed: deed,
                              currentUserId: ref.read(authStateProvider).value?.uid,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          deed.content,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => SizedBox(
            height: mediaQuery.size.height * 0.3,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Container(
            padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 48,
                ),
                SizedBox(height: mediaQuery.size.height * 0.01),
                Text(
                  'Error loading posts',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: mediaQuery.size.height * 0.02),
      ],
    );
  }
}

