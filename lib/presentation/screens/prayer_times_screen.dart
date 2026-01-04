import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_database.dart';
import '../../utils/offline_prayer_time_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

final madhabProvider = StateNotifierProvider<MadhabNotifier, Madhab>((ref) {
  return MadhabNotifier();
});

class MadhabNotifier extends StateNotifier<Madhab> {
  MadhabNotifier() : super(Madhab.shafi) {
    _loadMadhab();
  }

  Future<void> _loadMadhab() async {
    final prefs = await SharedPreferences.getInstance();
    final madhabIndex = prefs.getInt('selected_madhab') ?? 0;
    state = madhabIndex == 1 ? Madhab.hanafi : Madhab.shafi;
  }

  Future<void> setMadhab(Madhab madhab) async {
    state = madhab;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_madhab', madhab == Madhab.hanafi ? 1 : 0);
  }
}

final prayerTimesProvider = FutureProvider<Map<String, String>?>((ref) async {
  try {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to enable location services
      bool enabled = await Geolocator.openLocationSettings();
      if (!enabled) {
        return null;
      }
    }

    // Check and request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    
    // Handle different permission states
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied, return null to show permission request UI
        return null;
      }
    }

    // Handle permanently denied permission
    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied, user needs to enable in settings
      return null;
    }

    // Ensure we have valid permission before getting position
    if (permission != LocationPermission.whileInUse && 
        permission != LocationPermission.always) {
      // Unknown or restricted permission state
      return null;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    final madhab = ref.watch(madhabProvider);
    final date = DateTime.now();
    // Get timezone offset for the current date (accounts for DST)
    final timezone = OfflinePrayerTimeCalculator.getTimezoneOffset(date);
    
    // Debug: Log location and timezone info
    if (kDebugMode) {
      debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
      debugPrint('🕐 Timezone offset: $timezone hours');
      debugPrint('📅 Date: ${date.toString()}');
    }

    final today = DateFormat('yyyy-MM-dd').format(date);

    final localDb = AppDatabase.instance;
    final cached = await localDb.getPrayerTimes(today);

    // Check cache (recalculate if madhab changed or not in cache)
    final cachedMadhab = cached?['madhab'] as String?;
    final currentMadhabStr = madhab == Madhab.hanafi ? 'hanafi' : 'shafi';
    
    // Use approximate comparison for latitude/longitude (within 0.01 degrees ~1km)
    final cachedLat = cached?['latitude'] as double?;
    final cachedLon = cached?['longitude'] as double?;
    final isLocationMatch = cachedLat != null && cachedLon != null &&
        (cachedLat - position.latitude).abs() < 0.01 &&
        (cachedLon - position.longitude).abs() < 0.01;
    
    if (cached != null &&
        isLocationMatch &&
        (cachedMadhab == null || cachedMadhab == currentMadhabStr)) {
      return {
        'fajr': cached['fajr'] as String,
        'dhuhr': cached['dhuhr'] as String,
        'asr': cached['asr'] as String,
        'maghrib': cached['maghrib'] as String,
        'isha': cached['isha'] as String,
      };
    }

    final prayerTimes = OfflinePrayerTimeCalculator.calculate(
      date: date,
      latitude: position.latitude,
      longitude: position.longitude,
      timezone: timezone,
      madhab: madhab,
    );

    final timesMap = prayerTimes.toMap();

    await localDb.cachePrayerTimes({
      'id': today,
      'date': today,
      'fajr': timesMap['fajr']!,
      'dhuhr': timesMap['dhuhr']!,
      'asr': timesMap['asr']!,
      'maghrib': timesMap['maghrib']!,
      'isha': timesMap['isha']!,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'madhab': madhab == Madhab.hanafi ? 'hanafi' : 'shafi',
      'cachedAt': DateTime.now().toIso8601String(),
    });

    return timesMap;
  } catch (e) {
    return null;
  }
});

class PrayerTimesScreen extends ConsumerWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerTimesAsync = ref.watch(prayerTimesProvider);

    final madhab = ref.watch(madhabProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
        actions: [
          PopupMenuButton<Madhab>(
            tooltip: 'Select Madhab (Asr calculation method)',
            onSelected: (value) {
              ref.read(madhabProvider.notifier).setMadhab(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: Madhab.shafi,
                child: Text('Shafi / Maliki / Hanbali (Asr = 1 shadow)'),
              ),
              const PopupMenuItem(
                value: Madhab.hanafi,
                child: Text('Hanafi (Asr = 2 shadows)'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    madhab == Madhab.hanafi ? 'Hanafi' : 'Shafi',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: prayerTimesAsync.when(
        data: (prayerTimes) {
          if (prayerTimes == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
                      'Location Permission Required',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'To provide accurate prayer times, we need access to your device location.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Check current permission status
                          LocationPermission permission = await Geolocator.checkPermission();
                          
                          if (permission == LocationPermission.deniedForever) {
                            // Open app settings if permanently denied
                            await openAppSettings();
                          } else {
                            // Request permission
                            permission = await Geolocator.requestPermission();
                            if (permission == LocationPermission.deniedForever) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enable location permission in app settings'),
                                    action: SnackBarAction(
                                      label: 'Open Settings',
                                      onPressed: openAppSettings,
                                    ),
                                  ),
                                );
                              }
                            } else {
                              // Refresh provider
                              ref.invalidate(prayerTimesProvider);
                            }
                          }
                        },
                        icon: const Icon(Icons.location_on),
                        label: const Text('Grant Permission'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await openAppSettings();
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Open Settings'),
                      ),
                    ],
                  ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        ref.invalidate(prayerTimesProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
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
    int? nextPrayerIndex;

    // Find the next prayer time
    for (int i = 0; i < times.length; i++) {
      if (times[i] != null) {
        final prayerMinutes = _timeToMinutes(times[i]!);
        if (prayerMinutes > current) {
          nextPrayerIndex = i;
          break;
        }
      }
    }

    // If no prayer found today, next is tomorrow's Fajr (index 0)
    if (nextPrayerIndex == null) {
      return index == 0;
    }

    // Return true if current index is the next prayer
    return nextPrayerIndex == index;
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
