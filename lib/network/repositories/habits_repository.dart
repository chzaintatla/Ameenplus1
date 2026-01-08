import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_database.dart';
import '../../utils/xp_service.dart';
import '../../utils/points_service.dart';
import '../../models/habit_model.dart';

class HabitsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AppDatabase _localDb = AppDatabase.instance;
  final XPService _xpService = XPService();
  final PointsService _pointsService = PointsService();

  Future<HabitModel> createHabit({
    required String userId,
    required String habitType,
    required String habitName,
    int targetValue = 1,
    int? durationDays,
    bool autoRemoveAfterCompletion = false,
  }) async {
    try {
      final now = DateTime.now();
      final endDate = durationDays != null
          ? now.add(Duration(days: durationDays))
          : null;

      final habit = HabitModel(
        id: const Uuid().v4(),
        userId: userId,
        habitType: habitType,
        habitName: habitName,
        targetValue: targetValue,
        createdAt: now,
        durationDays: durationDays,
        endDate: endDate,
        autoRemoveAfterCompletion: autoRemoveAfterCompletion,
      );

      try {
        await _supabase
            .from(AppConstants.collectionHabits)
            .insert(habit.toMap());
      } catch (e) {
        // Silently fail if Supabase insert fails, will sync later
      }

      await _localDb.insertHabit(habit.toLocal());

      return habit;
    } catch (e) {
      throw Exception('Failed to create habit: $e');
    }
  }

  Stream<List<HabitModel>> getUserHabits(String userId) {
    try {
      return _supabase
          .from(AppConstants.collectionHabits)
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .asyncMap((data) async {
        final supabaseHabits = data
            .map((item) => HabitModel.fromMap(item))
            .toList();

        final filteredHabits = <HabitModel>[];
        for (var habit in supabaseHabits) {
          if (habit.shouldBeRemoved) {
            await deleteHabit(habit.id, userId);
          } else {
            filteredHabits.add(habit);
          }
        }

        try {
          final localHabits = await getLocalHabits(userId);
          final localHabitMap = {for (var h in localHabits) h.id: h};

          for (var supabaseHabit in filteredHabits) {
            if (!localHabitMap.containsKey(supabaseHabit.id) ||
                localHabitMap[supabaseHabit.id]!.syncStatus) {
              localHabitMap[supabaseHabit.id] = supabaseHabit;
              await _localDb.insertHabit(supabaseHabit.toLocal());
            }
          }

          final finalHabits = localHabitMap.values
              .where((h) => !h.shouldBeRemoved)
              .toList();
          finalHabits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return finalHabits;
        } catch (e) {
          return filteredHabits;
        }
      }).handleError((error) {
        return getLocalHabits(userId).asStream();
      });
    } catch (e) {
      return getLocalHabits(userId).asStream();
    }
  }

  Future<List<HabitModel>> getLocalHabits(String userId) async {
    final habits = await _localDb.getHabits(userId);
    final filtered = habits
        .map((data) => HabitModel.fromLocal(data))
        .where((h) => !h.shouldBeRemoved)
        .toList();
    return filtered;
  }

  Future<HabitModel?> completeHabit(String habitId, String userId, {int value = 1}) async {
    try {
      HabitModel? updatedHabit;

      try {
        // Get current habit
        final habitData = await _supabase
            .from(AppConstants.collectionHabits)
            .select()
            .eq('id', habitId)
            .maybeSingle();

        if (habitData == null) {
          throw Exception('Habit not found');
        }

        final habit = HabitModel.fromMap(habitData);

        if (habit.isCompletedToday) {
          throw Exception('Habit already completed today');
        }

        updatedHabit = habit.markCompleted(value: value);

        // Update in Supabase
        await _supabase
            .from(AppConstants.collectionHabits)
            .update(updatedHabit.toMap())
            .eq('id', habitId);

        await _localDb.insertHabitCompletion({
          'id': const Uuid().v4(),
          'habitId': habitId,
          'completedAt': DateTime.now().toIso8601String(),
          'value': value,
          'syncStatus': 0,
        });
      } catch (e) {
        if (e.toString().contains('already completed')) {
          rethrow;
        }
        final localHabits = await _localDb.getHabits(userId);
        final habitData = localHabits.firstWhere((h) => h['id'] == habitId);
        final habit = HabitModel.fromLocal(habitData);

        if (habit.isCompletedToday) {
          throw Exception('Habit already completed today');
        }

        updatedHabit = habit.markCompleted(value: value);
      }

      await _localDb.updateHabit(habitId, updatedHabit!.toLocal());

      if (updatedHabit.habitType == AppConstants.habitCustom) {
        await _xpService.awardXP(
          userId: userId,
          xpAmount: 1,
          actionType: 'custom_habit_complete',
          description: 'Completed custom habit: ${updatedHabit.habitName}',
        );
        await _pointsService.addHabitPoints(
          userId: userId,
          points: 1.0,
        );
      } else {
        await _xpService.awardXPForHabit(
          userId,
          streakDays: updatedHabit.streakDays,
        );
      }

      if (updatedHabit.autoRemoveAfterCompletion && updatedHabit.isCompletedToday) {
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final delay = tomorrow.difference(now);
        Future.delayed(delay, () async {
          await deleteHabit(habitId, userId);
        });
      }
      
      return updatedHabit;
    } catch (e) {
      throw Exception('Failed to complete habit: $e');
    }
  }

  Future<void> deleteHabit(String habitId, String userId) async {
    try {
      await _supabase
          .from(AppConstants.collectionHabits)
          .delete()
          .eq('id', habitId);
    } catch (e) {
      // Silently fail if Supabase delete fails
    }

    await _localDb.deleteHabit(habitId);
  }

  Future<List<Map<String, dynamic>>> getHabitHistory(String habitId) async {
    return await _localDb.getHabitCompletions(habitId);
  }

  Future<HabitModel?> updateHabitProgress(String habitId, String userId, int newValue) async {
    try {
      HabitModel? updatedHabit;

      try {
        final habitData = await _supabase
            .from(AppConstants.collectionHabits)
            .select()
            .eq('id', habitId)
            .maybeSingle();

        if (habitData == null) {
          throw Exception('Habit not found');
        }

        final habit = HabitModel.fromMap(habitData);
        final clampedValue = newValue.clamp(0, habit.targetValue);
        
        updatedHabit = habit.copyWith(
          currentValue: clampedValue,
          syncStatus: false,
        );

        await _supabase
            .from(AppConstants.collectionHabits)
            .update(updatedHabit.toMap())
            .eq('id', habitId);
      } catch (e) {
        // Fallback to local database if Supabase fails
        try {
          final localHabits = await _localDb.getHabits(userId);
          final habitData = localHabits.firstWhere(
            (h) => h['id'] == habitId,
            orElse: () => throw Exception('Habit not found in local database'),
          );
          final habit = HabitModel.fromLocal(habitData);
          final clampedValue = newValue.clamp(0, habit.targetValue);
          
          updatedHabit = habit.copyWith(
            currentValue: clampedValue,
            syncStatus: false,
          );
        } catch (localError) {
          throw Exception('Failed to update habit: ${e.toString()}');
        }
      }

      if (updatedHabit != null) {
        await _localDb.updateHabit(habitId, updatedHabit!.toLocal());
      }

      return updatedHabit;
    } catch (e) {
      throw Exception('Failed to update habit progress: $e');
    }
  }
}
