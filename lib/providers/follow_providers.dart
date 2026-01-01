import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/repositories/follow_repository.dart';

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository();
});

final isFollowingProvider = StreamProvider.family<bool, Map<String, String>>((ref, params) {
  final repository = ref.read(followRepositoryProvider);
  return repository.watchIsFollowing(
    followerId: params['followerId']!,
    followingId: params['followingId']!,
  );
});

final followersListProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async* {
  final repository = ref.read(followRepositoryProvider);
  final followerIds = <String>[];
  
  await for (final ids in repository.getFollowers(userId)) {
    followerIds.clear();
    followerIds.addAll(ids);
    
    if (followerIds.isEmpty) {
      yield [];
      continue;
    }
    
    final users = <Map<String, dynamic>>[];
    for (final id in followerIds) {
      final userData = await repository.getUserData(id);
      if (userData != null) {
        users.add({
          'uid': id,
          ...userData,
        });
      }
    }
    yield users;
  }
});

final followingListProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async* {
  final repository = ref.read(followRepositoryProvider);
  final followingIds = <String>[];
  
  await for (final ids in repository.getFollowing(userId)) {
    followingIds.clear();
    followingIds.addAll(ids);
    
    if (followingIds.isEmpty) {
      yield [];
      continue;
    }
    
    final users = <Map<String, dynamic>>[];
    for (final id in followingIds) {
      final userData = await repository.getUserData(id);
      if (userData != null) {
        users.add({
          'uid': id,
          ...userData,
        });
      }
    }
    yield users;
  }
});

