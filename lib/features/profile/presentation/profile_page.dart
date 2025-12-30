import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/firebase/firebase_ready_provider.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../data/user_profile_repository.dart';
import '../presentation/viewmodels/profile_viewmodel.dart';
import 'profile_controller.dart';
import 'screens/edit_profile_screen.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes in build method
    ref.listen(authStateProvider, (prev, next) async {
      final user = next.asData?.value;
      if (user == null) return;

      final ready = await ref.read(firebaseReadyProvider.future);
      if (!ready) return;

      await ref.read(userProfileRepositoryProvider).ensureProfileForUser(user);
      
      // Load profile in ViewModel
      ref.read(profileViewModelProvider.notifier).loadProfile();
    });
    final scheme = Theme.of(context).colorScheme;
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final isAdminAsync = ref.watch(isAdminProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final themeMode = ref.watch(themeModeProvider);

    final controller = ref.read(profileControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: authState.when(
              data: (user) {
                final isSignedIn = user != null;
                final profile = profileState.profile ?? profileAsync.valueOrNull;

                return Column(
                  children: [
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: scheme.primary.withValues(alpha: 0.15),
                          backgroundImage: profile?.photoUrl != null
                              ? NetworkImage(profile!.photoUrl!)
                              : (user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null),
                          child: profile?.photoUrl == null && user?.photoURL == null
                              ? Icon(Icons.person_rounded, color: scheme.primary, size: 32)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                profile?.displayName ?? user?.displayName ?? (user?.isAnonymous == true ? 'Guest' : 'Not signed in'),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              profileAsync.maybeWhen(
                                data: (p) => Text(
                                  p == null ? '' : 'Points: ${p.points}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                orElse: () => Text(
                                  isSignedIn ? 'Loading profile…' : 'Sign in to sync points & privacy',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  profile.bio!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                              if (profile?.interests.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: profile!.interests.take(5).map((interest) {
                                    return Chip(
                                      label: Text(
                                        interest,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    );
                                  }).toList(),
                                ),
                              ],
                              // Show email/phone only if public or own profile
                              if (profile?.email != null && (isSignedIn || profile!.isEmailPublic)) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        profile!.email!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (profile?.phoneNumber != null && (isSignedIn || profile!.isPhonePublic)) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        profile!.phoneNumber!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (profile?.age != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cake_outlined,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Age: ${profile!.age}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (profile?.gender != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Gender: ${profile!.gender == 'male' ? 'Male' : profile!.gender == 'female' ? 'Female' : 'Prefer not to say'}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'signin_guest') {
                              await controller.signInGuest();
                            }
                            if (value == 'signout') {
                              await controller.signOut();
                            }
                            if (value == 'edit') {
                              context.push('/profile/edit');
                            }
                          },
                          itemBuilder: (context) {
                            return <PopupMenuEntry<String>>[
                              if (!isSignedIn) const PopupMenuItem(value: 'signin_guest', child: Text('Continue as Guest')),
                              if (isSignedIn) const PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
                              if (isSignedIn) const PopupMenuDivider(),
                              if (isSignedIn) const PopupMenuItem(value: 'signout', child: Text('Sign out')),
                            ];
                          },
                        ),
                      ],
                    ),
                    if (isSignedIn) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/profile/edit'),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Profile'),
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                e.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Leaderboard (Top 5)'),
                subtitle: const Text('Only name, score and profile pic are shown'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/leaderboard'),
              ),
              ...isAdminAsync.maybeWhen(
                data: (isAdmin) {
                  if (!isAdmin) return const <Widget>[];

                  return <Widget>[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Admin Portal'),
                      subtitle: const Text('Add deeds and content for the app'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/admin'),
                    ),
                  ];
                },
                orElse: () => const <Widget>[],
              ),
              const Divider(height: 1),
              profileAsync.when(
                data: (p) {
                  if (p == null) {
                    return const ListTile(
                      leading: Icon(Icons.lock_outline_rounded),
                      title: Text('Profile Privacy'),
                      subtitle: Text('Sign in to manage privacy'),
                    );
                  }
                  return SwitchListTile(
                    secondary: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Public profile'),
                    subtitle: const Text('Controls visibility of profile details (leaderboard stays public for top 5).'),
                    value: p.isProfilePublic,
                    onChanged: (value) async {
                      await controller.setProfilePublic(uid: p.uid, isPublic: value);
                    },
                  );
                },
                loading: () => const ListTile(
                  leading: Icon(Icons.lock_outline_rounded),
                  title: Text('Profile Privacy'),
                  subtitle: Text('Loading…'),
                ),
                error: (e, _) => ListTile(
                  title: Text(
                    e.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  themeMode == ThemeMode.light
                      ? Icons.light_mode_outlined
                      : themeMode == ThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : Icons.brightness_auto_outlined,
                ),
                title: const Text('Theme'),
                subtitle: Text(
                  themeMode == ThemeMode.light
                      ? 'Light'
                      : themeMode == ThemeMode.dark
                          ? 'Dark'
                          : 'System',
                ),
                trailing: PopupMenuButton<ThemeMode>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (mode) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: ThemeMode.light,
                      child: Row(
                        children: [
                          const Icon(Icons.light_mode_outlined),
                          const SizedBox(width: 8),
                          const Text('Light'),
                          if (themeMode == ThemeMode.light)
                            const Spacer(),
                          if (themeMode == ThemeMode.light)
                            Icon(Icons.check, color: scheme.primary),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: ThemeMode.dark,
                      child: Row(
                        children: [
                          const Icon(Icons.dark_mode_outlined),
                          const SizedBox(width: 8),
                          const Text('Dark'),
                          if (themeMode == ThemeMode.dark)
                            const Spacer(),
                          if (themeMode == ThemeMode.dark)
                            Icon(Icons.check, color: scheme.primary),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: ThemeMode.system,
                      child: Row(
                        children: [
                          const Icon(Icons.brightness_auto_outlined),
                          const SizedBox(width: 8),
                          const Text('System'),
                          if (themeMode == ThemeMode.system)
                            const Spacer(),
                          if (themeMode == ThemeMode.system)
                            Icon(Icons.check, color: scheme.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              firebaseReady.when(
                data: (ready) {
                  if (ready) {
                    return const ListTile(
                      leading: Icon(Icons.cloud_done_outlined),
                      title: Text('Firebase'),
                      subtitle: Text('Connected'),
                    );
                  }

                  return const ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('Firebase'),
                    subtitle: Text('Not configured yet (add google-services.json / GoogleService-Info.plist)'),
                  );
                },
                loading: () => const ListTile(
                  leading: Icon(Icons.cloud_outlined),
                  title: Text('Firebase'),
                  subtitle: Text('Checking…'),
                ),
                error: (e, _) => ListTile(
                  title: Text(
                    e.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.explore_outlined),
                title: const Text('Qibla'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/qibla'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Prayer Times'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/prayer-times'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Hijri Calendar'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/hijri-calendar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
