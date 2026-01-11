import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_providers.dart';
import '../../providers/habits_providers.dart';
import '../../providers/deeds_providers.dart';
import '../../models/habit_model.dart';
import '../../models/deed_model.dart';
import '../../utils/app_constants.dart';

class HabitsHistoryScreen extends ConsumerStatefulWidget {
  const HabitsHistoryScreen({super.key});

  @override
  ConsumerState<HabitsHistoryScreen> createState() => _HabitsHistoryScreenState();
}

class _HabitsHistoryScreenState extends ConsumerState<HabitsHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Habits History')),
        body: const Center(child: Text('Please sign in to view history')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Created Habits', icon: Icon(Icons.add_circle_outline)),
            Tab(text: 'Completed', icon: Icon(Icons.check_circle_outline)),
            Tab(text: 'Points', icon: Icon(Icons.star_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreatedHabitsTab(currentUser.uid),
          _buildCompletedTab(currentUser.uid),
          _buildPointsTab(currentUser.uid),
        ],
      ),
    );
  }

  Widget _buildCreatedHabitsTab(String userId) {
    final habitsAsync = ref.watch(userHabitsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userHabitsProvider);
      },
      child: habitsAsync.when(
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No habits created yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return _buildHabitCard(habit);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
              Text('Error loading habits: $e'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedTab(String userId) {
    final deedsAsync = ref.watch(userDeedsProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userDeedsProvider(userId));
      },
      child: deedsAsync.when(
        data: (deeds) {
          // Filter only validated/completed deeds
          final completedDeeds = deeds.where((d) => d.isValidated).toList();

          if (completedDeeds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No completed deeds yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete habits and post deeds to see them here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedDeeds.length,
            itemBuilder: (context, index) {
              final deed = completedDeeds[index];
              return _buildDeedCard(deed);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
              Text('Error loading deeds: $e'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointsTab(String userId) {
    final habitsAsync = ref.watch(userHabitsProvider);
    final deedsAsync = ref.watch(userDeedsProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userHabitsProvider);
        ref.invalidate(userDeedsProvider(userId));
      },
      child: FutureBuilder(
        future: Future.wait([
          habitsAsync.when(
            data: (habits) => Future.value(habits),
            loading: () => Future.value(<HabitModel>[]),
            error: (_, __) => Future.value(<HabitModel>[]),
          ),
          deedsAsync.when(
            data: (deeds) => Future.value(deeds),
            loading: () => Future.value(<DeedModel>[]),
            error: (_, __) => Future.value(<DeedModel>[]),
          ),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final habits = snapshot.data![0] as List<HabitModel>;
          final deeds = snapshot.data![1] as List<DeedModel>;

          // Calculate points
          int habitPoints = 0;
          int deedPoints = 0;
          int totalCompletions = 0;
          int totalStreakDays = 0;

          for (var habit in habits) {
            totalCompletions += habit.totalCompletions;
            totalStreakDays += habit.streakDays;
            // Points from habit completions
            habitPoints += habit.totalCompletions * AppConstants.xpPerHabitComplete;
            // Points from streaks
            habitPoints += habit.streakDays * AppConstants.xpPerStreakDay;
          }

          // Points from validated deeds
          final validatedDeeds = deeds.where((d) => d.isValidated).length;
          deedPoints = validatedDeeds * AppConstants.xpPerDeedPost;

          final totalPoints = habitPoints + deedPoints;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Points Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPointsStat(
                            context,
                            'Total Points',
                            totalPoints.toString(),
                            Icons.star,
                            Colors.amber,
                          ),
                          _buildPointsStat(
                            context,
                            'Habit Points',
                            habitPoints.toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                          _buildPointsStat(
                            context,
                            'Deed Points',
                            deedPoints.toString(),
                            Icons.article,
                            Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Detailed Breakdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Breakdown',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildBreakdownItem(
                        context,
                        'Habit Completions',
                        totalCompletions.toString(),
                        '$totalCompletions × ${AppConstants.xpPerHabitComplete} XP',
                        habitPoints > 0 ? (totalCompletions * AppConstants.xpPerHabitComplete) : 0,
                      ),
                      const Divider(),
                      _buildBreakdownItem(
                        context,
                        'Streak Days',
                        totalStreakDays.toString(),
                        '$totalStreakDays × ${AppConstants.xpPerStreakDay} XP',
                        habitPoints > 0 ? (totalStreakDays * AppConstants.xpPerStreakDay) : 0,
                      ),
                      const Divider(),
                      _buildBreakdownItem(
                        context,
                        'Validated Deeds',
                        validatedDeeds.toString(),
                        '$validatedDeeds × ${AppConstants.xpPerDeedPost} XP',
                        deedPoints,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPointsStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(
    BuildContext context,
    String label,
    String count,
    String formula,
    int points,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  formula,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Text(
            '$points XP',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(HabitModel habit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          habit.habitName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Type: ${habit.habitType}'),
            Text('Created: ${DateFormat('MMM dd, yyyy').format(habit.createdAt)}'),
            Text('Completions: ${habit.totalCompletions}'),
            Text('Streak: ${habit.streakDays} days'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${habit.totalCompletions * AppConstants.xpPerHabitComplete + habit.streakDays * AppConstants.xpPerStreakDay} XP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeedCard(DeedModel deed) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: deed.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  deed.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
              )
            : CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.article,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
        title: Text(
          deed.content.length > 50
              ? '${deed.content.substring(0, 50)}...'
              : deed.content,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Posted: ${DateFormat('MMM dd, yyyy').format(deed.createdAt)}'),
            if (deed.validationReason != null)
              Text(
                'Validated: ${deed.validationReason}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${AppConstants.xpPerDeedPost} XP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Icon(Icons.verified, color: Colors.green, size: 16),
          ],
        ),
      ),
    );
  }
}
