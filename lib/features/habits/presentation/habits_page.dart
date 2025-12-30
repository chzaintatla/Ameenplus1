import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../data/habits_repository.dart';
import '../models/habit_model.dart';
import '../presentation/providers/habits_providers.dart';

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository();
});

class HabitsPage extends ConsumerWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(userHabitsProvider);
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userHabitsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats Card
          habitsAsync.when(
            data: (habits) => _buildStatsCard(context, habits),
            loading: () => _buildStatsCard(context, []),
            error: (_, __) => _buildStatsCard(context, []),
          ),
          const SizedBox(height: 16),
          
          // Today's Habits Section
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
                    // TODO: Navigate to add habit screen
                    _showAddHabitDialog(context, ref, currentUser.uid);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Habit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Habit Cards
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
                        if (currentUser != null)
                          ElevatedButton.icon(
                            onPressed: () {
                              _showAddHabitDialog(context, ref, currentUser.uid);
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
                    child: _buildHabitCard(context, ref, habit, currentUser?.uid),
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

  Widget _buildStatsCard(BuildContext context, List<HabitModel> habits) {
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
                '🔥 Habit Streak',
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
        onTap: () {
          // TODO: Navigate to habit detail
        },
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
                    IconButton(
                      onPressed: () async {
                        try {
                          await ref.read(habitsRepositoryProvider).completeHabit(
                            habit.id,
                            userId,
                            value: 1,
                          );
                          // Invalidate provider to refresh UI
                          ref.invalidate(userHabitsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${habit.habitName} completed! +${AppConstants.xpPerHabitComplete} XP'),
                                backgroundColor: Theme.of(context).colorScheme.tertiary,
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
        return '🕌';
      case AppConstants.habitQuran:
        return '📖';
      case AppConstants.habitTasbeeh:
        return '📿';
      case AppConstants.habitDua:
        return '🤲';
      case AppConstants.habitTahajjud:
        return '🌟';
      case AppConstants.habitZikr:
        return '💚';
      case AppConstants.habitSadaqah:
        return '💝';
      case AppConstants.habitCharity:
        return '❤️';
      case AppConstants.habitFasting:
        return '🌙';
      case AppConstants.habitLearning:
        return '📚';
      case AppConstants.habitGratitude:
        return '🙏';
      case AppConstants.habitPatience:
        return '⏳';
      case AppConstants.habitKindness:
        return '🤝';
      default:
        return '✨';
    }
  }

  Color _getHabitColor(String habitType, BuildContext context) {
    switch (habitType) {
      case AppConstants.habitSalah:
        return const Color(0xFF2196F3);
      case AppConstants.habitQuran:
        return const Color(0xFFFFD700);
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
    // Simple level calculation: every 100 XP = 1 level
    return (xp / 100).floor() + 1;
  }

  void _showAddHabitDialog(BuildContext context, WidgetRef ref, String userId) {
    final nameController = TextEditingController();
    final targetController = TextEditingController(text: '1');
    final selectedTypeNotifier = ValueNotifier<String>(AppConstants.habitCustom);

    showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: selectedTypeNotifier,
        builder: (context, selectedType, _) {
          return AlertDialog(
            title: const Text('Add New Habit'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Habit Name',
                      hintText: 'e.g., Morning Dua',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Habit Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: AppConstants.habitSalah, child: const Text('🕌 Salah')),
                      DropdownMenuItem(value: AppConstants.habitQuran, child: const Text('📖 Quran Reading')),
                      DropdownMenuItem(value: AppConstants.habitTasbeeh, child: const Text('📿 Tasbeeh')),
                      DropdownMenuItem(value: AppConstants.habitDua, child: const Text('🤲 Dua')),
                      DropdownMenuItem(value: AppConstants.habitTahajjud, child: const Text('🌟 Tahajjud')),
                      DropdownMenuItem(value: AppConstants.habitZikr, child: const Text('💚 Zikr')),
                      DropdownMenuItem(value: AppConstants.habitSadaqah, child: const Text('💝 Sadaqah')),
                      DropdownMenuItem(value: AppConstants.habitCharity, child: const Text('❤️ Charity')),
                      DropdownMenuItem(value: AppConstants.habitFasting, child: const Text('🌙 Fasting')),
                      DropdownMenuItem(value: AppConstants.habitLearning, child: const Text('📚 Learning')),
                      DropdownMenuItem(value: AppConstants.habitGratitude, child: const Text('🙏 Gratitude')),
                      DropdownMenuItem(value: AppConstants.habitPatience, child: const Text('⏳ Patience')),
                      DropdownMenuItem(value: AppConstants.habitKindness, child: const Text('🤝 Kindness')),
                      DropdownMenuItem(value: AppConstants.habitCustom, child: const Text('✨ Custom')),
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
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a habit name')),
                    );
                    return;
                  }

                  try {
                    final target = int.tryParse(targetController.text) ?? 1;
                    if (target < 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Target value must be at least 1')),
                      );
                      return;
                    }
                    
                    await ref.read(habitsRepositoryProvider).createHabit(
                      userId: userId,
                      habitType: selectedType,
                      habitName: nameController.text.trim(),
                      targetValue: target,
                    );
                    if (context.mounted) {
                      selectedTypeNotifier.dispose();
                      Navigator.pop(context);
                      // Invalidate provider to refresh the list
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
      ),
    ).then((_) => selectedTypeNotifier.dispose());
  }
}
