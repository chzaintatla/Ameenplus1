import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:sensors_plus/sensors_plus.dart';

const double kaabaLatitude = 21.4225241;
const double kaabaLongitude = 39.8261818;

class QiblaCompassService {
  static const double magneticDeclinationThreshold = 5.0;

  double calculateQiblaDirection(double latitude, double longitude) {
    final lat1 = latitude * math.pi / 180;
    final lon1 = longitude * math.pi / 180;
    final lat2 = kaabaLatitude * math.pi / 180;
    final lon2 = kaabaLongitude * math.pi / 180;

    final dLon = lon2 - lon1;
    
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
              math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x);
    var bearingDegrees = bearing * 180 / math.pi;
    
    bearingDegrees = (bearingDegrees + 360) % 360;

    return bearingDegrees;
  }

  Future<CompassAccuracy> validateCompassAccuracy() async {
    try {
      final compassEvents = FlutterCompass.events;
      if (compassEvents == null) {
        return CompassAccuracy.unavailable;
      }

      final samples = <double>[];
      await for (final event in compassEvents.take(10)) {
        if (event.heading != null) {
          samples.add(event.heading!);
        }
      }

      if (samples.length < 5) {
        return CompassAccuracy.unstable;
      }

      final variance = _calculateVariance(samples);
      if (variance > 100) {
        return CompassAccuracy.unstable;
      } else if (variance > 50) {
        return CompassAccuracy.moderate;
      } else {
        return CompassAccuracy.accurate;
      }
    } catch (e) {
      return CompassAccuracy.unavailable;
    }
  }

  double _calculateVariance(List<double> samples) {
    if (samples.isEmpty) return 0;
    
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final squaredDiffs = samples.map((x) => math.pow(x - mean, 2)).toList();
    final variance = squaredDiffs.reduce((a, b) => a + b) / samples.length;
    
    return variance;
  }

  Future<double?> getMagneticDeclination(double latitude, double longitude) async {
    try {
      final year = DateTime.now().year;
      final declination = _calculateMagneticDeclination(latitude, longitude, year);
      return declination;
    } catch (e) {
      return null;
    }
  }

  double _calculateMagneticDeclination(double lat, double lon, int year) {
    final latRad = lat * math.pi / 180;
    final lonRad = lon * math.pi / 180;
    
    final n = (year - 2020) / 5.0;
    
    final g0 = 11.4 + 0.7 * latRad;
    final g1 = -0.5 * math.sin(latRad) * math.cos(lonRad);
    final g2 = 0.3 * math.sin(2 * latRad) * math.sin(lonRad);
    
    final declination = g0 + g1 * n + g2 * n * n;
    
    return declination;
  }

  Future<QiblaLocationAccuracy> validateLocationAccuracy() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      
      if (position.accuracy != null) {
        if (position.accuracy! < 20) {
          return QiblaLocationAccuracy.high;
        } else if (position.accuracy! < 50) {
          return QiblaLocationAccuracy.medium;
        } else {
          return QiblaLocationAccuracy.low;
        }
      }
      return QiblaLocationAccuracy.medium;
    } catch (e) {
      return QiblaLocationAccuracy.low;
    }
  }

  double calculateAngleDifference(double compassHeading, double qiblaDirection) {
    var diff = (qiblaDirection - compassHeading).abs();
    if (diff > 180) {
      diff = 360 - diff;
    }
    return diff;
  }

  bool isPointingToQibla(double compassHeading, double qiblaDirection, {double tolerance = 5.0}) {
    final diff = calculateAngleDifference(compassHeading, qiblaDirection);
    return diff <= tolerance;
  }
}

enum CompassAccuracy {
  accurate,
  moderate,
  unstable,
  unavailable,
  noPermission,
}

enum QiblaLocationAccuracy {
  high,
  medium,
  low,
}

