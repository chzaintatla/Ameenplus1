import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/community_model.dart';
import '../../network/repositories/community_repository.dart';
import '../../network/repositories/chat_repository.dart';
import '../../services/storage_service.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;

  const CommunityDetailScreen({
    super.key,
    required this.communityId,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final CommunityRepository _communityRepo = CommunityRepository();
  final ChatRepository _chatRepo = ChatRepository();
  final ImagePicker _imagePicker = ImagePicker();

  Future<bool> _checkIsMember(String communityId, String userId) async {
    return await _communityRepo.isMember(communityId, userId);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
      ),
      body: FutureBuilder<CommunityModel?>(
        future: _communityRepo.getCommunity(widget.communityId),
        builder: (context, communitySnapshot) {
          if (communitySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (communitySnapshot.hasError) {
            return Center(child: Text('Error: ${communitySnapshot.error}'));
          }
          final community = communitySnapshot.data;
          if (community == null) {
            return const Center(child: Text('Community not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  backgroundImage: community.imageUrl != null
                                      ? CachedNetworkImageProvider(community.imageUrl!)
                                      : null,
                                  child: community.imageUrl == null
                                      ? Icon(
                                          Icons.groups,
                                          size: 30,
                                          color: Theme.of(context).colorScheme.primary,
                                        )
                                      : null,
                                ),
                                // Edit button for community owner
                                if (currentUser != null && community.createdBy == currentUser.uid)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: () => _pickAndUploadCommunityImage(community.id, currentUser.uid),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).scaffoldBackgroundColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    community.name,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${community.members.length} members',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          community.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<bool>(
                  future: currentUser != null ? _checkIsMember(widget.communityId, currentUser.uid) : Future.value(false),
                  builder: (context, isMemberSnapshot) {
                    if (isMemberSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final isMember = isMemberSnapshot.data ?? false;
                    
                    if (isMember) {
                      return Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (currentUser != null) {
                                try {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Opening chat...'),
                                          ],
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }

                                  final chatId = await _chatRepo.getOrCreateCommunityChat(widget.communityId, currentUser.uid);
                                  if (context.mounted) {
                                    setState(() {}); // Refresh member status
                                    context.push('/chat/$chatId', extra: {
                                      'isCommunityChat': true,
                                      'otherUserName': community.name,
                                    } as Map<String, dynamic>);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to open chat: ${e.toString()}'),
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.chat),
                            label: const Text('Open Chat'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              if (currentUser != null) {
                                await _communityRepo.leaveCommunity(
                                  widget.communityId,
                                  currentUser.uid,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Left community')),
                                  );
                                  setState(() {}); // Refresh member status
                                }
                              }
                            },
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Leave Community'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return ElevatedButton.icon(
                        onPressed: () async {
                          if (currentUser != null) {
                            await _communityRepo.joinCommunity(
                              widget.communityId,
                              currentUser.uid,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Joined community!')),
                              );
                              setState(() {}); // Refresh member status
                            }
                          }
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Join Community'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                FutureBuilder<bool>(
                  future: currentUser != null ? _checkIsMember(widget.communityId, currentUser.uid) : Future.value(false),
                  builder: (context, isMemberSnapshot) {
                    if (isMemberSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    final isMember = isMemberSnapshot.data ?? false;
                    if (!isMember) return const SizedBox.shrink();

                    return Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Make Friends',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Connect with other members of this community',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    context.push('/communities/${widget.communityId}/members');
                                  },
                                  icon: const Icon(Icons.people),
                                  label: const Text('View Members'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Members',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Discover and follow users with public profiles',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    context.push('/add-member');
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Add Member'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndUploadCommunityImage(String communityId, String userId) async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image...')),
      );

      final file = File(image.path);
      if (await file.length() > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be less than 5MB')),
        );
        return;
      }

      final fileName = '${communityId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'community_images/$fileName';

      final downloadUrl = await StorageService.uploadFile(
        bucket: 'media',
        filePath: filePath,
        file: file,
        contentType: 'image/jpeg',
        upsert: true,
      );

      await _communityRepo.updateCommunityImage(communityId, userId, downloadUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community image updated!'), backgroundColor: Colors.green),
      );
      
      setState(() {}); // Refresh to show new image
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
