import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'ameen_app.dart';
import 'network/repositories/notification_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize Supabase for storage only (images, videos, files)
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    debugPrint('Supabase initialized successfully (storage only)');
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  // Initialize local notifications for push notifications
  try {
    await NotificationRepository.initializeLocalNotifications();
    debugPrint('Local notifications initialized successfully');
  } catch (e) {
    debugPrint('Local notifications initialization error: $e');
  }

  runApp(const AmeenApp());
}
