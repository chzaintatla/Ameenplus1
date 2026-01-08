import '../utils/app_constants.dart';

class HabitModel {
  final String id;
  final String userId;
  final String habitType;
  final String habitName;
  final int targetValue;
  final int currentValue;
  final DateTime? lastCompleted;
  final int streakDays;
  final int totalCompletions;
  final DateTime createdAt;
  final bool syncStatus;
  final int? durationDays;
  final DateTime? endDate;
  final bool autoRemoveAfterCompletion;

  HabitModel({
    required this.id,
    required this.userId,
    required this.habitType,
    required this.habitName,
    this.targetValue = 1,
    this.currentValue = 0,
    this.lastCompleted,
    this.streakDays = 0,
    this.totalCompletions = 0,
    required this.createdAt,
    this.syncStatus = true,
    this.durationDays,
    this.endDate,
    this.autoRemoveAfterCompletion = false,
  });

  factory HabitModel.fromMap(Map<String, dynamic> data) {
    return HabitModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      habitType: data['habit_type'] ?? data['habitType'] ?? AppConstants.habitCustom,
      habitName: data['habit_name'] ?? data['habitName'] ?? '',
      targetValue: data['target_value'] ?? data['targetValue'] ?? 1,
      currentValue: data['current_value'] ?? data['currentValue'] ?? 0,
      lastCompleted: data['last_completed'] != null
          ? (data['last_completed'] is String
              ? DateTime.parse(data['last_completed'])
              : data['last_completed'] as DateTime?)
          : (data['lastCompleted'] != null
              ? (data['lastCompleted'] is String
                  ? DateTime.parse(data['lastCompleted'])
                  : data['lastCompleted'] as DateTime?)
              : null),
      streakDays: data['streak_days'] ?? data['streakDays'] ?? 0,
      totalCompletions: data['total_completions'] ?? data['totalCompletions'] ?? 0,
      createdAt: data['created_at'] != null
          ? (data['created_at'] is String ? DateTime.parse(data['created_at']) : data['created_at'] as DateTime)
          : (data['createdAt'] is String ? DateTime.parse(data['createdAt']) : DateTime.now()),
      syncStatus: true,
      durationDays: data['duration_days'] ?? data['durationDays'],
      endDate: data['end_date'] != null
          ? (data['end_date'] is String
              ? DateTime.parse(data['end_date'])
              : data['end_date'] as DateTime?)
          : (data['endDate'] != null
              ? (data['endDate'] is String
                  ? DateTime.parse(data['endDate'])
                  : data['endDate'] as DateTime?)
              : null),
      autoRemoveAfterCompletion: (data['auto_remove_after_completion'] ?? data['autoRemoveAfterCompletion']) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'habit_type': habitType,
      'habit_name': habitName,
      'target_value': targetValue,
      'current_value': currentValue,
      'last_completed': lastCompleted?.toIso8601String(),
      'streak_days': streakDays,
      'total_completions': totalCompletions,
      'created_at': createdAt.toIso8601String(),
      'duration_days': durationDays,
      'end_date': endDate?.toIso8601String(),
      'auto_remove_after_completion': autoRemoveAfterCompletion,
    };
  }

  Map<String, dynamic> toLocal() {
    return {
      'id': id,
      'userId': userId,
      'habitType': habitType,
      'habitName': habitName,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'lastCompleted': lastCompleted?.toIso8601String(),
      'streakDays': streakDays,
      'totalCompletions': totalCompletions,
      'createdAt': createdAt.toIso8601String(),
      'syncStatus': syncStatus ? 1 : 0,
      'lastSyncAt': DateTime.now().toIso8601String(),
      'durationDays': durationDays,
      'endDate': endDate?.toIso8601String(),
      'autoRemoveAfterCompletion': autoRemoveAfterCompletion ? 1 : 0,
    };
  }

  factory HabitModel.fromLocal(Map<String, dynamic> data) {
    return HabitModel(
      id: data['id'],
      userId: data['userId'],
      habitType: data['habitType'],
      habitName: data['habitName'] ?? '',
      targetValue: data['targetValue'] ?? 1,
      currentValue: data['currentValue'] ?? 0,
      lastCompleted: data['lastCompleted'] != null
          ? DateTime.parse(data['lastCompleted'])
          : null,
      streakDays: data['streakDays'] ?? 0,
      totalCompletions: data['totalCompletions'] ?? 0,
      createdAt: DateTime.parse(data['createdAt']),
      syncStatus: (data['syncStatus'] ?? 1) == 1,
      durationDays: data['durationDays'],
      endDate: data['endDate'] != null ? DateTime.parse(data['endDate']) : null,
      autoRemoveAfterCompletion: (data['autoRemoveAfterCompletion'] ?? 0) == 1,
    );
  }

  HabitModel copyWith({
    String? habitName,
    int? targetValue,
    int? currentValue,
    DateTime? lastCompleted,
    int? streakDays,
    int? totalCompletions,
    bool? syncStatus,
    int? durationDays,
    DateTime? endDate,
    bool? autoRemoveAfterCompletion,
  }) {
    return HabitModel(
      id: id,
      userId: userId,
      habitType: habitType,
      habitName: habitName ?? this.habitName,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      streakDays: streakDays ?? this.streakDays,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      durationDays: durationDays ?? this.durationDays,
      endDate: endDate ?? this.endDate,
      autoRemoveAfterCompletion: autoRemoveAfterCompletion ?? this.autoRemoveAfterCompletion,
    );
  }

  bool get isCompletedToday {
    if (lastCompleted == null) return false;

    final now = DateTime.now();
    final lastCompletedDate = lastCompleted!;

    return now.year == lastCompletedDate.year &&
        now.month == lastCompletedDate.month &&
        now.day == lastCompletedDate.day;
  }

  bool get isExpired {
    if (endDate == null) return false;
    final now = DateTime.now();
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(end);
  }

  bool get shouldBeRemoved {
    if (autoRemoveAfterCompletion && isCompletedToday) {
      final now = DateTime.now();
      final lastCompletedDate = DateTime(
        lastCompleted!.year,
        lastCompleted!.month,
        lastCompleted!.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      return today.isAfter(lastCompletedDate);
    }
    return isExpired;
  }

  bool get isStreakBroken {
    if (lastCompleted == null) return false;

    final now = DateTime.now();
    final daysSinceCompletion = now.difference(lastCompleted!).inDays;

    return daysSinceCompletion > 1;
  }

  double get completionPercentage {
    if (targetValue == 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  HabitModel markCompleted({int value = 1}) {
    final now = DateTime.now();
    final newCurrentValue = currentValue + value;
    final isComplete = newCurrentValue >= targetValue;

    int newStreakDays = streakDays;
    int newTotalCompletions = totalCompletions;
    DateTime? newLastCompleted = lastCompleted;

    if (isComplete) {
      if (lastCompleted != null) {
        final daysSinceLast = now.difference(lastCompleted!).inDays;
        if (daysSinceLast == 0) {
          newStreakDays = streakDays;
        } else if (daysSinceLast == 1) {
          newStreakDays = streakDays + 1;
        } else {
          newStreakDays = 1;
        }
      } else {
        newStreakDays = 1;
      }

      newTotalCompletions = totalCompletions + 1;
      newLastCompleted = now;
    }

    return copyWith(
      currentValue: isComplete ? 0 : newCurrentValue,
      lastCompleted: newLastCompleted,
      streakDays: newStreakDays,
      totalCompletions: newTotalCompletions,
      syncStatus: false,
    );
  }

  HabitModel resetDaily() {
    return copyWith(
      currentValue: 0,
      syncStatus: false,
    );
  }

  static String getHabitIcon(String habitType) {
    switch (habitType) {
      case AppConstants.habitTasbeeh:
        return 'ðŸ“¿';
      case AppConstants.habitSalah:
        return 'ðŸ•Œ';
      case AppConstants.habitQuran:
        return 'ðŸ“–';
      case AppConstants.habitDua:
        return 'ðŸ¤²';
      case AppConstants.habitTahajjud:
        return 'ðŸŒŸ';
      case AppConstants.habitZikr:
        return 'ðŸ’š';
      case AppConstants.habitFasting:
        return 'ðŸŒ™';
      case AppConstants.habitSadaqah:
        return 'ðŸ’';
      case AppConstants.habitCharity:
        return 'â¤ï¸';
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

  static int getHabitColor(String habitType) {
    switch (habitType) {
      case AppConstants.habitTasbeeh:
        return 0xFF4CAF50;
      case AppConstants.habitSalah:
        return 0xFF2196F3;
      case AppConstants.habitQuran:
        return 0xFF4CAF50; // Green instead of yellow
      case AppConstants.habitDua:
        return 0xFF00BCD4;
      case AppConstants.habitTahajjud:
        return 0xFF3F51B5;
      case AppConstants.habitZikr:
        return 0xFF4CAF50;
      case AppConstants.habitFasting:
        return 0xFF9C27B0;
      case AppConstants.habitSadaqah:
        return 0xFFE91E63;
      case AppConstants.habitCharity:
        return 0xFFE91E63;
      case AppConstants.habitLearning:
        return 0xFF795548;
      case AppConstants.habitGratitude:
        return 0xFFFF9800;
      case AppConstants.habitPatience:
        return 0xFF607D8B;
      case AppConstants.habitKindness:
        return 0xFF009688;
      default:
        return 0xFF1B5E20;
    }
  }
}

class HabitCompletion {
  final String id;
  final String habitId;
  final DateTime completedAt;
  final int value;
  final String? notes;

  HabitCompletion({
    required this.id,
    required this.habitId,
    required this.completedAt,
    this.value = 1,
    this.notes,
  });

  Map<String, dynamic> toLocal() {
    return {
      'id': id,
      'habitId': habitId,
      'completedAt': completedAt.toIso8601String(),
      'value': value,
      'notes': notes,
      'syncStatus': 0,
    };
  }

  factory HabitCompletion.fromLocal(Map<String, dynamic> data) {
    return HabitCompletion(
      id: data['id'],
      habitId: data['habitId'],
      completedAt: DateTime.parse(data['completedAt']),
      value: data['value'] ?? 1,
      notes: data['notes'],
    );
  }
}
