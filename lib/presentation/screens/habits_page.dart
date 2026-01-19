import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Islamic tools hub'),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.green.shade900,
        foregroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          // Islamic Habits Tracker
          _buildToolCard(
            context,
            icon: Icons.check_circle,
            title: 'Ameen Habits Tracker',
            subtitle: 'Track your daily Islamic habits and build consistency',
            color: Colors.blue,
            onTap: () {
              context.push('/habits-list');
            },
          ),
          const SizedBox(height: 12),
          // Mood & Spiritual Wellness
          _buildToolCard(
            context,
            icon: Icons.mood,
            title: 'Nafs Wellness Tracker',
            subtitle: 'Track your spiritual mood and receive Islamic guidance',
            color: Colors.purple,
            onTap: () {
              context.push('/mood');
            },
          ),
          const SizedBox(height: 12),
          // Prayer Times
          _buildToolCard(
            context,
            icon: Icons.mosque,
            title: 'Salah Times Ameen',
            subtitle: 'Accurate prayer times for your location',
            color: Colors.green,
            onTap: () {
              context.push('/prayer-times');
            },
          ),
          const SizedBox(height: 12),
          // Qibla Direction
          _buildToolCard(
            context,
            icon: Icons.explore,
            title: 'Qibla Compass Ameen',
            subtitle: 'Find the precise direction to Kaaba in Mecca',
            color: Colors.orange,
            onTap: () {
              context.push('/qibla');
            },
          ),
          const SizedBox(height: 12),
          // Hijri Calendar
          _buildToolCard(
            context,
            icon: Icons.calendar_today,
            title: 'Hijri Calendar Ameen',
            subtitle: 'Islamic calendar with important dates and events',
            color: Colors.teal,
            onTap: () {
              context.push('/hijri-calendar');
            },
          ),
          const SizedBox(height: 12),
          // Prayer Alarms
          _buildToolCard(
            context,
            icon: Icons.alarm,
            title: 'Salah Alarms Ameen',
            subtitle: 'Set reminders for all five daily prayers',
            color: Colors.red,
            onTap: () {
              context.push('/prayer-alarms');
            },
          ),
          const SizedBox(height: 12),
          // Tasbih Counter
          _buildToolCard(
            context,
            icon: Icons.eco,
            title: 'Digital Tasbih Ameen',
            subtitle: 'Digital tasbih counter for dhikr and remembrance',
            color: Colors.indigo,
            onTap: () {
              context.push('/tasbih-counter');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
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
      ),
    );
  }
}
