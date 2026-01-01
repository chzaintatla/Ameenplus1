import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../providers/auth_providers.dart';
import '../../utils/points_service.dart';
import '../../utils/app_constants.dart';

class TasbihCounterScreen extends ConsumerStatefulWidget {
  const TasbihCounterScreen({super.key});

  @override
  ConsumerState<TasbihCounterScreen> createState() => _TasbihCounterScreenState();
}

class _TasbihCounterScreenState extends ConsumerState<TasbihCounterScreen>
    with TickerProviderStateMixin {
  int _counter = 0;
  int _selectedWidget = 0;
  late AnimationController _bounceController;
  late AnimationController _rotateController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotateAnimation;

  final List<Map<String, dynamic>> _widgets = [
    {'name': 'Subhan Allah', 'color': Colors.green, 'icon': Icons.eco},
    {'name': 'Alhamdulillah', 'color': Colors.blue, 'icon': Icons.favorite},
    {'name': 'Allahu Akbar', 'color': Colors.orange, 'icon': Icons.star},
    {'name': 'La ilaha illa Allah', 'color': Colors.purple, 'icon': Icons.diamond},
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _incrementCounter() async {
    setState(() {
      _counter++;
    });

    _bounceController.forward().then((_) {
      _bounceController.reverse();
    });

    _rotateController.forward().then((_) {
      _rotateController.reset();
    });

    if (_counter % 100 == 0) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final pointsService = PointsService();
        await pointsService.addTasbihPoints(userId: user.uid, count: 100);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+${PointsService.tasbihPointsPer100} points for 100 counts!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedWidgetData = _widgets[_selectedWidget];
    final pointsEarned = (_counter / 100).floor() * PointsService.tasbihPointsPer100;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              selectedWidgetData['color'] as Color,
              (selectedWidgetData['color'] as Color).withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tasbih Counter',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _widgets.asMap().entries.map((entry) {
                                final index = entry.key;
                                final widget = entry.value;
                                return ListTile(
                                  leading: Icon(widget['icon'], color: widget['color']),
                                  title: Text(widget['name']),
                                  trailing: _selectedWidget == index
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedWidget = index;
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _widgets[_selectedWidget]['name'],
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: _incrementCounter,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_bounceAnimation, _rotateAnimation]),
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateAnimation.value,
                              child: Transform.scale(
                                scale: _bounceAnimation.value,
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_counter',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Points Earned',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pointsEarned.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 40),
                          Column(
                            children: [
                              Text(
                                'Next 100',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${100 - (_counter % 100)}',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _resetCounter,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: selectedWidgetData['color'] as Color,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _incrementCounter,
                      icon: const Icon(Icons.add),
                      label: const Text('Count'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: selectedWidgetData['color'] as Color,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

