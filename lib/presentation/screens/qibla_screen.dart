import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

const double kaabaLatitude = 21.4225;
const double kaabaLongitude = 39.8262;

final qiblaProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  try {
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

    Position position = await Geolocator.getCurrentPosition();

    final qiblaDirection = _calculateQiblaDirection(
      position.latitude,
      position.longitude,
    );

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

double _calculateQiblaDirection(double latitude, double longitude) {
  final lat1 = latitude * math.pi / 180;
  final lon1 = longitude * math.pi / 180;
  final lat2 = kaabaLatitude * math.pi / 180;
  final lon2 = kaabaLongitude * math.pi / 180;

  final dLon = lon2 - lon1;
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
            math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

  final bearing = math.atan2(y, x);

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

          double angleDifference = qiblaDirection - compassHeading;
          if (angleDifference < 0) {
            angleDifference += 360;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _CompassWidget(
                            compassHeading: compassHeading,
                            qiblaDirection: qiblaDirection,
                          ),
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
                        'The green arrow points to the Kaaba in Mecca',
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

class _CompassWidget extends StatefulWidget {
  final double compassHeading;
  final double qiblaDirection;

  const _CompassWidget({
    required this.compassHeading,
    required this.qiblaDirection,
  });

  @override
  State<_CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<_CompassWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _previousCompassHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _previousCompassHeading = widget.compassHeading;
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_CompassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.compassHeading - _previousCompassHeading).abs() > 1.0) {
      _controller.reset();
      _controller.forward();
      _previousCompassHeading = widget.compassHeading;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size.width - 80;
    
    double angleDifference = widget.qiblaDirection - widget.compassHeading;
    if (angleDifference < 0) {
      angleDifference += 360;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final compassAngle = -widget.compassHeading * math.pi / 180;
        final qiblaAngle = angleDifference * math.pi / 180;

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: compassAngle,
              child: CustomPaint(
                size: Size(size, size),
                painter: CompassPainter(
                  qiblaAngle: qiblaAngle,
                  qiblaDirection: widget.qiblaDirection,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CompassPainter extends CustomPainter {
  final double qiblaAngle;
  final double qiblaDirection;

  CompassPainter({
    required this.qiblaAngle,
    required this.qiblaDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final outerCirclePaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final innerCirclePaint = Paint()
      ..color = Colors.grey.shade900
      ..style = PaintingStyle.fill;

    final degreePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final majorTickPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final minorTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    canvas.drawCircle(center, radius, outerCirclePaint);
    canvas.drawCircle(center, radius - 2, innerCirclePaint);

    for (int i = 0; i < 360; i += 5) {
      final angle = i * math.pi / 180;
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 20.0 : 10.0;
      final tickPaint = isMajor ? majorTickPaint : minorTickPaint;

      final startX = center.dx + (radius - tickLength) * math.sin(angle);
      final startY = center.dy - (radius - tickLength) * math.cos(angle);
      final endX = center.dx + radius * math.sin(angle);
      final endY = center.dy - radius * math.cos(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        tickPaint,
      );

      if (isMajor) {
        final labelRadius = radius - 35;
        final labelX = center.dx + labelRadius * math.sin(angle);
        final labelY = center.dy - labelRadius * math.cos(angle);

        String label;
        if (i == 0) {
          label = 'N';
        } else if (i == 90) {
          label = 'E';
        } else if (i == 180) {
          label = 'S';
        } else if (i == 270) {
          label = 'W';
        } else {
          label = '${i ~/ 10}';
        }

        textPainter.text = TextSpan(text: label, style: textStyle);
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            labelX - textPainter.width / 2,
            labelY - textPainter.height / 2,
          ),
        );
      }
    }

    final northPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final northPath = Path();
    final northLength = radius * 0.4;
    final northWidth = 8.0;

    northPath.moveTo(center.dx, center.dy - radius + 20);
    northPath.lineTo(center.dx - northWidth / 2, center.dy - radius + 20 + northLength);
    northPath.lineTo(center.dx, center.dy - radius + 20 + northLength - 10);
    northPath.lineTo(center.dx + northWidth / 2, center.dy - radius + 20 + northLength);
    northPath.close();

    canvas.drawPath(northPath, northPaint);

    final qiblaPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final qiblaPath = Path();
    final qiblaLength = radius * 0.35;
    final qiblaWidth = 8.0;

    final qiblaAngleRad = qiblaAngle;
    final qiblaX = center.dx + qiblaLength * math.sin(qiblaAngleRad);
    final qiblaY = center.dy - qiblaLength * math.cos(qiblaAngleRad);

    qiblaPath.moveTo(center.dx, center.dy);
    qiblaPath.lineTo(
      center.dx + qiblaWidth * math.cos(qiblaAngleRad + math.pi / 2),
      center.dy + qiblaWidth * math.sin(qiblaAngleRad + math.pi / 2),
    );
    qiblaPath.lineTo(qiblaX, qiblaY);
    qiblaPath.lineTo(
      center.dx - qiblaWidth * math.cos(qiblaAngleRad + math.pi / 2),
      center.dy - qiblaWidth * math.sin(qiblaAngleRad + math.pi / 2),
    );
    qiblaPath.close();

    canvas.drawPath(qiblaPath, qiblaPaint);

    final qiblaIconPaint = Paint()
      ..color = Colors.green.shade700
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(qiblaX, qiblaY),
      8,
      qiblaIconPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is CompassPainter) {
      return oldDelegate.qiblaAngle != qiblaAngle ||
          oldDelegate.qiblaDirection != qiblaDirection;
    }
    return true;
  }
}
