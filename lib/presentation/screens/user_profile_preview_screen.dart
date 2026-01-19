import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../network/repositories/user_profile_repository.dart';
import '../../network/repositories/follow_repository.dart';
import '../../network/repositories/deeds_repository.dart';
import '../../widgets/deed_card.dart';
import '../../models/deed_model.dart';

Stream<int> _getFollowersCountStream(String userId) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) {
        if (data.isEmpty) return 0;
        return (data.first['followers_count'] as num?)?.toInt() ?? 0;
      });
}

Stream<int> _getFollowingCountStream(String userId) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) {
        if (data.isEmpty) return 0;
        return (data.first['following_count'] as num?)?.toInt() ?? 0;
      });
}

class UserProfilePreviewScreen extends StatefulWidget {
  final String userId;

  const UserProfilePreviewScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfilePreviewScreen> createState() => _UserProfilePreviewScreenState();
}

class _UserProfilePreviewScreenState extends State<UserProfilePreviewScreen> {
  final UserProfileRepository _profileRepo = SupabaseUserProfileRepository(Supabase.instance.client);
  final FollowRepository _followRepo = FollowRepository();
  final DeedsRepository _deedsRepo = DeedsRepository();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnProfile = currentUser?.uid == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: FutureBuilder<UserProfile?>(
        future: _profileRepo.getProfile(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
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
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          final profile = snapshot.data;
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
                            profile.displayName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isOwnProfile) ...[
                            SizedBox(height: mediaQuery.size.height * 0.015),
                            _buildFollowButton(context, currentUser?.uid ?? '', widget.userId),
                          ],
                          SizedBox(height: mediaQuery.size.height * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildFollowerCount(context, widget.userId, true, mediaQuery),
                              SizedBox(width: mediaQuery.size.width * 0.08),
                              _buildFollowerCount(context, widget.userId, false, mediaQuery),
                            ],
                          ),
                          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                            SizedBox(height: mediaQuery.size.height * 0.02),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).brightness == Brightness.light
                                          ? Colors.black
                                          : null,
                                    ),
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
                  child: _buildPostsSection(context, widget.userId, mediaQuery),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFollowButton(BuildContext context, String currentUserId, String targetUserId) {
    if (currentUserId.isEmpty || currentUserId == targetUserId) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: _followRepo.isFollowing(currentUserId, targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: double.infinity,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final isFollowing = snapshot.data ?? false;
        
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                if (isFollowing) {
                  await _followRepo.unfollowUser(currentUserId, targetUserId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unfollowed')),
                    );
                    setState(() {}); // Refresh button state
                  }
                } else {
                  await _followRepo.followUser(currentUserId, targetUserId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Following')),
                    );
                    setState(() {}); // Refresh button state
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
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: isFollowing
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowerCount(
    BuildContext context,
    String userId,
    bool isFollowers,
    MediaQueryData mediaQuery,
  ) {
    return InkWell(
      onTap: () {
        context.push('/followers-following/$userId', extra: {
          'initialTab': isFollowers ? 0 : 1,
        } as Map<String, dynamic>);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: StreamBuilder<int>(
          stream: isFollowers ? _getFollowersCountStream(userId) : _getFollowingCountStream(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
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
              );
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  const Text('0'),
                  Text(
                    isFollowers ? 'Followers' : 'Following',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              );
            }
            final count = snapshot.data ?? 0;
            return Column(
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildPostsSection(BuildContext context, String userId, MediaQueryData mediaQuery) {

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
        StreamBuilder<List<DeedModel>>(
          stream: _deedsRepo.getUserDeeds(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: mediaQuery.size.height * 0.3,
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Container(
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
              );
            }
            final deeds = snapshot.data ?? [];
            if (deeds.isEmpty) {
              return Container(
                padding: EdgeInsets.all(mediaQuery.size.width * 0.08),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                              currentUserId: FirebaseAuth.instance.currentUser?.uid,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: deed.imageUrl != null && deed.imageUrl!.isNotEmpty
                          ? Image.network(
                              deed.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => _buildFallbackContent(context, deed, mediaQuery),
                            )
                          : deed.mediaUrls.isNotEmpty
                              ? Image.network(
                                  deed.mediaUrls.first,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => _buildFallbackContent(context, deed, mediaQuery),
                                )
                              : _buildFallbackContent(context, deed, mediaQuery),
                    ),
                  ),
                );
              },
            );
          },
        ),
        SizedBox(height: mediaQuery.size.height * 0.02),
      ],
    );
  }

  Widget _buildFallbackContent(BuildContext context, deed, MediaQueryData mediaQuery) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: deed.content.isNotEmpty
          ? Center(
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
            )
          : Center(
              child: Icon(
                Icons.article_outlined,
                size: mediaQuery.size.width * 0.1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

