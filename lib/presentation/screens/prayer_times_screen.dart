import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan_dart/adhan_dart.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_database.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

// Enum for Madhab (Asr calculation method)
enum PrayerMadhab {
  shafi, // Asr shadow = 1 (Shafi, Maliki, Hanbali)
  hanafi, // Asr shadow = 2 (Hanafi)
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> with WidgetsBindingObserver {
  // State variables
  Map<String, String>? _prayerTimes;
  bool _isLoading = false;
  String? _errorMessage;
  PrayerMadhab _madhab = PrayerMadhab.shafi;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMadhab();
    _checkAndLoadPrayerTimes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app resumes (e.g., returning from settings)
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkAndLoadPrayerTimes();
        }
      });
    }
  }

  Future<void> _loadMadhab() async {
    final prefs = await SharedPreferences.getInstance();
    final madhabIndex = prefs.getInt('selected_madhab') ?? 0;
    setState(() {
      _madhab = madhabIndex == 1 ? PrayerMadhab.hanafi : PrayerMadhab.shafi;
    });
  }

  Future<void> _saveMadhab(PrayerMadhab madhab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_madhab', madhab == PrayerMadhab.hanafi ? 1 : 0);
    setState(() {
      _madhab = madhab;
    });
    // Reload prayer times with new madhab
    _checkAndLoadPrayerTimes();
  }

  Future<void> _checkAndLoadPrayerTimes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location services are disabled. Please enable location services.';
        });
        return;
      }

      // Step 2: Check location permission
      bool hasPermission = await _checkLocationPermission();
      
      if (!hasPermission) {
        setState(() {
          _isLoading = false;
          _prayerTimes = null;
        });
        return;
      }

      // Step 3: Get current position
      Position position = await _getCurrentPosition();
      
      // Step 4: Calculate prayer times
      await _calculatePrayerTimes(position);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
        _prayerTimes = null;
      });
    }
  }

  Future<bool> _checkLocationPermission() async {
    try {
      // Check using permission_handler
      final phStatus = await Permission.location.status;
      if (phStatus.isGranted || phStatus.isLimited) {
        return true;
      }

      // Check using Geolocator
      final geoPermission = await Geolocator.checkPermission();
      return geoPermission == LocationPermission.whileInUse || 
             geoPermission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }

  Future<Position> _getCurrentPosition() async {
    // Try different accuracy levels
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e2) {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 15),
        );
      }
    }
  }

  Future<void> _calculatePrayerTimes(Position position) async {
    final date = DateTime.now();
    
    // Check cache first
    final today = DateFormat('yyyy-MM-dd').format(date);
    final localDb = AppDatabase.instance;
    final cached = await localDb.getPrayerTimes(today);
    
    final cachedMadhab = cached?['madhab'] as String?;
    final currentMadhabStr = _madhab == PrayerMadhab.hanafi ? 'hanafi' : 'shafi';
    
    // Check if cached location is close (within 500m)
    final cachedLat = cached?['latitude'] as double?;
    final cachedLon = cached?['longitude'] as double?;
    double locationDistance = double.infinity;
    
    if (cachedLat != null && cachedLon != null) {
      locationDistance = Geolocator.distanceBetween(
        cachedLat, cachedLon,
        position.latitude, position.longitude,
      );
    }
    
    // Use cache if location is close and madhab matches
    if (cached != null && 
        locationDistance < 500 &&
        (cachedMadhab == null || cachedMadhab == currentMadhabStr)) {
      setState(() {
        _prayerTimes = {
          'fajr': cached['fajr'] as String,
          'dhuhr': cached['dhuhr'] as String,
          'asr': cached['asr'] as String,
          'maghrib': cached['maghrib'] as String,
          'isha': cached['isha'] as String,
        };
        _currentPosition = position;
        _isLoading = false;
      });
      return;
    }
    
    // Calculate new prayer times using adhan_dart (more accurate)
    final coordinates = Coordinates(position.latitude, position.longitude);
    
    // Get calculation parameters (Muslim World League by default)
    CalculationParameters params = CalculationMethodParameters.muslimWorldLeague();
    
    // Set Asr method based on madhab using adhan_dart's Madhab enum
    // Convert our PrayerMadhab to adhan_dart's Madhab
    final adhanMadhab = _madhab == PrayerMadhab.hanafi 
        ? Madhab.hanafi 
        : Madhab.shafi;
    
    // Update params with correct madhab
    params = CalculationParameters(
      method: params.method,
      fajrAngle: params.fajrAngle,
      ishaAngle: params.ishaAngle,
      ishaInterval: params.ishaInterval,
      madhab: adhanMadhab,
      highLatitudeRule: params.highLatitudeRule,
      adjustments: params.adjustments,
    );
    
    // Create PrayerTimes instance
    final prayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: date,
      calculationParameters: params,
    );
    
    // Format times as HH:mm
    final format = DateFormat('HH:mm');
    
    final timesMap = {
      'fajr': format.format(prayerTimes.fajr.toLocal()),
      'dhuhr': format.format(prayerTimes.dhuhr.toLocal()),
      'asr': format.format(prayerTimes.asr.toLocal()),
      'maghrib': format.format(prayerTimes.maghrib.toLocal()),
      'isha': format.format(prayerTimes.isha.toLocal()),
    };
    
    // Cache the results
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
      'madhab': currentMadhabStr,
      'cachedAt': DateTime.now().toIso8601String(),
    });
    
    setState(() {
      _prayerTimes = timesMap;
      _currentPosition = position;
      _isLoading = false;
    });
  }

  Future<void> _requestLocationPermission() async {
    try {
      // Try permission_handler first
      final phStatus = await Permission.location.request();
      if (phStatus.isGranted || phStatus.isLimited) {
        _checkAndLoadPrayerTimes();
        return;
      }
      
      // Try Geolocator
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.whileInUse || 
            permission == LocationPermission.always) {
          _checkAndLoadPrayerTimes();
        } else if (permission == LocationPermission.deniedForever) {
          if (mounted) {
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
        }
      } else if (permission == LocationPermission.deniedForever) {
        await openAppSettings();
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          _checkAndLoadPrayerTimes();
        }
      } else {
        _checkAndLoadPrayerTimes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permission: $e')),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _checkAndLoadPrayerTimes();
    }
  }

  Widget _buildPermissionRequiredUI() {
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
                  onPressed: _isLoading ? null : _requestLocationPermission,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Grant Permission'),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _openSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _isLoading ? null : _checkAndLoadPrayerTimes,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimesUI() {
    if (_prayerTimes == null) return _buildPermissionRequiredUI();

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
            _prayerTimes!['fajr'],
            _prayerTimes!['dhuhr'],
            _prayerTimes!['asr'],
            _prayerTimes!['maghrib'],
            _prayerTimes!['isha'],
          ][index];

          final isNext = _isNextPrayer(_prayerTimes!, currentTime, index);

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
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
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
      ],
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

    for (int i = 0; i < times.length; i++) {
      if (times[i] != null) {
        final prayerMinutes = _timeToMinutes(times[i]!);
        if (prayerMinutes > current) {
          nextPrayerIndex = i;
          break;
        }
      }
    }

    if (nextPrayerIndex == null) {
      return index == 0;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
        actions: [
          PopupMenuButton<PrayerMadhab>(
            tooltip: 'Select Madhab (Asr calculation method)',
            onSelected: _saveMadhab,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PrayerMadhab.shafi,
                child: Text('Shafi / Maliki / Hanbali (Asr = 1 shadow)'),
              ),
              const PopupMenuItem(
                value: PrayerMadhab.hanafi,
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
                    _madhab == PrayerMadhab.hanafi ? 'Hanafi' : 'Shafi',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _checkAndLoadPrayerTimes,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _prayerTimes == null
                  ? _buildPermissionRequiredUI()
                  : _buildPrayerTimesUI(),
    );
  }
}
