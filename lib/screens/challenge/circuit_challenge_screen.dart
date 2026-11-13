import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/daily_challenge.dart';
import '../../data/challenge_data.dart';
import '../../services/challenge_service.dart';
import '../../services/database_helper.dart';

/// Одно упражнение «Утреннего взрыва».
class CircuitExercise {
  final String name;
  final String emoji;
  final int durationSeconds;

  const CircuitExercise({
    required this.name,
    required this.emoji,
    required this.durationSeconds,
  });
}

/// Комплекс «Утренний взрыв».
/// Хочешь поменять упражнения — правь только этот список.
const List<CircuitExercise> kCircuitExercises = [
  CircuitExercise(name: 'Приседания', emoji: '🏋️', durationSeconds: 30),
  CircuitExercise(name: 'Отжимания', emoji: '💪', durationSeconds: 30),
  CircuitExercise(name: 'Скручивания', emoji: '🎯', durationSeconds: 30),
  CircuitExercise(name: 'Планка', emoji: '🧘', durationSeconds: 30),
  CircuitExercise(name: 'Берпи', emoji: '🔥', durationSeconds: 30),
];

class CircuitChallengeScreen extends StatefulWidget {
  final int profileId;
  final DailyChallenge challenge;

  const CircuitChallengeScreen({
    super.key,
    required this.profileId,
    required this.challenge,
  });

  @override
  State<CircuitChallengeScreen> createState() => _CircuitChallengeScreenState();
}

class _CircuitChallengeScreenState extends State<CircuitChallengeScreen> {
  late int _completed;
  late bool _isCompleted;
  bool _isRunning = false;

  int get _total => kCircuitExercises.length;

  @override
  void initState() {
    super.initState();
    _completed = widget.challenge.currentProgress.clamp(0, _total);
    _isCompleted = widget.challenge.isCompleted || _completed >= _total;
  }

  Future<void> _startExercise() async {
    if (_isCompleted || _isRunning) return;
    if (_completed >= _total) return;

    final exercise = kCircuitExercises[_completed];

    setState(() => _isRunning = true);

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExerciseTimerDialog(exercise: exercise),
    );

    if (!mounted) return;

    setState(() => _isRunning = false);

    if (success != true) return; // пользователь прервал

    // Отмечаем упражнение выполненным
    final newCompleted = _completed + 1;
    final newIsCompleted = newCompleted >= _total;

    final db = await DatabaseHelper.instance.database;
    await db.update(
      'daily_challenges',
      {
        'currentProgress': newCompleted,
        'isCompleted': newIsCompleted ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [widget.challenge.id],
    );

    setState(() {
      _completed = newCompleted;
      _isCompleted = newIsCompleted;
    });

    // Если всё готово — начисляем энергию
    if (newIsCompleted) {
      final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
      final granted = await ChallengeService.tryAwardReward(
        profileId: widget.profileId,
        challengeId: widget.challenge.id!,
        energyAmount: config.energyReward,
      );
      if (!mounted) return;
      _showCompletionDialog(granted, config.energyReward);
    }
  }

  void _showCompletionDialog(bool granted, int reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🎉 Утренний взрыв выполнен!', textAlign: TextAlign.center),
        content: Text(
          granted
              ? 'Все $_total упражнений пройдены!\n\n+$reward ⚡️ Жизненной Энергии.\n\n🌿 Загляни в свой Сад Феи — там расцвел новый цветок! 🌸'
              : 'Все упражнения пройдены! (Награда уже была получена ранее)',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Забрать награду'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
    final progressPercent = _completed / _total;

    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Прогресс
              Row(
                children: [
                  Text(
                    '$_completed / $_total',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressPercent.clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: Colors.deepPurple.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(
                          _isCompleted ? const Color(0xFF00B894) : Colors.deepPurple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Список упражнений
              Expanded(
                child: ListView.separated(
                  itemCount: _total,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _buildExerciseTile(index);
                  },
                ),
              ),

              // Кнопка / статус
              const SizedBox(height: 12),
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseTile(int index) {
    final ex = kCircuitExercises[index];
    final isDone = index < _completed;
    final isCurrent = index == _completed && !_isCompleted;
    final isLocked = index > _completed;

    Color borderColor;
    Color bgColor;
    Color textColor;
    IconData? trailingIcon;

    if (isDone) {
      borderColor = const Color(0xFF00B894);
      bgColor = const Color(0xFF00B894).withOpacity(0.08);
      textColor = const Color(0xFF00B894);
      trailingIcon = Icons.check_circle_rounded;
    } else if (isCurrent) {
      borderColor = Colors.deepPurple;
      bgColor = Colors.deepPurple.withOpacity(0.08);
      textColor = Colors.deepPurple;
      trailingIcon = _isRunning ? null : Icons.play_circle_fill_rounded;
    } else if (isLocked) {
      borderColor = Colors.grey.shade300;
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade500;
      trailingIcon = Icons.lock_rounded;
    } else {
      borderColor = Colors.grey.shade300;
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade500;
      trailingIcon = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(ex.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ex.durationSeconds} сек',
                  style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: textColor, size: 24),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF00B894).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00B894)),
            SizedBox(width: 8),
            Text(
              'Выполнено',
              style: TextStyle(
                color: Color(0xFF00B894),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    final nextEx = kCircuitExercises[_completed];

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isRunning ? null : _startExercise,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(
          _isRunning ? 'Выполняется...' : 'Начать: ${nextEx.name}',
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Диалог с таймером одного упражнения (обратный отсчёт).
class _ExerciseTimerDialog extends StatefulWidget {
  final CircuitExercise exercise;

  const _ExerciseTimerDialog({required this.exercise});

  @override
  State<_ExerciseTimerDialog> createState() => _ExerciseTimerDialogState();
}

class _ExerciseTimerDialogState extends State<_ExerciseTimerDialog> {
  Timer? _ticker;
  late int _remaining;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.exercise.durationSeconds;
    WakelockPlus.enable();

    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() {
          _remaining = 0;
          _done = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _cancel() {
    Navigator.pop(context, false);
  }

  void _finish() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.exercise.durationSeconds;
    final progress = 1 - (_remaining / total).clamp(0.0, 1.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.exercise.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(
              widget.exercise.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: Colors.deepPurple.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(
                        _done ? const Color(0xFF00B894) : Colors.deepPurple,
                      ),
                    ),
                  ),
                  Text(
                    _done ? '✓' : '$_remaining',
                    style: TextStyle(
                      fontSize: _done ? 60 : 56,
                      fontWeight: FontWeight.w800,
                      color: _done ? const Color(0xFF00B894) : Colors.deepPurple,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!_done)
              TextButton(
                onPressed: _cancel,
                child: const Text(
                  'Прервать',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B894),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Готово, дальше!'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}