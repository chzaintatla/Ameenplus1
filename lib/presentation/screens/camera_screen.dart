import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isRecording = false;
  XFile? _capturedImage;
  XFile? _capturedVideo;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![_selectedCameraIndex],
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _isInitialized = false;
    });

    await _controller?.dispose();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;

    _controller = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
        _capturedVideo = null;
      });
      _showOptionsBottomSheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _capturedVideo = video;
        _capturedImage = null;
      });
      _showOptionsBottomSheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  void _showOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose an option',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.article,
              title: 'Post',
              subtitle: 'Share your deed with Islamic validation',
              onTap: () {
                Navigator.pop(context);
                _navigateToCreatePost();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.verified,
              title: 'Validate Content',
              subtitle: 'Validate content with AI chatbot',
              onTap: () {
                Navigator.pop(context);
                _navigateToValidateContent();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreatePost() {
    final mediaPath = _capturedImage?.path ?? _capturedVideo?.path;
    final mediaType = _capturedImage != null ? 'image' : 'video';
    
    context.push('/create-deed', extra: {
      'mediaPath': mediaPath,
      'mediaType': mediaType,
    });
  }

  void _navigateToValidateContent() {
    if (_capturedImage == null && _capturedVideo == null) return;
    
    final mediaPath = _capturedImage?.path ?? _capturedVideo?.path;
    final mediaType = _capturedImage != null ? 'image' : 'video';
    
    final validationMessage = 'Please validate this $mediaType content.';
    
    context.push('/ai-chatbot', extra: {
      'initialMessage': validationMessage,
      'mediaPath': mediaPath,
      'mediaType': mediaType,
    } as Map<String, dynamic>);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isInitialized && _controller != null)
              Positioned.fill(
                child: CameraPreview(_controller!),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (_cameras != null && _cameras!.length > 1)
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                      onPressed: _switchCamera,
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _isRecording ? null : _takePicture,
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd: (_) => _stopRecording(),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                            color: _isRecording ? Colors.red : Colors.transparent,
                          ),
                          child: _isRecording
                              ? const Center(
                                  child: Icon(
                                    Icons.stop,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                )
                              : Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                        onPressed: () async {
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
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );

                          if (result == null) return;

                          final picker = ImagePicker();
                          if (result == 'image') {
                            final image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null && mounted) {
                              setState(() {
                                _capturedImage = image;
                                _capturedVideo = null;
                              });
                              _showOptionsBottomSheet();
                            }
                          } else {
                            final video = await picker.pickVideo(source: ImageSource.gallery);
                            if (video != null && mounted) {
                              setState(() {
                                _capturedVideo = video;
                                _capturedImage = null;
                              });
                              _showOptionsBottomSheet();
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 40),
                      IconButton(
                        icon: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.black87,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            'assets/images/chatbot.png',
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : Colors.black54,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/ai-chatbot');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

