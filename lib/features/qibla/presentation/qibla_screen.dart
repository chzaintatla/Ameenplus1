import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

// Kaaba coordinates in Mecca
const double kaabaLatitude = 21.4225;
const double kaabaLongitude = 39.8262;

final qiblaProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  try {
    // Get location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      yield {
        'error': 'Location services are disabled',
        'compassHeading': 0.0,
        'qiblaDirection': 0.0,
      };
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        yield {
          'error': 'Location permission denied',
          'compassHeading': 0.0,
          'qiblaDirection': 0.0,
        };
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      yield {
        'error': 'Location permission permanently denied',
        'compassHeading': 0.0,
        'qiblaDirection': 0.0,
      };
      return;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition();
    
    // Calculate Qibla direction
    final qiblaDirection = _calculateQiblaDirection(
      position.latitude,
      position.longitude,
    );

    // Listen to compass
    await for (final compassEvent in FlutterCompass.events!) {
      if (compassEvent.heading != null) {
        yield {
          'compassHeading': compassEvent.heading!,
          'qiblaDirection': qiblaDirection,
          'latitude': position.latitude,
          'longitude': position.longitude,
        };
      }
    }
  } catch (e) {
    yield {
      'error': e.toString(),
      'compassHeading': 0.0,
      'qiblaDirection': 0.0,
    };
  }
});

/// Calculate Qibla direction from current location to Kaaba
double _calculateQiblaDirection(double latitude, double longitude) {
  // Convert to radians
  final lat1 = latitude * math.pi / 180;
  final lon1 = longitude * math.pi / 180;
  final lat2 = kaabaLatitude * math.pi / 180;
  final lon2 = kaabaLongitude * math.pi / 180;

  // Calculate bearing
  final dLon = lon2 - lon1;
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - 
            math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  
  final bearing = math.atan2(y, x);
  
  // Convert to degrees and normalize to 0-360
  final bearingDegrees = (bearing * 180 / math.pi + 360) % 360;
  
  return bearingDegrees;
}

class QiblaScreen extends ConsumerWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qiblaAsync = ref.watch(qiblaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla Direction'),
      ),
      body: qiblaAsync.when(
        data: (data) {
          if (data.containsKey('error')) {
            return Center(
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
                    'Error',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      data['error'] as String,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(qiblaProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final compassHeading = (data['compassHeading'] as num).toDouble();
          final qiblaDirection = (data['qiblaDirection'] as num).toDouble();
          final latitude = data['latitude'] as double?;
          final longitude = data['longitude'] as double?;

          // Calculate angle difference
          double angleDifference = qiblaDirection - compassHeading;
          if (angleDifference < 0) {
            angleDifference += 360;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Compass Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Compass background
                            Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 3,
                                ),
                                color: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                            // Qibla indicator (arrow pointing to Kaaba)
                            Transform.rotate(
                              angle: (angleDifference * math.pi / 180),
                              child: Container(
                                width: 200,
                                height: 200,
                                child: CustomPaint(
                                  painter: QiblaArrowPainter(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            // Center dot
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            // North indicator
                            Positioned(
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'N',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onError,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Point your device towards the arrow',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The arrow points to the Kaaba in Mecca',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Information Cards
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.explore,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Qibla Direction',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        'Direction',
                        '${qiblaDirection.toStringAsFixed(1)}°',
                        Icons.navigation,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        'Compass Heading',
                        '${compassHeading.toStringAsFixed(1)}°',
                        Icons.compass_calibration,
                      ),
                      if (latitude != null && longitude != null) ...[
                        const Divider(),
                        _buildInfoRow(
                          context,
                          'Your Location',
                          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                          Icons.location_on,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Instructions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Instructions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionItem(
                        context,
                        '1',
                        'Hold your device flat and level',
                      ),
                      _buildInstructionItem(
                        context,
                        '2',
                        'Rotate your device until the arrow points up',
                      ),
                      _buildInstructionItem(
                        context,
                        '3',
                        'You are now facing the Qibla direction',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
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
                'Error loading Qibla',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(qiblaProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionItem(BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for Qibla arrow
class QiblaArrowPainter extends CustomPainter {
  final Color color;

  QiblaArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final arrowLength = size.width * 0.35;
    final arrowWidth = size.width * 0.1;

    // Arrow pointing up (towards Qibla)
    path.moveTo(centerX, centerY - arrowLength);
    path.lineTo(centerX - arrowWidth / 2, centerY - arrowLength + arrowWidth);
    path.lineTo(centerX - arrowWidth / 4, centerY - arrowLength + arrowWidth);
    path.lineTo(centerX - arrowWidth / 4, centerY);
    path.lineTo(centerX + arrowWidth / 4, centerY);
    path.lineTo(centerX + arrowWidth / 4, centerY - arrowLength + arrowWidth);
    path.lineTo(centerX + arrowWidth / 2, centerY - arrowLength + arrowWidth);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

