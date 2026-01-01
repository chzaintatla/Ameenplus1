import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IslamicToolsScreen extends StatelessWidget {
  const IslamicToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
          child: Text(
            'Islamic Tools',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListView(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
          _buildToolCard(
            context,
            icon: Icons.explore_outlined,
            title: 'Qibla Direction',
            subtitle: 'Find the direction to Mecca',
            color: Colors.blue,
            onTap: () => context.push('/qibla'),
            mediaQuery: mediaQuery,
          ),
          SizedBox(height: mediaQuery.size.height * 0.015),
          _buildToolCard(
            context,
            icon: Icons.schedule_outlined,
            title: 'Prayer Times',
            subtitle: 'View daily prayer schedules',
            color: Colors.green,
            onTap: () => context.push('/prayer-times'),
            mediaQuery: mediaQuery,
          ),
          SizedBox(height: mediaQuery.size.height * 0.015),
          _buildToolCard(
            context,
            icon: Icons.calendar_month_outlined,
            title: 'Hijri Calendar',
            subtitle: 'Islamic calendar and important dates',
            color: Colors.orange,
            onTap: () => context.push('/hijri-calendar'),
            mediaQuery: mediaQuery,
          ),
            ],
          ),
      ],
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required MediaQueryData mediaQuery,
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
          padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: mediaQuery.size.width * 0.08,
                  color: color,
                ),
              ),
              SizedBox(width: mediaQuery.size.width * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.005),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

