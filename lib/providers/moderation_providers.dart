import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/moderation_service.dart';

final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService();
});

final moderationStatusProvider = FutureProvider.family<ModerationStatus, String>((ref, userId) async {
  final service = ref.read(moderationServiceProvider);
  return await service.getModerationStatus(userId);
});
