import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import '../../widgets/weight_chart.dart';
import '../../widgets/weekly_bar_chart.dart';
import '../../widgets/training_calendar.dart';
import 'exercise_analysis_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  UserProfile? _activeProfile;
  bool _loading = true;

  int? _selectedExerciseId;
  String _selectedExerciseName = '';

  List<Map<String, dynamic>> _weightData = [];
  Map<int, int> _weeklyData = {};
  int _totalWorkouts = 0;
  int _totalMinutes = 0;
  double _totalVolume = 0;

  List<Map<String, dynamic>> _availableExercises = [];
  List<WorkoutDay> _monthWorkouts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    FairyReactionService().addProfileListener(_onProfileChanged);
    FairyReactionService().addWorkoutListener(_onWorkoutCompleted);
  }

  void _onProfileChanged() {
    if (!mounted) return;
    _loadData();
  }

  void _onWorkoutCompleted() {
    if (!mounted) return;
    _loadData();
  }

  @override
  void dispose() {
    FairyReactionService().removeProfileListener(_onProfileChanged);
    FairyReactionService().removeWorkoutListener(_onWorkoutCompleted);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    var profiles = await DatabaseHelper.instance.getProfiles();

    if (profiles.isEmpty) {
      for (int attempt = 0; attempt < 5; attempt++) {
        await Future.delayed(const Duration(milliseconds: 300));
        profiles = await DatabaseHelper.instance.getProfiles();
        if (profiles.isNotEmpty) break;
      }
    }

    if (profiles.isEmpty) {
      if (!mounted) return;
      setState(() {
        _activeProfile = null;
        _loading = false;
      });
      return;
    }

    final active = profiles.first;

    final history = await DatabaseHelper.instance.getWorkoutDays(
      profileId: active.id!,
      limit: 100,
    );

    final completed =
        history.where((w) => w.status == 'completed').toList();

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

    // ═══ Тренировки за текущий месяц (для календаря) ═══
    final monthWorkouts = await DatabaseHelper.instance
        .getWorkoutDaysForMonth(
      profileId: active.id!,
      year: now.year,
      month: now.month,
    );

    // ═══ Объём ═══
    double volume = 0;
    for (final w in completed) {
      final exercises =
          await DatabaseHelper.instance.getWorkoutExercises(w.id!);
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

    // ═══ Упражнения для графика ═══
    final availableExercises = <Map<String, dynamic>>[];
    final seenIds = <int>{};
    for (final w in completed) {
      final exercises =
          await DatabaseHelper.instance.getWorkoutExercises(w.id!);
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

    if (!mounted) return;
    setState(() {
      _activeProfile = active;
      _totalWorkouts = completed.length;
      _totalMinutes = totalMin;
      _totalVolume = volume;
      _weeklyData = weekly;
      _availableExercises = availableExercises;
      _monthWorkouts = monthWorkouts;
      _loading = false;
    });

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

    if (!mounted) return;
    setState(() {
      _selectedExerciseId = exerciseId;
      _selectedExerciseName = exerciseName;
      _weightData = data.reversed.toList();
    });
  }

  void _openAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseAnalysisScreen(),
      ),
    );
  }

  /// Загрузка тренировок за конкретный месяц (для листания календаря).
  Future<List<WorkoutDay>> _loadMonthWorkouts(int year, int month) async {
    if (_activeProfile == null) return [];

    final workouts = await DatabaseHelper.instance.getWorkoutDaysForMonth(
      profileId: _activeProfile!.id!,
      year: year,
      month: month,
    );

    // Если это текущий отображаемый месяц — синхронизируем с состоянием
    final now = DateTime.now();
    if (year == now.year && month == now.month && mounted) {
      setState(() => _monthWorkouts = workouts);
    }

    return workouts;
  }

  /// Тап на день календаря — SnackBar с деталями.
  void _onCalendarDayTap(WorkoutDay workout) {
    final status = workout.status == 'completed'
        ? '✅ Завершена'
        : '⏳ В процессе';
    final minutes = workout.durationMinutes != null
        ? ' · ${workout.durationMinutes} мин'
        : '';

    final months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    final dateStr = '${workout.date.day} '
        '${months[workout.date.month - 1]}';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$dateStr — ${workout.name}\n$status$minutes',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
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
            _buildStatsRow(context),
            const SizedBox(height: 16),

            // ═══ Кнопка «Анализ упражнений» ═══
            _buildAnalysisButton(context),
            const SizedBox(height: 16),

            // ═══ Календарь ═══
            TrainingCalendar(
              workouts: _monthWorkouts,
              onDayTap: _onCalendarDayTap,
              onLoadMonth: _loadMonthWorkouts,
            ),
            const SizedBox(height: 16),

            WeeklyBarChart(data: _weeklyData),
            const SizedBox(height: 16),

            if (_availableExercises.isNotEmpty) ...[
              _buildExerciseDropdown(context),
              const SizedBox(height: 16),
              WeightChart(data: _weightData),
            ] else
              _buildNoDataCard(context),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAnalysis,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Анализ упражнений',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Тренды весов — растёт / стагнация / падает',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
            ],
          ),
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
              Text('Нет профиля',
                  style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Создайте профиль во вкладке «Профиль»',
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