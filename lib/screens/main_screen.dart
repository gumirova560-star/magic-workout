import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profiles/profiles_screen.dart';
import 'workout/workout_screen.dart';
import 'progress/progress_screen.dart';
import 'history/history_screen.dart';
import 'settings/settings_screen.dart';
import '../widgets/fairy_bubble.dart';

/// Главный экран с нижней навигацией и феей-наставником.
///
/// Активный таб сохраняется в SharedPreferences — при F5 (Web)
/// или перезапуске приложения возвращаемся на тот же таб.
///
/// KeyedSubtree — при переключении таба экран ПЕРЕСОЗДАЁТСЯ,
/// поэтому данные (прогресс, история, тренировки) обновляются сразу.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _keyLastTab = 'main_screen_last_tab';

  int _currentIndex = 0;
  bool _restored = false;

  final List<Widget> _screens = const [
    ProfilesScreen(),
    WorkoutScreen(),
    ProgressScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  final List<String> _screenKeys = const [
    'profiles',
    'workout',
    'progress',
    'history',
    'settings',
  ];

  @override
  void initState() {
    super.initState();
    _restoreTab();
  }

  Future<void> _restoreTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_keyLastTab);
    if (!mounted) return;

    setState(() {
      _currentIndex =
          (saved != null && saved >= 0 && saved < _screens.length)
              ? saved
              : 0;
      _restored = true;
    });
  }

  Future<void> _saveTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastTab, index);
  }

  void _onTabChanged(int index) {
    setState(() => _currentIndex = index);
    _saveTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_restored) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ═══ KeyedSubtree — пересоздание экрана при смене таба ═══
          KeyedSubtree(
            key: ValueKey('screen_$_currentIndex'),
            child: _screens[_currentIndex],
          ),
          FairyBubble(screenKey: _screenKeys[_currentIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Профиль',
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  icon: Icons.fitness_center_outlined,
                  activeIcon: Icons.fitness_center,
                  label: 'Тренировки',
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights_rounded,
                  label: 'Прогресс',
                ),
                _buildNavItem(
                  context,
                  index: 3,
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history_rounded,
                  label: 'История',
                ),
                _buildNavItem(
                  context,
                  index: 4,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Настройки',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.5),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}