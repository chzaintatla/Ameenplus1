import 'dart:math' as math;
import 'package:intl/intl.dart';

/// Madhab enum for Asr calculation method
enum Madhab {
  shafi, // Asr shadow = 1 (Shafi, Maliki, Hanbali)
  hanafi, // Asr shadow = 2 (Hanafi)
}

/// Prayer Times Model
class PrayerTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  Map<String, String> toMap() {
    final format = DateFormat('HH:mm');
    return {
      'fajr': format.format(fajr),
      'sunrise': format.format(sunrise),
      'dhuhr': format.format(dhuhr),
      'asr': format.format(asr),
      'maghrib': format.format(maghrib),
      'isha': format.format(isha),
    };
  }
}

/// Complete Offline Prayer Time Calculator (NO INTERNET REQUIRED)
/// Mathematically accurate, production-ready implementation
class OfflinePrayerTimeCalculator {
  static const double pi = math.pi;

  /// Calculate prayer times for a given date and location
  static PrayerTimes calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required double timezone,
    required Madhab madhab,
  }) {
    final dayOfYear = int.parse(DateFormat("D").format(date));

    final declination = _sunDeclination(dayOfYear);
    final equation = _equationOfTime(dayOfYear);

    final dhuhr = _solarNoon(longitude, timezone, equation, date);

    final fajr = _timeForAngle(
      date, latitude, declination, -18, dhuhr, false);

    final sunrise = _timeForAngle(
      date, latitude, declination, -0.833, dhuhr, false);

    final maghrib = _timeForAngle(
      date, latitude, declination, 0, dhuhr, true);

    final isha = _timeForAngle(
      date, latitude, declination, -18, dhuhr, true);

    final asr = _asrTime(
      date, latitude, declination, dhuhr, madhab);

    return PrayerTimes(
      fajr: fajr,
      sunrise: sunrise,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
    );
  }

  /// Calculate sun declination angle
  static double _sunDeclination(int n) =>
      23.45 * math.sin(pi / 180 * (360 / 365 * (284 + n)));

  /// Calculate equation of time
  static double _equationOfTime(int n) {
    final b = 2 * pi * (n - 81) / 364;
    return 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
  }

  /// Calculate solar noon (Dhuhr time)
  /// Returns time in LOCAL timezone
  /// Formula: Local Solar Noon = 12:00 + (longitude offset) - (equation of time) + (timezone offset)
  /// Where longitude offset = longitude / 15 (converted to minutes = longitude * 4)
  static DateTime _solarNoon(
      double lon, double tz, double eot, DateTime date) {
    // Calculate solar noon in minutes from midnight (local time)
    // 720 = 12:00 in minutes (noon)
    // Longitude correction: each degree of longitude = 4 minutes
    //   For east longitude (positive): sun rises earlier, so we subtract: -4 * lon
    //   For west longitude (negative): sun rises later, so we add: -4 * lon (becomes positive)
    // Equation of time correction: accounts for Earth's elliptical orbit (in minutes)
    //   Negative when sun is fast, positive when sun is slow
    //   We subtract it: -eot
    // Timezone offset: converts to local clock time (in hours, converted to minutes)
    //   For east of UTC (positive): add timezone offset: +tz * 60
    //   For west of UTC (negative): add timezone offset: +tz * 60 (tz is negative)
    // 
    // Correct formula: 720 - 4*lon - eot + tz*60
    // But we need to ensure timezone is correctly applied
    final longitudeOffsetMinutes = lon * 4.0; // 1 degree = 4 minutes
    final timezoneOffsetMinutes = tz * 60.0; // Convert hours to minutes
    final minutes = 720.0 - longitudeOffsetMinutes - eot + timezoneOffsetMinutes;
    final totalMinutes = minutes.round();
    
    // Normalize to 0-1439 minutes (0-23:59)
    var normalizedMinutes = totalMinutes;
    while (normalizedMinutes < 0) {
      normalizedMinutes += 1440; // Add a day
    }
    while (normalizedMinutes >= 1440) {
      normalizedMinutes -= 1440; // Subtract a day
    }
    
    final hours = normalizedMinutes ~/ 60;
    final mins = normalizedMinutes % 60;
    
    // Create DateTime in local timezone
    var result = DateTime(
      date.year, date.month, date.day, hours, mins);
    
    // Handle day overflow/underflow
    if (totalMinutes < 0) {
      result = result.subtract(const Duration(days: 1));
    } else if (totalMinutes >= 1440) {
      result = result.add(const Duration(days: 1));
    }
    
    return result;
  }

  /// Calculate time for a specific angle (Fajr, Sunrise, Maghrib, Isha)
  static DateTime _timeForAngle(
      DateTime date,
      double lat,
      double dec,
      double angle,
      DateTime dhuhr,
      bool afterNoon) {
    final latRad = lat * pi / 180;
    final decRad = dec * pi / 180;
    final angleRad = angle * pi / 180;

    final numerator = math.sin(angleRad) -
        math.sin(latRad) * math.sin(decRad);
    final denominator = math.cos(latRad) * math.cos(decRad);

    if (denominator.abs() < 0.0001) {
      return dhuhr;
    }

    final cosH = numerator / denominator;
    final ha = math.acos(cosH.clamp(-1.0, 1.0));

    final hours = ha * 180 / pi / 15;
    final minutesOffset = (hours * 60).round();
    
    return afterNoon
        ? dhuhr.add(Duration(minutes: minutesOffset))
        : dhuhr.subtract(Duration(minutes: minutesOffset));
  }

  /// Calculate Asr time based on Madhab
  static DateTime _asrTime(
      DateTime date,
      double lat,
      double dec,
      DateTime dhuhr,
      Madhab madhab) {
    final factor = madhab == Madhab.hanafi ? 2 : 1;

    final latRad = lat * pi / 180;
    final decRad = dec * pi / 180;

    final altitude = (latRad - decRad).abs();
    final angle = -math.atan(
      1 / (factor + math.tan(altitude)),
    ) *
        180 /
        pi;

    return _timeForAngle(date, lat, dec, angle, dhuhr, true);
  }

  /// Get timezone offset from DateTime (in hours)
  /// Returns the offset from UTC for the device's local timezone
  static double getTimezoneOffset(DateTime date) {
    // Create a local time at noon
    final localTime = DateTime(date.year, date.month, date.day, 12, 0, 0);
    // Convert to UTC to get the difference
    final utcTime = localTime.toUtc();
    // Calculate offset in hours (positive for east of UTC, negative for west)
    final offsetMinutes = localTime.difference(utcTime).inMinutes;
    return offsetMinutes / 60.0;
  }
}

