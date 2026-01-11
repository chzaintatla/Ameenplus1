import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/repositories/community_repository.dart';
import '../models/community_model.dart';
import 'auth_providers.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

final communitiesProvider = StreamProvider<List<CommunityModel>>((ref) {
  final repository = ref.read(communityRepositoryProvider);
  return repository.getCommunities();
});

final userCommunitiesProvider = StreamProvider<List<CommunityModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value([]);
  
  final repository = ref.read(communityRepositoryProvider);
  return repository.getUserCommunities(user.uid);
});

final communityProvider = FutureProvider.family<CommunityModel?, String>((ref, communityId) async {
  final repository = ref.read(communityRepositoryProvider);
  return await repository.getCommunity(communityId);
});

final isCommunityMemberProvider = FutureProvider.family<bool, String>((ref, communityId) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return false;

  final repository = ref.read(communityRepositoryProvider);
  return await repository.isMember(communityId, user.uid);
});
