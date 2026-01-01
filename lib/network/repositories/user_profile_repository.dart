import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase/firebase_ready_provider.dart';
import '../../models/user_profile.dart';

abstract class UserProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);
  Future<UserProfile?> getProfile(String uid);
  Future<void> ensureProfileForUser(User user);
  Future<void> setProfilePublic({required String uid, required bool isPublic});
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    String? bio,
    List<String>? interests,
    String? email,
    String? phoneNumber,
    int? age,
    String? gender,
    bool? isEmailPublic,
    bool? isPhonePublic,
  });
}

class FirebaseUserProfileRepository implements UserProfileRepository {
  FirebaseUserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, Object?>> _doc(String uid) => _firestore.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return UserProfile.fromMap(snap.id, data);
    });
  }

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return UserProfile.fromMap(doc.id, data);
  }

  @override
  Future<void> ensureProfileForUser(User user) async {
    final ref = _doc(user.uid);
    final existing = await ref.get();

    final next = <String, Object?>{
      'displayName': user.displayName ?? (user.isAnonymous ? 'Guest' : 'User'),
      'photoUrl': user.photoURL,
      'points': 0,
      'isProfilePublic': true,
      'interests': <String>[],
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      await ref.set(next);
    } else {
      await ref.set(
        <String, Object?>{
          'displayName': next['displayName'],
          'photoUrl': next['photoUrl'],
          'updatedAt': next['updatedAt'],
        },
        SetOptions(merge: true),
      );
    }
  }

  @override
  Future<void> setProfilePublic({required String uid, required bool isPublic}) async {
    await _doc(uid).set(
      <String, Object?>{
        'isProfilePublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    String? bio,
    List<String>? interests,
    String? email,
    String? phoneNumber,
    int? age,
    String? gender,
    bool? isEmailPublic,
    bool? isPhonePublic,
  }) async {
    final updates = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (displayName != null) {
      updates['displayName'] = displayName;
    }
    if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
    }
    if (bio != null) {
      updates['bio'] = bio;
    }
    if (interests != null) {
      updates['interests'] = interests;
    }
    if (email != null) {
      updates['email'] = email;
    }
    if (phoneNumber != null) {
      updates['phoneNumber'] = phoneNumber;
    }
    if (age != null) {
      updates['age'] = age;
    }
    if (gender != null) {
      updates['gender'] = gender;
    }
    if (isEmailPublic != null) {
      updates['isEmailPublic'] = isEmailPublic;
    }
    if (isPhonePublic != null) {
      updates['isPhonePublic'] = isPhonePublic;
    }

    await _doc(uid).set(updates, SetOptions(merge: true));
  }
}

class DisabledUserProfileRepository implements UserProfileRepository {
  @override
  Future<void> ensureProfileForUser(User user) async {}

  @override
  Future<void> setProfilePublic({required String uid, required bool isPublic}) async {}

  @override
  Stream<UserProfile?> watchProfile(String uid) => const Stream<UserProfile?>.empty();

  @override
  Future<UserProfile?> getProfile(String uid) async => null;

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    String? bio,
    List<String>? interests,
    String? email,
    String? phoneNumber,
    int? age,
    String? gender,
    bool? isEmailPublic,
    bool? isPhonePublic,
  }) async {}
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final readyAsync = ref.watch(firebaseReadyProvider);
  return readyAsync.maybeWhen(
    data: (ready) => ready ? FirebaseUserProfileRepository(FirebaseFirestore.instance) : DisabledUserProfileRepository(),
    orElse: () => DisabledUserProfileRepository(),
  );
});

