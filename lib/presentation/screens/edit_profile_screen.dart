import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../utils/permission_service.dart';
import '../../viewmodels/profile_viewmodel.dart';

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
  final _birthdayController = TextEditingController();
  File? _selectedImage;
  String? _currentImageUrl;
  List<String> _selectedInterests = [];
  String? _selectedGender;
  DateTime? _selectedBirthday;
  bool _isEmailPublic = false;
  bool _isPhonePublic = false;
  bool _useCalendarPicker = true;

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
          if (profile.age != null) {
            final currentYear = DateTime.now().year;
            final birthYear = currentYear - profile.age!;
            _selectedBirthday = DateTime(birthYear, 1, 1);
            _birthdayController.text = _formatBirthday(_selectedBirthday!);
          }
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
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required ImageSource source}) async {
    if (!mounted) return;
    
    try {
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

      if (!mounted) return;

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      ).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error selecting image: ${error.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return null;
      });

      if (pickedFile == null || !mounted) return;

      final pickedFilePath = pickedFile.path;
      if (pickedFilePath.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Invalid image path'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      final pickedFileObj = File(pickedFilePath);
      if (!await pickedFileObj.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image file not found'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFilePath,
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
        ).catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error cropping image: ${error.toString()}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return null;
        });

        if (croppedFile != null && mounted) {
          final croppedFilePath = croppedFile.path;
          if (croppedFilePath.isNotEmpty) {
            final croppedFileObj = File(croppedFilePath);
            if (await croppedFileObj.exists()) {
              setState(() {
                _selectedImage = croppedFileObj;
              });
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Cropped image file not found'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        }
      } catch (cropError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cropping image: ${cropError.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
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

    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (source != null && mounted) {
        await _pickImage(source: source);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening image picker: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = ref.read(profileViewModelProvider.notifier);

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

    await viewModel.updateProfile(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      interests: _selectedInterests,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      age: _calculateAge(),
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

    if (profileState.profile == null && !profileState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(profileViewModelProvider.notifier).loadProfile();
      });
    }

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
              Text(
                'Birthday',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        segmentedButtonTheme: SegmentedButtonThemeData(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Theme.of(context).colorScheme.primary;
                                }
                                return Theme.of(context).colorScheme.surface;
                              },
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return Theme.of(context).brightness == Brightness.light
                                    ? Colors.black
                                    : null;
                              },
                            ),
                            iconColor: WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return Theme.of(context).brightness == Brightness.light
                                    ? Colors.black
                                    : null;
                              },
                            ),
                          ),
                        ),
                      ),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Calendar'),
                            icon: Icon(Icons.calendar_today, size: 18),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Manual'),
                            icon: Icon(Icons.edit, size: 18),
                          ),
                        ],
                        selected: {_useCalendarPicker},
                        onSelectionChanged: (Set<bool> selected) {
                          setState(() {
                            _useCalendarPicker = selected.first;
                            if (!_useCalendarPicker) {
                              _birthdayController.clear();
                              _selectedBirthday = null;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_useCalendarPicker)
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      helpText: 'Select Birthday',
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedBirthday = pickedDate;
                        _birthdayController.text = _formatBirthday(pickedDate);
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthday',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      hintText: 'Select your birthday',
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedBirthday != null
                          ? _formatBirthday(_selectedBirthday!)
                          : 'Select your birthday',
                      style: TextStyle(
                        color: _selectedBirthday != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                TextFormField(
                  controller: _birthdayController,
                  decoration: InputDecoration(
                    labelText: 'Birthday (DD/MM/YYYY)',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    hintText: '12/10/2003',
                    helperText: 'Format: DD/MM/YYYY',
                  ),
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    _BirthdayInputFormatter(),
                  ],
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final date = _parseBirthday(value);
                      if (date == null) {
                        return 'Please enter a valid date (DD/MM/YYYY)';
                      }
                      if (date.isAfter(DateTime.now())) {
                        return 'Birthday cannot be in the future';
                      }
                      if (date.isBefore(DateTime(1900))) {
                        return 'Please enter a valid date';
                      }
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value.length == 10) {
                      final date = _parseBirthday(value);
                      if (date != null) {
                        setState(() {
                          _selectedBirthday = date;
                        });
                      }
                    }
                  },
                ),
              const SizedBox(height: 16),
              if (_selectedBirthday != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Age: ${_calculateAge() ?? 'N/A'} years',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
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
                    label: Text(
                      interest,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.light
                                ? Colors.black
                                : null),
                      ),
                    ),
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

  String _formatBirthday(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTime? _parseBirthday(String value) {
    try {
      final parts = value.split('/');
      if (parts.length != 3) return null;
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day == null || month == null || year == null) return null;
      if (day < 1 || day > 31 || month < 1 || month > 12) return null;
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  int? _calculateAge() {
    if (_selectedBirthday == null) {
      if (_birthdayController.text.isNotEmpty && !_useCalendarPicker) {
        final date = _parseBirthday(_birthdayController.text);
        if (date != null) {
          final now = DateTime.now();
          int age = now.year - date.year;
          if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
            age--;
          }
          return age;
        }
      }
      return null;
    }
    final now = DateTime.now();
    int age = now.year - _selectedBirthday!.year;
    if (now.month < _selectedBirthday!.month || (now.month == _selectedBirthday!.month && now.day < _selectedBirthday!.day)) {
      age--;
    }
    return age;
  }
}

class _BirthdayInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d/]'), '');
    
    if (text.length <= 2) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } else if (text.length <= 5) {
      if (text[2] != '/') {
        return TextEditingValue(
          text: '${text.substring(0, 2)}/${text.substring(2)}',
          selection: TextSelection.collapsed(offset: text.length + 1),
        );
      }
    } else if (text.length <= 10) {
      if (text[2] != '/' || text[5] != '/') {
        String formatted = text;
        if (text.length > 2 && text[2] != '/') {
          formatted = '${text.substring(0, 2)}/${text.substring(2)}';
        }
        if (formatted.length > 5 && formatted[5] != '/') {
          formatted = '${formatted.substring(0, 5)}/${formatted.substring(5)}';
        }
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
    
    return TextEditingValue(
      text: text.length > 10 ? text.substring(0, 10) : text,
      selection: TextSelection.collapsed(offset: text.length > 10 ? 10 : text.length),
    );
  }
}
