import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase/firebase_ready_provider.dart';

abstract class AdminRepository {
  Stream<bool> watchIsAdmin({required String uid});
  Future<void> addDeed({
    required String createdByUid,
    required String type,
    required String title,
    required String content,
    String? reference,
    String? imageUrl,
  });
}

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<bool> watchIsAdmin({required String uid}) {
    return _firestore.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return false;
      return (data['isAdmin'] as bool?) ?? false;
    });
  }

  @override
  Future<void> addDeed({
    required String createdByUid,
    required String type,
    required String title,
    required String content,
    String? reference,
    String? imageUrl,
  }) async {
    await _firestore.collection('deeds').add(<String, Object?>{
      'type': type,
      'title': title,
      'content': content,
      'reference': reference,
      'imageUrl': imageUrl,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class DisabledAdminRepository implements AdminRepository {
  @override
  Future<void> addDeed({
    required String createdByUid,
    required String type,
    required String title,
    required String content,
    String? reference,
    String? imageUrl,
  }) async {}

  @override
  Stream<bool> watchIsAdmin({required String uid}) => const Stream<bool>.empty();
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final readyAsync = ref.watch(firebaseReadyProvider);
  return readyAsync.maybeWhen(
    data: (ready) => ready ? FirebaseAdminRepository(FirebaseFirestore.instance) : DisabledAdminRepository(),
    orElse: () => DisabledAdminRepository(),
  );
});

final isAdminProvider = StreamProvider.autoDispose<bool>((ref) {
  final readyAsync = ref.watch(firebaseReadyProvider);
  final user = ref.watch(_authUserProvider);

  return readyAsync.maybeWhen(
    data: (ready) {
      if (!ready || user == null) return Stream<bool>.value(false);
      return ref.read(adminRepositoryProvider).watchIsAdmin(uid: user.uid);
    },
    orElse: () => Stream<bool>.value(false),
  );
});

final _authUserProvider = Provider<User?>((ref) {
  final readyAsync = ref.watch(firebaseReadyProvider);
  return readyAsync.maybeWhen(
    data: (ready) => ready ? FirebaseAuth.instance.currentUser : null,
    orElse: () => null,
  );
});

