import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_helper.dart';
import '../../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final mode = await ThemeService.loadThemeMode();
    setState(() {
      _themeMode = mode;
      _loading = false;
    });
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    await ThemeService.saveThemeMode(mode);
    setState(() => _themeMode = mode);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Тема: ${ThemeService.getThemeModeLabel(mode)}'),
      ),
    );
  }

  Future<void> _clearHistory() async {
    final profiles = await DatabaseHelper.instance.getProfiles();
    if (profiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: Text(
            'Все тренировки профиля «${profiles.first.name}» будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final history = await DatabaseHelper.instance
        .getWorkoutDays(profileId: profiles.first.id!);
    for (final w in history) {
      await DatabaseHelper.instance.deleteWorkoutDay(w.id!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('История очищена')),
    );
  }

  Future<void> _clearAllProfiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить все профили?'),
        content: const Text(
            'Все профили, тренировки и история будут удалены. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить всё',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final profiles = await DatabaseHelper.instance.getProfiles();
    for (final p in profiles) {
      await DatabaseHelper.instance.deleteProfile(p.id!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Все профили удалены')),
    );
  }

  Future<void> _showAbout() async {
    showAboutDialog(
      context: context,
      applicationName: 'Magic Workout',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.fitness_center,
            color: Colors.white, size: 32),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Magic Workout - Приложение для составления и ведения плана тренировок.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        const Text(
          '• 73 упражнения\n'
          '• 55 растяжек и йога-поз\n'
          '• 7 йога-сессий\n'
          '• Автоматический подбор плана',
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══ ТЕМА ═══
          _sectionTitle(context, 'Оформление'),
          _buildCard(
            context,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: _themeMode,
                onChanged: (v) => _changeTheme(v!),
                title: const Text('Системная'),
                subtitle: const Text('Как в телефоне'),
                secondary: const Icon(Icons.brightness_auto_rounded),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: _themeMode,
                onChanged: (v) => _changeTheme(v!),
                title: const Text('Светлая'),
                secondary: const Icon(Icons.light_mode_rounded),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: _themeMode,
                onChanged: (v) => _changeTheme(v!),
                title: const Text('Тёмная'),
                secondary: const Icon(Icons.dark_mode_rounded),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ═══ ДАННЫЕ ═══
          _sectionTitle(context, 'Данные'),
          _buildCard(
            context,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDCB6E).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_rounded,
                      color: Color(0xFFFDCB6E), size: 20),
                ),
                title: const Text('Очистить историю'),
                subtitle: const Text('Удалить завершённые тренировки'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _clearHistory,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_forever_rounded,
                      color: theme.colorScheme.error, size: 20),
                ),
                title: const Text('Удалить все профили'),
                subtitle: const Text('Полный сброс данных'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _clearAllProfiles,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ═══ О ПРИЛОЖЕНИИ ═══
          _sectionTitle(context, 'О приложении'),
          _buildCard(
            context,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.info_outline_rounded,
                      color: theme.colorScheme.primary, size: 20),
                ),
                title: const Text('О приложении'),
                subtitle: const Text('Версия 1.0.0'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showAbout,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ═══ Версия ═══
          Center(
            child: Column(
              children: [
                Text(
                  'Magic Workout',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Версия 1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}