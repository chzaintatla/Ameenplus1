import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/ameen_theme.dart';
import '../../providers/leaderboard_providers.dart';
import '../../models/leaderboard_user.dart';
import '../../providers/auth_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(globalLeaderboardProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(globalLeaderboardProvider),
          ),
        ],
      ),
      body: leaderboardAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No leaderboard data yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start earning XP by posting deeds and completing habits!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Find current user's rank
          int? currentUserRank;
          if (currentUser != null) {
            currentUserRank = users.indexWhere((u) => u.uid == currentUser.uid);
            if (currentUserRank == -1) {
              currentUserRank = null;
            } else {
              currentUserRank = currentUserRank + 1;
            }
          }

          return Column(
            children: [
              // Top 3 Podium
              if (users.length >= 3) _buildTopThreePodium(context, users),
              
              // Full Leaderboard List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final rank = index + 1;
                    final isCurrentUser = currentUser != null && user.uid == currentUser.uid;
                    final isTopThree = rank <= 3;

                    return _LeaderboardCard(
                      user: user,
                      rank: rank,
                      isTopThree: isTopThree,
                      isCurrentUser: isCurrentUser,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => Center(
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
                'Error loading leaderboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(globalLeaderboardProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopThreePodium(BuildContext context, List<LeaderboardUser> users) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: Theme.of(context).brightness == Brightness.dark
            ? LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : AmeenTheme.goldGradient,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            'Top Performers',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              _buildPodiumPlace(context, users[1], 2, false),
              // 1st Place
              _buildPodiumPlace(context, users[0], 1, true),
              // 3rd Place
              _buildPodiumPlace(context, users[2], 3, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(
    BuildContext context,
    LeaderboardUser user,
    int rank,
    bool isFirst,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: isFirst ? 35 : 28,
          backgroundImage: user.photoUrl != null
              ? CachedNetworkImageProvider(user.photoUrl!)
              : null,
          child: user.photoUrl == null
              ? Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: isFirst ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          user.displayName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${user.points} XP',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final LeaderboardUser user;
  final int rank;
  final bool isTopThree;
  final bool isCurrentUser;

  const _LeaderboardCard({
    required this.user,
    required this.rank,
    required this.isTopThree,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.secondaryContainer,
      Theme.of(context).colorScheme.tertiary,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isTopThree ? 4 : 2,
      color: isCurrentUser
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isTopThree
            ? BorderSide(color: rankColors[rank - 1], width: 2)
            : isCurrentUser
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: isTopThree ? 28 : 24,
              backgroundImage: user.photoUrl != null
                  ? CachedNetworkImageProvider(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: isTopThree ? 20 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            if (isTopThree)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: rankColors[rank - 1],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: isTopThree || isCurrentUser
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'You',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.star,
              size: 16,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              '${user.points} XP',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AmeenTheme.primaryGreen,
                  ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isTopThree
                ? rankColors[rank - 1].withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '#$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isTopThree
                  ? rankColors[rank - 1]
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
