import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../network/repositories/friends_repository.dart';
import '../../network/repositories/community_repository.dart';

class CommunityMembersScreen extends StatefulWidget {
  final String communityId;

  const CommunityMembersScreen({
    super.key,
    required this.communityId,
  });

  @override
  State<CommunityMembersScreen> createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  final CommunityRepository _communityRepo = CommunityRepository();
  final FriendsRepository _friendsRepo = FriendsRepository();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final community = await _communityRepo.getCommunity(widget.communityId);
      if (community == null) {
        if (mounted) {
          setState(() {
            _members = [];
            _isLoading = false;
          });
        }
        return;
      }

      final members = <Map<String, dynamic>>[];

      for (var memberId in community.members) {
        try {
          final userDoc = await supabase
              .from('users')
              .select()
              .eq('id', memberId)
              .maybeSingle();
          
          if (userDoc != null) {
            members.add({
              'id': memberId,
              'name': userDoc['display_name'] ?? userDoc['displayName'] ?? 'Unknown',
              'photoUrl': userDoc['avatar_url'] ?? userDoc['profilePicture'] ?? userDoc['photoUrl'],
            });
          } else {
            members.add({
              'id': memberId,
              'name': 'Unknown',
              'photoUrl': null,
            });
          }
        } catch (e) {
          members.add({
            'id': memberId,
            'name': 'Unknown',
            'photoUrl': null,
          });
        }
      }

      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Members'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
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
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _members.isEmpty
                  ? Center(
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
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isCurrentUser = member['id'] == currentUser?.uid;

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
                            currentUser?.uid ?? '',
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
                                final user = currentUser;
                                if (user != null) {
                                  try {
                                    await _friendsRepo.sendFriendRequest(
                                      user.uid,
                                      member['id'] as String,
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
                    ),
    );
  }

  static Future<bool> _checkIfFriends(String userId1, String userId2) async {
    if (userId1.isEmpty || userId2.isEmpty) return false;

    try {
      final supabase = Supabase.instance.client;
      final userDoc = await supabase
          .from('users')
          .select('friends')
          .eq('id', userId1)
          .maybeSingle();
      
      if (userDoc == null) return false;

      final friendsList = List<String>.from(userDoc['friends'] ?? []);
      return friendsList.contains(userId2);
    } catch (e) {
      return false;
    }
  }
}
