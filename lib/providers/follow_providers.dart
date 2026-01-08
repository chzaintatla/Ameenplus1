import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/repositories/follow_repository.dart';

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository();
});

final isFollowingProvider = StreamProvider.family<bool, Map<String, String>>((ref, params) {
  final repository = ref.read(followRepositoryProvider);
  return repository.watchIsFollowing(
    params['followerId']!,
    params['followingId']!,
  );
});

final followersListProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  final repository = ref.read(followRepositoryProvider);
  return repository.watchFollowers(userId);
});

final followingListProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  final repository = ref.read(followRepositoryProvider);
  return repository.watchFollowing(userId);
});
