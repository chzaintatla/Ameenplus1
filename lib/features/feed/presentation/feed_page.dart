import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import 'providers/feed_providers.dart';
import 'widgets/deed_card.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deedsAsync = ref.watch(deedsFeedProvider);
    final currentUser = ref.watch(currentUserProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(deedsFeedProvider);
      },
      child: CustomScrollView(
        slivers: [
          // Hero Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 12),
                  _QuickActionsCard(
                    onCreateDeed: () {
                      context.push('/create-deed');
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Deeds List
          deedsAsync.when(
            data: (deeds) {
              if (deeds.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No deeds yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to share a good deed!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/create-deed'),
                          icon: const Icon(Icons.add),
                          label: const Text('Share a Deed'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final deed = deeds[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DeedCard(
                        deed: deed,
                        currentUserId: currentUser.value?.uid,
                        onTap: () {
                          // TODO: Navigate to deed detail
                        },
                        onComment: () {
                          // TODO: Show comments
                        },
                      ),
                    );
                  },
                  childCount: deeds.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading deeds',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(deedsFeedProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: <Color>[scheme.primary, scheme.primaryContainer],
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ameen+',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Share a deed, inspire someone, earn reward.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.secondary.withValues(alpha: 0.25),
            child: Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback? onCreateDeed;
  
  const _QuickActionsCard({this.onCreateDeed});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _ActionChip(
              icon: Icons.book_outlined,
              label: 'Share Ayah',
              onTap: onCreateDeed ?? () {},
            ),
            _ActionChip(
              icon: Icons.format_quote_outlined,
              label: 'Share Hadith',
              onTap: onCreateDeed ?? () {},
            ),
            _ActionChip(
              icon: Icons.volunteer_activism_outlined,
              label: 'Request Dua',
              onTap: onCreateDeed ?? () {},
            ),
            _ActionChip(
              icon: Icons.image_outlined,
              label: 'Islamic Card',
              onTap: onCreateDeed ?? () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: colorScheme.primary),
      label: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: colorScheme.surface,
      side: BorderSide(color: colorScheme.primary),
      onPressed: onTap,
    );
  }
}
