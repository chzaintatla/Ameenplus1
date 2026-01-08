import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/theme_mode_provider.dart';
import '../../providers/deeds_providers.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/deed_card.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

final followersCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) {
        if (data.isEmpty) return 0;
        return (data.first['followers_count'] as num?)?.toInt() ?? 0;
      });
});

final followingCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) {
        if (data.isEmpty) return 0;
        return (data.first['following_count'] as num?)?.toInt() ?? 0;
      });
});

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    ref.listen(authStateProvider, (prev, next) async {
      final user = next.asData?.value;
      if (user == null) return;
      await ref.read(userProfileRepositoryProvider).ensureProfileForUser(user);
      ref.read(profileViewModelProvider.notifier).loadProfile();
    });

    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.green.shade900,
        foregroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(),
              SwitchListTile(
              title: const Text('Public Profile'),
              subtitle: const Text('Controls visibility of profile details'),
              value: profileAsync.valueOrNull?.isProfilePublic ?? false,
              onChanged: (value) async {
                final user = authState.value;
                if (user != null) {
                  await ref.read(userProfileRepositoryProvider).setProfilePublic(
                        uid: user.id,
                        isPublic: value,
                      );
                  if (mounted && context.mounted) {
                    ref.invalidate(currentUserProfileProvider);
                    Navigator.pop(context);
                  }
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                onChanged: (ThemeMode? newMode) {
                  if (newMode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(newMode);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
              ),
            ),
            const Divider(),
            authState.when(
              data: (user) {
                if (user == null) return const SizedBox.shrink();
                return ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () async {
                    if (context.mounted) {
                      Navigator.pop(context);
                      final shouldSignOut = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (shouldSignOut == true && context.mounted) {
                        try {
                          await ref.read(authRepositoryProvider).signOut();
                          if (context.mounted) {
                            context.go('/auth');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error signing out: $e'),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                child: authState.when(
                  data: (user) {
                    final isSignedIn = user != null;
                    final profile = profileState.profile ?? profileAsync.valueOrNull;
                    final userId = user?.id;

                    return Column(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: mediaQuery.size.width * 0.15,
                                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                                backgroundImage: profile?.photoUrl != null
                                    ? NetworkImage(profile!.photoUrl!)
                                    : (user?.userMetadata?['avatar_url'] != null
                                        ? NetworkImage(user!.userMetadata!['avatar_url'] as String)
                                        : null),
                                child: profile?.photoUrl == null && user?.userMetadata?['avatar_url'] == null
                                    ? Icon(Icons.person_rounded,
                                        color: scheme.primary,
                                        size: mediaQuery.size.width * 0.15)
                                    : null,
                              ),
                              if (isSignedIn)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: mediaQuery.size.width * 0.04,
                                    backgroundColor: scheme.primary,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit, size: 16),
                                      color: scheme.onPrimary,
                                      onPressed: () => context.push('/profile/edit'),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.02),
                        Text(
                          profile?.displayName ??
                              user?.userMetadata?['display_name'] as String? ??
                              'User',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (userId != null) ...[
                          SizedBox(height: mediaQuery.size.height * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildFollowerCount(context, userId, true, mediaQuery),
                              SizedBox(width: mediaQuery.size.width * 0.08),
                              _buildFollowerCount(context, userId, false, mediaQuery),
                            ],
                          ),
                        ],
                        SizedBox(height: mediaQuery.size.height * 0.015),
                        if (_hasDetails(profile)) ...[
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                            label: Text(_isExpanded ? 'Less' : 'More'),
                          ),
                          if (_isExpanded) ...[
                            SizedBox(height: mediaQuery.size.height * 0.01),
                            if (profile?.email != null && profile!.email!.isNotEmpty) ...[
                              if (isSignedIn && (userId == user?.id || profile.isEmailPublic)) ...[
                                _buildInfoRow(
                                  context,
                                  Icons.email_outlined,
                                  'Email',
                                  profile.email!,
                                  mediaQuery,
                                ),
                                SizedBox(height: mediaQuery.size.height * 0.01),
                              ],
                            ],
                            if (profile?.phoneNumber != null && profile!.phoneNumber!.isNotEmpty) ...[
                              if (isSignedIn && (userId == user?.id || profile.isPhonePublic)) ...[
                                _buildInfoRow(
                                  context,
                                  Icons.phone_outlined,
                                  'Phone',
                                  profile.phoneNumber!,
                                  mediaQuery,
                                ),
                                SizedBox(height: mediaQuery.size.height * 0.01),
                              ],
                            ],
                            if (profile?.age != null) ...[
                              _buildInfoRow(
                                context,
                                Icons.cake_outlined,
                                'Age',
                                '${profile?.age} years',
                                mediaQuery,
                              ),
                              SizedBox(height: mediaQuery.size.height * 0.01),
                            ],
                            if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.description_outlined,
                                          size: mediaQuery.size.width * 0.05,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        SizedBox(width: mediaQuery.size.width * 0.02),
                                        Text(
                                          'Bio',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: mediaQuery.size.height * 0.01),
                                    Text(
                                      profile.bio!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: mediaQuery.size.height * 0.015),
                            ],
                          ],
                        ],
                        if (profile?.interests.isNotEmpty == true && _isExpanded) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite_outline,
                                      size: mediaQuery.size.width * 0.05,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    SizedBox(width: mediaQuery.size.width * 0.02),
                                    Text(
                                      'Interests',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: mediaQuery.size.height * 0.01),
                                Wrap(
                                  spacing: mediaQuery.size.width * 0.02,
                                  runSpacing: mediaQuery.size.width * 0.02,
                                  children: profile!.interests.map((interest) {
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
                            ),
                          ),
                          SizedBox(height: mediaQuery.size.height * 0.015),
                        ],
                        if (isSignedIn) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/profile/edit'),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit Profile'),
                            ),
                          ),
                        ],
                        if (!isSignedIn) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/auth'),
                              icon: const Icon(Icons.login),
                              label: const Text('Sign In'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => SizedBox(
                    height: mediaQuery.size.height * 0.2,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text(
                    e.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
        authState.when(
          data: (user) {
            if (user == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
                child: _buildPostsSection(context, user.id, mediaQuery),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
      )
    );
  }

  bool _hasDetails(UserProfile? profile) {
    if (profile == null) return false;
    return (profile.email != null && profile.email!.isNotEmpty) ||
        (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) ||
        profile.age != null ||
        (profile.bio != null && profile.bio!.isNotEmpty) ||
        profile.interests.isNotEmpty;
  }

  Widget _buildFollowerCount(BuildContext context, String userId, bool isFollowers, MediaQueryData mediaQuery) {
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

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    MediaQueryData mediaQuery,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: mediaQuery.size.width * 0.05,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: mediaQuery.size.width * 0.03),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection(BuildContext context, String userId, MediaQueryData mediaQuery) {
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
                    SizedBox(height: mediaQuery.size.height * 0.01),
                    Text(
                      'Share your first post!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                              currentUserId: userId,
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
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
                SizedBox(height: mediaQuery.size.height * 0.01),
                TextButton.icon(
                  onPressed: () {
                    ref.invalidate(userDeedsProvider(userId));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
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
