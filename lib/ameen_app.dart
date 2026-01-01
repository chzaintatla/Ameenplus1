import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/ameen_theme.dart';
import 'providers/theme_mode_provider.dart';
import 'app_router.dart';

class AmeenApp extends ConsumerWidget {
  const AmeenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Ameen+',
      debugShowCheckedModeBanner: false,
      theme: AmeenTheme.lightTheme(),
      darkTheme: AmeenTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

