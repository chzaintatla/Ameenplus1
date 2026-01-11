import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../supabase/supabase_ready_provider.dart';

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

class SupabaseUserProfileRepository implements UserProfileRepository {
  SupabaseUserProfileRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((data) {
          if (data.isEmpty) return null;
          return UserProfile.fromMap(uid, data.first);
        });
  }

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final data = await _supabase
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();
    
    if (data == null) return null;
    return UserProfile.fromMap(uid, data);
  }

  @override
  Future<void> ensureProfileForUser(User user) async {
    final existing = await _supabase
        .from('users')
        .select()
        .eq('id', user.uid)
        .maybeSingle();

    final next = <String, Object?>{
      'id': user.uid,
      'display_name': user.displayName ?? 'User',
      'photo_url': user.photoURL,
      'points': 0,
      'is_profile_public': true,
      'interests': <String>[],
      'email': user.email,
      'phone_number': user.phoneNumber,
      'updated_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    if (existing == null) {
      await _supabase.from('users').insert(next);
    } else {
      await _supabase
          .from('users')
          .update({
            'display_name': next['display_name'],
            'photo_url': next['photo_url'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.uid);
    }
  }

  @override
  Future<void> setProfilePublic({required String uid, required bool isPublic}) async {
    await _supabase
        .from('users')
        .update({
          'is_profile_public': isPublic,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', uid);
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
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (displayName != null) {
      updates['display_name'] = displayName;
    }
    if (photoUrl != null) {
      updates['photo_url'] = photoUrl;
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
      updates['phone_number'] = phoneNumber;
    }
    if (age != null) {
      updates['age'] = age;
    }
    if (gender != null) {
      updates['gender'] = gender;
    }
    if (isEmailPublic != null) {
      updates['is_email_public'] = isEmailPublic;
    }
    if (isPhonePublic != null) {
      updates['is_phone_public'] = isPhonePublic;
    }

    await _supabase
        .from('users')
        .update(updates)
        .eq('id', uid);
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
  final readyAsync = ref.watch(supabaseReadyProvider);
  return readyAsync.maybeWhen(
    data: (ready) => ready 
        ? SupabaseUserProfileRepository(Supabase.instance.client) 
        : DisabledUserProfileRepository(),
    orElse: () => DisabledUserProfileRepository(),
  );
});
