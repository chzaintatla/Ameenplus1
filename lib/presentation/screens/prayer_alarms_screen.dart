import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/accurate_prayer_time_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

class PrayerAlarmsScreen extends ConsumerStatefulWidget {
  const PrayerAlarmsScreen({super.key});

  @override
  ConsumerState<PrayerAlarmsScreen> createState() => _PrayerAlarmsScreenState();
}

class _PrayerAlarmsScreenState extends ConsumerState<PrayerAlarmsScreen> {
  final AccuratePrayerTimeService _prayerService = AccuratePrayerTimeService();
  Map<String, DateTime>? _prayerTimes;
  Map<String, bool> _alarmEnabled = {};
  bool _isLoading = true;
  String _calculationMethod = AccuratePrayerTimeService.methodMuslimWorldLeague;
  geo.LocationAccuracy? _locationAccuracy;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _prayerService.initialize();
    await _loadPrayerTimes();
    await _loadAlarmSettings();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() => _isLoading = true);
    try {
      final accuracy = await _prayerService.validateLocationAccuracy();
      final times = await _prayerService.getPrayerTimes(
        calculationMethod: _calculationMethod,
      );
      setState(() {
        _prayerTimes = times;
        _locationAccuracy = accuracy;
        _isLoading = false;
      });
      
      // Set alarms for all prayers
      for (final entry in times.entries) {
        if (_alarmEnabled[entry.key] ?? true) {
          await _prayerService.setPrayerAlarm(entry.key, entry.value);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading prayer times: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadAlarmSettings() async {
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final prayer in prayers) {
      final enabled = await _prayerService.isAlarmEnabled(prayer);
      setState(() {
        _alarmEnabled[prayer] = enabled;
      });
    }
  }

  Future<void> _toggleAlarm(String prayerName) async {
    final newValue = !(_alarmEnabled[prayerName] ?? true);
    await _prayerService.setAlarmEnabled(prayerName, newValue);
    setState(() {
      _alarmEnabled[prayerName] = newValue;
    });

    // Update alarm if prayer time exists
    if (newValue && _prayerTimes != null && _prayerTimes!.containsKey(prayerName)) {
      await _prayerService.setPrayerAlarm(prayerName, _prayerTimes![prayerName]!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Time Alarms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => _updateLocation(),
            tooltip: 'Update Location',
          ),
          PopupMenuButton<String>(
            onSelected: (method) {
              setState(() => _calculationMethod = method);
              _loadPrayerTimes();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodMuslimWorldLeague,
                child: Text('Muslim World League'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodIslamicSociety,
                child: Text('Islamic Society of North America'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodEgyptian,
                child: Text('Egyptian General Authority'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodMakkah,
                child: Text('Umm al-Qura, Makkah'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodKarachi,
                child: Text('University of Islamic Sciences, Karachi'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodTehran,
                child: Text('Institute of Geophysics, Tehran'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodJafari,
                child: Text('Shia Ithna-Ashari (Jafari)'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prayerTimes == null
              ? const Center(child: Text('Unable to load prayer times'))
              : RefreshIndicator(
                  onRefresh: _loadPrayerTimes,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Calculation Method',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (_locationAccuracy != null)
                                    _AccuracyIndicator(accuracy: _locationAccuracy!),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_getMethodName(_calculationMethod)),
                              if (_locationAccuracy != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Location Accuracy: ${_getAccuracyText(_locationAccuracy!)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: _getAccuracyColor(_locationAccuracy!),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._prayerTimes!.entries.map((entry) {
                        return _PrayerTimeCard(
                          prayerName: entry.key,
                          prayerTime: entry.value,
                          isAlarmEnabled: _alarmEnabled[entry.key] ?? true,
                          onToggleAlarm: () => _toggleAlarm(entry.key),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Future<void> _updateLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      await _loadPrayerTimes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating location: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _getMethodName(String method) {
    switch (method) {
      case AccuratePrayerTimeService.methodMuslimWorldLeague:
        return 'Muslim World League';
      case AccuratePrayerTimeService.methodIslamicSociety:
        return 'Islamic Society of North America';
      case AccuratePrayerTimeService.methodEgyptian:
        return 'Egyptian General Authority';
      case AccuratePrayerTimeService.methodMakkah:
        return 'Umm al-Qura, Makkah';
      case AccuratePrayerTimeService.methodKarachi:
        return 'University of Islamic Sciences, Karachi';
      case AccuratePrayerTimeService.methodTehran:
        return 'Institute of Geophysics, Tehran';
      case AccuratePrayerTimeService.methodJafari:
        return 'Shia Ithna-Ashari (Jafari)';
      default:
        return method;
    }
  }

  String _getAccuracyText(geo.LocationAccuracy accuracy) {
    switch (accuracy) {
      case geo.LocationAccuracy.bestForNavigation:
        return 'Best for Navigation (Most Accurate)';
      case geo.LocationAccuracy.best:
        return 'Best (Most Accurate)';
      case geo.LocationAccuracy.high:
        return 'High (Very Accurate)';
      case geo.LocationAccuracy.medium:
        return 'Medium (Accurate)';
      case geo.LocationAccuracy.low:
        return 'Low (Less Accurate)';
      case geo.LocationAccuracy.lowest:
        return 'Lowest (Less Accurate)';
      case geo.LocationAccuracy.reduced:
        return 'Reduced (Limited Accuracy)';
    }
  }

  Color _getAccuracyColor(geo.LocationAccuracy accuracy) {
    switch (accuracy) {
      case geo.LocationAccuracy.bestForNavigation:
        return Colors.green;
      case geo.LocationAccuracy.best:
        return Colors.green;
      case geo.LocationAccuracy.high:
        return Colors.green;
      case geo.LocationAccuracy.medium:
        return Colors.orange;
      case geo.LocationAccuracy.low:
        return Colors.red;
      case geo.LocationAccuracy.lowest:
        return Colors.red;
      case geo.LocationAccuracy.reduced:
        return Colors.orange;
    }
  }
}

class _AccuracyIndicator extends StatelessWidget {
  final geo.LocationAccuracy accuracy;

  const _AccuracyIndicator({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (accuracy) {
      case geo.LocationAccuracy.bestForNavigation:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case geo.LocationAccuracy.best:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case geo.LocationAccuracy.high:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case geo.LocationAccuracy.medium:
        icon = Icons.info;
        color = Colors.orange;
        break;
      case geo.LocationAccuracy.low:
        icon = Icons.warning;
        color = Colors.red;
        break;
      case geo.LocationAccuracy.lowest:
        icon = Icons.warning;
        color = Colors.red;
        break;
      case geo.LocationAccuracy.reduced:
        icon = Icons.info;
        color = Colors.orange;
        break;
    }

    return Icon(icon, color: color, size: 20);
  }
}

class _PrayerTimeCard extends StatelessWidget {
  final String prayerName;
  final DateTime prayerTime;
  final bool isAlarmEnabled;
  final VoidCallback onToggleAlarm;

  const _PrayerTimeCard({
    required this.prayerName,
    required this.prayerTime,
    required this.isAlarmEnabled,
    required this.onToggleAlarm,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = '${prayerTime.hour.toString().padLeft(2, '0')}:${prayerTime.minute.toString().padLeft(2, '0')}';
    final isPast = prayerTime.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPrayerColor(prayerName),
          child: Icon(
            _getPrayerIcon(prayerName),
            color: Colors.white,
          ),
        ),
        title: Text(
          prayerName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPast ? Theme.of(context).colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text(
          timeStr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isPast ? Theme.of(context).colorScheme.onSurfaceVariant : _getPrayerColor(prayerName),
          ),
        ),
        trailing: Switch(
          value: isAlarmEnabled,
          onChanged: (_) => onToggleAlarm(),
        ),
      ),
    );
  }

  Color _getPrayerColor(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return Colors.blue;
      case 'Dhuhr':
        return Colors.orange;
      case 'Asr':
        return const Color(0xFF4CAF50); // Green instead of amber/yellow
      case 'Maghrib':
        return Colors.red;
      case 'Isha':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  IconData _getPrayerIcon(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return Icons.wb_sunny_outlined;
      case 'Dhuhr':
        return Icons.wb_sunny;
      case 'Asr':
        return Icons.wb_twilight;
      case 'Maghrib':
        return Icons.nightlight_round;
      case 'Isha':
        return Icons.nightlight_outlined;
      default:
        return Icons.mosque;
    }
  }
}

