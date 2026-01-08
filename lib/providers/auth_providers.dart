import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../supabase/supabase_ready_provider.dart';
import '../network/repositories/auth_repository.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  final readyAsync = ref.watch(supabaseReadyProvider);

  return readyAsync.maybeWhen(
    data: (ready) => ready ? Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session?.user) : const Stream<User?>.empty(),
    orElse: () => const Stream<User?>.empty(),
  );
});

final supabaseAuthProvider = Provider<SupabaseClient?>((ref) {
  final readyAsync = ref.watch(supabaseReadyProvider);
  return readyAsync.maybeWhen(
    data: (ready) => ready ? Supabase.instance.client : null,
    orElse: () => null,
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final currentUserProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges.map((event) => event.session?.user);
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return const Stream<UserModel?>.empty();

      return Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', user.id)
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
