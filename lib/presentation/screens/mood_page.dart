import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_constants.dart';
import '../../models/mood_model.dart';
import 'leaderboard_page.dart';
import 'islamic_tools_screen.dart';

class MoodPage extends StatefulWidget {
  const MoodPage({super.key});

  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? selectedMood;

  final List<Map<String, dynamic>> moods = [
    {'mood': AppConstants.moodAngry, 'label': 'Angry', 'emoji': '😠', 'color': const Color(0xFFD32F2F)},
    {'mood': AppConstants.moodSad, 'label': 'Sad', 'emoji': '😢', 'color': const Color(0xFF1976D2)},
    {'mood': AppConstants.moodHappy, 'label': 'Happy', 'emoji': '😊', 'color': const Color(0xFFFFA726)},
    {'mood': AppConstants.moodStressed, 'label': 'Stressed', 'emoji': '😰', 'color': const Color(0xFF7B1FA2)},
    {'mood': AppConstants.moodDemotivated, 'label': 'Demotivated', 'emoji': '😔', 'color': const Color(0xFF616161)},
    {'mood': AppConstants.moodLonely, 'label': 'Lonely', 'emoji': '😞', 'color': const Color(0xFF5E35B1)},
    {'mood': AppConstants.moodRepent, 'label': 'Want to Repent', 'emoji': '😌', 'color': const Color(0xFF4CAF50)},
    {'mood': AppConstants.moodLearn, 'label': 'Want to Learn', 'emoji': '🤓', 'color': const Color(0xFF00ACC1)},
    {'mood': AppConstants.moodPeace, 'label': 'Seeking Peace', 'emoji': '😇', 'color': const Color(0xFF66BB6A)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.green.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green.shade700,
          tabs: const [
            Tab(icon: Icon(Icons.self_improvement), text: 'Mood'),
            Tab(icon: Icon(Icons.dashboard), text: 'Tools & Leaderboard'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMoodTab(),
              _buildToolsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoodTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.tertiaryContainer,
                Theme.of(context).colorScheme.tertiary,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How are you feeling?',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get Islamic guidance based on your current mood',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.self_improvement,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Select Your Mood',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: moods.length,
          itemBuilder: (context, index) {
            final moodData = moods[index];
            final isSelected = selectedMood == moodData['mood'];

            return _buildMoodCard(
              mood: moodData['mood'],
              label: moodData['label'],
              emoji: moodData['emoji'],
              color: moodData['color'],
              isSelected: isSelected,
            );
          },
        ),
        const SizedBox(height: 20),
        if (selectedMood != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Islamic Guidance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View History'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...MoodSuggestionsData.getSuggestions(selectedMood!).map((suggestion) {
            return _buildSuggestionCard(suggestion);
          }),
        ],
        if (selectedMood == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select a mood above to get Islamic guidance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToolsTab() {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: LeaderboardPage(),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
        const SliverToBoxAdapter(
          child: IslamicToolsScreen(),
        ),
      ],
    );
  }

  Widget _buildMoodCard({
    required String mood,
    required String label,
    required String emoji,
    required Color color,
    required bool isSelected,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? color.withValues(alpha: 0.15) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedMood = mood;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? color : null,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(MoodSuggestion suggestion) {
    final Color contentColor;
    switch (suggestion.contentType) {
      case 'ayah':
        contentColor = const Color(0xFFFFD700);
      case 'hadith':
        contentColor = const Color(0xFF4CAF50);
      case 'dua':
        contentColor = const Color(0xFF2196F3);
      default:
        contentColor = const Color(0xFF9C27B0);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: contentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    suggestion.contentType.toUpperCase(),
                    style: TextStyle(
                      color: contentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              suggestion.arabicText,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                height: 2,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Text(
              suggestion.translation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (suggestion.reference != null) ...[
              const SizedBox(height: 8),
              Text(
                '— ${suggestion.reference}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
