import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/ameen_theme.dart';
import '../../providers/auth_providers.dart';
import '../../utils/permission_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    await PermissionService.requestInitialPermissions();

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final authState = ref.read(authStateProvider);
    final isGuest = ref.read(guestModeProvider);

    authState.when(
      data: (user) {
        if (user != null || isGuest) {
          context.go('/feed');
        } else {
          context.go('/auth');
        }
      },
      loading: () {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          final authStateAfterWait = ref.read(authStateProvider);
          final guestAfterWait = ref.read(guestModeProvider);
          authStateAfterWait.whenData((user) {
            if (mounted) {
              if (user != null || guestAfterWait) {
                context.go('/feed');
              } else {
                context.go('/auth');
              }
            }
          });
        });
      },
      error: (_, __) => context.go('/auth'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AmeenTheme.islamicGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 70,
                  color: AmeenTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ameen+',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Islamic Companion',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
