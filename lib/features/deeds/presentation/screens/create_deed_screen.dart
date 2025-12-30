import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/deeds_repository.dart';

class CreateDeedScreen extends ConsumerStatefulWidget {
  const CreateDeedScreen({super.key});

  @override
  ConsumerState<CreateDeedScreen> createState() => _CreateDeedScreenState();
}

class _CreateDeedScreenState extends ConsumerState<CreateDeedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _arabicController = TextEditingController();
  final _translationController = TextEditingController();
  final _referenceController = TextEditingController();
  
  String _selectedDeedType = AppConstants.deedGeneral;
  String? _selectedCategory;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    _arabicController.dispose();
    _translationController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submitDeed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter content')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) {
        throw Exception('Please sign in to post a deed');
      }

      final repository = DeedsRepository();
      await repository.createDeed(
        userId: user.uid,
        userName: user.displayName ?? 'User',
        userPhotoUrl: user.profilePicture,
        deedType: _selectedDeedType,
        content: _contentController.text.trim(),
        arabicText: _arabicController.text.trim().isEmpty 
            ? null 
            : _arabicController.text.trim(),
        translation: _translationController.text.trim().isEmpty
            ? null
            : _translationController.text.trim(),
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        category: _selectedCategory,
        imagePath: _selectedImage?.path,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deed posted successfully! +${AppConstants.xpPerDeedPost} XP'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share a Deed'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitDeed,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Deed Type Selection
            Text(
              'Deed Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _DeedTypeChip(
                  label: 'Ayah',
                  value: AppConstants.deedAyah,
                  icon: Icons.menu_book,
                  selected: _selectedDeedType == AppConstants.deedAyah,
                  onTap: () => setState(() => _selectedDeedType = AppConstants.deedAyah),
                ),
                _DeedTypeChip(
                  label: 'Hadith',
                  value: AppConstants.deedHadith,
                  icon: Icons.format_quote,
                  selected: _selectedDeedType == AppConstants.deedHadith,
                  onTap: () => setState(() => _selectedDeedType = AppConstants.deedHadith),
                ),
                _DeedTypeChip(
                  label: 'Quote',
                  value: AppConstants.deedQuote,
                  icon: Icons.auto_awesome,
                  selected: _selectedDeedType == AppConstants.deedQuote,
                  onTap: () => setState(() => _selectedDeedType = AppConstants.deedQuote),
                ),
                _DeedTypeChip(
                  label: 'Task',
                  value: AppConstants.deedTask,
                  icon: Icons.task,
                  selected: _selectedDeedType == AppConstants.deedTask,
                  onTap: () => setState(() => _selectedDeedType = AppConstants.deedTask),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Category Selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category (Optional)',
                prefixIcon: Icon(Icons.category),
              ),
              initialValue: _selectedCategory,
              items: AppConstants.deedCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 24),
            
            // Content
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content *',
                hintText: 'Enter your deed content...',
                prefixIcon: Icon(Icons.text_fields),
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter content';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Arabic Text (Optional)
            TextFormField(
              controller: _arabicController,
              decoration: const InputDecoration(
                labelText: 'Arabic Text (Optional)',
                hintText: 'Enter Arabic text...',
                prefixIcon: Icon(Icons.language),
              ),
              maxLines: 3,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            
            // Translation (Optional)
            TextFormField(
              controller: _translationController,
              decoration: const InputDecoration(
                labelText: 'Translation (Optional)',
                hintText: 'Enter translation...',
                prefixIcon: Icon(Icons.translate),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Reference (Optional)
            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Reference (Optional)',
                hintText: 'e.g., Quran 2:255, Sahih Bukhari 1',
                prefixIcon: Icon(Icons.bookmark),
              ),
            ),
            const SizedBox(height: 24),
            
            // Image Selection
            if (_selectedImage != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _selectedImage = null),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Add Image (Optional)'),
              ),
            const SizedBox(height: 24),
            
            // Info Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will earn ${AppConstants.xpPerDeedPost} XP for posting this deed!',
                        style: TextStyle(color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeedTypeChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DeedTypeChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

