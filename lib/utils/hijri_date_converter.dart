import 'dart:math' as math;

class HijriDateConverter {
  static const double hijriEpoch = 1948438.5;
  
  static Map<String, dynamic> gregorianToHijri(DateTime gregorianDate) {
    final julianDay = _gregorianToJulianDay(
      gregorianDate.year,
      gregorianDate.month,
      gregorianDate.day,
    );
    
    final daysSinceEpoch = (julianDay - hijriEpoch).floor();
    
    if (daysSinceEpoch < 0) {
      return {
        'year': 1,
        'month': 1,
        'day': 1,
        'monthName': 'Muharram',
      };
    }
    
    int daysRemaining = daysSinceEpoch;
    int hijriYear = 1;
    
    while (daysRemaining >= 0) {
      final yearLength = _getHijriYearLength(hijriYear);
      if (daysRemaining >= yearLength) {
        daysRemaining -= yearLength;
        hijriYear++;
      } else {
        break;
      }
    }
    
    int hijriMonth = 1;
    int hijriDay = 1;
    
    while (hijriMonth <= 12 && daysRemaining >= 0) {
      final monthLength = _getHijriMonthLength(hijriYear, hijriMonth);
      if (daysRemaining >= monthLength) {
        daysRemaining -= monthLength;
        hijriMonth++;
      } else {
        hijriDay = daysRemaining;
        if (hijriDay == 0) {
          hijriDay = 1;
        }
        break;
      }
    }
    
    if (hijriMonth > 12) {
      hijriMonth = 1;
      hijriYear += 1;
      hijriDay = 1;
    }
    
    if (hijriDay < 1) {
      hijriDay = 1;
    }
    
    final maxDay = _getHijriMonthLength(hijriYear, hijriMonth);
    if (hijriDay > maxDay) {
      hijriDay = maxDay;
    }
    
    final monthNames = [
      'Muharram',
      'Safar',
      'Rabi\' al-awwal',
      'Rabi\' al-thani',
      'Jumada al-awwal',
      'Jumada al-thani',
      'Rajab',
      'Sha\'ban',
      'Ramadan',
      'Shawwal',
      'Dhu al-Qi\'dah',
      'Dhu al-Hijjah',
    ];
    
    return {
      'year': hijriYear,
      'month': hijriMonth,
      'day': hijriDay,
      'monthName': monthNames[hijriMonth - 1],
    };
  }
  
  static double _gregorianToJulianDay(int year, int month, int day) {
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
  
  static int _getHijriYearLength(int hijriYear) {
    final yearInCycle = ((hijriYear - 1) % 30) + 1;
    
    final leapYears = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29];
    final isLeapYear = leapYears.contains(yearInCycle);
    
    return isLeapYear ? 355 : 354;
  }
  
  static int _getHijriMonthLength(int hijriYear, int hijriMonth) {
    final yearInCycle = ((hijriYear - 1) % 30) + 1;
    
    final leapYears = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29];
    final isLeapYear = leapYears.contains(yearInCycle);
    
    if (hijriMonth == 12 && isLeapYear) {
      return 30;
    }
    
    if (hijriMonth % 2 == 1) {
      return 30;
    } else {
      return 29;
    }
  }
}

