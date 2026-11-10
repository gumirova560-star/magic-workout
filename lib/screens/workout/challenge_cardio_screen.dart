import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/workout_day.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../data/base_exercises.dart';
import 'workout_complete_screen.dart';

class ChallengeCardioScreen extends StatefulWidget {
  final WorkoutDay day;
  final int profileId;
  final List<WorkoutExercise> items;
  final Map<int, Exercise> exerciseMap;

  const ChallengeCardioScreen({super.key, required this.day, required this.profileId, required this.items, required this.exerciseMap});

  @override
  State<ChallengeCardioScreen> createState() => _ChallengeCardioScreenState();
}

class _ChallengeCardioScreenState extends State<ChallengeCardioScreen> {
  bool _started = false;
  bool _finished = false;
  bool _isPaused = false;

  int _currentExIndex = 0;
  int _currentRound = 1;
  int _totalRounds = 2;

  int _secondsLeft = 40;
  bool _isResting = false;
  Timer? _timer;

  List<Exercise> _cardioExercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCardio();
  }

  Future<void> _loadCardio() async {
    final all = await DatabaseHelper.instance.getExercises();
    final targetNames = ['Берпи', 'Джампинг Джек', 'Скакалка', 'Канат'];
    List<Exercise> found = [];

    for (final name in targetNames) {
      final match = all.where((e) => e.name.toLowerCase().contains(name.toLowerCase())).toList();
      if (match.isNotEmpty && !found.any((f) => f.id == match.first.id)) {
        found.add(match.first);
      }
    }

    if (found.length < 4) {
      final extraCardio = all.where((e) =>
      e.muscleGroups.contains('cardio') &&
          !found.any((f) => f.id == e.id)
      ).toList();
      found.addAll(extraCardio);
    }

    if (found.isEmpty) found = all.take(4).toList();
    if (found.length > 4) found = found.take(4).toList();

    if (mounted) {
      setState(() {
        _cardioExercises = found;
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
    setState(() {
      _started = true;
      _currentExIndex = 0;
      _currentRound = 1;
      _secondsLeft = 40;
      _isResting = false;
    });
    _runTimer();
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _finished || _isPaused || _cardioExercises.isEmpty) return;

      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          if (_isResting) {
            _isResting = false;
            _secondsLeft = 40;
            _currentExIndex++;

            if (_currentExIndex >= _cardioExercises.length) {
              _currentExIndex = 0;
              _currentRound++;

              if (_currentRound > _totalRounds) {
                _finishChallenge();
              }
            }
          } else {
            _isResting = true;
            _secondsLeft = 20;
          }
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
      await _generateIsolations(widget.day.id!, profile, 6, {});
    }

    final updated = widget.day.copyWith(status: 'completed', completedAt: DateTime.now(), durationMinutes: 8);
    await DatabaseHelper.instance.updateWorkoutDay(updated);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(
          completedDay: updated,
          exercisesCount: 8,
          isWeekComplete: false,
          isCycleComplete: false,
          isChallenge: true,
          userName: profile?.name ?? 'Спортсмен',
          challengeStat: 'HIIT',
        ),
      ),
    );
  }

  // 👇 УМНАЯ ГЕНЕРАЦИЯ ИЗОЛЯЦИЙ (КАК В 300)
  Future<void> _generateIsolations(int workoutDayId, UserProfile profile, int count, Set<int> selectedBaseIds) async {
    final allExercises = await DatabaseHelper.instance.getExercises();
    final allZones = ['chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'];
    final blockedZones = profile.limitations.map((e) => e.toLowerCase()).toList();
    final focusZones = profile.focusAreas.map((e) => e.toLowerCase()).toList();

    int added = 0;
    int order = 200;
    final Set<int> usedIds = {...selectedBaseIds};
    final Set<String> usedFamilies = {};

    bool isSafe(Exercise e) {
      final primaryZone = getExerciseZone(e).toLowerCase();
      if (blockedZones.contains(primaryZone)) return false;
      for (final c in e.contraindications) {
        for (final b in blockedZones) {
          if (c.toLowerCase().contains(b) || b.contains(c.toLowerCase())) return false;
        }
      }
      return true;
    }

    Future<void> tryAdd(Exercise ex) async {
      if (added >= count) return;
      if (ex.id == null) return;
      if (usedIds.contains(ex.id)) return;
      if (ex.muscleGroups.contains('cardio')) return;
      if (usedFamilies.contains(getExerciseFamily(ex.name))) return;
      if (!isSafe(ex)) return;

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

    final forgottenZones = allZones.where((z) => !blockedZones.contains(z) && !focusZones.contains(z)).toList();

    // 1. Изоляции из забытых
    for (final zone in forgottenZones) {
      if (added >= count) break;
      final zoneExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
        return e.muscleGroups.contains(zone);
      }).toList()..shuffle();
      for (final ex in zoneExs) { if (added >= count) break; await tryAdd(ex); }
    }

    // 2. Базы из забытых
    if (added < count) {
      for (final zone in forgottenZones) {
        if (added >= count) break;
        final zoneExs = allExercises.where((e) {
          if (e.id == null) return false;
          if (!isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
          return e.muscleGroups.contains(zone);
        }).toList()..shuffle();
        for (final ex in zoneExs) { if (added >= count) break; await tryAdd(ex); }
      }
    }

    // 3. Изоляции из фокусных
    if (added < count) {
      for (final zone in focusZones) {
        if (added >= count) break;
        if (blockedZones.contains(zone)) continue;
        final zoneExs = allExercises.where((e) {
          if (e.id == null) return false;
          if (isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
          return e.muscleGroups.contains(zone);
        }).toList()..shuffle();
        for (final ex in zoneExs) { if (added >= count) break; await tryAdd(ex); }
      }
    }

    // 4. Базы из фокусных
    if (added < count) {
      for (final zone in focusZones) {
        if (added >= count) break;
        if (blockedZones.contains(zone)) continue;
        final zoneExs = allExercises.where((e) {
          if (e.id == null) return false;
          if (!isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
          return e.muscleGroups.contains(zone);
        }).toList()..shuffle();
        for (final ex in zoneExs) { if (added >= count) break; await tryAdd(ex); }
      }
    }

    // 5. Любые безопасные
    if (added < count) {
      final fallbackExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (e.muscleGroups.contains('cardio')) return false;
        return isSafe(e);
      }).toList()..shuffle();
      for (final ex in fallbackExs) { if (added >= count) break; await tryAdd(ex); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSeconds = _isResting ? 20 : 40;
    final progress = _secondsLeft / totalSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('🔥 HIIT Кардио-взрыв')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_started
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 80, color: Color(0xFF6C5CE7)),
              const SizedBox(height: 24),
              Text('HIIT', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('$_totalRounds раунда по 40 сек работы и 20 сек отдыха.', textAlign: TextAlign.center),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: _cardioExercises.map((ex) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Color(0xFF6C5CE7)),
                        const SizedBox(width: 8),
                        Text(ex.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startChallenge,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), padding: const EdgeInsets.symmetric(vertical: 16)),
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
                width: 300, // 👈 УВЕЛИЧИЛИ КРУГ
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 14, // 👈 УМЕНЬШИЛИ ТОЛЩИНУ
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation(_isResting ? const Color(0xFF00B894) : const Color(0xFFE17055)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_isResting ? 'ОТДЫХ' : 'РАБОТА', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isResting ? const Color(0xFF00B894) : const Color(0xFFE17055))),
                        Text('$_secondsLeft', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)), // 👈 УМЕНЬШИЛИ ШРИФТ
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Упражнение:', style: theme.textTheme.titleLarge),
                Text(_cardioExercises.isEmpty ? 'Нет упражнений' : _cardioExercises[_currentExIndex].name, style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Раунд $_currentRound из $_totalRounds', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Упражнение ${_currentExIndex + 1} из ${_cardioExercises.length}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _togglePause,
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