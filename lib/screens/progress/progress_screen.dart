import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../widgets/weight_chart.dart';
import '../../widgets/weekly_bar_chart.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<UserProfile> _profiles = [];
  UserProfile? _activeProfile;
  bool _loading = true;

  // Выбранное упражнение для графика веса
  int? _selectedExerciseId;
  String _selectedExerciseName = '';

  // Данные
  List<Map<String, dynamic>> _weightData = [];
  Map<int, int> _weeklyData = {};
  int _totalWorkouts = 0;
  int _totalMinutes = 0;
  double _totalVolume = 0;

  // Список упражнений (для выпадающего списка)
  List<Map<String, dynamic>> _availableExercises = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final profiles = await DatabaseHelper.instance.getProfiles();

    if (profiles.isEmpty) {
      setState(() {
        _profiles = [];
        _activeProfile = null;
        _loading = false;
      });
      return;
    }

    final active = profiles.first;

    // История тренировок за последние 30 дней
    final history = await DatabaseHelper.instance.getWorkoutDays(
      profileId: active.id!,
      limit: 100,
    );

    final completed =
        history.where((w) => w.status == 'completed').toList();

    // ═══ Статистика ═══
    int totalMin = 0;
    for (final w in completed) {
      totalMin += w.durationMinutes ?? 0;
    }

    // ═══ За неделю ═══
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);

    final weekly = <int, int>{0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    for (final w in completed) {
      if (w.date.isAfter(weekStart.subtract(const Duration(days: 1)))) {
        weekly[w.date.weekday - 1] = (weekly[w.date.weekday - 1] ?? 0) + 1;
      }
    }

    // ═══ Объём ═══
    double volume = 0;
    for (final w in completed) {
      final exercises = await DatabaseHelper.instance
          .getWorkoutExercises(w.id!);
      for (final we in exercises) {
        final sets =
            await DatabaseHelper.instance.getWorkoutSets(we.id!);
        for (final s in sets) {
          if (s.completed && s.weight != null && s.reps != null) {
            volume += s.weight! * s.reps!;
          }
        }
      }
    }

    // ═══ Доступные упражнения (для графика) ═══
    final availableExercises = <Map<String, dynamic>>[];
    final seenIds = <int>{};
    for (final w in completed) {
      final exercises = await DatabaseHelper.instance
          .getWorkoutExercises(w.id!);
      for (final we in exercises) {
        if (we.itemType != 'exercise' || we.isCoolDown) continue;
        final id = we.replacedByItemId ?? we.itemId;
        if (seenIds.contains(id)) continue;
        seenIds.add(id);
        final ex = await DatabaseHelper.instance.getExerciseById(id);
        if (ex != null) {
          availableExercises.add({
            'id': ex.id,
            'name': ex.name,
          });
        }
      }
    }

    setState(() {
      _profiles = profiles;
      _activeProfile = active;
      _totalWorkouts = completed.length;
      _totalMinutes = totalMin;
      _totalVolume = volume;
      _weeklyData = weekly;
      _availableExercises = availableExercises;
      _loading = false;
    });

    // Если есть упражнения — загрузить первое
    if (availableExercises.isNotEmpty) {
      _loadWeightFor(availableExercises.first['id'],
          availableExercises.first['name']);
    }
  }

  Future<void> _loadWeightFor(int exerciseId, String exerciseName) async {
    if (_activeProfile == null) return;

    final data = await DatabaseHelper.instance.getWeightProgress(
      profileId: _activeProfile!.id!,
      exerciseId: exerciseId,
    );

    setState(() {
      _selectedExerciseId = exerciseId;
      _selectedExerciseName = exerciseName;
      _weightData = data.reversed.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeProfile == null) {
      return _buildNoProfileState(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Прогресс'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══ Статистика ═══
            _buildStatsRow(context),
            const SizedBox(height: 16),

            // ═══ График за неделю ═══
            WeeklyBarChart(data: _weeklyData),
            const SizedBox(height: 16),

            // ═══ Выбор упражнения ═══
            if (_availableExercises.isNotEmpty) ...[
              _buildExerciseDropdown(context),
              const SizedBox(height: 16),

              // ═══ График веса ═══
              WeightChart(data: _weightData),
            ] else
              _buildNoDataCard(context),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            icon: Icons.calendar_today_rounded,
            value: '$_totalWorkouts',
            label: 'тренировок',
            color: const Color(0xFF6C5CE7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            context,
            icon: Icons.timer_rounded,
            value: '$_totalMinutes',
            label: 'минут',
            color: const Color(0xFF00B894),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            context,
            icon: Icons.fitness_center_rounded,
            value: _totalVolume >= 1000
                ? '${(_totalVolume / 1000).toStringAsFixed(1)}т'
                : '${_totalVolume.toInt()}',
            label: 'объём',
            color: const Color(0xFFE17055),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseDropdown(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedExerciseId,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.primary),
          items: _availableExercises.map((e) {
            return DropdownMenuItem<int>(
              value: e['id'] as int,
              child: Text(
                e['name'] as String,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            final ex = _availableExercises
                .firstWhere((e) => e['id'] == id);
            _loadWeightFor(id, ex['name'] as String);
          },
        ),
      ),
    );
  }

  Widget _buildNoDataCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_rounded,
            size: 48,
            color: theme.colorScheme.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text('Прогресса пока нет',
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Завершите тренировки с весами — появятся графики',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileState(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_rounded,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text('Нет профилей',
                  style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Создайте профиль во вкладке «Профили»',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}