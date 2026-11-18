import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_strategy/url_strategy.dart';

// ИМПОРТЫ ДЛЯ FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'services/data_initializer.dart';
import 'services/theme_service.dart';
import 'services/database_helper.dart';
import 'services/fairy_reaction_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profiles/profile_edit_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();

  // ИНИЦИАЛИЗАЦИЯ FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

    // Слушаем события смены профиля, чтобы вовремя переключать экраны
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
    _checkState(); // проверяем профиль после онбординга
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
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ru', 'RU'),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    // Пока идёт инициализация — показываем загрузку,
    // чтобы MainScreen не монтировался со «случайными» дефолтами.
    if (_loading) {
      return const Scaffold(
        key: ValueKey('loading'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Порядок проверки важен: онбординг старше требования профиля
    if (_showOnboarding) {
      return OnboardingScreen(
        key: const ValueKey('onboarding'),
        onFinish: _finishOnboarding,
      );
    }

    if (_needsProfile) {
      return const ProfileEditScreen(key: ValueKey('profile_edit'));
    }

    return const MainScreen(key: ValueKey('main_screen'));
  }
}
