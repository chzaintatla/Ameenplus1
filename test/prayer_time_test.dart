import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_dart/adhan_dart.dart';
import '../lib/services/accurate_prayer_time_service.dart';

void main() {
  group('Prayer Time Calculation Tests', () {
    test('Lahore Prayer Times - January 4, 2026', () async {
      final service = AccuratePrayerTimeService();
      await service.initialize();
      
      // Lahore coordinates: 31.5497° N, 74.3436° E
      final date = DateTime(2026, 1, 4);
      
      final prayerTimes = await service.getPrayerTimes(
        latitude: 31.5497,
        longitude: 74.3436,
        calculationMethod: AccuratePrayerTimeService.methodKarachi,
        date: date,
      );
      
      // Expected times (Lahore, UTC+5, January 4, 2026)
      // Based on Google search results
      final expectedFajr = DateTime(2026, 1, 4, 5, 36); // 05:36
      final expectedDhuhr = DateTime(2026, 1, 4, 12, 7); // 12:07
      final expectedAsr = DateTime(2026, 1, 4, 15, 35); // 15:35 (3:35 PM)
      final expectedMaghrib = DateTime(2026, 1, 4, 17, 12); // 17:12 (5:12 PM)
      final expectedIsha = DateTime(2026, 1, 4, 18, 39); // 18:39 (6:39 PM)
      
      final fajr = prayerTimes['Fajr']!;
      final dhuhr = prayerTimes['Dhuhr']!;
      final asr = prayerTimes['Asr']!;
      final maghrib = prayerTimes['Maghrib']!;
      final isha = prayerTimes['Isha']!;
      
      // Allow 5 minutes tolerance
      const tolerance = Duration(minutes: 5);
      
      final fajrDiff = (fajr.hour * 60 + fajr.minute) - (expectedFajr.hour * 60 + expectedFajr.minute);
      expect(
        fajrDiff.abs(),
        lessThanOrEqualTo(tolerance.inMinutes),
        reason: 'Fajr time mismatch. Got ${fajr.hour}:${fajr.minute.toString().padLeft(2, '0')}, expected 05:36',
      );
      
      final dhuhrDiff = (dhuhr.hour * 60 + dhuhr.minute) - (expectedDhuhr.hour * 60 + expectedDhuhr.minute);
      expect(
        dhuhrDiff.abs(),
        lessThanOrEqualTo(tolerance.inMinutes),
        reason: 'Dhuhr time mismatch. Got ${dhuhr.hour}:${dhuhr.minute.toString().padLeft(2, '0')}, expected 12:07',
      );
      
      final asrDiff = (asr.hour * 60 + asr.minute) - (expectedAsr.hour * 60 + expectedAsr.minute);
      expect(
        asrDiff.abs(),
        lessThanOrEqualTo(tolerance.inMinutes),
        reason: 'Asr time mismatch. Got ${asr.hour}:${asr.minute.toString().padLeft(2, '0')}, expected 15:35',
      );
      
      final maghribDiff = (maghrib.hour * 60 + maghrib.minute) - (expectedMaghrib.hour * 60 + expectedMaghrib.minute);
      expect(
        maghribDiff.abs(),
        lessThanOrEqualTo(tolerance.inMinutes),
        reason: 'Maghrib time mismatch. Got ${maghrib.hour}:${maghrib.minute.toString().padLeft(2, '0')}, expected 17:12',
      );
      
      final ishaDiff = (isha.hour * 60 + isha.minute) - (expectedIsha.hour * 60 + expectedIsha.minute);
      expect(
        ishaDiff.abs(),
        lessThanOrEqualTo(tolerance.inMinutes),
        reason: 'Isha time mismatch. Got ${isha.hour}:${isha.minute.toString().padLeft(2, '0')}, expected 18:39',
      );
    });
    
    test('Prayer times should be in local timezone (not UTC)', () async {
      final service = AccuratePrayerTimeService();
      await service.initialize();
      
      // Lahore coordinates: 31.5497° N, 74.3436° E
      final prayerTimes = await service.getPrayerTimes(
        latitude: 31.5497,
        longitude: 74.3436,
        calculationMethod: AccuratePrayerTimeService.methodKarachi,
      );
      
      final fajr = prayerTimes['Fajr']!;
      final dhuhr = prayerTimes['Dhuhr']!;
      
      // Fajr should be early morning (4-6 AM local time for Lahore)
      expect(fajr.hour, greaterThanOrEqualTo(4), reason: 'Fajr should be 4-6 AM, got ${fajr.hour}:${fajr.minute}');
      expect(fajr.hour, lessThanOrEqualTo(6), reason: 'Fajr should be 4-6 AM, got ${fajr.hour}:${fajr.minute}');
      
      // Dhuhr should be around noon (11 AM - 1 PM local time for Lahore)
      expect(dhuhr.hour, greaterThanOrEqualTo(11), reason: 'Dhuhr should be 11 AM - 1 PM, got ${dhuhr.hour}:${dhuhr.minute}');
      expect(dhuhr.hour, lessThanOrEqualTo(13), reason: 'Dhuhr should be 11 AM - 1 PM, got ${dhuhr.hour}:${dhuhr.minute}');
    });
    
    test('Prayer times should convert UTC to local time', () async {
      final service = AccuratePrayerTimeService();
      await service.initialize();
      
      final prayerTimes = await service.getPrayerTimes(
        latitude: 31.5497,
        longitude: 74.3436,
        calculationMethod: AccuratePrayerTimeService.methodKarachi,
      );
      
      // All times should be in local timezone (not UTC)
      for (final entry in prayerTimes.entries) {
        final time = entry.value;
        // Check that the time is reasonable (not showing UTC times like 00:36 for Fajr)
        expect(time.hour, greaterThanOrEqualTo(0));
        expect(time.hour, lessThan(24));
        
        // For Lahore, Fajr should never be at 00:xx (midnight)
        if (entry.key == 'Fajr') {
          expect(time.hour, greaterThan(0), reason: 'Fajr should not be at midnight (00:xx)');
        }
      }
    });
  });
}

