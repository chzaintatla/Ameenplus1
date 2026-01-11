import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_providers.dart';
import '../../providers/deeds_providers.dart';
import '../../providers/interests_providers.dart';
import '../../utils/app_constants.dart';
import '../../services/moderation_service.dart';
import '../../services/interests_service.dart';

class CreateDeedScreen extends ConsumerStatefulWidget {
  final String? initialMediaPath;
  final String? initialMediaType;
  
  const CreateDeedScreen({
    super.key,
    this.initialMediaPath,
    this.initialMediaType,
  });

  @override
  ConsumerState<CreateDeedScreen> createState() => _CreateDeedScreenState();
}

class _CreateDeedScreenState extends ConsumerState<CreateDeedScreen> {
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();
  final ModerationService _moderationService = ModerationService();
  final InterestsService _interestsService = InterestsService();
  
  File? _selectedImage;
  File? _selectedVideo;
  PlatformFile? _selectedFile;
  String? _selectedMediaType;
  List<String> _selectedInterests = [];
  bool _isLoading = false;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMediaPath != null) {
      if (widget.initialMediaType == 'image') {
        _selectedImage = File(widget.initialMediaPath!);
        _selectedMediaType = 'image';
      } else if (widget.initialMediaType == 'video') {
        _selectedVideo = File(widget.initialMediaPath!);
        _selectedMediaType = 'video';
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Video'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('PDF'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: const Text('Audio'),
                onTap: () => Navigator.pop(context, 'audio'),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Word / Excel'),
                onTap: () => Navigator.pop(context, 'document'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (result == null) return;

      if (result == 'image') {
        // Show source selection (Camera or Gallery)
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

        if (source == null) return;

        final image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (image != null) {
          final file = File(image.path);
          if (await file.exists()) {
            final fileSize = await file.length();
            if (fileSize > 10 * 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image must be less than 10MB')),
                );
              }
              return;
            }
            setState(() {
              _selectedImage = file;
              _selectedVideo = null;
              _selectedFile = null;
              _selectedMediaType = 'image';
            });
          }
        }
      } else if (result == 'video') {
        if (!mounted) return;
        // Show source selection (Camera or Gallery)
        final source = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.videocam),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );

        if (source == null) return;

        final video = await _imagePicker.pickVideo(source: source);
        if (video != null) {
          final file = File(video.path);
          if (await file.exists()) {
            final fileSize = await file.length();
            if (fileSize > 50 * 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video must be less than 50MB')),
                );
              }
              return;
            }
            setState(() {
              _selectedVideo = file;
              _selectedImage = null;
              _selectedFile = null;
              _selectedMediaType = 'video';
            });
          }
        }
      } else {
        FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
          type: result == 'pdf'
              ? FileType.custom
              : result == 'audio'
                  ? FileType.audio
                  : FileType.custom,
          allowedExtensions: result == 'pdf'
              ? ['pdf']
              : result == 'audio'
                  ? null
                  : ['doc', 'docx', 'xls', 'xlsx'],
        );

        if (fileResult != null && fileResult.files.single.path != null) {
          final file = File(fileResult.files.single.path!);
          if (await file.exists()) {
            final fileSize = await file.length();
            final maxSize = result == 'pdf' || result == 'audio' ? 20 * 1024 * 1024 : 10 * 1024 * 1024;
            if (fileSize > maxSize) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('File must be less than ${maxSize ~/ (1024 * 1024)}MB')),
                );
              }
              return;
            }
            setState(() {
              _selectedFile = fileResult.files.single;
              _selectedImage = null;
              _selectedVideo = null;
              _selectedMediaType = result;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _removeMedia() {
    setState(() {
      _selectedImage = null;
      _selectedVideo = null;
      _selectedFile = null;
      _selectedMediaType = null;
    });
  }

  Future<void> _validateContent() async {
    final content = _contentController.text.trim();
    final mediaPath = _selectedImage?.path ?? 
                     _selectedVideo?.path ?? 
                     _selectedFile?.path;
    final mediaType = _selectedMediaType;

    // Build validation message
    String validationMessage = '';
    if (content.isNotEmpty) {
      validationMessage = 'Please validate this content: $content';
    }
    if (mediaPath != null) {
      validationMessage += '\n\nI have attached a ${mediaType ?? 'file'} for validation.';
    }
    if (validationMessage.isEmpty) {
      validationMessage = 'Please validate the selected media.';
    }

    // Navigate to chatbot with validation message
    if (mounted) {
      context.push('/ai-chatbot', extra: {
        'initialMessage': validationMessage,
        'mediaPath': mediaPath,
        'mediaType': mediaType,
      } as Map<String, dynamic>);
    }
  }

  Future<void> _submitDeed() async {
    if (_contentController.text.trim().isEmpty && 
        _selectedImage == null && 
        _selectedVideo == null && 
        _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter content or select media')),
      );
      return;
    }

    setState(() {
      _isValidating = true;
      _isLoading = true;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) {
        throw Exception('Please sign in to post');
      }

      // Check moderation status
      final canPost = await _moderationService.canUserPost(user.uid);
      if (!canPost) {
        final status = await _moderationService.getModerationStatus(user.uid);
        if (mounted) {
          setState(() {
            _isValidating = false;
            _isLoading = false;
          });
          
          String message = 'You cannot post content. ';
          if (status.isBlocked && status.blockedUntil != null) {
            message += 'Your account is blocked until ${status.blockedUntil!.toLocal()}';
          } else {
            message += 'You have ${status.negativePoints}/${status.maxNegativePoints} negative points.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      
      // Note: Validation is now done on the backend
      // Posts are saved with isValidated: false and backend will validate
      setState(() => _isValidating = false);

      // Increment interest counts
      for (final interest in _selectedInterests) {
        await _interestsService.incrementInterestCount(interest);
      }

      final repository = ref.read(deedsRepositoryProvider);
      await repository.createDeed(
        userId: user.uid,
        userName: user.displayName ?? 'User',
        userPhotoUrl: user.photoURL,
        deedType: AppConstants.deedGeneral,
        content: _contentController.text.trim().isEmpty 
            ? (_selectedMediaType == 'image' ? 'ðŸ“· Image' 
               : _selectedMediaType == 'video' ? 'ðŸŽ¥ Video'
               : _selectedMediaType == 'pdf' ? 'ðŸ“„ PDF'
               : _selectedMediaType == 'audio' ? 'ðŸŽµ Audio'
               : 'ðŸ“Ž Document')
            : _contentController.text.trim(),
        arabicText: null,
        translation: null,
        reference: null,
        category: null,
        imagePath: _selectedImage?.path,
        videoPath: _selectedVideo?.path,
        filePath: _selectedFile?.path,
        mediaType: _selectedMediaType,
        interests: _selectedInterests,
        isValidated: false, // Backend will validate and set to true
        validationReason: null,
        validationConfidence: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post submitted! It will be reviewed and appear after validation.'),
            backgroundColor: Colors.blue,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.contains('Exception:') 
                ? errorMessage.split('Exception:').last.trim()
                : 'Error: $errorMessage'
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isValidating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(''),
        actions: [
          if (_isValidating)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Validating...'),
                ],
              ),
            )
          else
            TextButton(
              onPressed: _isLoading ? null : _submitDeed,
              child: _isLoading
                  ? SizedBox(
                      width: mediaQuery.size.width * 0.05,
                      height: mediaQuery.size.width * 0.05,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Text(
                      'Post',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                CircleAvatar(
                  radius: mediaQuery.size.width * 0.06,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Icon(Icons.person, size: mediaQuery.size.width * 0.06)
                      : null,
                ),
                SizedBox(width: mediaQuery.size.width * 0.03),
                Text(
                  user?.displayName ?? 'User',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?',
                border: InputBorder.none,
                hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              maxLines: null,
              style: Theme.of(context).textTheme.bodyLarge,
              autofocus: true,
            ),
            if (_selectedImage != null || _selectedVideo != null || _selectedFile != null) ...[
              SizedBox(height: mediaQuery.size.height * 0.02),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _selectedImage != null
                        ? Image.file(
                            _selectedImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                width: double.infinity,
                                color: Theme.of(context).colorScheme.errorContainer,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Theme.of(context).colorScheme.error,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Could not load image',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : _selectedVideo != null
                            ? Container(
                                height: 200,
                                width: double.infinity,
                                color: Colors.black,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Video selected',
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                height: 200,
                                width: double.infinity,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedMediaType == 'pdf'
                                          ? Icons.picture_as_pdf
                                          : _selectedMediaType == 'audio'
                                              ? Icons.audiotrack
                                              : Icons.description,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedFile?.name ?? 'File selected',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _validateContent(),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                          tooltip: 'Validate Content',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _removeMedia,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: mediaQuery.size.height * 0.02),
            Text(
              'Add Interest Tags',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            Consumer(
              builder: (context, ref, child) {
                final trendingInterestsAsync = ref.watch(trendingInterestsProvider);
                return trendingInterestsAsync.when(
                  data: (interests) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: interests.map((interest) {
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
                              if (!_selectedInterests.contains(interest)) {
                                _selectedInterests.add(interest);
                              }
                            } else {
                              _selectedInterests.remove(interest);
                            }
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            SizedBox(height: mediaQuery.size.height * 0.02),
            Row(
              children: [
                IconButton(
                  onPressed: _pickMedia,
                  icon: Icon(
                    Icons.photo_library_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Add Photo',
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }
}
