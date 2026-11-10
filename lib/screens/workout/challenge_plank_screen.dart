import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/workout_day.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../data/base_exercises.dart';
import 'workout_complete_screen.dart';

class ChallengePlankScreen extends StatefulWidget {
  final WorkoutDay day;
  final int profileId;
  final List<WorkoutExercise> items;
  final Map<int, Exercise> exerciseMap;

  const ChallengePlankScreen({
    super.key,
    required this.day,
    required this.profileId,
    required this.items,
    required this.exerciseMap,
  });

  @override
  State<ChallengePlankScreen> createState() => _ChallengePlankScreenState();
}

class _ChallengePlankScreenState extends State<ChallengePlankScreen> {
  bool _started = false;
  bool _finished = false;
  bool _isPaused = false;
  int _secondsElapsed = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startChallenge() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _finished || _isPaused) return;
      setState(() {
        _secondsElapsed++;
        if (_secondsElapsed >= 300) { // 5 минут
          _finishChallenge();
        }
      });
    });
  }

  Future<void> _finishChallenge() async {
    if (_finished) return;
    _timer?.cancel();
    setState(() => _finished = true);

    final profile = await DatabaseHelper.instance.getProfileById(widget.profileId);

    // Удаляем старые изоляции
    final existing = await DatabaseHelper.instance.getWorkoutExercises(widget.day.id!);
    for (final e in existing) {
      if (e.id != null && e.blockNumber == 1) {
        await DatabaseHelper.instance.deleteWorkoutExercise(e.id!);
      }
    }

    if (profile != null) {
      await _generateIsolations(widget.day.id!, profile, 8);
    }

    final updated = widget.day.copyWith(status: 'completed', completedAt: DateTime.now(), durationMinutes: 5);
    await DatabaseHelper.instance.updateWorkoutDay(updated);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(
          completedDay: updated,
          exercisesCount: 1,
          isWeekComplete: false,
          isCycleComplete: false,
          isChallenge: true,
          userName: profile?.name ?? 'Спортсмен',
          challengeStat: '5 мин',
        ),
      ),
    );
  }

  Future<void> _generateIsolations(int workoutDayId, UserProfile profile, int count) async {
    final allExercises = await DatabaseHelper.instance.getExercises();
    final blockedZones = profile.limitations.map((e) => e.toLowerCase()).toList();
    final focusZones = profile.focusAreas.map((e) => e.toLowerCase()).toList();

    // 👇 ФИКСИРОВАННОЕ РАСПРЕДЕЛЕНИЕ ДЛЯ ПЛАНКИ (8 упражнений)
    final Map<String, int> zoneNeeds = {
      'legs': 2,
      'back': 2,
      'arms': 2,
      'chest': 1,
      'glutes': 1,
    };

    int added = 0;
    int order = 200;
    final Set<int> usedIds = {};
    final Set<String> usedFamilies = {};

    // 1. Идем по зонам с учетом лимитов
    for (final entry in zoneNeeds.entries) {
      final zone = entry.key;
      int needed = entry.value;

      // Если зона в ограничениях или фокусе — пропускаем
      if (blockedZones.contains(zone) || focusZones.contains(zone)) continue;

      final zoneExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (usedIds.contains(e.id)) return false;
        if (isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
        if (usedFamilies.contains(getExerciseFamily(e.name))) return false;
        return e.muscleGroups.contains(zone);
      }).toList()..shuffle();

      for (final ex in zoneExs) {
        if (needed <= 0 || added >= count) break;
        usedIds.add(ex.id!);
        usedFamilies.add(getExerciseFamily(ex.name));

        final we = WorkoutExercise(
          workoutDayId: workoutDayId, itemType: 'exercise', itemId: ex.id!,
          order: order++, sets: 3, reps: '15', blockNumber: 1,
        );
        final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
        for (int s = 1; s <= 3; s++) {
          await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: newId, order: s, completed: false));
        }
        added++;
        needed--;
      }
    }

    // 2. Добивка, если из-за ограничений не хватило
    if (added < count) {
      final availableZones = ['legs', 'back', 'arms', 'chest', 'glutes'].where((z) => !blockedZones.contains(z)).toList();
      final fallbackExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (usedIds.contains(e.id)) return false;
        if (e.muscleGroups.contains('cardio')) return false;
        if (usedFamilies.contains(getExerciseFamily(e.name))) return false;
        return availableZones.any((z) => e.muscleGroups.contains(z));
      }).toList()..shuffle();

      for (final ex in fallbackExs) {
        if (added >= count) break;
        usedIds.add(ex.id!);
        usedFamilies.add(getExerciseFamily(ex.name));

        final we = WorkoutExercise(
          workoutDayId: workoutDayId, itemType: 'exercise', itemId: ex.id!,
          order: order++, sets: 3, reps: '15', blockNumber: 1,
        );
        final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
        for (int s = 1; s <= 3; s++) {
          await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: newId, order: s, completed: false));
        }
        added++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final progress = _secondsElapsed / 300;

    return Scaffold(
      appBar: AppBar(title: const Text('🧘 Планка-марафон 5 мин')),
      body: !_started
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_rounded, size: 80, color: Color(0xFF00B894)),
              const SizedBox(height: 24),
              Text('Планка 5 минут', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Продержись в планке суммарно 5 минут. Можно отдыхать, ставя на паузу.'),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startChallenge,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B894), padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Начать', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: 250, height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 16,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF00B894))
                    ),
                    Text(timeStr, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isPaused = !_isPaused),
                    icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                    label: Text(_isPaused ? 'Продолжить' : 'Пауза'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPaused ? const Color(0xFF00B894) : const Color(0xFFE17055),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}