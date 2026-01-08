import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/repositories/habits_repository.dart';
import '../models/habit_model.dart';
import 'auth_providers.dart';

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository();
});

final userHabitsProvider = StreamProvider<List<HabitModel>>((ref) {
  final repository = ref.watch(habitsRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  
  if (currentUser.value == null) {
    return Stream.value([]);
  }
  
  return repository.getUserHabits(currentUser.value!.id);
});

