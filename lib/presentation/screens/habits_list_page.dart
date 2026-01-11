import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../utils/app_constants.dart';
import '../../models/habit_model.dart';
import '../../providers/habits_providers.dart';
import '../../utils/points_service.dart';

class HabitsListPage extends ConsumerStatefulWidget {
  const HabitsListPage({super.key});

  @override
  ConsumerState<HabitsListPage> createState() => _HabitsListPageState();
}

class _HabitsListPageState extends ConsumerState<HabitsListPage> {
  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(userHabitsProvider);
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              context.push('/habits-history');
            },
            tooltip: 'View History',
          ),
        ],
      ),
      body: _buildHabitsTab(habitsAsync, currentUser),
    );
  }

  Widget _buildHabitsTab(AsyncValue<List<HabitModel>> habitsAsync, currentUser) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userHabitsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          habitsAsync.when(
            data: (habits) => _buildStatsCard(context, habits, currentUser),
            loading: () => _buildStatsCard(context, [], currentUser),
            error: (_, __) => _buildStatsCard(context, [], currentUser),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Habits',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (currentUser != null)
                TextButton.icon(
                  onPressed: () {
                    _showAddHabitDialog(context, ref, currentUser.uid);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Habit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (currentUser != null) _buildNamazTracker(context, currentUser.uid),
          const SizedBox(height: 12),
          habitsAsync.when(
            data: (habits) {
              if (habits.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No habits yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start tracking your Islamic habits!',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showAddHabitDialog(context, ref, currentUser!.uid);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Your First Habit'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: habits.map((habit) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: Key(habit.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Habit'),
                            content: Text('Are you sure you want to delete "${habit.habitName}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (direction) async {
                        if (currentUser != null) {
                          try {
                            await ref.read(habitsRepositoryProvider).deleteHabit(
                              habit.id,
                              currentUser.uid,
                            );
                            ref.invalidate(userHabitsProvider);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${habit.habitName} deleted'),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting habit: $e'),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                      child: _buildHabitCard(context, ref, habit, currentUser?.uid),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading habits',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
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

  Widget _buildNamazTracker(BuildContext context, String userId) {
    final farzNamaz = [
      {'name': 'Fajr', 'icon': Icons.wb_sunny_outlined},
      {'name': 'Dhuhr', 'icon': Icons.wb_sunny},
      {'name': 'Asr', 'icon': Icons.wb_twilight},
      {'name': 'Maghrib', 'icon': Icons.nightlight_round},
      {'name': 'Isha', 'icon': Icons.nightlight_outlined},
    ];

    final nafalNamaz = [
      {'name': 'Tahajjud', 'icon': Icons.bedtime_outlined},
      {'name': 'Ishraq', 'icon': Icons.wb_sunny_outlined},
      {'name': 'Chasht', 'icon': Icons.wb_sunny},
      {'name': 'Awwabin', 'icon': Icons.nightlight_round},
      {'name': 'Witr', 'icon': Icons.nightlight_outlined},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mosque, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Namaz Tracker',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: PointsService().getDailyStats(userId),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {
                  'farzCount': 0,
                  'nafalCount': 0,
                  'totalPoints': 0.0,
                };

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Farz Namaz (1 point each, max 5)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: farzNamaz.map((namaz) {
                        return _buildNamazButton(
                          context,
                          namaz['name'] as String,
                          namaz['icon'] as IconData,
                          Colors.blue,
                          true,
                          userId,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nafal Namaz (0.65 points each, max 5)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: nafalNamaz.map((namaz) {
                        return _buildNamazButton(
                          context,
                          namaz['name'] as String,
                          namaz['icon'] as IconData,
                          Colors.green,
                          false,
                          userId,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today\'s Points',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '${(stats['totalPoints'] ?? 0.0).toStringAsFixed(1)} / ${PointsService.maxPointsPerDay}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamazButton(
    BuildContext context,
    String name,
    IconData icon,
    Color color,
    bool isFarz,
    String userId,
  ) {
    return InkWell(
      onTap: () => _markNamazComplete(context, name, isFarz, userId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markNamazComplete(BuildContext context, String namazName, bool isFarz, String userId) async {
    final pointsService = PointsService();
    try {
      if (isFarz) {
        await pointsService.addNamazPoints(
          userId: userId,
          farzCount: 1,
          nafalCount: 0,
        );
      } else {
        await pointsService.addNamazPoints(
          userId: userId,
          farzCount: 0,
          nafalCount: 1,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$namazName completed! +${isFarz ? "1" : "0.65"} points'),
            backgroundColor: Colors.green,
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

  Widget _buildStatsCard(BuildContext context, List<HabitModel> habits, currentUser) {
    final totalStreak = habits.fold<int>(0, (sum, habit) => sum + habit.streakDays);
    final totalXP = habits.fold<int>(0, (sum, habit) => sum + (habit.totalCompletions * AppConstants.xpPerHabitComplete));
    final completedToday = habits.where((h) {
      if (h.lastCompleted == null) return false;
      final today = DateTime.now();
      return h.lastCompleted!.year == today.year &&
          h.lastCompleted!.month == today.month &&
          h.lastCompleted!.day == today.day;
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.primary,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ðŸ”¥ Habit Streak',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Level ${_calculateLevel(totalXP)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(context, totalStreak.toString(), 'Days Streak', Icons.local_fire_department),
              ),
              Expanded(
                child: _buildStatItem(context, totalXP.toString(), 'Total XP', Icons.star),
              ),
              Expanded(
                child: _buildStatItem(context, completedToday.toString(), 'Completed Today', Icons.check_circle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHabitCard(BuildContext context, WidgetRef ref, HabitModel habit, String? userId) {
    final progressPercent = habit.targetValue > 0
        ? (habit.currentValue / habit.targetValue).clamp(0.0, 1.0)
        : 0.0;
    final isComplete = habit.currentValue >= habit.targetValue;
    final color = _getHabitColor(habit.habitType, context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getHabitEmoji(habit.habitType),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.habitName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 16,
                              color: habit.streakDays > 0 ? Colors.orange : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${habit.streakDays} day streak',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isComplete)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.tertiary,
                        size: 24,
                      ),
                    )
                  else if (userId != null)
                    habit.targetValue > 1 && habit.habitType == AppConstants.habitCustom
                        ? IconButton(
                            onPressed: () => _showProgressSlider(context, ref, habit, userId, color),
                            icon: Icon(Icons.tune, color: color),
                            tooltip: 'Update Progress',
                          )
                        : IconButton(
                            onPressed: () async {
                              if (habit.isCompletedToday) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${habit.habitName} already completed today!'),
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    ),
                                  );
                                }
                                return;
                              }

                              try {
                                await ref.read(habitsRepositoryProvider).completeHabit(
                                  habit.id,
                                  userId,
                                  value: 1,
                                );
                                ref.invalidate(userHabitsProvider);
                                if (context.mounted) {
                                  final pointsText = habit.habitType == AppConstants.habitCustom
                                      ? '1 point'
                                      : '${AppConstants.xpPerHabitComplete} points';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${habit.habitName} completed! +$pointsText'),
                                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().contains('already completed') 
                                          ? 'Habit already completed today!' 
                                          : 'Error: $e'),
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.add_circle_outline, color: color),
                          ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        minHeight: 8,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${habit.currentValue}/${habit.targetValue}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getHabitEmoji(String habitType) {
    switch (habitType) {
      case AppConstants.habitSalah:
        return 'ðŸ•Œ';
      case AppConstants.habitQuran:
        return 'ðŸ“–';
      case AppConstants.habitTasbeeh:
        return 'ðŸ“¿';
      case AppConstants.habitDua:
        return 'ðŸ¤²';
      case AppConstants.habitTahajjud:
        return 'ðŸŒŸ';
      case AppConstants.habitZikr:
        return 'ðŸ’š';
      case AppConstants.habitSadaqah:
        return 'ðŸ’';
      case AppConstants.habitCharity:
        return 'â¤ï¸';
      case AppConstants.habitFasting:
        return 'ðŸŒ™';
      case AppConstants.habitLearning:
        return 'ðŸ“š';
      case AppConstants.habitGratitude:
        return 'ðŸ™';
      case AppConstants.habitPatience:
        return 'â³';
      case AppConstants.habitKindness:
        return 'ðŸ¤';
      default:
        return 'âœ¨';
    }
  }

  Color _getHabitColor(String habitType, BuildContext context) {
    switch (habitType) {
      case AppConstants.habitSalah:
        return const Color(0xFF2196F3);
      case AppConstants.habitQuran:
        return const Color(0xFF4CAF50); // Green instead of yellow
      case AppConstants.habitTasbeeh:
        return const Color(0xFF4CAF50);
      case AppConstants.habitDua:
        return const Color(0xFF00BCD4);
      case AppConstants.habitTahajjud:
        return const Color(0xFF3F51B5);
      case AppConstants.habitZikr:
        return const Color(0xFF4CAF50);
      case AppConstants.habitSadaqah:
        return const Color(0xFFE91E63);
      case AppConstants.habitCharity:
        return const Color(0xFFE91E63);
      case AppConstants.habitFasting:
        return const Color(0xFF9C27B0);
      case AppConstants.habitLearning:
        return const Color(0xFF795548);
      case AppConstants.habitGratitude:
        return const Color(0xFFFF9800);
      case AppConstants.habitPatience:
        return const Color(0xFF607D8B);
      case AppConstants.habitKindness:
        return const Color(0xFF009688);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  int _calculateLevel(int xp) {
    return (xp / 100).floor() + 1;
  }

  void _showProgressSlider(BuildContext context, WidgetRef ref, HabitModel habit, String userId, Color color) {
    final currentValueNotifier = ValueNotifier<int>(habit.currentValue);
    
    showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: currentValueNotifier,
        builder: (context, currentValue, _) {
          return AlertDialog(
            title: Text('Update ${habit.habitName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Progress: $currentValue / ${habit.targetValue}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: currentValue.toDouble(),
                  min: 0,
                  max: habit.targetValue.toDouble(),
                  divisions: habit.targetValue,
                  label: '$currentValue',
                  activeColor: color,
                  onChanged: (value) {
                    currentValueNotifier.value = value.round();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(habitsRepositoryProvider).updateHabitProgress(
                      habit.id,
                      userId,
                      currentValue,
                    );
                    ref.invalidate(userHabitsProvider);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Progress updated to $currentValue/${habit.targetValue}'),
                          backgroundColor: Theme.of(context).colorScheme.tertiary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating progress: $e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: color),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context, WidgetRef ref, String userId) {
    final nameController = TextEditingController();
    final targetController = TextEditingController(text: '1');
    final selectedTypeNotifier = ValueNotifier<String>(AppConstants.habitCustom);
    final durationNotifier = ValueNotifier<int?>(null);
    final autoRemoveNotifier = ValueNotifier<bool>(false);

    final predefinedHabits = [
      {'type': AppConstants.habitSalah, 'name': 'Daily Salah', 'icon': 'ðŸ•Œ'},
      {'type': AppConstants.habitQuran, 'name': 'Quran Reading', 'icon': 'ðŸ“–'},
      {'type': AppConstants.habitDua, 'name': 'Morning Dua', 'icon': 'ðŸ¤²'},
      {'type': AppConstants.habitTasbeeh, 'name': 'Tasbeeh', 'icon': 'ðŸ“¿'},
      {'type': AppConstants.habitTahajjud, 'name': 'Tahajjud Prayer', 'icon': 'ðŸŒŸ'},
      {'type': AppConstants.habitZikr, 'name': 'Zikr', 'icon': 'ðŸ’š'},
      {'type': AppConstants.habitSadaqah, 'name': 'Sadaqah', 'icon': 'ðŸ’'},
      {'type': AppConstants.habitFasting, 'name': 'Fasting', 'icon': 'ðŸŒ™'},
      {'type': AppConstants.habitGratitude, 'name': 'Gratitude', 'icon': 'ðŸ™'},
      {'type': AppConstants.habitKindness, 'name': 'Acts of Kindness', 'icon': 'ðŸ¤'},
    ];

    showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: selectedTypeNotifier,
        builder: (context, selectedType, _) {
          return ValueListenableBuilder<int?>(
            valueListenable: durationNotifier,
            builder: (context, durationDays, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: autoRemoveNotifier,
                builder: (context, autoRemove, _) {
                  return AlertDialog(
                    title: const Text('Add New Habit'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select a Habit',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: predefinedHabits.map((habit) {
                              final isSelected = selectedType == habit['type'];
                              return InkWell(
                                onTap: () {
                                  selectedTypeNotifier.value = habit['type'] as String;
                                  nameController.text = habit['name'] as String;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primaryContainer
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(habit['icon'] as String),
                                      const SizedBox(width: 4),
                                      Text(
                                        habit['name'] as String,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Habit Name',
                              hintText: 'e.g., Morning Dua',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: selectedType,
                            decoration: InputDecoration(
                              labelText: 'Habit Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: AppConstants.habitSalah,
                                child: const Text('ðŸ•Œ Salah'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitQuran,
                                child: const Text('ðŸ“– Quran Reading'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitTasbeeh,
                                child: const Text('ðŸ“¿ Tasbeeh'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitDua,
                                child: const Text('ðŸ¤² Dua'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitTahajjud,
                                child: const Text('ðŸŒŸ Tahajjud'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitZikr,
                                child: const Text('ðŸ’š Zikr'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitSadaqah,
                                child: const Text('ðŸ’ Sadaqah'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitCharity,
                                child: const Text('â¤ï¸ Charity'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitFasting,
                                child: const Text('ðŸŒ™ Fasting'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitLearning,
                                child: const Text('ðŸ“š Learning'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitGratitude,
                                child: const Text('ðŸ™ Gratitude'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitPatience,
                                child: const Text('â³ Patience'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitKindness,
                                child: const Text('ðŸ¤ Kindness'),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.habitCustom,
                                child: const Text('âœ¨ Custom'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                selectedTypeNotifier.value = value;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: targetController,
                            decoration: InputDecoration(
                              labelText: 'Target Value',
                              hintText: '1',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              helperText: 'Enter the number of times to complete this habit',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: targetController,
                            builder: (context, value, child) {
                              final targetValue = (int.tryParse(value.text) ?? 1).clamp(1, 100);
                              return Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: targetValue.toDouble(),
                                      min: 1,
                                      max: 100,
                                      divisions: 99,
                                      label: '$targetValue',
                                      onChanged: (newValue) {
                                        targetController.text = newValue.round().toString();
                                      },
                                    ),
                                  ),
                                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                                  Text(
                                    '$targetValue',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int?>(
                            initialValue: durationDays,
                            decoration: InputDecoration(
                              labelText: 'Duration (Optional)',
                              hintText: 'No limit',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('No limit'),
                              ),
                              ...List.generate(30, (index) {
                                final days = index + 1;
                                return DropdownMenuItem<int?>(
                                  value: days,
                                  child: Text('$days ${days == 1 ? 'day' : 'days'}'),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              durationNotifier.value = value;
                            },
                          ),
                          if (durationDays != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Habit will be removed after $durationDays ${durationDays == 1 ? 'day' : 'days'}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            value: autoRemove,
                            onChanged: (value) {
                              autoRemoveNotifier.value = value ?? false;
                            },
                            title: const Text('Remove after completion'),
                            subtitle: const Text(
                              'Habit will be removed at the end of the day after completion',
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          selectedTypeNotifier.dispose();
                          durationNotifier.dispose();
                          autoRemoveNotifier.dispose();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a habit name'),
                              ),
                            );
                            return;
                          }

                          try {
                            final target = int.tryParse(targetController.text) ?? 1;
                            if (target < 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Target value must be at least 1'),
                                ),
                              );
                              return;
                            }

                            await ref.read(habitsRepositoryProvider).createHabit(
                              userId: userId,
                              habitType: selectedType,
                              habitName: nameController.text.trim(),
                              targetValue: target,
                              durationDays: durationDays,
                              autoRemoveAfterCompletion: autoRemove,
                            );
                            if (context.mounted) {
                              selectedTypeNotifier.dispose();
                              durationNotifier.dispose();
                              autoRemoveNotifier.dispose();
                              Navigator.pop(context);
                              ref.invalidate(userHabitsProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Habit added successfully!'),
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
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    ).then((_) {
      selectedTypeNotifier.dispose();
      durationNotifier.dispose();
      autoRemoveNotifier.dispose();
    });
  }
}

