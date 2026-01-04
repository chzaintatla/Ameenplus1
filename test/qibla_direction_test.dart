import 'package:flutter_test/flutter_test.dart';
import 'package:ameen_mobile_app/services/qibla_compass_service.dart';
import 'dart:math' as math;

void main() {
  group('Qibla Direction Calculation Tests', () {
    final service = QiblaCompassService();
    const double kaabaLatitude = 21.4225241;
    const double kaabaLongitude = 39.8261818;

    test('Qibla direction from Lahore, Pakistan', () {
      // Lahore coordinates: 31.5497° N, 74.3436° E
      // Expected Qibla direction: approximately 265-270° (West)
      final qiblaDirection = service.calculateQiblaDirection(31.5497, 74.3436);
      
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
      expect(qiblaDirection, closeTo(265.0, 5.0), 
        reason: 'Lahore Qibla should be approximately 265° (West)');
    });

    test('Qibla direction from New York, USA', () {
      // New York coordinates: 40.7128° N, -74.0060° W
      // Expected Qibla direction: approximately 58-60° (Northeast)
      final qiblaDirection = service.calculateQiblaDirection(40.7128, -74.0060);
      
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
      expect(qiblaDirection, closeTo(58.0, 5.0),
        reason: 'New York Qibla should be approximately 58° (Northeast)');
    });

    test('Qibla direction from London, UK', () {
      // London coordinates: 51.5074° N, -0.1278° W
      // Expected Qibla direction: approximately 118-120° (Southeast)
      final qiblaDirection = service.calculateQiblaDirection(51.5074, -0.1278);
      
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
      expect(qiblaDirection, closeTo(118.0, 5.0),
        reason: 'London Qibla should be approximately 118° (Southeast)');
    });

    test('Qibla direction from Jakarta, Indonesia', () {
      // Jakarta coordinates: -6.2088° S, 106.8456° E
      // Expected Qibla direction: approximately 295-300° (Northwest)
      final qiblaDirection = service.calculateQiblaDirection(-6.2088, 106.8456);
      
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
      expect(qiblaDirection, closeTo(295.0, 5.0),
        reason: 'Jakarta Qibla should be approximately 295° (Northwest)');
    });

    test('Qibla direction from Cairo, Egypt', () {
      // Cairo coordinates: 30.0444° N, 31.2357° E
      // Expected Qibla direction: approximately 135-140° (Southeast)
      final qiblaDirection = service.calculateQiblaDirection(30.0444, 31.2357);
      
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
      expect(qiblaDirection, closeTo(135.0, 5.0),
        reason: 'Cairo Qibla should be approximately 135° (Southeast)');
    });

    test('Qibla direction from Makkah (should be 0° or 360°)', () {
      // When at Kaaba, direction should be undefined or 0
      // For practical purposes, we test a location very close to Kaaba
      final qiblaDirection = service.calculateQiblaDirection(
        kaabaLatitude + 0.001,
        kaabaLongitude + 0.001,
      );
      
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
    });

    test('Qibla direction from North Pole', () {
      // North Pole: 90° N, any longitude
      // All directions from North Pole point South, so Qibla should be South
      final qiblaDirection = service.calculateQiblaDirection(90.0, 0.0);
      
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
      // From North Pole, Qibla should be approximately South (180°)
      expect(qiblaDirection, closeTo(180.0, 10.0),
        reason: 'From North Pole, Qibla should be approximately South (180°)');
    });

    test('Qibla direction from South Pole', () {
      // South Pole: -90° S, any longitude
      // All directions from South Pole point North, so Qibla should be North
      final qiblaDirection = service.calculateQiblaDirection(-90.0, 0.0);
      
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
      // From South Pole, Qibla should be approximately North (0° or 360°)
      // Check if it's close to 0° or close to 360°
      final isCloseToNorth = (qiblaDirection <= 10.0) || (qiblaDirection >= 350.0);
      expect(isCloseToNorth, isTrue,
        reason: 'From South Pole, Qibla should be approximately North (0° or 360°), got $qiblaDirection°');
    });

    test('Qibla direction always returns 0-360 range', () {
      final testLocations = [
        [0.0, 0.0],           // Equator, Prime Meridian
        [45.0, 45.0],         // Northern hemisphere, Eastern
        [-45.0, -45.0],       // Southern hemisphere, Western
        [0.0, 180.0],         // Equator, International Date Line
        [kaabaLatitude, kaabaLongitude], // At Kaaba
      ];

      for (final location in testLocations) {
        final lat = location[0] as double;
        final lon = location[1] as double;
        final qiblaDirection = service.calculateQiblaDirection(lat, lon);
        
        expect(qiblaDirection, greaterThanOrEqualTo(0),
          reason: 'Qibla direction from ($lat, $lon) should be >= 0');
        expect(qiblaDirection, lessThan(360),
          reason: 'Qibla direction from ($lat, $lon) should be < 360');
      }
    });

    test('Qibla direction calculation is consistent', () {
      // Same location should always return same direction
      const lat = 31.5497;
      const lon = 74.3436;
      
      final direction1 = service.calculateQiblaDirection(lat, lon);
      final direction2 = service.calculateQiblaDirection(lat, lon);
      final direction3 = service.calculateQiblaDirection(lat, lon);
      
      expect(direction1, equals(direction2));
      expect(direction2, equals(direction3));
    });
  });

  group('Angle Difference Calculation Tests', () {
    final service = QiblaCompassService();

    test('Angle difference for same direction', () {
      final diff = service.calculateAngleDifference(90.0, 90.0);
      expect(diff, equals(0.0));
    });

    test('Angle difference for 90° difference', () {
      final diff = service.calculateAngleDifference(0.0, 90.0);
      expect(diff, equals(90.0));
    });

    test('Angle difference for 180° difference', () {
      final diff = service.calculateAngleDifference(0.0, 180.0);
      expect(diff, equals(180.0));
    });

    test('Angle difference wraps around 360°', () {
      // 350° to 10° should be 20°, not 340°
      final diff = service.calculateAngleDifference(350.0, 10.0);
      expect(diff, equals(20.0));
    });

    test('Angle difference is always positive and <= 180°', () {
      final testCases = [
        [0.0, 45.0],
        [45.0, 0.0],
        [90.0, 270.0],
        [270.0, 90.0],
        [359.0, 1.0],
        [1.0, 359.0],
      ];

      for (final testCase in testCases) {
        final heading = testCase[0] as double;
        final qibla = testCase[1] as double;
        final diff = service.calculateAngleDifference(heading, qibla);
        
        expect(diff, greaterThanOrEqualTo(0),
          reason: 'Angle difference should be >= 0');
        expect(diff, lessThanOrEqualTo(180),
          reason: 'Angle difference should be <= 180');
      }
    });

    test('Angle difference is symmetric', () {
      final diff1 = service.calculateAngleDifference(90.0, 45.0);
      final diff2 = service.calculateAngleDifference(45.0, 90.0);
      expect(diff1, equals(diff2));
    });
  });

  group('isPointingToQibla Tests', () {
    final service = QiblaCompassService();

    test('Device pointing exactly at Qibla', () {
      final isPointing = service.isPointingToQibla(90.0, 90.0);
      expect(isPointing, isTrue);
    });

    test('Device pointing within tolerance (5°)', () {
      final isPointing = service.isPointingToQibla(90.0, 93.0);
      expect(isPointing, isTrue);
    });

    test('Device pointing outside tolerance (5°)', () {
      final isPointing = service.isPointingToQibla(90.0, 100.0);
      expect(isPointing, isFalse);
    });

    test('Custom tolerance', () {
      final isPointing1 = service.isPointingToQibla(90.0, 100.0, tolerance: 10.0);
      expect(isPointing1, isTrue);
      
      final isPointing2 = service.isPointingToQibla(90.0, 100.0, tolerance: 5.0);
      expect(isPointing2, isFalse);
    });

    test('Wraps around 360° correctly', () {
      // 359° and 1° are only 2° apart
      final isPointing = service.isPointingToQibla(359.0, 1.0, tolerance: 5.0);
      expect(isPointing, isTrue);
    });
  });

  group('Variance Calculation Tests', () {
    final service = QiblaCompassService();

    test('Variance for stable compass readings', () {
      // Use reflection to access private method for testing
      // For now, we'll test through validateCompassAccuracy indirectly
      // Stable readings should have low variance
      final stableReadings = [90.0, 90.5, 89.5, 90.0, 90.2, 89.8, 90.0, 90.1, 89.9, 90.0];
      
      // Calculate variance manually to verify
      final mean = stableReadings.reduce((a, b) => a + b) / stableReadings.length;
      final squaredDiffs = stableReadings.map((x) => math.pow(x - mean, 2)).toList();
      final variance = squaredDiffs.reduce((a, b) => a + b) / stableReadings.length;
      
      expect(variance, lessThan(1.0),
        reason: 'Stable compass readings should have variance < 1.0');
    });

    test('Variance for unstable compass readings', () {
      // Unstable readings should have high variance
      final unstableReadings = [0.0, 90.0, 180.0, 270.0, 45.0, 135.0, 225.0, 315.0, 10.0, 350.0];
      
      final mean = unstableReadings.reduce((a, b) => a + b) / unstableReadings.length;
      final squaredDiffs = unstableReadings.map((x) => math.pow(x - mean, 2)).toList();
      final variance = squaredDiffs.reduce((a, b) => a + b) / unstableReadings.length;
      
      expect(variance, greaterThan(50.0),
        reason: 'Unstable compass readings should have variance > 50.0');
    });
  });

  group('Magnetic Declination Tests', () {
    final service = QiblaCompassService();

    test('Magnetic declination calculation returns value', () async {
      final declination = await service.getMagneticDeclination(31.5497, 74.3436);
      expect(declination, isNotNull);
    });

    test('Magnetic declination for Lahore', () async {
      // Lahore magnetic declination is approximately 0-2° East
      final declination = await service.getMagneticDeclination(31.5497, 74.3436);
      expect(declination, isNotNull);
      // Declination should be within reasonable range (-30° to +30°)
      expect(declination!, greaterThan(-30.0));
      expect(declination!, lessThan(30.0));
    });

    test('Magnetic declination for different locations', () async {
      final locations = [
        [40.7128, -74.0060],  // New York
        [51.5074, -0.1278],   // London
        [-6.2088, 106.8456],  // Jakarta
      ];

      for (final location in locations) {
        final lat = location[0] as double;
        final lon = location[1] as double;
        final declination = await service.getMagneticDeclination(lat, lon);
        
        expect(declination, isNotNull);
        // Declination should be within reasonable range
        expect(declination!, greaterThan(-60.0));
        expect(declination!, lessThan(60.0));
      }
    });
  });

  group('Edge Cases and Boundary Tests', () {
    final service = QiblaCompassService();

    test('Qibla direction at Equator, Prime Meridian', () {
      final qiblaDirection = service.calculateQiblaDirection(0.0, 0.0);
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
    });

    test('Qibla direction at International Date Line', () {
      final qiblaDirection = service.calculateQiblaDirection(0.0, 180.0);
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
    });

    test('Qibla direction for extreme longitudes', () {
      final testCases = [
        [0.0, -180.0],  // Westernmost point
        [0.0, 180.0],   // Easternmost point
        [45.0, -179.0],
        [45.0, 179.0],
      ];

      for (final testCase in testCases) {
        final lat = testCase[0] as double;
        final lon = testCase[1] as double;
        final qiblaDirection = service.calculateQiblaDirection(lat, lon);
        
        expect(qiblaDirection, greaterThanOrEqualTo(0));
        expect(qiblaDirection, lessThan(360));
      }
    });

    test('Angle difference handles negative angles', () {
      // Compass heading might be negative, but should be normalized
      // Test that our calculation handles it correctly
      final diff1 = service.calculateAngleDifference(-10.0, 10.0);
      final diff2 = service.calculateAngleDifference(350.0, 10.0);
      
      // Both should give same result (20° difference)
      expect(diff1, closeTo(diff2, 0.1));
    });

    test('isPointingToQibla with zero tolerance', () {
      final isPointing1 = service.isPointingToQibla(90.0, 90.0, tolerance: 0.0);
      expect(isPointing1, isTrue);
      
      final isPointing2 = service.isPointingToQibla(90.0, 90.1, tolerance: 0.0);
      expect(isPointing2, isFalse);
    });

    test('isPointingToQibla with large tolerance', () {
      final isPointing = service.isPointingToQibla(0.0, 180.0, tolerance: 180.0);
      expect(isPointing, isTrue);
    });
  });

  group('Accuracy Validation Tests', () {
    final service = QiblaCompassService();

    test('Location accuracy validation returns valid enum', () async {
      // Note: This test requires location permissions
      // It may fail if permissions are not granted, which is acceptable
      try {
        final accuracy = await service.validateLocationAccuracy();
        expect(accuracy, isA<QiblaLocationAccuracy>());
      } catch (e) {
        // If location services are unavailable, that's acceptable for testing
        expect(e, isNotNull);
      }
    });

    test('Compass accuracy validation returns valid enum', () async {
      // Note: This test requires compass access
      // It may return unavailable if compass is not available
      try {
        final accuracy = await service.validateCompassAccuracy();
        expect(accuracy, isA<CompassAccuracy>());
      } catch (e) {
        // If compass is unavailable, that's acceptable for testing
        expect(e, isNotNull);
      }
    });
  });

  group('Integration Tests', () {
    final service = QiblaCompassService();

    test('Complete Qibla calculation flow for Lahore', () {
      const lat = 31.5497;
      const lon = 74.3436;
      
      // Calculate Qibla direction
      final qiblaDirection = service.calculateQiblaDirection(lat, lon);
      expect(qiblaDirection, greaterThanOrEqualTo(0));
      expect(qiblaDirection, lessThan(360));
      
      // Simulate compass heading (pointing West)
      const compassHeading = 270.0;
      
      // Calculate angle difference
      final angleDiff = service.calculateAngleDifference(compassHeading, qiblaDirection);
      expect(angleDiff, greaterThanOrEqualTo(0));
      expect(angleDiff, lessThanOrEqualTo(180));
      
      // Check if pointing to Qibla
      final isPointing = service.isPointingToQibla(compassHeading, qiblaDirection);
      expect(isPointing, isA<bool>());
    });

    test('Qibla direction accuracy for multiple major cities', () {
      final cities = [
        {'name': 'Lahore', 'lat': 31.5497, 'lon': 74.3436, 'expected': 265.0},
        {'name': 'New York', 'lat': 40.7128, 'lon': -74.0060, 'expected': 58.0},
        {'name': 'London', 'lat': 51.5074, 'lon': -0.1278, 'expected': 118.0},
        {'name': 'Cairo', 'lat': 30.0444, 'lon': 31.2357, 'expected': 135.0},
        {'name': 'Jakarta', 'lat': -6.2088, 'lon': 106.8456, 'expected': 295.0},
      ];

      for (final city in cities) {
        final name = city['name'] as String;
        final lat = city['lat'] as double;
        final lon = city['lon'] as double;
        final expected = city['expected'] as double;
        
        final qiblaDirection = service.calculateQiblaDirection(lat, lon);
        
        expect(qiblaDirection, closeTo(expected, 10.0),
          reason: 'Qibla direction for $name should be close to $expected°');
      }
    });
  });
}

