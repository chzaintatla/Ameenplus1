import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationStatus {
  final bool isBlocked;
  final bool isBanned;
  final DateTime? blockedUntil;
  final int negativePoints;
  final int maxNegativePoints = 10;
  final String? message;

  ModerationStatus({
    required this.isBlocked,
    required this.isBanned,
    this.blockedUntil,
    required this.negativePoints,
    this.message,
  });

  bool get canPost => !isBanned && !isBlocked;
}

class ModerationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> moderateContent(String content) async {
    // Simple content moderation - can be enhanced with AI/ML
    final inappropriateWords = ['spam', 'abuse', 'hate'];
    
    for (final word in inappropriateWords) {
      if (content.toLowerCase().contains(word)) {
        return false;
      }
    }
    
    return true;
  }

  Future<void> reportContent({
    required String contentId,
    required String contentType,
    required String reportedBy,
    required String reason,
  }) async {
    try {
      await _supabase.from('reports').insert({
        'content_id': contentId,
        'content_type': contentType,
        'reported_by': reportedBy,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
    } catch (e) {
      // Silently fail or log
    }
  }

  Future<bool> canUserPost(String userId) async {
    final status = await getModerationStatus(userId);
    return status.canPost;
  }

  Future<ModerationStatus> getModerationStatus(String userId) async {
    final userData = await _supabase
        .from('users')
        .select('account_blocked_until, is_banned, negative_points')
        .eq('id', userId)
        .maybeSingle();
    
    if (userData == null) {
      return ModerationStatus(
        isBlocked: false,
        isBanned: false,
        negativePoints: 0,
      );
    }
    
    final isBanned = userData['is_banned'] == true;
    final blockedUntilStr = userData['account_blocked_until'] as String?;
    DateTime? blockedUntil;
    bool isBlocked = false;

    if (blockedUntilStr != null) {
      blockedUntil = DateTime.parse(blockedUntilStr);
      if (blockedUntil.isAfter(DateTime.now())) {
        isBlocked = true;
      }
    }
    
    final negativePoints = (userData['negative_points'] as num?)?.toInt() ?? 0;
    
    String? message;
    if (isBanned) {
      message = 'Your account has been permanently banned.';
    } else if (isBlocked) {
      message = 'Your account is blocked until ${blockedUntilStr?.split('T').first}.';
    }
    
    return ModerationStatus(
      isBlocked: isBlocked,
      isBanned: isBanned,
      blockedUntil: blockedUntil,
      negativePoints: negativePoints,
      message: message,
    );
  }

  Future<({bool showWarning, bool isFinalWarning, bool isBlocked, String message})> addNegativePoint({
    required String userId,
    required String reason,
  }) async {
    final userData = await _supabase
        .from('users')
        .select('negative_points')
        .eq('id', userId)
        .maybeSingle();
    
    final currentPoints = (userData?['negative_points'] as num?)?.toInt() ?? 0;
    final nextPoints = currentPoints + 1;
    
    final updates = <String, dynamic>{
      'negative_points': nextPoints,
    };
    
    bool isBlocked = false;
    DateTime? blockedUntil;
    
    if (nextPoints >= 10) {
      blockedUntil = DateTime.now().add(const Duration(days: 7));
      updates['account_blocked_until'] = blockedUntil.toIso8601String();
      isBlocked = true;
    } else if (nextPoints >= 5) {
      blockedUntil = DateTime.now().add(const Duration(days: 1));
      updates['account_blocked_until'] = blockedUntil.toIso8601String();
      isBlocked = true;
    }
    
    await _supabase
        .from('users')
        .update(updates)
        .eq('id', userId);
        
    await _supabase.from('moderation_logs').insert({
      'user_id': userId,
      'action': 'negative_point',
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });

    String message = 'Content flagged. You now have $nextPoints/10 negative points.';
    if (isBlocked) {
      message = 'Content flagged. Your account is blocked until ${blockedUntil?.toIso8601String().split('T').first}.';
    }

    return (
      showWarning: true,
      isFinalWarning: nextPoints >= 8,
      isBlocked: isBlocked,
      message: message,
    );
  }
}
