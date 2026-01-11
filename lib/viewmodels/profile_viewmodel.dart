import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../network/repositories/user_profile_repository.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class ProfileViewModel extends StateNotifier<ProfileState> {
  ProfileViewModel({
    required this.authRepository,
    required this.profileRepository,
  }) : super(ProfileState.initial());

  final AuthRepository authRepository;
  final UserProfileRepository profileRepository;

  Future<void> loadProfile() async {
    final user = authRepository.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'No user signed in');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final profile = await profileRepository.getProfile(user.uid);
      state = state.copyWith(
        isLoading: false,
        profile: profile,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<String?> uploadProfileImage(File imageFile) async {
    final user = authRepository.currentUser;
    if (user == null) return null;

    state = state.copyWith(isUploadingImage: true, error: null);

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

      state = state.copyWith(
        isUploadingImage: false,
        profile: state.profile?.copyWith(photoUrl: downloadUrl),
      );

      return downloadUrl;
    } catch (e) {
      state = state.copyWith(
        isUploadingImage: false,
        error: e.toString(),
      );
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
      state = state.copyWith(error: 'No user signed in');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

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
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
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
      state = state.copyWith(error: e.toString());
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

final profileViewModelProvider = StateNotifierProvider<ProfileViewModel, ProfileState>((ref) {
  return ProfileViewModel(
    authRepository: ref.read(authRepositoryProvider),
    profileRepository: ref.read(userProfileRepositoryProvider),
  );
});
