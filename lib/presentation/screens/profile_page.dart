import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/deed_card.dart';
import '../../models/deed_model.dart';
import '../../network/repositories/auth_repository.dart';
import '../../network/repositories/user_profile_repository.dart';
import '../../network/repositories/deeds_repository.dart';

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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isExpanded = false;
  final AuthRepository _authRepo = AuthRepository();
  final UserProfileRepository _profileRepo = SupabaseUserProfileRepository(Supabase.instance.client);
  final DeedsRepository _deedsRepo = DeedsRepository();
  late final ProfileViewModel _profileViewModel;
  ProfileState _profileState = ProfileState.initial();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _profileViewModel = ProfileViewModel(
      authRepository: _authRepo,
      profileRepository: _profileRepo,
    );
    _profileViewModel.addListener(_onProfileStateChanged);
    _loadThemeMode();
    _setupAuthListener();
  }

  void _onProfileStateChanged() {
    if (mounted) {
      setState(() {
        _profileState = _profileViewModel.state;
      });
    }
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeModeIndex];
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    setState(() {
      _themeMode = mode;
    });
  }

  void _setupAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _profileRepo.ensureProfileForUser(user);
        _profileViewModel.loadProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _profileViewModel.removeListener(_onProfileStateChanged);
    _profileViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;

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
              value: _profileState.profile?.isProfilePublic ?? false,
              onChanged: (value) async {
                if (currentUser != null) {
                  await _profileRepo.setProfilePublic(
                    uid: currentUser.uid,
                    isPublic: value,
                  );
                  if (mounted && context.mounted) {
                    _profileViewModel.loadProfile();
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
                value: _themeMode,
                onChanged: (ThemeMode? newMode) {
                  if (newMode != null) {
                    _setThemeMode(newMode);
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
            if (currentUser != null) ...[
              ListTile(
                leading: const Icon(Icons.bookmark),
                title: const Text('Favourites'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/favorites');
                },
              ),
              const Divider(),
              ListTile(
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
                        await _authRepo.signOut();
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
              ),
            ],
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
                child: StreamBuilder<UserProfile?>(
                  stream: currentUser != null ? _profileRepo.watchProfile(currentUser.uid) : null,
                  builder: (context, profileSnapshot) {
                    final profile = _profileState.profile ?? profileSnapshot.data;
                    final userId = currentUser?.uid;
                    final isSignedIn = currentUser != null;

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
                                    : (currentUser?.photoURL != null
                                        ? NetworkImage(currentUser!.photoURL!)
                                        : null),
                                child: profile?.photoUrl == null && currentUser?.photoURL == null
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
                              currentUser?.displayName ??
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
                              if (isSignedIn && (userId == currentUser?.uid || profile.isEmailPublic)) ...[
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
                              if (isSignedIn && (userId == currentUser?.uid || profile.isPhonePublic)) ...[
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
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
            child: currentUser != null ? _buildPostsSection(context, currentUser.uid, mediaQuery) : const SizedBox.shrink(),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildFollowerCount(BuildContext context, String userId, bool isFollowers, MediaQueryData mediaQuery) {
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
            const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {}); // Reload stream
                  },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
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

  Widget _buildFallbackContent(BuildContext context, DeedModel deed, MediaQueryData mediaQuery) {
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

  bool _hasDetails(UserProfile? profile) {
    if (profile == null) return false;
    return (profile.email != null && profile.email!.isNotEmpty) ||
        (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) ||
        profile.age != null ||
        (profile.bio != null && profile.bio!.isNotEmpty) ||
        profile.interests.isNotEmpty;
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
}
