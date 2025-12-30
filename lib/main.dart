import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app/ameen_app.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  try{
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }
  catch (e){
    debugPrint('Firebase initialization error: $e');
  }
  
  runApp(
      const ProviderScope(
          child: AmeenApp()
      )
  );
}

