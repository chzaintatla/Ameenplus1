import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/local/app_database.dart';
import '../../../core/services/xp_service.dart';
import '../models/habit_model.dart';

/// Repository for managing habits
class HabitsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppDatabase _localDb = AppDatabase.instance;
  final XPService _xpService = XPService();

  /// Create a new habit
  Future<HabitModel> createHabit({
    required String userId,
    required String habitType,
    required String habitName,
    int targetValue = 1,
  }) async {
    try {
      final habit = HabitModel(
        id: const Uuid().v4(),
        userId: userId,
        habitType: habitType,
        habitName: habitName,
        targetValue: targetValue,
        createdAt: DateTime.now(),
      );

      // Save to Firestore if user is authenticated
      try {
        await _firestore
            .collection(AppConstants.collectionHabits)
            .doc(habit.id)
            .set(habit.toFirestore());
      } catch (e) {
        // If Firebase fails, save locally only
      }

      // Always save locally
      await _localDb.insertHabit(habit.toLocal());

      return habit;
    } catch (e) {
      throw Exception('Failed to create habit: $e');
    }
  }

  /// Get user's habits - merges Firestore and local database
  Stream<List<HabitModel>> getUserHabits(String userId) {
    // Try Firestore first, fallback to local
    try {
      return _firestore
          .collection(AppConstants.collectionHabits)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
        final firestoreHabits = snapshot.docs
            .map((doc) => HabitModel.fromFirestore(doc))
            .toList();
        
        // Merge with local habits (local takes precedence for unsynced changes)
        try {
          final localHabits = await getLocalHabits(userId);
          final localHabitMap = {for (var h in localHabits) h.id: h};
          
          // Update local habits with Firestore data, but keep local if unsynced
          for (var firestoreHabit in firestoreHabits) {
            if (!localHabitMap.containsKey(firestoreHabit.id) || 
                localHabitMap[firestoreHabit.id]!.syncStatus) {
              localHabitMap[firestoreHabit.id] = firestoreHabit;
              // Update local database
              await _localDb.insertHabit(firestoreHabit.toLocal());
            }
          }
          
          return localHabitMap.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } catch (e) {
          // If local fails, return Firestore data
          return firestoreHabits;
        }
      }).handleError((error) {
        // On error, return local habits
        return getLocalHabits(userId).asStream();
      });
    } catch (e) {
      // If Firestore query fails, return local habits stream
      return getLocalHabits(userId).asStream();
    }
  }

  /// Get habits from local database
  Future<List<HabitModel>> getLocalHabits(String userId) async {
    final habits = await _localDb.getHabits(userId);
    return habits.map((data) => HabitModel.fromLocal(data)).toList();
  }

  /// Complete a habit
  Future<HabitModel?> completeHabit(String habitId, String userId, {int value = 1}) async {
    try {
      HabitModel? updatedHabit;

      // Update in Firestore
      try {
        final habitRef = _firestore
            .collection(AppConstants.collectionHabits)
            .doc(habitId);

        await _firestore.runTransaction((transaction) async {
          final habitDoc = await transaction.get(habitRef);
          if (!habitDoc.exists) return;

          final habit = HabitModel.fromFirestore(habitDoc);
          updatedHabit = habit.markCompleted(value: value);

          transaction.update(habitRef, updatedHabit!.toFirestore());

          // Record completion
          await _localDb.insertHabitCompletion({
            'id': const Uuid().v4(),
            'habitId': habitId,
            'completedAt': DateTime.now().toIso8601String(),
            'value': value,
            'syncStatus': 0,
          });
        });
      } catch (e) {
        // If Firebase fails, update locally
        final localHabits = await _localDb.getHabits(userId);
        final habitData = localHabits.firstWhere((h) => h['id'] == habitId);
        final habit = HabitModel.fromLocal(habitData);
        updatedHabit = habit.markCompleted(value: value);
      }

      // Update locally
      if (updatedHabit != null) {
        await _localDb.updateHabit(habitId, updatedHabit!.toLocal());

        // Award XP for completing habit
        await _xpService.awardXPForHabit(
          userId,
          streakDays: updatedHabit!.streakDays,
        );
      }

      if (updatedHabit == null) {
        throw Exception('Failed to complete habit');
      }
      return updatedHabit;
    } catch (e) {
      throw Exception('Failed to complete habit: $e');
    }
  }

  /// Delete a habit
  Future<void> deleteHabit(String habitId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.collectionHabits)
          .doc(habitId)
          .delete();
    } catch (e) {
      // Continue even if Firebase fails
    }

    await _localDb.deleteHabit(habitId);
  }

  /// Get habit completion history
  Future<List<Map<String, dynamic>>> getHabitHistory(String habitId) async {
    return await _localDb.getHabitCompletions(habitId);
  }
}

