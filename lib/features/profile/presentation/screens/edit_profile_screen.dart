import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/permission_service.dart';
import '../../presentation/viewmodels/profile_viewmodel.dart';
import '../../domain/user_profile.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  File? _selectedImage;
  String? _currentImageUrl;
  List<String> _selectedInterests = [];
  String? _selectedGender;
  bool _isEmailPublic = false;
  bool _isPhonePublic = false;

  final List<String> _availableInterests = [
    'Quran',
    'Hadith',
    'Salah',
    'Zikr',
    'Dua',
    'Charity',
    'Fasting',
    'Hajj',
    'Umrah',
    'Islamic History',
    'Fiqh',
    'Tafsir',
    'Seerah',
    'Arabic Language',
    'Islamic Art',
    'Community Service',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  void _loadProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileState = ref.read(profileViewModelProvider);
      final profile = profileState.profile;
      
      if (profile != null) {
        setState(() {
          _nameController.text = profile.displayName;
          _bioController.text = profile.bio ?? '';
          _emailController.text = profile.email ?? '';
          _phoneController.text = profile.phoneNumber ?? '';
          _ageController.text = profile.age?.toString() ?? '';
          _currentImageUrl = profile.photoUrl;
          _selectedInterests = List.from(profile.interests);
          _selectedGender = profile.gender;
          _isEmailPublic = profile.isEmailPublic;
          _isPhonePublic = profile.isPhonePublic;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required ImageSource source}) async {
    try {
      // Request permission based on source
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        hasPermission = await PermissionService.requestCameraPermission();
      } else {
        hasPermission = await PermissionService.requestPhotoLibraryPermission();
      }

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera
                    ? 'Camera permission is required'
                    : 'Photo library permission is required',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => PermissionService.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Profile Image',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Profile Image',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null && mounted) {
          setState(() {
            _selectedImage = File(croppedFile.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      await _pickImage(source: source);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = ref.read(profileViewModelProvider.notifier);

    // Upload image if selected
    if (_selectedImage != null) {
      final imageUrl = await viewModel.uploadProfileImage(_selectedImage!);
      if (imageUrl == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to upload image'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    // Update profile
    await viewModel.updateProfile(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      interests: _selectedInterests,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      age: _ageController.text.trim().isEmpty ? null : int.tryParse(_ageController.text.trim()),
      gender: _selectedGender,
      isEmailPublic: _isEmailPublic,
      isPhonePublic: _isPhonePublic,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileViewModelProvider);
    final isLoading = profileState.isLoading || profileState.isUploadingImage;
    
    // Load profile if not already loaded
    if (profileState.profile == null && !profileState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(profileViewModelProvider.notifier).loadProfile();
      });
    }
    
    // Update form fields when profile loads
    if (profileState.profile != null) {
      final profile = profileState.profile!;
      if (_nameController.text != profile.displayName) {
        _nameController.text = profile.displayName;
        _bioController.text = profile.bio ?? '';
        _emailController.text = profile.email ?? '';
        _phoneController.text = profile.phoneNumber ?? '';
        _ageController.text = profile.age?.toString() ?? '';
        _currentImageUrl = profile.photoUrl;
        _selectedInterests = List.from(profile.interests);
        _selectedGender = profile.gender;
        _isEmailPublic = profile.isEmailPublic;
        _isPhonePublic = profile.isPhonePublic;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Profile Image
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (_currentImageUrl != null
                            ? NetworkImage(_currentImageUrl!)
                            : null),
                    child: _selectedImage == null && _currentImageUrl == null
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20),
                        color: Theme.of(context).colorScheme.onPrimary,
                        onPressed: _showImageSourceDialog,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Bio Field
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                prefixIcon: Icon(Icons.description_outlined),
                hintText: 'Tell us about yourself...',
              ),
              maxLines: 4,
              maxLength: 200,
            ),
            const SizedBox(height: 16),
            // Email Field
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                hintText: 'your.email@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Phone Number Field
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+1234567890',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            // Age Field
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age',
                prefixIcon: Icon(Icons.cake_outlined),
                hintText: '25',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final age = int.tryParse(value);
                  if (age == null || age < 1 || age > 150) {
                    return 'Please enter a valid age';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Gender Dropdown
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
            const SizedBox(height: 24),
            // Privacy Settings
            Text(
              'Privacy Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Make Email Public'),
              subtitle: const Text('Allow others to see your email'),
              value: _isEmailPublic,
              onChanged: (value) {
                setState(() {
                  _isEmailPublic = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Make Phone Number Public'),
              subtitle: const Text('Allow others to see your phone number'),
              value: _isPhonePublic,
              onChanged: (value) {
                setState(() {
                  _isPhonePublic = value;
                });
              },
            ),
            const SizedBox(height: 24),
            // Interests Section
            Text(
              'Interests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (profileState.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profileState.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}

