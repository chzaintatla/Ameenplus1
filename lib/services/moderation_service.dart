import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const int maxNegativePoints = 10;
  static const int maxAttemptsPerMonth = 10;
  static const int warningThreshold = 4;
  static const int finalWarningThreshold = 7;
  static const int blockDurationYears = 10;

  Future<ModerationResult> addNegativePoint({
    required String userId,
    required String reason,
    String? postId,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final currentNegativePoints = (userData['negativePoints'] as num?)?.toInt() ?? 0;
      final moderationLogs = (userData['moderationLogs'] as List?)
              ?.map((e) => ModerationLog.fromMap(e as Map<String, dynamic>))
              .toList() ??
          <ModerationLog>[];

      if (userData['accountBlockedUntil'] != null) {
        final blockedUntil = DateTime.parse(userData['accountBlockedUntil'] as String);
        if (blockedUntil.isAfter(DateTime.now())) {
          return ModerationResult(
            isBlocked: true,
            message: 'Account is blocked until ${blockedUntil.toLocal()}',
            negativePoints: currentNegativePoints,
          );
        }
      }

      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month);
      final attemptsThisMonth = moderationLogs.where((log) {
        final logDate = log.timestamp;
        return logDate.isAfter(thisMonth);
      }).length;

      if (attemptsThisMonth >= maxAttemptsPerMonth) {
        return ModerationResult(
          isBlocked: false,
          message: 'Maximum attempts for this month reached. Please try again next month.',
          negativePoints: currentNegativePoints,
          showWarning: true,
        );
      }

      final newNegativePoints = currentNegativePoints + 1;
      final newLog = ModerationLog(
        timestamp: DateTime.now(),
        reason: reason,
        pointsAdded: 1,
        postId: postId,
      );

      final updatedLogs = [...moderationLogs, newLog];

      bool shouldBlock = false;
      DateTime? blockUntil;
      String message = '';

      if (newNegativePoints >= finalWarningThreshold) {
        if (newNegativePoints > finalWarningThreshold) {
          shouldBlock = true;
          blockUntil = DateTime.now().add(Duration(days: blockDurationYears * 365));
          message = 'Account blocked for 10 years due to repeated violations.';
        } else {
          message = 'FINAL WARNING: One more violation will result in a 10-year account ban.';
        }
      } else if (newNegativePoints >= warningThreshold) {
        message = 'WARNING: You have $newNegativePoints negative points. Continued violations may result in account suspension.';
      } else {
        message = 'Content rejected. Negative point added. You now have $newNegativePoints/$maxNegativePoints negative points.';
      }

      await _firestore.collection('users').doc(userId).update({
        'negativePoints': newNegativePoints,
        'moderationLogs': updatedLogs.map((e) => e.toMap()).toList(),
        if (shouldBlock) 'accountBlockedUntil': blockUntil!.toIso8601String(),
      });

      return ModerationResult(
        isBlocked: shouldBlock,
        message: message,
        negativePoints: newNegativePoints,
        showWarning: newNegativePoints >= warningThreshold,
        isFinalWarning: newNegativePoints == finalWarningThreshold,
      );
    } catch (e) {
      throw Exception('Failed to add negative point: $e');
    }
  }

  Future<bool> canUserPost(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      
      if (userData['accountBlockedUntil'] != null) {
        final blockedUntil = DateTime.parse(userData['accountBlockedUntil'] as String);
        if (blockedUntil.isAfter(DateTime.now())) {
          return false;
        }
      }

      final negativePoints = (userData['negativePoints'] as num?)?.toInt() ?? 0;
      if (negativePoints >= maxNegativePoints) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> resetNegativePoints(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'negativePoints': 0,
      'accountBlockedUntil': FieldValue.delete(),
    });
  }

  Future<ModerationStatus> getModerationStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final negativePoints = (userData['negativePoints'] as num?)?.toInt() ?? 0;
      final accountBlockedUntil = userData['accountBlockedUntil'] as String?;
      
      final isBlocked = accountBlockedUntil != null && 
          DateTime.parse(accountBlockedUntil).isAfter(DateTime.now());

      return ModerationStatus(
        negativePoints: negativePoints,
        maxNegativePoints: maxNegativePoints,
        isBlocked: isBlocked,
        blockedUntil: accountBlockedUntil != null 
            ? DateTime.parse(accountBlockedUntil)
            : null,
        showWarning: negativePoints >= warningThreshold,
        isFinalWarning: negativePoints == finalWarningThreshold,
      );
    } catch (e) {
      throw Exception('Failed to get moderation status: $e');
    }
  }
}

class ModerationResult {
  final bool isBlocked;
  final String message;
  final int negativePoints;
  final bool showWarning;
  final bool isFinalWarning;

  ModerationResult({
    required this.isBlocked,
    required this.message,
    required this.negativePoints,
    this.showWarning = false,
    this.isFinalWarning = false,
  });
}

class ModerationStatus {
  final int negativePoints;
  final int maxNegativePoints;
  final bool isBlocked;
  final DateTime? blockedUntil;
  final bool showWarning;
  final bool isFinalWarning;

  ModerationStatus({
    required this.negativePoints,
    required this.maxNegativePoints,
    required this.isBlocked,
    this.blockedUntil,
    required this.showWarning,
    required this.isFinalWarning,
  });
}

