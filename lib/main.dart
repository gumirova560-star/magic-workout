import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_strategy/url_strategy.dart';

import 'services/data_initializer.dart';
import 'services/theme_service.dart';
import 'services/database_helper.dart';
import 'services/fairy_reaction_service.dart'; // 👈 Добавили для отслеживания смены профиля
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profiles/profile_edit_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();

  // Инициализируем БД до запуска приложения
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
  bool _loading = true;
  bool _showOnboarding = false;
  bool _needsProfile = false;

  @override
  void initState() {
    super.initState();
    _init();

    // Слушаем события смены профиля, чтобы вовремя переключить экран
    FairyReactionService().addProfileListener(_checkState);
  }

  @override
  void dispose() {
    FairyReactionService().removeProfileListener(_checkState);
    super.dispose();
  }

  Future<void> _init() async {
    final mode = await ThemeService.loadThemeMode();
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('fairy_onboarding_done') ?? false;

    // Проверяем, есть ли профиль
    final profiles = await DatabaseHelper.instance.getProfiles();
    final hasProfile = profiles.isNotEmpty;

    if (!mounted) return;
    setState(() {
      _themeMode = mode;
      _showOnboarding = !done;
      _needsProfile = !hasProfile;
      _loading = false;
    });
  }

  Future<void> _checkState() async {
    final profiles = await DatabaseHelper.instance.getProfiles();
    if (!mounted) return;

    setState(() {
      _needsProfile = profiles.isEmpty;
    });
  }

  void _finishOnboarding() {
    setState(() => _showOnboarding = false);
    _checkState(); // Проверяем профиль после онбординга
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magic Workout',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],
      locale: const Locale('ru', 'RU'),
      // 👇 ЕДИНЫЙ ДОМ (HOME) С ПЛАВНЫМ ПЕРЕКЛЮЧЕНИЕМ
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    if (_loading) {
      return const Scaffold(
        key: ValueKey('loading'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        key: const ValueKey('onboarding'),
        onFinish: _finishOnboarding,
      );
    }

    if (_needsProfile) {
      return Scaffold(
        key: const ValueKey('profile_edit'),
        body: ProfileEditScreen(
          key: UniqueKey(),
          // Если ProfileEditScreen умеет принимать колбэк — добавьте его.
          // Если нет, он просто сохранит профиль, а FairyReactionService
          // вызовет _checkState и переключит экран.
        ),
      );
    }

    return const MainScreen(key: ValueKey('main_screen'));
  }
}