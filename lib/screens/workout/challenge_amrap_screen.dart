import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/workout_day.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../data/base_exercises.dart';
import 'workout_complete_screen.dart';

class ChallengeAmrapScreen extends StatefulWidget {
  final WorkoutDay day;
  final int profileId;
  final List<WorkoutExercise> items;
  final Map<int, Exercise> exerciseMap;

  const ChallengeAmrapScreen({
    super.key,
    required this.day,
    required this.profileId,
    required this.items,
    required this.exerciseMap,
  });

  @override
  State<ChallengeAmrapScreen> createState() => _ChallengeAmrapScreenState();
}

class _ChallengeAmrapScreenState extends State<ChallengeAmrapScreen> {
  bool _started = false;
  bool _finished = false;
  int _secondsLeft = 600;
  int _rounds = 0;
  Timer? _timer;

  List<Exercise> _amrapExercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final all = await DatabaseHelper.instance.getExercises();
    final targetNames = ['Приседания', 'Отжимания', 'Скручивания'];
    List<Exercise> found = [];

    for (final name in targetNames) {
      final match = all.where((e) => e.name.toLowerCase().contains(name.toLowerCase())).toList();
      if (match.isNotEmpty) found.add(match.first);
    }

    if (found.length < 3) {
      final bases = all.where((e) => isBaseExercise(e)).take(3).toList();
      found = bases;
    }

    if (mounted) {
      setState(() {
        _amrapExercises = found;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startChallenge() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _finished) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _finishChallenge();
        }
      });
    });
  }

  void _addRound() {
    if (!_started || _finished) return;
    setState(() => _rounds++);
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
      await _generateIsolations(widget.day.id!, profile, 6);
    }

    final updated = widget.day.copyWith(status: 'completed', completedAt: DateTime.now(), durationMinutes: 10);
    await DatabaseHelper.instance.updateWorkoutDay(updated);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(
          completedDay: updated,
          exercisesCount: _amrapExercises.length * _rounds,
          isWeekComplete: false,
          isCycleComplete: false,
          isChallenge: true,
          userName: profile?.name ?? 'Спортсмен',
          challengeStat: '10 мин',
        ),
      ),
    );
  }

  Future<void> _generateIsolations(int workoutDayId, UserProfile profile, int count) async {
    final allExercises = await DatabaseHelper.instance.getExercises();
    final allZones = ['chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'];
    final blockedZones = profile.limitations.map((e) => e.toLowerCase()).toList();
    final focusZones = profile.focusAreas.map((e) => e.toLowerCase()).toList();

    final forgottenZones = allZones.where((z) =>
    !blockedZones.contains(z) && !focusZones.contains(z)
    ).toList();

    int added = 0;
    int order = 200;
    final Set<int> usedIds = {};
    final Set<String> usedFamilies = {};

    // 1. Изоляции
    for (final zone in forgottenZones) {
      if (added >= count) break;
      final zoneExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (usedIds.contains(e.id)) return false;
        if (isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
        if (usedFamilies.contains(getExerciseFamily(e.name))) return false;
        return e.muscleGroups.contains(zone);
      }).toList()..shuffle();

      for (final ex in zoneExs.take(2)) {
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

    // 2. Базы на забытые зоны
    if (added < count) {
      for (final zone in forgottenZones) {
        if (added >= count) break;
        final zoneExs = allExercises.where((e) {
          if (e.id == null) return false;
          if (usedIds.contains(e.id)) return false;
          if (!isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
          if (usedFamilies.contains(getExerciseFamily(e.name))) return false;
          return e.muscleGroups.contains(zone);
        }).toList()..shuffle();

        for (final ex in zoneExs.take(2)) {
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

    // 3. Добивка любыми доступными
    if (added < count) {
      final availableZones = allZones.where((z) => !blockedZones.contains(z)).toList();
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
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('⏱ AMRAP 10 минут')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_started
          ? _buildStartScreen(theme)
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: const Color(0xFFE17055).withOpacity(0.1),
            child: Column(
              children: [
                Text(timeStr, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFFE17055))),
                Text('Кругов выполнено: $_rounds', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._amrapExercises.map((ex) => Card(
                  child: ListTile(
                    title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('10 повторений'),
                    trailing: const Icon(Icons.loop_rounded, color: Color(0xFFE17055)),
                  ),
                )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B894),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Круг выполнен!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_rounded, size: 80, color: Color(0xFFE17055)),
            const SizedBox(height: 24),
            Text('AMRAP 10 минут', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Сделай как можно больше кругов по 10 повторений каждого упражнения.', textAlign: TextAlign.center),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startChallenge,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE17055), padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Начать AMRAP', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}