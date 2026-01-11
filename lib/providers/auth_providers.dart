import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../network/repositories/auth_repository.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final currentUserProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return const Stream<UserModel?>.empty();

      return Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', user.uid)
          .map((data) {
            if (data.isEmpty) return null;
            return UserModel.fromMap(data.first);
          });
    },
    loading: () => const Stream<UserModel?>.empty(),
    error: (_, __) => const Stream<UserModel?>.empty(),
  );
});

final guestModeProvider = StateProvider<bool>((ref) => false);

final isAuthenticatedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final isGuest = ref.watch(guestModeProvider);

  return (userAsync.hasValue && userAsync.value != null) || isGuest;
});
