import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/ameen_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../deeds/models/deed_model.dart';
import '../../../deeds/data/deeds_repository.dart';

class DeedCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isLiked = currentUserId != null && deed.isLikedBy(currentUserId!);
    final deedTypeIcon = _getDeedTypeIcon(deed.deedType);
    final deedTypeColor = _getDeedTypeColor(deed.deedType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: deed.userPhotoUrl != null
                        ? CachedNetworkImageProvider(deed.userPhotoUrl!)
                        : null,
                    child: deed.userPhotoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deed.userName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          timeago.format(deed.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Deed Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: deedTypeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(deedTypeIcon, size: 16, color: deedTypeColor),
                        const SizedBox(width: 4),
                        Text(
                          _getDeedTypeLabel(deed.deedType),
                          style: TextStyle(
                            color: deedTypeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Arabic Text (if exists)
              if (deed.arabicText != null) ...[
                Text(
                  deed.arabicText!,
                  style: AmeenTheme.arabicTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),
              ],
              
              // Content
              Text(
                deed.content,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Translation (if exists)
              if (deed.translation != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    deed.translation!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
              
              // Reference (if exists)
              if (deed.reference != null) ...[
                const SizedBox(height: 8),
                Text(
                  '— ${deed.reference}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
              
              // Image (if exists)
              if (deed.imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: deed.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Actions
              Row(
                children: [
                  _ActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '${deed.likesCount}',
                    color: isLiked ? Colors.red : Colors.grey,
                    onTap: () async {
                      if (currentUserId != null) {
                        final repository = DeedsRepository();
                        await repository.likeDeed(deed.id, currentUserId!);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    icon: Icons.comment_outlined,
                    label: '${deed.commentsCount}',
                    onTap: onComment ?? () {},
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: () {
                      // TODO: Implement share
                    },
                  ),
                  const Spacer(),
                  if (deed.category != null)
                    Chip(
                      label: Text(deed.category!),
                      avatar: const Icon(Icons.category, size: 16),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeedTypeIcon(String deedType) {
    switch (deedType) {
      case AppConstants.deedAyah:
        return Icons.menu_book;
      case AppConstants.deedHadith:
        return Icons.format_quote;
      case AppConstants.deedQuote:
        return Icons.auto_awesome;
      case AppConstants.deedTask:
        return Icons.task;
      default:
        return Icons.article;
    }
  }

  Color _getDeedTypeColor(String deedType) {
    switch (deedType) {
      case AppConstants.deedAyah:
        return AmeenTheme.sacredGold;
      case AppConstants.deedHadith:
        return AmeenTheme.primaryGreen;
      case AppConstants.deedQuote:
        return AmeenTheme.accentTeal;
      case AppConstants.deedTask:
        return AmeenTheme.accentEmerald;
      default:
        return Colors.grey;
    }
  }

  String _getDeedTypeLabel(String deedType) {
    switch (deedType) {
      case AppConstants.deedAyah:
        return 'Ayah';
      case AppConstants.deedHadith:
        return 'Hadith';
      case AppConstants.deedQuote:
        return 'Quote';
      case AppConstants.deedTask:
        return 'Task';
      default:
        return 'Deed';
    }
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color ?? Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

