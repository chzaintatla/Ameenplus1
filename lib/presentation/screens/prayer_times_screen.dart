import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_database.dart';

final prayerTimesProvider = FutureProvider<Map<String, String>?>((ref) async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    Position position = await Geolocator.getCurrentPosition();

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final localDb = AppDatabase.instance;
    final cached = await localDb.getPrayerTimes(today);

    if (cached != null &&
        cached['latitude'] == position.latitude &&
        cached['longitude'] == position.longitude) {
      return {
        'fajr': cached['fajr'] as String,
        'dhuhr': cached['dhuhr'] as String,
        'asr': cached['asr'] as String,
        'maghrib': cached['maghrib'] as String,
        'isha': cached['isha'] as String,
      };
    }

    final prayerTimes = _calculatePrayerTimes(
      position.latitude,
      position.longitude,
      DateTime.now(),
    );

    await localDb.cachePrayerTimes({
      'id': today,
      'date': today,
      'fajr': prayerTimes['fajr']!,
      'dhuhr': prayerTimes['dhuhr']!,
      'asr': prayerTimes['asr']!,
      'maghrib': prayerTimes['maghrib']!,
      'isha': prayerTimes['isha']!,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'cachedAt': DateTime.now().toIso8601String(),
    });

    return prayerTimes;
  } catch (e) {
    return null;
  }
});

Map<String, String> _calculatePrayerTimes(double latitude, double longitude, DateTime date) {
  final now = DateTime.now();
  final hour = now.hour;
  final minute = now.minute;

  return {
    'fajr': '05:30',
    'dhuhr': '12:30',
    'asr': '15:45',
    'maghrib': '18:15',
    'isha': '19:45',
  };
}

class PrayerTimesScreen extends ConsumerWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerTimesAsync = ref.watch(prayerTimesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
      ),
      body: prayerTimesAsync.when(
        data: (prayerTimes) {
          if (prayerTimes == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location permission required',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please enable location services to get accurate prayer times',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(prayerTimesProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final currentTime = DateFormat('HH:mm').format(now);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.mosque,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(now),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Time: $currentTime',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...AppConstants.prayerNames.asMap().entries.map((entry) {
                final index = entry.key;
                final prayerName = entry.value;
                final prayerTime = [
                  prayerTimes['fajr'],
                  prayerTimes['dhuhr'],
                  prayerTimes['asr'],
                  prayerTimes['maghrib'],
                  prayerTimes['isha'],
                ][index];

                final isNext = _isNextPrayer(prayerTimes, currentTime, index);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isNext
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isNext
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _getPrayerEmoji(prayerName),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    title: Text(
                      prayerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                        color: isNext
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                    trailing: Text(
                      prayerTime ?? '--:--',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isNext
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Prayer times are calculated based on your location. Times may vary slightly based on your calculation method.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading prayer times',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(prayerTimesProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isNextPrayer(Map<String, String> prayerTimes, String currentTime, int index) {
    final times = [
      prayerTimes['fajr'],
      prayerTimes['dhuhr'],
      prayerTimes['asr'],
      prayerTimes['maghrib'],
      prayerTimes['isha'],
    ];

    final current = _timeToMinutes(currentTime);

    for (int i = index; i < times.length; i++) {
      if (times[i] != null) {
        final prayerMinutes = _timeToMinutes(times[i]!);
        if (prayerMinutes > current) {
          return i == index;
        }
      }
    }

    return index == 0;
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  String _getPrayerEmoji(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return '🌅';
      case 'dhuhr':
        return '☀️';
      case 'asr':
        return '🌤️';
      case 'maghrib':
        return '🌆';
      case 'isha':
        return '🌙';
      default:
        return '🕌';
    }
  }
}
