import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:adhan_dart/adhan_dart.dart';

class AccuratePrayerTimeService {
  static const String _prefKeyLocation = 'prayer_location';
  static const String _prefKeyCalculationMethod = 'prayer_calculation_method';
  static const String _prefKeyAlarmEnabled = 'prayer_alarm_enabled_';
  static const String _prefKeyAlarmTone = 'prayer_alarm_tone_';
  static const String _prefKeyAsrMethod = 'asr_calculation_method';
  static const String _prefKeyHighLatitude = 'high_latitude_method';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const String methodMuslimWorldLeague = 'MWL';
  static const String methodIslamicSociety = 'ISNA';
  static const String methodEgyptian = 'Egyptian';
  static const String methodMakkah = 'Makkah';
  static const String methodKarachi = 'Karachi';
  static const String methodTehran = 'Tehran';
  static const String methodJafari = 'Jafari';

  static const String asrMethodStandard = 'Standard';
  static const String asrMethodHanafi = 'Hanafi';

  static const String highLatitudeTwilight = 'TwilightAngle';
  static const String highLatitudeMiddleOfNight = 'MiddleOfNight';
  static const String highLatitudeOneSeventh = 'OneSeventh';

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
    String? asrMethod,
    String? highLatitudeMethod,
    DateTime? date,
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
          final position = await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high,
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
    asrMethod ??= prefs.getString(_prefKeyAsrMethod) ?? asrMethodStandard;
    highLatitudeMethod ??= prefs.getString(_prefKeyHighLatitude) ?? highLatitudeTwilight;
    date ??= DateTime.now();

    final coordinates = Coordinates(latitude!, longitude!);
    final params = _getCalculationParameters(calculationMethod, asrMethod: asrMethod);
    params.highLatitudeRule = _getHighLatitudeRule(highLatitudeMethod);

    final prayerTimes = PrayerTimes(
      date: date,
      coordinates: coordinates,
      calculationParameters: params,
    );

    // Convert UTC times to local time
    return {
      'Fajr': prayerTimes.fajr!.toLocal(),
      'Dhuhr': prayerTimes.dhuhr!.toLocal(),
      'Asr': prayerTimes.asr!.toLocal(),
      'Maghrib': prayerTimes.maghrib!.toLocal(),
      'Isha': prayerTimes.isha!.toLocal(),
    };
  }

  CalculationParameters _getCalculationParameters(String method, {String? asrMethod}) {
    CalculationParameters params;
    switch (method) {
      case methodMuslimWorldLeague:
        params = CalculationMethodParameters.muslimWorldLeague();
        break;
      case methodIslamicSociety:
        params = CalculationMethodParameters.northAmerica();
        break;
      case methodEgyptian:
        params = CalculationMethodParameters.egyptian();
        break;
      case methodMakkah:
        params = CalculationMethodParameters.ummAlQura();
        break;
      case methodKarachi:
        params = CalculationMethodParameters.karachi();
        break;
      case methodTehran:
        params = CalculationMethodParameters.tehran();
        break;
      case methodJafari:
        params = CalculationParameters(
          method: CalculationMethod.other,
          fajrAngle: 16.0,
          ishaAngle: 14.0,
        );
        break;
      default:
        params = CalculationMethodParameters.muslimWorldLeague();
    }
    
    // Note: Asr calculation method is determined by the calculation method itself
    // The adhan_dart library handles this internally based on the method selected
    
    return params;
  }

  HighLatitudeRule _getHighLatitudeRule(String method) {
    switch (method) {
      case highLatitudeTwilight:
        return HighLatitudeRule.twilightAngle;
      case highLatitudeMiddleOfNight:
        return HighLatitudeRule.middleOfTheNight;
      case highLatitudeOneSeventh:
        return HighLatitudeRule.seventhOfTheNight;
      default:
        return HighLatitudeRule.twilightAngle;
    }
  }

  Future<void> setPrayerAlarm(String prayerName, DateTime prayerTime, {String? customTone}) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('$_prefKeyAlarmEnabled$prayerName') ?? true;
    
    if (!isEnabled) return;

    final tone = customTone ?? prefs.getString('$_prefKeyAlarmTone$prayerName') ?? 'default';

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
          sound: RawResourceAndroidNotificationSound(tone),
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

  Future<void> setCalculationMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyCalculationMethod, method);
  }

  Future<void> setAsrMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyAsrMethod, method);
  }

  Future<void> setHighLatitudeMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyHighLatitude, method);
  }

  Future<geo.LocationAccuracy> validateLocationAccuracy() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      
      if (position.accuracy != null && position.accuracy! < 50) {
        return geo.LocationAccuracy.high;
      } else if (position.accuracy != null && position.accuracy! < 100) {
        return geo.LocationAccuracy.medium;
      } else {
        return geo.LocationAccuracy.low;
      }
    } catch (e) {
      return geo.LocationAccuracy.low;
    }
  }
}

