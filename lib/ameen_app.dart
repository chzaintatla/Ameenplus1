import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/ameen_theme.dart';
import 'utils/app_constants.dart';
import 'app_router.dart';

class AmeenApp extends StatefulWidget {
  const AmeenApp({super.key});

  @override
  State<AmeenApp> createState() => _AmeenAppState();
}

class _AmeenAppState extends State<AmeenApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isThemeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(AppConstants.keyThemeMode);
      
      if (themeModeString != null) {
        setState(() {
          _themeMode = ThemeMode.values.firstWhere(
            (mode) => mode.name == themeModeString,
            orElse: () => ThemeMode.system,
          );
          _isThemeLoaded = true;
        });
      } else {
        setState(() {
          _isThemeLoaded = true;
        });
      }
    } catch (e) {
      setState(() {
        _isThemeLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isThemeLoaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp.router(
      title: 'Ameen+',
      debugShowCheckedModeBanner: false,
      theme: AmeenTheme.lightTheme(),
      darkTheme: AmeenTheme.darkTheme(),
      themeMode: _themeMode,
      routerConfig: getGoRouter(
        onThemeModeChanged: (mode) {
          setState(() {
            _themeMode = mode;
          });
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString(AppConstants.keyThemeMode, mode.name);
          });
        },
      ),
    );
  }
}

