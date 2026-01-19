import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../network/repositories/deeds_repository.dart';
import '../../widgets/deed_card.dart';
import '../../models/deed_model.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final DeedsRepository _deedsRepository = DeedsRepository();
  late Stream<List<DeedModel>> _feedStream;
  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _feedStream = _deedsRepository.getDeedsFeed(limit: 20);
  }

  Future<void> _refreshFeed() async {
    if (mounted) {
      setState(() {
        _feedStream = _deedsRepository.getDeedsFeed(limit: 20);
        _streamKey = UniqueKey();
      });
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return RefreshIndicator(
      onRefresh: _refreshFeed,
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
          StreamBuilder<List<DeedModel>>(
            key: _streamKey,
            stream: _feedStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: mediaQuery.size.width * 0.15,
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                            snapshot.error.toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.02),
                        ElevatedButton(
                          onPressed: _refreshFeed,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final deeds = snapshot.data ?? [];
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
                      key: ValueKey('deed_${deed.id}'),
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.size.width * 0.04,
                        vertical: mediaQuery.size.height * 0.01,
                      ),
                      child: DeedCard(
                        key: ValueKey('deedcard_${deed.id}'),
                        deed: deed,
                        currentUserId: currentUser?.uid,
                        onTap: () {},
                        onComment: () {},
                      ),
                    );
                  },
                  childCount: deeds.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                ),
              );
            },
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
    final currentUser = FirebaseAuth.instance.currentUser;

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
