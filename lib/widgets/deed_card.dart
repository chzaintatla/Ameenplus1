import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../theme/ameen_theme.dart';
import '../utils/app_constants.dart';
import '../models/deed_model.dart';
import '../network/repositories/deeds_repository.dart';
import '../providers/follow_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/comments_providers.dart';
import '../providers/deeds_providers.dart';
import '../network/repositories/comments_repository.dart';
import '../models/comment_model.dart';

class DeedCard extends ConsumerWidget {
  final DeedModel deed;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onComment;

  const DeedCard({
    super.key,
    required this.deed,
    this.currentUserId,
    this.onTap,
    this.onComment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final isLiked = currentUserId != null && deed.isLikedBy(currentUserId!);
    final isOwnPost = currentUserId == deed.userId;
    final isFollowingAsync = isOwnPost
        ? null
        : currentUserId != null
            ? ref.watch(isFollowingProvider({
                'followerId': currentUserId!,
                'followingId': deed.userId,
              }))
            : null;

    final isFavoritedAsync = currentUserId != null
        ? ref.watch(isFavoritedProvider({
            'deedId': deed.id,
            'userId': currentUserId!,
          }))
        : null;

    return Card(
      margin: EdgeInsets.only(bottom: mediaQuery.size.height * 0.015),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: mediaQuery.size.width * 0.06,
                      backgroundImage: deed.userPhotoUrl != null
                          ? CachedNetworkImageProvider(deed.userPhotoUrl!)
                          : null,
                      child: deed.userPhotoUrl == null
                          ? Icon(Icons.person, size: mediaQuery.size.width * 0.06)
                          : null,
                    ),
                    if (deed.isValidated)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified,
                            size: mediaQuery.size.width * 0.03,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: mediaQuery.size.width * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              deed.userName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        timeago.format(deed.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (!isOwnPost && currentUserId != null)
                  isFollowingAsync?.when(
                    data: (isFollowing) => TextButton(
                      onPressed: () async {
                        final repository = ref.read(followRepositoryProvider);
                        try {
                          if (isFollowing) {
                            await repository.unfollowUser(
                              currentUserId!,
                              deed.userId,
                            );
                          } else {
                            await repository.followUser(
                              currentUserId!,
                              deed.userId,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    ) ??
                    const SizedBox.shrink(),
                    loading: () => SizedBox(
                      width: mediaQuery.size.width * 0.05,
                      height: mediaQuery.size.width * 0.05,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ) ??
                  const SizedBox.shrink()
                else
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      if (isOwnPost)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) async {
                      if (value == 'delete' && currentUserId != null) {
                        try {
                          final repository = ref.read(deedsRepositoryProvider);
                          await repository.deleteDeed(deed.id, currentUserId!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post deleted')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
          if (deed.arabicText != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
              child: Text(
                deed.arabicText!,
                style: AmeenTheme.arabicTextStyle(
                  fontSize: mediaQuery.size.width * 0.05,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
          ],
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: deed.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Description copied to clipboard')),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
              child: Text(
                deed.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (deed.imageUrl != null && deed.imageUrl!.isNotEmpty) ...[
            SizedBox(height: mediaQuery.size.height * 0.01),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: deed.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load image',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (deed.mediaUrls.isNotEmpty) ...[
            SizedBox(height: mediaQuery.size.height * 0.01),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
                itemCount: deed.mediaUrls.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: deed.mediaUrls[index],
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 200,
                          height: 200,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 200,
                          height: 200,
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.error,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (deed.translation != null) ...{
            SizedBox(height: mediaQuery.size.height * 0.01),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
              child: Container(
                padding: EdgeInsets.all(mediaQuery.size.width * 0.03),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deed.translation!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          },
          if (deed.interests.isNotEmpty) ...[
            SizedBox(height: mediaQuery.size.height * 0.01),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.04),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: deed.interests.map((interest) {
                  return Chip(
                    label: Text(
                      interest,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
          ],
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: mediaQuery.size.width * 0.04,
              vertical: mediaQuery.size.height * 0.01,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '${deed.likesCount}',
                    color: isLiked
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    onTap: () async {
                      if (currentUserId != null) {
                        final repository = ref.read(deedsRepositoryProvider);
                        await repository.likeDeed(deed.id, currentUserId!);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.comment_outlined,
                    label: '${deed.commentsCount}',
                    onTap: () {
                      _showCommentsDialog(context, ref, deed.id);
                    },
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_outlined,
                    label: '${deed.sharesCount}',
                    onTap: () async {
                      if (currentUserId != null) {
                        final repository = ref.read(deedsRepositoryProvider);
                        await repository.shareDeed(deed.id, currentUserId!);
                        final shareText = '${deed.content}\n\nShared from Ameen+';
                        await Share.share(shareText);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Shared! +${AppConstants.xpPerShare} XP'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                if (deed.imageUrl != null && deed.imageUrl!.isNotEmpty)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.download_outlined,
                      label: 'Download',
                      onTap: () => _downloadFile(context, ref, deed.imageUrl!, 'image'),
                    ),
                  ),
                if (currentUserId != null)
                  Expanded(
                    child: isFavoritedAsync?.when(
                      data: (isFavorited) => _ActionButton(
                        icon: isFavorited ? Icons.bookmark : Icons.bookmark_border,
                        label: '',
                        color: isFavorited
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        onTap: () async {
                          final repository = ref.read(deedsRepositoryProvider);
                          final wasFavorited = isFavorited;
                          await repository.favoriteDeed(deed.id, currentUserId!);
                          if (context.mounted && !wasFavorited) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Favorited! +${AppConstants.xpPerFavorite} points'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),
                      loading: () => _ActionButton(
                        icon: Icons.bookmark_border,
                        label: '',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onTap: () {},
                      ),
                      error: (_, __) => _ActionButton(
                        icon: Icons.bookmark_border,
                        label: '',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onTap: () {},
                      ),
                    ) ??
                    _ActionButton(
                      icon: Icons.bookmark_border,
                      label: '',
                      onTap: () async {
                        final repository = ref.read(deedsRepositoryProvider);
                        await repository.favoriteDeed(deed.id, currentUserId!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Favorited! +${AppConstants.xpPerFavorite} points'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadFile(BuildContext context, WidgetRef ref, String url, String type) async {
    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = url.split('/').last;
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded to: $filePath'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () async {
                  final uri = Uri.file(filePath);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCommentsDialog(BuildContext context, WidgetRef ref, String deedId) {
    final mediaQuery = MediaQuery.of(context);
    final commentController = TextEditingController();
    final currentUser = ref.read(currentUserProvider).value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(mediaQuery.size.width * 0.05),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CommentModel>>(
                stream: ref.read(commentsRepositoryProvider).getComments(deedId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final comments = snapshot.data ?? [];

                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: mediaQuery.size.width * 0.15,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: mediaQuery.size.height * 0.02),
                          Text(
                            'No comments yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          SizedBox(height: mediaQuery.size.height * 0.01),
                          Text(
                            'Be the first to comment!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final isCommentLiked = currentUser != null &&
                          comment.isLikedBy(currentUser.id);

                      return Padding(
                        padding: EdgeInsets.only(bottom: mediaQuery.size.height * 0.015),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: mediaQuery.size.width * 0.05,
                              backgroundImage: comment.userPhotoUrl != null
                                  ? CachedNetworkImageProvider(comment.userPhotoUrl!)
                                  : null,
                              child: comment.userPhotoUrl == null
                                  ? Icon(Icons.person, size: mediaQuery.size.width * 0.05)
                                  : null,
                            ),
                            SizedBox(width: mediaQuery.size.width * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(mediaQuery.size.width * 0.03),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.userName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        SizedBox(height: mediaQuery.size.height * 0.005),
                                        Text(
                                          comment.content,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: mediaQuery.size.height * 0.005),
                                  Row(
                                    children: [
                                      Text(
                                        timeago.format(comment.createdAt),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      SizedBox(width: mediaQuery.size.width * 0.03),
                                      InkWell(
                                        onTap: () async {
                                          if (currentUser != null) {
                                            final repository =
                                                ref.read(commentsRepositoryProvider);
                                            await repository.likeComment(
                                              comment.id,
                                              currentUser.id,
                                            );
                                          }
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isCommentLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: mediaQuery.size.width * 0.04,
                                              color: isCommentLiked
                                                  ? Theme.of(context).colorScheme.error
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                            SizedBox(width: mediaQuery.size.width * 0.01),
                                            Text(
                                              '${comment.likesCount}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: mediaQuery.size.width * 0.04,
                          vertical: mediaQuery.size.height * 0.01,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  SizedBox(width: mediaQuery.size.width * 0.02),
                  IconButton(
                    onPressed: () async {
                      if (commentController.text.trim().isEmpty) return;
                      if (currentUser == null) return;

                      try {
                        final repository = ref.read(commentsRepositoryProvider);
                        await repository.addComment(
                          deedId: deedId,
                          userId: currentUser.id,
                          userName: currentUser.userMetadata?['display_name'] ?? 'User',
                          userPhotoUrl: currentUser.userMetadata?['avatar_url'],
                          content: commentController.text.trim(),
                        );
                        commentController.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Comment added! +${AppConstants.xpPerComment} XP'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: mediaQuery.size.width * 0.02,
          vertical: mediaQuery.size.height * 0.01,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: mediaQuery.size.width * 0.05,
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            if (label.isNotEmpty) ...[
              SizedBox(width: mediaQuery.size.width * 0.01),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
