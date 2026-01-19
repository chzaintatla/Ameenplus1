import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/ameen_theme.dart';
import '../../utils/permission_service.dart';
import '../../utils/app_constants.dart';
import '../../network/repositories/notification_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool(AppConstants.keyGuestMode) ?? false;

      if (!mounted) return;

      if (user != null || isGuest) {
        if (user != null) {
          NotificationRepository.startNotificationListener(user.uid);
        }
        context.go('/feed');
      } else {
        // Clear guest mode if we're not authenticated and not explicitly in guest mode
        await prefs.setBool(AppConstants.keyGuestMode, false);
        context.go('/auth');
      }
    } catch (e) {
      if (!mounted) return;
      context.go('/auth');
    }
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
                textAlign: TextAlign.center,
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
