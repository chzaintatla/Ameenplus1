import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/models/user_model.dart';
import '../firebase/firebase_ready_provider.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  final readyAsync = ref.watch(firebaseReadyProvider);

  return readyAsync.maybeWhen(
    data: (ready) => ready ? FirebaseAuth.instance.authStateChanges() : const Stream<User?>.empty(),
    orElse: () => const Stream<User?>.empty(),
  );
});

final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  final readyAsync = ref.watch(firebaseReadyProvider);
  return readyAsync.maybeWhen(
    data: (ready) => ready ? FirebaseAuth.instance : null,
    orElse: () => null,
  );
});

// Current user provider that fetches user data from Firestore
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return const Stream<UserModel?>.empty();
      
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;
            return UserModel.fromFirestore(doc);
          });
    },
    loading: () => const Stream<UserModel?>.empty(),
    error: (_, __) => const Stream<UserModel?>.empty(),
  );
});
