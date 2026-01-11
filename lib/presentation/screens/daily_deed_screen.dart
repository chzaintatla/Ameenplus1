import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../services/daily_deeds_service.dart';
import '../../models/daily_deed.dart';

class DailyDeedScreen extends ConsumerStatefulWidget {
  const DailyDeedScreen({super.key});

  @override
  ConsumerState<DailyDeedScreen> createState() => _DailyDeedScreenState();
}

class _DailyDeedScreenState extends ConsumerState<DailyDeedScreen> {
  final DailyDeedsService _deedsService = DailyDeedsService();
  DailyDeed? _todaysDeed;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodaysDeed();
  }

  Future<void> _loadTodaysDeed() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final profileAsync = ref.read(currentUserProfileProvider);
      final profile = profileAsync.value;
      if (profile != null) {
        final deed = await _deedsService.getTodaysDeed(profile);
        setState(() {
          _todaysDeed = deed;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading daily deed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Deed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodaysDeed,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _todaysDeed == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No deed available',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please complete your profile to get personalized deeds',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primaryContainer,
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _todaysDeed!.name,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _todaysDeed!.description,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _InfoCard(
                        icon: Icons.work_outline,
                        title: 'Why This Deed?',
                        content: _todaysDeed!.connection,
                      ),
                      const SizedBox(height: 16),
                      _InfoCard(
                        icon: Icons.star_outline,
                        title: 'Benefits',
                        content: _todaysDeed!.benefit,
                      ),
                      const SizedBox(height: 16),
                      if (_todaysDeed!.interests.isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Based on Your Interests',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _todaysDeed!.interests.map((interest) {
                                    return Chip(
                                      label: Text(
                                        interest,
                                        style: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.light
                                              ? Colors.black
                                              : null,
                                        ),
                                      ),
                                      avatar: const Icon(Icons.favorite, size: 18),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to create post or mark as completed
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Great! Keep up the good work.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark as Completed'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
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
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: Theme.of(context).textTheme.bodyMedium,
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

