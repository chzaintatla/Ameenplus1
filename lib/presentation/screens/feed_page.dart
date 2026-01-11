import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/feed_providers.dart';
import '../../widgets/deed_card.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final deedsAsync = ref.watch(deedsFeedProvider);
    final currentUser = ref.watch(currentUserProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(deedsFeedProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mediaQuery.size.width * 0.04,
                vertical: mediaQuery.size.height * 0.02,
              ),
              child: _CreatePostCard(
                onCreateDeed: () {
                  context.push('/create-deed');
                },
              ),
            ),
          ),
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
                          size: mediaQuery.size.width * 0.15,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.02),
                        Text(
                          'No posts yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.01),
                        Text(
                          'Be the first to share something!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.03),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/create-deed'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Post'),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.size.width * 0.04,
                        vertical: mediaQuery.size.height * 0.01,
                      ),
                      child: DeedCard(
                        deed: deed,
                        currentUserId: currentUser.value?.uid,
                        onTap: () {},
                        onComment: () {},
                      ),
                    );
                  },
                  childCount: deeds.length,
                ),
              );
            },
            loading: () => SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: mediaQuery.size.width * 0.15,
                        color: Theme.of(context).colorScheme.error),
                    SizedBox(height: mediaQuery.size.height * 0.02),
                    Text(
                      'Error loading posts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.01),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.size.width * 0.1,
                      ),
                      child: Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.02),
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

class _CreatePostCard extends StatelessWidget {
  final VoidCallback? onCreateDeed;

  const _CreatePostCard({this.onCreateDeed});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = context.findAncestorStateOfType<ConsumerState>()?.ref
        .read(currentUserProvider)
        .value;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onCreateDeed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
          child: Row(
            children: [
              CircleAvatar(
                radius: mediaQuery.size.width * 0.06,
                backgroundImage: currentUser?.photoURL != null
                    ? NetworkImage(currentUser!.photoURL!)
                    : null,
                child: currentUser?.photoURL == null
                    ? Icon(Icons.person, size: mediaQuery.size.width * 0.06)
                    : null,
              ),
              SizedBox(width: mediaQuery.size.width * 0.03),
              Expanded(
                child: Text(
                  'What\'s on your mind?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Icon(
                Icons.photo_library_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
