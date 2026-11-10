import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/workout_day.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import 'workout_complete_screen.dart';

class Challenge300Screen extends StatefulWidget {
  final WorkoutDay day;
  final int profileId;
  final List<WorkoutExercise> items;
  final Map<int, Exercise> exerciseMap;

  const Challenge300Screen({
    super.key,
    required this.day,
    required this.profileId,
    required this.items,
    required this.exerciseMap,
  });

  @override
  State<Challenge300Screen> createState() => _Challenge300ScreenState();
}

class _Challenge300ScreenState extends State<Challenge300Screen> {
  final Map<int, int> _remainingReps = {};
  final Map<int, int> _targets = {};

  bool _started = false;
  bool _finished = false;
  int _secondsElapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    for (final item in widget.items.take(3)) {
      if (item.id != null) {
        final match = RegExp(r'(\d+)').firstMatch(item.reps);
        final target = int.tryParse(match?.group(1) ?? '') ?? 100;

        _targets[item.id!] = target;
        _remainingReps[item.id!] = target;
      }
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
      setState(() => _secondsElapsed++);
    });
  }

  void _updateProgress(int itemId, int amount) {
    if (!_started || _finished) return;

    setState(() {
      final current = _remainingReps[itemId] ?? _targets[itemId]!;
      final newValue = current - amount;
      _remainingReps[itemId] = newValue <= 0 ? 0 : newValue;
    });

    _checkCompletion();
  }

  void _checkCompletion() {
    final allDone = _remainingReps.values.every((reps) => reps == 0);
    if (allDone && !_finished) {
      setState(() => _finished = true);
      _completeChallenge();
    }
  }

  Future<void> _completeChallenge() async {
    _timer?.cancel();

    final profile = await DatabaseHelper.instance.getProfileById(widget.profileId);

    // 👇 МЫ БОЛЬШЕ НЕ УДАЛЯЕМ И НЕ ГЕНЕРИРУЕМ ИЗОЛЯЦИИ.
    // Они уже были сгенерированы в ChallengeSetupScreen и ждут своего часа.

    final updated = widget.day.copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
      durationMinutes: _secondsElapsed > 0 ? (_secondsElapsed / 60).ceil() : 1,
    );
    await DatabaseHelper.instance.updateWorkoutDay(updated);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(
          completedDay: updated,
          exercisesCount: 3,
          isWeekComplete: false,
          isCycleComplete: false,
          isChallenge: true,
          userName: profile?.name ?? 'Спортсмен',
          challengeStat: '300 раз',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔥 Челлендж 300'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !_started
          ? _buildStartScreen(context, theme)
          : _buildChallengeBody(context, theme),
    );
  }

  Widget _buildStartScreen(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_fire_department_rounded, size: 80, color: Color(0xFFFFB800)),
            const SizedBox(height: 24),
            Text('Челлендж 300', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              'Тебе нужно выполнить ${widget.items.length} упражнения по 100 раз. Никаких подходов и весов — просто сделай это!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startChallenge,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Начать челлендж'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeBody(BuildContext context, ThemeData theme) {
    final minutes = (_secondsElapsed / 60).floor();
    final seconds = _secondsElapsed % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB800).withOpacity(0.1),
            border: const Border(bottom: BorderSide(color: Color(0xFFFFB800), width: 2)),
          ),
          child: Center(
            child: Text(
              'Время: $timeStr',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFFFB800)),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...widget.items.take(3).map((item) {
                final ex = widget.exerciseMap[item.replacedByItemId ?? item.itemId];
                if (ex == null || item.id == null) return const SizedBox.shrink();

                final target = _targets[item.id!] ?? 100;
                final remaining = _remainingReps[item.id!] ?? target;
                final done = target - remaining;
                final progress = done / target;
                final isTimed = item.reps.contains('сек');
                final unit = isTimed ? 'сек' : 'раз';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          ex.name,
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 140, height: 140,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 12,
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation(
                                    remaining == 0 ? const Color(0xFF00B894) : const Color(0xFFFFB800),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    remaining == 0 ? '✓' : '$remaining',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      color: remaining == 0 ? const Color(0xFF00B894) : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  if (remaining > 0)
                                    Text(
                                      'осталось $unit',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (remaining > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPlusButton('+10', 10, item.id!, theme),
                              const SizedBox(width: 12),
                              _buildPlusButton('+20', 20, item.id!, theme),
                              const SizedBox(width: 12),
                              if (remaining > 20) _buildPlusButton('+25', 25, item.id!, theme),
                              if (remaining <= 20 && remaining > 0)
                                _buildPlusButton('+$remaining', remaining, item.id!, theme),
                            ],
                          )
                        else
                          Text('Выполнено!', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlusButton(String label, int amount, int itemId, ThemeData theme) {
    return ElevatedButton(
      onPressed: () => _updateProgress(itemId, amount),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}