import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:math' as math;

class PrayerTimeService {
  static const String _prefKeyLocation = 'prayer_location';
  static const String _prefKeyCalculationMethod = 'prayer_calculation_method';
  static const String _prefKeyAlarmEnabled = 'prayer_alarm_enabled_';
  static const String _prefKeyAlarmTone = 'prayer_alarm_tone_';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const String methodMuslimWorldLeague = 'MWL';
  static const String methodIslamicSociety = 'ISNA';
  static const String methodEgyptian = 'Egyptian';
  static const String methodMakkah = 'Makkah';
  static const String methodKarachi = 'Karachi';
  static const String methodTehran = 'Tehran';
  static const String methodJafari = 'Jafari';

  Future<void> initialize() async {
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
  }

  Future<Map<String, DateTime>> getPrayerTimes({
    double? latitude,
    double? longitude,
    String? calculationMethod,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (latitude == null || longitude == null) {
      final savedLocation = prefs.getString(_prefKeyLocation);
      if (savedLocation != null) {
        final parts = savedLocation.split(',');
        latitude = double.parse(parts[0]);
        longitude = double.parse(parts[1]);
      } else {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          latitude = position.latitude;
          longitude = position.longitude;
          await prefs.setString(_prefKeyLocation, '$latitude,$longitude');
        } catch (e) {
          latitude = 21.4225;
          longitude = 39.8262;
        }
      }
    } else {
      await prefs.setString(_prefKeyLocation, '$latitude,$longitude');
    }

    calculationMethod ??= prefs.getString(_prefKeyCalculationMethod) ?? methodMuslimWorldLeague;

    final now = DateTime.now();
    return _calculatePrayerTimes(
      latitude,
      longitude,
      now.year,
      now.month,
      now.day,
      calculationMethod,
    );
  }

  Map<String, DateTime> _calculatePrayerTimes(
    double latitude,
    double longitude,
    int year,
    int month,
    int day,
    String method,
  ) {
    final julianDay = _julianDay(year, month, day);
    final dayOfYear = _dayOfYear(year, month, day);
    final eqTime = _equationOfTime(dayOfYear);
    final declination = _solarDeclination(dayOfYear);
    final (fajrAngle, ishaAngle) = _getMethodAngles(method);
    
    final fajr = _calculateTime(latitude, longitude, julianDay, fajrAngle, eqTime, declination, -1);
    final dhuhr = _calculateTime(latitude, longitude, julianDay, 0, eqTime, declination, 0);
    final asr = _calculateAsrTime(latitude, longitude, julianDay, eqTime, declination);
    final maghrib = _calculateTime(latitude, longitude, julianDay, 0.833, eqTime, declination, 1);
    final isha = _calculateTime(latitude, longitude, julianDay, ishaAngle, eqTime, declination, 1);

    return {
      'Fajr': fajr,
      'Dhuhr': dhuhr,
      'Asr': asr,
      'Maghrib': maghrib,
      'Isha': isha,
    };
  }

  (double, double) _getMethodAngles(String method) {
    switch (method) {
      case methodMuslimWorldLeague:
        return (18.0, 17.0);
      case methodIslamicSociety:
        return (15.0, 15.0);
      case methodEgyptian:
        return (19.5, 17.5);
      case methodMakkah:
        return (18.5, 90.0);
      case methodKarachi:
        return (18.0, 18.0);
      case methodTehran:
        return (17.7, 14.0);
      case methodJafari:
        return (16.0, 14.0);
      default:
        return (18.0, 17.0);
    }
  }

  double _julianDay(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() + (30.6001 * (month + 1)).floor() + day + b - 1524.5;
  }

  int _dayOfYear(int year, int month, int day) {
    final daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
      daysInMonth[1] = 29;
    }
    var dayOfYear = day;
    for (int i = 0; i < month - 1; i++) {
      dayOfYear += daysInMonth[i];
    }
    return dayOfYear;
  }

  double _equationOfTime(int dayOfYear) {
    final B = (360 / 365) * (dayOfYear - 81) * (math.pi / 180);
    return 9.87 * math.sin(2 * B) - 7.53 * math.cos(B) - 1.5 * math.sin(B);
  }

  double _solarDeclination(int dayOfYear) {
    return 23.45 * math.sin((360 / 365) * (284 + dayOfYear) * (math.pi / 180));
  }

  DateTime _calculateTime(
    double latitude,
    double longitude,
    double julianDay,
    double angle,
    double eqTime,
    double declination,
    int sign,
  ) {
    final hourAngle = _hourAngle(latitude, angle, declination, sign);
    final time = 12 + (4 * (longitude - hourAngle) + eqTime) / 60;
    final hours = time.floor();
    final minutes = ((time - hours) * 60).round();
    
    return DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hours, minutes);
  }

  double _hourAngle(double latitude, double angle, double declination, int sign) {
    final latRad = latitude * (math.pi / 180);
    final decRad = declination * (math.pi / 180);
    final angleRad = angle * (math.pi / 180);
    
    final cosH = -math.tan(latRad) * math.tan(decRad) - 
        math.sin(angleRad) / (math.cos(latRad) * math.cos(decRad));
    
    final H = math.acos(cosH.clamp(-1.0, 1.0)) * (180 / math.pi);
    return sign < 0 ? -H : H;
  }

  DateTime _calculateAsrTime(
    double latitude,
    double longitude,
    double julianDay,
    double eqTime,
    double declination,
  ) {
    final latRad = latitude * (math.pi / 180);
    final decRad = declination * (math.pi / 180);
    
    final tanLat = math.tan(latRad);
    final tanDec = math.tan(decRad);
    
    final H = math.atan(1 / (1 + tanLat * tanDec)) * (180 / math.pi);
    
    final time = 12 + (4 * (longitude - H) + eqTime) / 60;
    final hours = time.floor();
    final minutes = ((time - hours) * 60).round();
    
    return DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hours, minutes);
  }

  Future<void> setPrayerAlarm(String prayerName, DateTime prayerTime, {String? customTone}) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('$_prefKeyAlarmEnabled$prayerName') ?? true;
    
    if (!isEnabled) return;

    final tone = customTone ?? prefs.getString('$_prefKeyAlarmTone$prayerName');
    
    // Use default system sound if no custom tone is specified
    // Don't use RawResourceAndroidNotificationSound unless we have actual raw resource files
    final androidSound = tone != null && tone != 'default' 
        ? RawResourceAndroidNotificationSound(tone)
        : null;

    await _notifications.zonedSchedule(
      _getPrayerId(prayerName),
      'Prayer Time: $prayerName',
      'It\'s time for $prayerName prayer',
      _convertToTZDateTime(prayerTime),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_times',
          'Prayer Time Alarms',
          channelDescription: 'Notifications for prayer times',
          importance: Importance.high,
          priority: Priority.high,
          sound: androidSound,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  int _getPrayerId(String prayerName) {
    switch (prayerName) {
      case 'Fajr': return 1;
      case 'Dhuhr': return 2;
      case 'Asr': return 3;
      case 'Maghrib': return 4;
      case 'Isha': return 5;
      default: return 0;
    }
  }

  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    final local = tz.local;
    return tz.TZDateTime.from(dateTime, local);
  }

  Future<void> setAlarmEnabled(String prayerName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefKeyAlarmEnabled$prayerName', enabled);
  }

  Future<void> setAlarmTone(String prayerName, String tone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefKeyAlarmTone$prayerName', tone);
  }

  Future<bool> isAlarmEnabled(String prayerName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefKeyAlarmEnabled$prayerName') ?? true;
  }
}


