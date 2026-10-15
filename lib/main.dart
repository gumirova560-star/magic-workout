import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_strategy/url_strategy.dart';
import 'services/data_initializer.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══ URL без # (только для Web) ═══
  setPathUrlStrategy();

  await DataInitializer.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _showOnboarding = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final mode = await ThemeService.loadThemeMode();
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('fairy_onboarding_done') ?? false;

    setState(() {
      _themeMode = mode;
      _showOnboarding = !done;
      _loading = false;
    });
  }

  void _finishOnboarding() {
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'Magic Workout',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,

      // ═══ ЛОКАЛИЗАЦИЯ (для DatePicker и др.) ═══
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ru', 'RU'),

      home: _showOnboarding
          ? OnboardingScreen(onFinish: _finishOnboarding)
          : const MainScreen(),
    );
  }
}