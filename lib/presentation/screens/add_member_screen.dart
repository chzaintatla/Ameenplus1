import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../network/repositories/follow_repository.dart';

Stream<List<Map<String, dynamic>>> _getPublicProfileUsersStream() async* {
  final supabase = Supabase.instance.client;
  final currentUser = FirebaseAuth.instance.currentUser;
  
  try {
    final stream = supabase
        .from('users')
        .stream(primaryKey: ['id']);

    await for (final data in stream) {
      final users = <Map<String, dynamic>>[];
      
      for (final item in data) {
        final userId = item['id'] as String;
        final isPublic = item['is_profile_public'] as bool? ?? false;
        
        if (!isPublic || (currentUser != null && userId == currentUser.uid)) {
          continue;
        }
        
        users.add({
          'uid': userId,
          'displayName': item['display_name'] ?? item['displayName'] ?? 'User',
          'photoUrl': item['avatar_url'] ?? item['photoUrl'] ?? item['profilePicture'],
          'bio': item['bio'],
          'interests': List<String>.from(item['interests'] ?? []),
          'points': (item['points'] as num?)?.toInt() ?? 0,
          'followersCount': (item['followers_count'] as num?)?.toInt() ?? 0,
        });
      }
      
      yield users;
    }
  } catch (e) {
    yield <Map<String, dynamic>>[];
  }
}

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final FollowRepository _followRepo = FollowRepository();
  Stream<List<Map<String, dynamic>>>? _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _getPublicProfileUsersStream();
  }

  void _reloadUsers() {
    setState(() {
      _usersStream = _getPublicProfileUsersStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final usersStream = _usersStream ?? _getPublicProfileUsersStream();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Members'),
            Text(
              'Find users with public profiles',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: usersStream,
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
                    'Error loading users',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _reloadUsers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final users = snapshot.data ?? [];
          
          return _buildUsersList(context, currentUser, users);
        },
      ),
    );
  }

  Widget _buildUsersList(BuildContext context, User? currentUser, List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No users with public profiles available',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _reloadUsers();
      },
      child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final userId = user['uid'] as String;
                final displayName = user['displayName'] as String;
                final photoUrl = user['photoUrl'] as String?;
                final bio = user['bio'] as String?;
                final interests = user['interests'] as List<String>;
                final points = user['points'] as int;
                final followersCount = user['followersCount'] as int;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bio != null && bio.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (interests.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: interests.take(3).map((interest) {
                              return Chip(
                                label: Text(
                                  interest,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.black
                                        : null,
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$points points',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.people,
                              size: 14,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$followersCount followers',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: currentUser == null
                        ? const SizedBox.shrink()
                        : StreamBuilder<bool>(
                            stream: _followRepo.watchIsFollowing(
                              currentUser.uid,
                              userId,
                            ),
                            builder: (context, snapshot) {
                              final isFollowing = snapshot.data ?? false;
                              
                              if (isFollowing) {
                                return OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await _followRepo.unfollowUser(
                                        currentUser.uid,
                                        userId,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Unfollowed $displayName'),
                                            backgroundColor: Theme.of(context).colorScheme.primary,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Theme.of(context).colorScheme.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Following'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                );
                              }
                              
                              return ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    await _followRepo.followUser(
                                      currentUser.uid,
                                      userId,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Now following $displayName'),
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text('Follow'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
          );
    }
  }
