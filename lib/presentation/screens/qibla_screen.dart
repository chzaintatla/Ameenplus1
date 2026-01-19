import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../services/qibla_compass_service.dart';
import '../../widgets/kaaba_image_widget.dart';

const double kaabaLatitude = 21.4225241;
const double kaabaLongitude = 39.8261818;

Stream<Map<String, dynamic>> _getQiblaStream() async* {
  try {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      yield {
        'error': 'Location services are disabled',
        'compassHeading': 0.0,
        'qiblaDirection': 0.0,
      };
      return;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        yield {
          'error': 'Location permission denied',
          'compassHeading': 0.0,
          'qiblaDirection': 0.0,
        };
        return;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      yield {
        'error': 'Location permission permanently denied',
        'compassHeading': 0.0,
        'qiblaDirection': 0.0,
      };
      return;
    }

    geo.Position position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );

    final qiblaService = QiblaCompassService();
    final qiblaDirection = qiblaService.calculateQiblaDirection(
      position.latitude,
      position.longitude,
    );

    await for (final compassEvent in FlutterCompass.events!) {
      if (compassEvent.heading != null) {
        var heading = compassEvent.heading!;
        if (heading < 0) {
          heading += 360;
        }
        heading = heading % 360;
        
        yield {
          'compassHeading': heading,
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
}


class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  CompassAccuracy? _compassAccuracy;
  QiblaLocationAccuracy? _locationAccuracy;
  bool _isValidating = false;
  final QiblaCompassService _qiblaService = QiblaCompassService();
  Stream<Map<String, dynamic>>? _qiblaStream;

  @override
  void initState() {
    super.initState();
    _qiblaStream = _getQiblaStream();
    _validateAccuracy();
  }

  void _reloadQibla() {
    setState(() {
      _qiblaStream = _getQiblaStream();
    });
  }

  Future<void> _validateAccuracy() async {
    setState(() => _isValidating = true);
    final compassAcc = await _qiblaService.validateCompassAccuracy();
    final locationAcc = await _qiblaService.validateLocationAccuracy();
    setState(() {
      _compassAccuracy = compassAcc;
      _locationAccuracy = locationAcc;
      _isValidating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final qiblaStream = _qiblaStream ?? _getQiblaStream();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla Compass'),
        actions: [
          IconButton(
            icon: _isValidating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isValidating ? null : _validateAccuracy,
            tooltip: 'Validate Accuracy',
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: qiblaStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
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
                    'Error loading Qibla',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _reloadQibla,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          
          if (data['error'] != null) {
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
                  Text(
                    data['error'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _reloadQibla,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return _buildQiblaContent(context, data);
        },
      ),
    );
  }

  Widget _buildQiblaContent(BuildContext context, Map<String, dynamic> data) {
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
                _reloadQibla();
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

    final angleDifference = _qiblaService.calculateAngleDifference(compassHeading, qiblaDirection);
    final isPointing = _qiblaService.isPointingToQibla(compassHeading, qiblaDirection);

    return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_compassAccuracy != null || _locationAccuracy != null)
                Card(
                  color: _getAccuracyCardColor(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          _getAccuracyIcon(),
                          color: _getAccuracyIconColor(),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getAccuracyMessage(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: _getAccuracyIconColor(),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_compassAccuracy != null || _locationAccuracy != null)
                const SizedBox(height: 16),
              if (isPointing)
                Card(
                  color: Colors.green.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You are pointing towards Qibla! (${angleDifference.toStringAsFixed(1)}Â° off)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.green,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isPointing) const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _CompassWidget(
                                compassHeading: compassHeading,
                                qiblaDirection: qiblaDirection,
                              ),
                              // Kaaba image at the center pointing towards Qibla
                              Positioned(
                                child: StreamBuilder<CompassEvent>(
                                  stream: FlutterCompass.events,
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData || snapshot.data!.heading == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final heading = snapshot.data!.heading!;
                                    final relativeQiblaAngle = 
                                        ((qiblaDirection - heading + 360) % 360) * math.pi / 180;
                                    return KaabaImageWidget(
                                      rotationAngle: relativeQiblaAngle,
                                      size: 100,
                                    );
                                  },
                                ),
                              ),
                            ],
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
                        'The Kaaba image at the center points towards the Holy Kaaba in makkah',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Green arrow = Qibla direction',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF8B4513), Color(0xFF654321)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                         // Text(
                           // 'Center image = Kaaba (rotate device to align)',
                            //style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            //  color: Theme.of(context).colorScheme.onSurfaceVariant,
                           // ),
                         // ),
                        ],
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
                        '${qiblaDirection.toStringAsFixed(1)}Â°',
                        Icons.navigation,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        'Compass Heading',
                        '${compassHeading.toStringAsFixed(1)}Â°',
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
                        'Move away from magnetic interference (metal, electronics)',
                      ),
                      _buildInstructionItem(
                        context,
                        '3',
                        'Rotate your device until the green arrow points up',
                      ),
                      _buildInstructionItem(
                        context,
                        '4',
                        'You are now facing the Qibla direction',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
  }

  Color _getAccuracyCardColor() {
    if (_compassAccuracy == CompassAccuracy.accurate && 
        _locationAccuracy == QiblaLocationAccuracy.high) {
      return Colors.green.withValues(alpha: 0.1);
    } else if (_compassAccuracy == CompassAccuracy.unstable || 
               _locationAccuracy == QiblaLocationAccuracy.low) {
      return Colors.red.withValues(alpha: 0.1);
    }
    return Colors.orange.withValues(alpha: 0.1);
  }

  IconData _getAccuracyIcon() {
    if (_compassAccuracy == CompassAccuracy.accurate && 
        _locationAccuracy == QiblaLocationAccuracy.high) {
      return Icons.check_circle;
    } else if (_compassAccuracy == CompassAccuracy.unstable || 
               _locationAccuracy == QiblaLocationAccuracy.low) {
      return Icons.warning;
    }
    return Icons.info;
  }

  Color _getAccuracyIconColor() {
    if (_compassAccuracy == CompassAccuracy.accurate && 
        _locationAccuracy == QiblaLocationAccuracy.high) {
      return Colors.green;
    } else if (_compassAccuracy == CompassAccuracy.unstable || 
               _locationAccuracy == QiblaLocationAccuracy.low) {
      return Colors.red;
    }
    return Colors.orange;
  }

  String _getAccuracyMessage() {
    final compassMsg = _compassAccuracy != null 
        ? 'Compass: ${_getCompassAccuracyText(_compassAccuracy!)}'
        : '';
    final locationMsg = _locationAccuracy != null
        ? 'Location: ${_getLocationAccuracyText(_locationAccuracy!)}'
        : '';
    
    if (compassMsg.isNotEmpty && locationMsg.isNotEmpty) {
      return '$compassMsg • $locationMsg';
    } else if (compassMsg.isNotEmpty) {
      return compassMsg;
    } else if (locationMsg.isNotEmpty) {
      return locationMsg;
    }
    return 'Validating accuracy...';
  }

  String _getCompassAccuracyText(CompassAccuracy accuracy) {
    switch (accuracy) {
      case CompassAccuracy.accurate:
        return 'Accurate';
      case CompassAccuracy.moderate:
        return 'Moderate';
      case CompassAccuracy.unstable:
        return 'Unstable - Move away from interference';
      case CompassAccuracy.unavailable:
        return 'Unavailable';
      case CompassAccuracy.noPermission:
        return 'Permission needed';
    }
  }

  String _getLocationAccuracyText(QiblaLocationAccuracy accuracy) {
    switch (accuracy) {
      case QiblaLocationAccuracy.high:
        return 'High';
      case QiblaLocationAccuracy.medium:
        return 'Medium';
      case QiblaLocationAccuracy.low:
        return 'Low - Enable GPS';
    }
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
  double _smoothedHeading = 0.0;
  static const double _smoothingFactor = 0.15;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _smoothedHeading = widget.compassHeading;
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_CompassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final headingDiff = (widget.compassHeading - _smoothedHeading).abs();
    final normalizedDiff = headingDiff > 180 ? 360 - headingDiff : headingDiff;
    
    if (normalizedDiff > 0.5) {
      _smoothedHeading = _smoothedHeading + (widget.compassHeading - _smoothedHeading) * _smoothingFactor;
      if (_smoothedHeading < 0) _smoothedHeading += 360;
      if (_smoothedHeading >= 360) _smoothedHeading -= 360;
      _controller.reset();
      _controller.forward();
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final compassAngle = -_smoothedHeading * math.pi / 180;
        final relativeQiblaAngle = (widget.qiblaDirection - _smoothedHeading + 360) % 360;
        final qiblaAngleRad = relativeQiblaAngle * math.pi / 180;

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: compassAngle,
              child: CustomPaint(
                size: Size(size, size),
                painter: CompassPainter(
                  qiblaAngle: qiblaAngleRad,
                  qiblaDirection: widget.qiblaDirection,
                ),
              ),
            ),
            // Kaaba Image pointing to Qibla
            Transform.rotate(
              angle: qiblaAngleRad,
              child: KaabaImageWidget(
                rotationAngle: 0, // Image itself doesn't need rotation, compass handles it
                size: size * 0.15,
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
    final qiblaWidth = 10.0;

    final qiblaAngleRad = qiblaAngle;
    final qiblaX = center.dx + qiblaLength * math.sin(qiblaAngleRad);
    final qiblaY = center.dy - qiblaLength * math.cos(qiblaAngleRad);

    final perpAngle = qiblaAngleRad + math.pi / 2;
    final perpX = math.cos(perpAngle) * qiblaWidth;
    final perpY = math.sin(perpAngle) * qiblaWidth;

    qiblaPath.moveTo(center.dx, center.dy);
    qiblaPath.lineTo(center.dx + perpX, center.dy + perpY);
    qiblaPath.lineTo(qiblaX, qiblaY);
    qiblaPath.lineTo(center.dx - perpX, center.dy - perpY);
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
