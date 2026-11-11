import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/fairy_mood.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_stats_service.dart';
import '../../widgets/share_card.dart';
import '../../services/share_service.dart';
import 'workout_detail_screen.dart';
import '../../models/user_profile.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  final WorkoutDay completedDay;
  final int exercisesCount;
  final bool isWeekComplete;
  final bool isCycleComplete;
  final bool isChallenge;
  final String userName;
  final String? challengeStat;

  const WorkoutCompleteScreen({
    super.key,
    required this.completedDay,
    required this.exercisesCount,
    required this.isWeekComplete,
    required this.isCycleComplete,
    this.isChallenge = false,
    required this.userName,
    this.challengeStat,
  });

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  int _streak = 0;
  int _totalWorkoutsInPeriod = 1;
  int _totalExercisesInPeriod = 0;
  late ShareCardMode _mode;
  String _userName = 'Спортсмен';
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _loadData();

    if (widget.isChallenge) {
      _mode = ShareCardMode.challenge;
    } else if (widget.isCycleComplete) {
      _mode = ShareCardMode.cycle;
    } else if (widget.isWeekComplete) {
      _mode = ShareCardMode.week;
    } else {
      _mode = ShareCardMode.workout;
    }
  }

  Future<void> _loadData() async {
    _profile = await DatabaseHelper.instance.getProfileById(widget.completedDay.profileId);

    if (_userName == 'Спортсмен' || _userName.isEmpty) {
      if (_profile != null && _profile!.name.isNotEmpty) {
        _userName = _profile!.name;
      }
    }

    final streak = await FairyStatsService.recalculateWeeklyStreak();

    int workouts = 1;
    int exercises = widget.exercisesCount;

    if (widget.isWeekComplete || widget.isCycleComplete) {
      final allDays = await DatabaseHelper.instance.getWorkoutDays(profileId: widget.completedDay.profileId, limit: 100);

      final relevantDays = allDays.where((d) {
        if (d.status != 'completed') return false;
        if (d.cycleNumber != widget.completedDay.cycleNumber) return false;

        if (widget.isCycleComplete) return true;

        final currentWeek = widget.completedDay.weekNumber ?? 1;
        final dayWeek = d.weekNumber ?? 1;
        return dayWeek <= currentWeek;
      }).toList();

      workouts = relevantDays.isNotEmpty ? relevantDays.length : 1;

      int totalEx = 0;
      for (final day in relevantDays) {
        if (day.id != null) {
          final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
          totalEx += exs.where((e) => !e.isWarmup && !e.isCoolDown).length;
        }
      }
      if (totalEx > 0) exercises = totalEx;
    }

    if (mounted) setState(() {
      _streak = streak;
      _totalWorkoutsInPeriod = workouts;
      _totalExercisesInPeriod = exercises;
    });
  }

  String get _title {
    if (_mode == ShareCardMode.cycle) return 'Цикл ${widget.completedDay.cycleNumber ?? 1}';
    if (_mode == ShareCardMode.week) return 'Неделя ${widget.completedDay.weekNumber ?? 1}';
    if (_mode == ShareCardMode.challenge) return widget.challengeStat ?? 'Челлендж';

    final name = widget.completedDay.name;
    final match = RegExp(r'День (\d+)').firstMatch(name);
    if (match != null) return 'Тренировка · День ${match.group(1)}';
    return 'Тренировка';
  }

  String get _headline {
    if (_mode == ShareCardMode.challenge) return 'Челлендж пройден! 🔥';
    if (_mode == ShareCardMode.cycle) return 'Месяц завершён! 🏆';
    if (_mode == ShareCardMode.week) return 'Неделя завершена! 🔥';
    return 'Тренировка завершена! 💪';
  }

  String get _subheadline {
    if (_mode == ShareCardMode.challenge) return 'Это было мощно. Настоящий вызов!';
    if (_mode == ShareCardMode.cycle) return 'Ты прошла весь месяц. Это огромный шаг к цели!';
    if (_mode == ShareCardMode.week) return 'Все тренировки недели выполнены. Ты молодец!';
    return 'Ещё один шаг к цели. Продолжай в том же духе!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.primary.withOpacity(0.1), theme.colorScheme.surface],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                Image.asset(
                  FairyMood.party.asset,
                  width: 140, height: 140, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.celebration_rounded, size: 100, color: theme.colorScheme.primary),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),

                const SizedBox(height: 24),

                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                ).animate().slideY(begin: 0.2).fadeIn(delay: 200.ms),

                const SizedBox(height: 12),

                Text(
                  _subheadline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7), height: 1.4),
                ).animate().slideY(begin: 0.2).fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(theme, Icons.fitness_center_rounded, '$_totalExercisesInPeriod упр.'),
                    if (_streak > 0) ...[
                      const SizedBox(width: 12),
                      _buildStatChip(theme, Icons.local_fire_department_rounded, '$_streak нед.'),
                    ],
                  ],
                ).animate().fadeIn(delay: 400.ms),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final plannedDays = _profile?.daysPerWeek ?? 3;
                      final isWeekInProgress = !widget.isWeekComplete && _mode != ShareCardMode.challenge;

                      final streakValueToPass = widget.isWeekComplete
                          ? (widget.completedDay.weekNumber ?? 1)
                          : _totalWorkoutsInPeriod;

                      ShareService.shareWorkoutCard(
                        context: context,
                        mode: _mode,
                        userName: _userName,
                        title: _title,
                        minutes: widget.completedDay.durationMinutes ?? 0,
                        exercisesCount: _totalExercisesInPeriod,
                        workoutsCount: _totalWorkoutsInPeriod,
                        streakWeeks: streakValueToPass,
                        isWeekInProgress: isWeekInProgress,
                        plannedDays: plannedDays,
                        challengeStat: widget.challengeStat,
                        challengeMainStat: widget.isChallenge ? (widget.challengeStat ?? 'Выполнено') : null,
                        challengeSubStat: widget.isChallenge ? '${widget.completedDay.durationMinutes} мин' : null,
                        challengeTimeStat: widget.isChallenge ? '100%' : null,
                      );
                    },
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(_mode == ShareCardMode.workout ? 'Поделиться результатом' : 'Поделиться итогами'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ).animate().slideY(begin: 0.5).fadeIn(delay: 500.ms),

                if (widget.isChallenge) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (widget.completedDay.id == null) return;

                        final day = await DatabaseHelper.instance.getWorkoutDayById(widget.completedDay.id!);
                        if (day == null || !mounted) return;

                        await Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutDetailScreen(
                              workoutDay: day,
                              profileId: day.profileId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.fitness_center_rounded),
                      label: const Text('Продолжить тренировку'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B894),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                ],

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                      foregroundColor: theme.colorScheme.primary,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('На главную'),
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary, fontSize: 13)),
        ],
      ),
    );
  }
}