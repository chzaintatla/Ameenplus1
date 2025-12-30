import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../models/user_model.dart';

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Current user provider
final currentUserProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

/// Current user model provider
final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  
  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      final repository = ref.read(authRepositoryProvider);
      return Stream.fromFuture(repository.getUserModel(user.uid));
    },
    loading: () => const Stream<UserModel?>.empty(),
    error: (_, __) => const Stream<UserModel?>.empty(),
  );
});

/// Guest mode provider
final guestModeProvider = StateProvider<bool>((ref) => false);

/// Check if user is authenticated (including guest mode)
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final isGuest = ref.watch(guestModeProvider);
  
  return (userAsync.hasValue && userAsync.value != null) || isGuest;
});

