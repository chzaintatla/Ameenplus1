import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../network/repositories/deeds_repository.dart';
import '../../models/deed_model.dart';
import '../../widgets/deed_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DeedsRepository _deedsRepository = DeedsRepository();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final mediaQuery = MediaQuery.of(context);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Favorites'),
        ),
        body: const Center(
          child: Text('Please sign in to view favorites'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: StreamBuilder<List<String>>(
        stream: _getFavoriteIdsStream(currentUser.uid),
        builder: (context, favIdsSnapshot) {
          if (!favIdsSnapshot.hasData || favIdsSnapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: mediaQuery.size.width * 0.15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(height: mediaQuery.size.height * 0.02),
                  Text(
                    'No favorites yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: mediaQuery.size.height * 0.01),
                  Text(
                    'Start favoriting posts to see them here!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          final favoriteIds = favIdsSnapshot.data!;
          
          return StreamBuilder<List<DeedModel>>(
            stream: _deedsRepository.getDeedsFeed(limit: 100),
            builder: (context, deedsSnapshot) {
              if (!deedsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDeeds = deedsSnapshot.data!;
              final favoriteDeeds = allDeeds
                  .where((deed) => favoriteIds.contains(deed.id))
                  .toList();

              if (favoriteDeeds.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: mediaQuery.size.width * 0.15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: mediaQuery.size.height * 0.02),
                      Text(
                        'No favorite posts found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: mediaQuery.size.width * 0.04,
                  vertical: mediaQuery.size.height * 0.02,
                ),
                itemCount: favoriteDeeds.length,
                itemBuilder: (context, index) {
                  final deed = favoriteDeeds[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: mediaQuery.size.height * 0.01,
                    ),
                    child: DeedCard(
                      deed: deed,
                      currentUserId: currentUser.uid,
                      onTap: () {},
                      onComment: () {},
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<String>> _getFavoriteIdsStream(String userId) {
    return _deedsRepository.getFavoriteIdsStream(userId);
  }
}

