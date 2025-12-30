import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

final firebaseReadyProvider = FutureProvider<bool>((ref) async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return true;
  } catch (e) {
    // Firebase not configured yet - app can still run in guest mode
    print('Firebase initialization error: $e');
    return false;
  }
});
