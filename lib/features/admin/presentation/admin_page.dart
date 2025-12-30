import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_ready_provider.dart';
import '../data/admin_repository.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _referenceController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String _type = 'ayah';
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _referenceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ready = await ref.read(firebaseReadyProvider.future);
    if (!ready) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).addDeed(
            createdByUid: user.uid,
            type: _type,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
            imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
          );

      if (!mounted) return;
      _titleController.clear();
      _contentController.clear();
      _referenceController.clear();
      _imageUrlController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deed saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Portal')),
      body: firebaseReady.when(
        data: (ready) {
          if (!ready) {
            return const Center(child: Text('Firebase not configured yet.'));
          }

          return isAdmin.when(
            data: (ok) {
              if (!ok) {
                return const Center(child: Text('Access denied: admin only'));
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Add Deed Content', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _type,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(value: 'ayah', child: Text('Ayah')),
                              DropdownMenuItem(value: 'hadith', child: Text('Hadith')),
                              DropdownMenuItem(value: 'reminder', child: Text('Reminder')),
                              DropdownMenuItem(value: 'request', child: Text('Good Deed Request')),
                              DropdownMenuItem(value: 'dua', child: Text('Dua')),
                            ],
                            onChanged: (v) => setState(() => _type = v ?? 'ayah'),
                            decoration: const InputDecoration(labelText: 'Type'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(labelText: 'Title'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _contentController,
                            minLines: 4,
                            maxLines: 10,
                            decoration: const InputDecoration(labelText: 'Content'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _referenceController,
                            decoration: const InputDecoration(labelText: 'Reference (optional)'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _imageUrlController,
                            decoration: const InputDecoration(labelText: 'Image URL (optional)'),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}
