import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/accurate_prayer_time_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geocoding/geocoding.dart';

class PrayerAlarmsScreen extends StatefulWidget {
  const PrayerAlarmsScreen({super.key});

  @override
  State<PrayerAlarmsScreen> createState() => _PrayerAlarmsScreenState();
}

class _PrayerAlarmsScreenState extends State<PrayerAlarmsScreen> {
  final AccuratePrayerTimeService _prayerService = AccuratePrayerTimeService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<String, DateTime>? _prayerTimes;
  Map<String, bool> _alarmEnabled = {};
  bool _isLoading = true;
  bool _isPlayingTest = false;
  String _calculationMethod = AccuratePrayerTimeService.methodMuslimWorldLeague;
  geo.LocationAccuracy? _locationAccuracy;
  String? _locationName;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
      
      // Get location name from coordinates
      await _loadLocationName();
      
      setState(() {
        _prayerTimes = times;
        _locationAccuracy = accuracy;
        _isLoading = false;
      });
      
      // Set alarms for all prayers with azan sound
      for (final entry in times.entries) {
        if (_alarmEnabled[entry.key] ?? true) {
          await _prayerService.setPrayerAlarm(entry.key, entry.value, customTone: 'azan');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading prayer times: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadLocationName() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty && mounted) {
        final placemark = placemarks.first;
        final cityName = placemark.locality ?? 
                        placemark.subAdministrativeArea ?? 
                        placemark.administrativeArea ?? 
                        'Unknown Location';
        setState(() {
          _locationName = cityName;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationName = 'Unknown Location';
        });
      }
    }
  }

  Future<void> _loadAlarmSettings() async {
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final prayer in prayers) {
      final enabled = await _prayerService.isAlarmEnabled(prayer);
      if (mounted) {
        setState(() {
          _alarmEnabled[prayer] = enabled;
        });
      }
    }
  }

  Future<void> _toggleAlarm(String prayerName) async {
    final newValue = !(_alarmEnabled[prayerName] ?? true);
    await _prayerService.setAlarmEnabled(prayerName, newValue);
    if (mounted) {
      setState(() {
        _alarmEnabled[prayerName] = newValue;
      });
    }

    // Update alarm if prayer time exists
    if (newValue && _prayerTimes != null && _prayerTimes!.containsKey(prayerName)) {
      await _prayerService.setPrayerAlarm(prayerName, _prayerTimes![prayerName]!, customTone: 'azan');
    }
  }

  Future<void> _playTestAlarm() async {
    if (_isPlayingTest) {
      await _audioPlayer.stop();
      setState(() => _isPlayingTest = false);
      return;
    }

    try {
      setState(() => _isPlayingTest = true);
      // Play azan.mp3 from assets/audios/
      await _audioPlayer.play(AssetSource('audios/azan.mp3'));
      
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() => _isPlayingTest = false);
        }
      });
    } catch (e) {
      setState(() => _isPlayingTest = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing test alarm: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Alarms'),
        actions: [
          IconButton(
            icon: Icon(_isPlayingTest ? Icons.stop_circle : Icons.play_circle),
            onPressed: _playTestAlarm,
            tooltip: 'Test Azan Sound',
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => _updateLocation(),
            tooltip: 'Update Location',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
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
                child: Text('Islamic Society of NA'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodEgyptian,
                child: Text('Egyptian Authority'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodMakkah,
                child: Text('Umm al-Qura, Makkah'),
              ),
              const PopupMenuItem(
                value: AccuratePrayerTimeService.methodKarachi,
                child: Text('Karachi'),
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
                      _buildLocationCard(),
                      const SizedBox(height: 16),
                      ..._prayerTimes!.entries.map((entry) {
                        return _PrayerTimeCard(
                          prayerName: entry.key,
                          prayerTime: entry.value,
                          isAlarmEnabled: _alarmEnabled[entry.key] ?? true,
                          onToggleAlarm: () => _toggleAlarm(entry.key),
                        );
                      }),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Azan sound will play from assets/audios/azan.mp3',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_locationAccuracy != null)
                  _AccuracyIndicator(accuracy: _locationAccuracy!),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _locationName ?? 'Detecting...',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateLocation() async {
    try {
      await _loadLocationName();
      await _loadPrayerTimes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating location: $e')),
        );
      }
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
      case geo.LocationAccuracy.high:
      case geo.LocationAccuracy.best:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case geo.LocationAccuracy.medium:
        icon = Icons.info;
        color = Colors.orange;
        break;
      default:
        icon = Icons.warning;
        color = Colors.red;
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
          backgroundColor: _getPrayerColor(prayerName).withValues(alpha: 0.8),
          child: Icon(_getPrayerIcon(prayerName), color: Colors.white),
        ),
        title: Text(
          prayerName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPast ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          timeStr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isPast ? Colors.grey : _getPrayerColor(prayerName),
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
      case 'Fajr': return Colors.blue;
      case 'Dhuhr': return Colors.orange;
      case 'Asr': return Colors.green;
      case 'Maghrib': return Colors.red;
      case 'Isha': return Colors.purple;
      default: return Colors.teal;
    }
  }

  IconData _getPrayerIcon(String prayerName) {
    switch (prayerName) {
      case 'Fajr': return Icons.wb_sunny_outlined;
      case 'Dhuhr': return Icons.wb_sunny;
      case 'Asr': return Icons.wb_twilight;
      case 'Maghrib': return Icons.nightlight_round;
      case 'Isha': return Icons.nightlight_outlined;
      default: return Icons.mosque;
    }
  }
}
