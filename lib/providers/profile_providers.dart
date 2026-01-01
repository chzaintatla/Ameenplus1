import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import '../network/repositories/user_profile_repository.dart';
import '../models/user_profile.dart';

class ProfileController {
  ProfileController(this._ref);

  final Ref _ref;

  Future<void> signInGuest() async {
    final auth = _ref.read(firebaseAuthProvider);
    if (auth == null) return;

    final cred = await auth.signInAnonymously();
    final user = cred.user;
    if (user == null) return;

    await _ref.read(userProfileRepositoryProvider).ensureProfileForUser(user);
  }

  Future<void> signOut() async {
    final auth = _ref.read(firebaseAuthProvider);
    if (auth == null) return;
    await auth.signOut();
  }

  Future<void> setProfilePublic({required String uid, required bool isPublic}) async {
    await _ref.read(userProfileRepositoryProvider).setProfilePublic(uid: uid, isPublic: isPublic);
  }
}

final profileControllerProvider = Provider<ProfileController>((ref) {
  return ProfileController(ref);
});

final currentUserProfileProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.maybeWhen(
    data: (user) {
      if (user == null) return const Stream<UserProfile?>.empty();
      return ref.read(userProfileRepositoryProvider).watchProfile(user.uid);
    },
    orElse: () => const Stream<UserProfile?>.empty(),
  );
});
