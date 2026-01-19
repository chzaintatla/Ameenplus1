import 'dart:io';
import 'package:flutter/foundation.dart';
import '../network/repositories/auth_repository.dart';
import '../network/repositories/user_profile_repository.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required this.authRepository,
    required this.profileRepository,
  });

  final AuthRepository authRepository;
  final UserProfileRepository profileRepository;
  ProfileState _state = ProfileState.initial();
  
  ProfileState get state => _state;

  Future<void> loadProfile() async {
    final user = authRepository.currentUser;
    if (user == null) {
      _state = _state.copyWith(error: 'No user signed in');
      notifyListeners();
      return;
    }

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final profile = await profileRepository.getProfile(user.uid);
      _state = _state.copyWith(
        isLoading: false,
        profile: profile,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<String?> uploadProfileImage(File imageFile) async {
    final user = authRepository.currentUser;
    if (user == null) return null;

    _state = _state.copyWith(isUploadingImage: true, error: null);
    notifyListeners();

    try {
      final fileName = '${user.uid}.jpg';
      final filePath = 'profile_images/$fileName';

      // Upload to Supabase Storage (using StorageService)
      final downloadUrl = await StorageService.uploadFile(
        bucket: 'avatars',
        filePath: filePath,
        file: imageFile,
        contentType: 'image/jpeg',
        upsert: true,
      );

      await profileRepository.updateProfile(
        uid: user.uid,
        photoUrl: downloadUrl,
      );

      // Update Firebase Auth user photo URL
      await user.updatePhotoURL(downloadUrl);

      _state = _state.copyWith(
        isUploadingImage: false,
        profile: _state.profile?.copyWith(photoUrl: downloadUrl),
      );
      notifyListeners();

      return downloadUrl;
    } catch (e) {
      _state = _state.copyWith(
        isUploadingImage: false,
        error: e.toString(),
      );
      notifyListeners();
      return null;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    List<String>? interests,
    String? email,
    String? phoneNumber,
    int? age,
    String? gender,
    bool? isEmailPublic,
    bool? isPhonePublic,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) {
      _state = _state.copyWith(error: 'No user signed in');
      notifyListeners();
      return;
    }

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      await profileRepository.updateProfile(
        uid: user.uid,
        displayName: displayName,
        bio: bio,
        interests: interests,
        email: email,
        phoneNumber: phoneNumber,
        age: age,
        gender: gender,
        isEmailPublic: isEmailPublic,
        isPhonePublic: isPhonePublic,
      );

      if (displayName != null) {
        final user = authRepository.currentUser;
        if (user != null) {
          await user.updateDisplayName(displayName);
        }
      }

      await loadProfile();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> setProfilePublic(bool isPublic) async {
    final user = authRepository.currentUser;
    if (user == null) return;

    try {
      await profileRepository.setProfilePublic(
        uid: user.uid,
        isPublic: isPublic,
      );
      await loadProfile();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }
}

class ProfileState {
  final bool isLoading;
  final bool isUploadingImage;
  final UserProfile? profile;
  final String? error;

  ProfileState({
    required this.isLoading,
    required this.isUploadingImage,
    this.profile,
    this.error,
  });

  factory ProfileState.initial() {
    return ProfileState(
      isLoading: false,
      isUploadingImage: false,
    );
  }

  ProfileState copyWith({
    bool? isLoading,
    bool? isUploadingImage,
    UserProfile? profile,
    String? error,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      profile: profile ?? this.profile,
      error: error ?? this.error,
    );
  }
}

