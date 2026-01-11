import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/repositories/user_profile_repository.dart';
import '../models/user_profile.dart'; // Using UserProfile which contains more details
import 'auth_providers.dart';

// Re-export the repository provider from its main file
export '../network/repositories/user_profile_repository.dart' show userProfileRepositoryProvider;

final userProfileProvider = StreamProvider.family<UserProfile?, String>((ref, userId) {
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.watchProfile(userId);
});

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);
  
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.watchProfile(user.uid);
});
