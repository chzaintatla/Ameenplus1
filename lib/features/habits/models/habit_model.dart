import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

/// Habit model for tracking Islamic habits
class HabitModel {
  final String id;
  final String userId;
  final String habitType; // tasbeeh, salah, quran, fasting, sadaqah, dua, tahajjud, custom
  final String habitName;
  final int targetValue;
  final int currentValue;
  final DateTime? lastCompleted;
  final int streakDays;
  final int totalCompletions;
  final DateTime createdAt;
  final bool syncStatus;
  
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
  });
  
  /// Create HabitModel from Firestore document
  factory HabitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return HabitModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      habitType: data['habitType'] ?? AppConstants.habitCustom,
      habitName: data['habitName'] ?? '',
      targetValue: data['targetValue'] ?? 1,
      currentValue: data['currentValue'] ?? 0,
      lastCompleted: data['lastCompleted'] != null
          ? (data['lastCompleted'] as Timestamp).toDate()
          : null,
      streakDays: data['streakDays'] ?? 0,
      totalCompletions: data['totalCompletions'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      syncStatus: true,
    );
  }
  
  /// Convert HabitModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'habitType': habitType,
      'habitName': habitName,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'lastCompleted': lastCompleted != null
          ? Timestamp.fromDate(lastCompleted!)
          : null,
      'streakDays': streakDays,
      'totalCompletions': totalCompletions,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
  
  /// Convert to local database format
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
    };
  }
  
  /// Create from local database
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
    );
  }
  
  /// Create a copy with updated fields
  HabitModel copyWith({
    String? habitName,
    int? targetValue,
    int? currentValue,
    DateTime? lastCompleted,
    int? streakDays,
    int? totalCompletions,
    bool? syncStatus,
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
    );
  }
  
  /// Check if habit is completed today
  bool get isCompletedToday {
    if (lastCompleted == null) return false;
    
    final now = DateTime.now();
    final lastCompletedDate = lastCompleted!;
    
    return now.year == lastCompletedDate.year &&
           now.month == lastCompletedDate.month &&
           now.day == lastCompletedDate.day;
  }
  
  /// Check if streak is broken
  bool get isStreakBroken {
    if (lastCompleted == null) return false;
    
    final now = DateTime.now();
    final daysSinceCompletion = now.difference(lastCompleted!).inDays;
    
    return daysSinceCompletion > 1;
  }
  
  /// Get completion percentage
  double get completionPercentage {
    if (targetValue == 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }
  
  /// Mark habit as completed
  HabitModel markCompleted({int value = 1}) {
    final now = DateTime.now();
    final newCurrentValue = currentValue + value;
    final isComplete = newCurrentValue >= targetValue;
    
    int newStreakDays = streakDays;
    int newTotalCompletions = totalCompletions;
    DateTime? newLastCompleted = lastCompleted;
    
    if (isComplete) {
      // Check if we're continuing a streak or starting a new one
      if (lastCompleted != null) {
        final daysSinceLast = now.difference(lastCompleted!).inDays;
        if (daysSinceLast == 0) {
          // Already completed today - don't increment streak again
          newStreakDays = streakDays;
        } else if (daysSinceLast == 1) {
          // Continuing streak - increment
          newStreakDays = streakDays + 1;
        } else {
          // Streak broken - restart at 1
          newStreakDays = 1;
        }
      } else {
        // First completion ever
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
  
  /// Reset daily habit
  HabitModel resetDaily() {
    return copyWith(
      currentValue: 0,
      syncStatus: false,
    );
  }
  
  /// Get habit icon based on type
  static String getHabitIcon(String habitType) {
    switch (habitType) {
      case AppConstants.habitTasbeeh:
        return '📿';
      case AppConstants.habitSalah:
        return '🕌';
      case AppConstants.habitQuran:
        return '📖';
      case AppConstants.habitDua:
        return '🤲';
      case AppConstants.habitTahajjud:
        return '🌟';
      case AppConstants.habitZikr:
        return '💚';
      case AppConstants.habitFasting:
        return '🌙';
      case AppConstants.habitSadaqah:
        return '💝';
      case AppConstants.habitCharity:
        return '❤️';
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
  
  /// Get habit color based on type
  static int getHabitColor(String habitType) {
    switch (habitType) {
      case AppConstants.habitTasbeeh:
        return 0xFF4CAF50; // Green
      case AppConstants.habitSalah:
        return 0xFF2196F3; // Blue
      case AppConstants.habitQuran:
        return 0xFFFFD700; // Gold
      case AppConstants.habitDua:
        return 0xFF00BCD4; // Cyan
      case AppConstants.habitTahajjud:
        return 0xFF3F51B5; // Indigo
      case AppConstants.habitZikr:
        return 0xFF4CAF50; // Green
      case AppConstants.habitFasting:
        return 0xFF9C27B0; // Purple
      case AppConstants.habitSadaqah:
        return 0xFFE91E63; // Pink
      case AppConstants.habitCharity:
        return 0xFFE91E63; // Pink
      case AppConstants.habitLearning:
        return 0xFF795548; // Brown
      case AppConstants.habitGratitude:
        return 0xFFFF9800; // Orange
      case AppConstants.habitPatience:
        return 0xFF607D8B; // Blue Grey
      case AppConstants.habitKindness:
        return 0xFF009688; // Teal
      default:
        return 0xFF1B5E20; // Dark Green
    }
  }
}

/// Habit completion record
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
