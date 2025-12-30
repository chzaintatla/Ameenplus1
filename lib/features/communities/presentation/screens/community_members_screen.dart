import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../friends/data/friends_repository.dart';
import '../../data/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

final communityMembersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, communityId) async {
  final repository = ref.read(communityRepositoryProvider);
  final community = await repository.getCommunity(communityId);
  if (community == null) return [];
  
  final firestore = FirebaseFirestore.instance;
  final members = <Map<String, dynamic>>[];
  
  for (var memberId in community.members) {
    try {
      final userDoc = await firestore.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        // Only include public data - name and photo URL
        // Email and phone are private and not included
        members.add({
          'id': memberId,
          'name': data['displayName'] ?? 'Unknown',
          'photoUrl': data['profilePicture'] ?? data['photoUrl'],
        });
      } else {
        // Fallback: add with minimal info
        members.add({
          'id': memberId,
          'name': 'Unknown',
          'photoUrl': null,
        });
      }
    } catch (e) {
      // Skip if user not found
      members.add({
        'id': memberId,
        'name': 'Unknown',
        'photoUrl': null,
      });
    }
  }
  
  return members;
});

class CommunityMembersScreen extends ConsumerWidget {
  final String communityId;
  
  const CommunityMembersScreen({
    super.key,
    required this.communityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(communityMembersProvider(communityId));
    final currentUser = ref.watch(authStateProvider);
    final friendsRepo = FriendsRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Members'),
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
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
                    'No members found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final isCurrentUser = member['id'] == currentUser.value?.uid;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: member['photoUrl'] != null
                        ? NetworkImage(member['photoUrl'] as String)
                        : null,
                    child: member['photoUrl'] == null
                        ? Text(
                            (member['name'] as String).isNotEmpty
                                ? (member['name'] as String)[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  title: Text(
                    member['name'] as String,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Email and phone are private - only show name and profile pic
                  subtitle: null,
                  trailing: isCurrentUser
                      ? Chip(
                          label: const Text('You'),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        )
                      : FutureBuilder<bool>(
                          future: _checkIfFriends(
                            FirebaseFirestore.instance,
                            currentUser.value?.uid ?? '',
                            member['id'] as String,
                          ),
                          builder: (context, snapshot) {
                            final areFriends = snapshot.data ?? false;
                            if (areFriends) {
                              return Chip(
                                label: const Text('Friend'),
                                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                              );
                            }
                            return ElevatedButton.icon(
                              onPressed: () async {
                                final user = currentUser.value;
                                if (user != null) {
                                  try {
                                    await friendsRepo.sendFriendRequest(
                                      senderId: user.uid,
                                      senderName: user.displayName ?? 'User',
                                      senderPhotoUrl: user.photoURL,
                                      receiverId: member['id'] as String,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Friend request sent to ${member['name']}'),
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
                                }
                              },
                              icon: const Icon(Icons.person_add, size: 18),
                              label: const Text('Add Friend'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            );
                          },
                        ),
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
                'Error loading members',
                style: Theme.of(context).textTheme.titleMedium,
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

  /// Helper function to check if two users are friends
  static Future<bool> _checkIfFriends(
    FirebaseFirestore firestore,
    String userId1,
    String userId2,
  ) async {
    if (userId1.isEmpty || userId2.isEmpty) return false;
    
    try {
      final userDoc = await firestore.collection('users').doc(userId1).get();
      if (!userDoc.exists) return false;
      
      final friendsList = List<String>.from(userDoc.data()?['friends'] ?? []);
      return friendsList.contains(userId2);
    } catch (e) {
      return false;
    }
  }
}

