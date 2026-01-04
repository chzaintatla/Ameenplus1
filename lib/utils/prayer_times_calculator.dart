import 'dart:math' as math;

class PrayerTimesCalculator {
  static const double pi = math.pi;
  static const double deg2rad = pi / 180.0;
  static const double rad2deg = 180.0 / pi;

  static Map<String, String> calculatePrayerTimes(
    double latitude,
    double longitude,
    DateTime date,
  ) {
    final dayOfYear = _dayOfYear(date.year, date.month, date.day);
    
    final declination = _sunDeclination(dayOfYear);
    final equationOfTime = _equationOfTime(dayOfYear);
    
    final timezoneOffset = _getTimezoneOffset(date);
    final longitudeOffset = longitude / 15.0;
    final timeCorrection = equationOfTime / 60.0;
    
    final solarNoon = 12.0 - longitudeOffset - timeCorrection;
    
    final fajrAngle = 18.0;
    final ishaAngle = 18.0;
    
    final fajr = _calculatePrayerTime(
      latitude,
      declination,
      fajrAngle,
      solarNoon,
      false,
    );
    
    final dhuhr = solarNoon + timezoneOffset;
    
    final asr = _calculateAsrTime(
      latitude,
      declination,
      solarNoon,
      timezoneOffset,
    );
    
    final maghrib = _calculatePrayerTime(
      latitude,
      declination,
      0.833,
      solarNoon,
      true,
    );
    
    final isha = _calculatePrayerTime(
      latitude,
      declination,
      ishaAngle,
      solarNoon,
      true,
    );
    
    return {
      'fajr': _formatTime(fajr + timezoneOffset),
      'dhuhr': _formatTime(dhuhr),
      'asr': _formatTime(asr),
      'maghrib': _formatTime(maghrib + timezoneOffset),
      'isha': _formatTime(isha + timezoneOffset),
    };
  }
  
  static double _julianDay(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }
  
  static int _dayOfYear(int year, int month, int day) {
    final daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (_isLeapYear(year)) {
      daysInMonth[1] = 29;
    }
    int dayOfYear = 0;
    for (int i = 0; i < month - 1; i++) {
      dayOfYear += daysInMonth[i];
    }
    return dayOfYear + day;
  }
  
  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }
  
  static double _sunDeclination(int dayOfYear) {
    return 23.45 * math.sin(deg2rad * (360.0 * (284 + dayOfYear) / 365.25));
  }
  
  static double _equationOfTime(int dayOfYear) {
    final b = 360.0 * (dayOfYear - 81) / 365.0;
    final bRad = b * deg2rad;
    return 9.87 * math.sin(2 * bRad) - 7.53 * math.cos(bRad) - 1.5 * math.sin(bRad);
  }
  
  static double _getTimezoneOffset(DateTime date) {
    final localTime = DateTime(date.year, date.month, date.day, 12, 0, 0);
    final utcTime = localTime.toUtc();
    final offset = (localTime.difference(utcTime).inMinutes / 60.0);
    return offset;
  }
  
  static double _calculatePrayerTime(
    double latitude,
    double declination,
    double angle,
    double localMeanTime,
    bool isAfternoon,
  ) {
    final latRad = latitude * deg2rad;
    final decRad = declination * deg2rad;
    final angleRad = angle * deg2rad;
    
    final numerator = math.sin(angleRad) - math.sin(latRad) * math.sin(decRad);
    final denominator = math.cos(latRad) * math.cos(decRad);
    
    if (denominator.abs() < 0.0001) {
      return localMeanTime;
    }
    
    final hourAngle = math.acos(numerator / denominator) * rad2deg;
    
    if (hourAngle.isNaN || hourAngle.isInfinite) {
      return localMeanTime;
    }
    
    final timeOffset = hourAngle / 15.0;
    
    return isAfternoon
        ? localMeanTime + timeOffset
        : localMeanTime - timeOffset;
  }
  
  static double _calculateAsrTime(
    double latitude,
    double declination,
    double solarNoon,
    double timezoneOffset,
  ) {
    final latRad = latitude * deg2rad;
    final decRad = declination * deg2rad;
    
    final shadowFactor = 1.0;
    final altitude = latRad - decRad;
    
    if (math.tan(altitude).abs() < 0.0001) {
      return solarNoon + timezoneOffset;
    }
    
    final arccot = math.atan(shadowFactor + math.tan(altitude).abs());
    final angleRad = math.pi / 2 - arccot;
    
    final numerator = math.sin(angleRad) - math.sin(latRad) * math.sin(decRad);
    final denominator = math.cos(latRad) * math.cos(decRad);
    
    if (denominator.abs() < 0.0001) {
      return solarNoon + timezoneOffset;
    }
    
    final ratio = (numerator / denominator).clamp(-1.0, 1.0);
    final hourAngle = math.acos(ratio) * rad2deg;
    
    if (hourAngle.isNaN || hourAngle.isInfinite) {
      return solarNoon + timezoneOffset;
    }
    
    return solarNoon + (hourAngle / 15.0) + timezoneOffset;
  }
  
  static String _formatTime(double time) {
    while (time < 0) time += 24;
    while (time >= 24) time -= 24;
    
    final hours = time.floor();
    final minutes = ((time - hours) * 60).round();
    
    final formattedHours = hours.toString().padLeft(2, '0');
    final formattedMinutes = minutes.toString().padLeft(2, '0');
    
    return '$formattedHours:$formattedMinutes';
  }
}
