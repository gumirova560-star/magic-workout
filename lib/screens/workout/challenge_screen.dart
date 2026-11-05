import 'package:flutter/material.dart';
import '../../models/workout_day.dart';
import '../../models/exercise.dart';
import '../../services/database_helper.dart';
import 'workout_complete_screen.dart'; // 👈 Импортируем экран итогов

class ChallengeScreen extends StatefulWidget {
  final WorkoutDay day;
  final int profileId;
  final List<WorkoutExercise> items;
  final Map<int, Exercise> exerciseMap;

  const ChallengeScreen({
    super.key,
    required this.day,
    required this.profileId,
    required this.items,
    required this.exerciseMap,
  });

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
// Храним прогресс: ключ — id упражнения, значение — сколько осталось
final Map<int, int> _remainingReps = {};

// Храним цели: ключ — id упражнения, значение — сколько всего надо сделать
final Map<int, int> _targets = {};

bool _started = false;
bool _finished = false;
int _secondsElapsed = 0;

@override
void initState() {
super.initState();
// Инициализируем счетчики из базы (например, 100 повторений или 100 секунд)
for (final item in widget.items) {
if (item.id != null) {
// Парсим число из строки (например, из "100" или "100 сек")
final match = RegExp(r'(\d+)').firstMatch(item.reps);
final target = int.tryParse(match?.group(1) ?? '') ?? 100;

_targets[item.id!] = target;
_remainingReps[item.id!] = target;
}
}
}

void _startChallenge() {
setState(() => _started = true);
Future.doWhile(() async {
await Future.delayed(const Duration(seconds: 1));
if (!mounted || _finished) return false;
setState(() => _secondsElapsed++);
return true;
});
}

void _updateProgress(int itemId, int amount) {
if (!_started || _finished) return;

setState(() {
final current = _remainingReps[itemId] ?? _targets[itemId]!;
final newValue = current - amount;

if (newValue <= 0) {
_remainingReps[itemId] = 0;
} else {
_remainingReps[itemId] = newValue;
}
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
final updated = widget.day.copyWith(
status: 'completed',
completedAt: DateTime.now(),
durationMinutes: _secondsElapsed > 0 ? (_secondsElapsed / 60).ceil() : 1,
);
await DatabaseHelper.instance.updateWorkoutDay(updated);

if (!mounted) return;

// 👇 Открываем экран итогов, как обычная тренировка!
Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) => WorkoutCompleteScreen(
completedDay: updated,
exercisesCount: widget.items.length,
isWeekComplete: false, // Можно добавить логику проверки недели
isCycleComplete: false,
userName: 'Спортсмен', // Или передать имя из профиля
),
),
);
}

// ═══ ОТКАЗ ОТ ЧЕЛЛЕНДЖА ═══
Future<void> _declineChallenge() async {
final confirm = await showDialog<bool>(
context: context,
builder: (ctx) => AlertDialog(
title: const Text('Отказаться от челленджа?'),
content: const Text('Этот день превратится в обычную силовую тренировку.'),
actions: [
TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет, я справлюсь!')),
TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да, к обычной тренировке')),
],
),
);

if (confirm == true) {
// Меняем тип дня на обычный
final updated = widget.day.copyWith(type: 'strength');
await DatabaseHelper.instance.updateWorkoutDay(updated);

if (!mounted) return;
Navigator.pop(context); // Возвращаемся на экран плана
}
}
// ═══ КОНЕЦ ЧАСТИ 1 из 2 ═══
// Скажи «часть 2», чтобы получить экран с кольцами и кнопками (с учетом секунд).
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
              'Тебе нужно выполнить 3 упражнения. Никаких подходов и весов — просто сделай это!',
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
            const SizedBox(height: 12),
            TextButton(
              onPressed: _declineChallenge,
              child: const Text('Отказаться и сделать обычную тренировку'),
            )
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
        // 👇 Таймер сверху
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
              // 👇 Список упражнений
              ...widget.items.map((item) {
                final ex = widget.exerciseMap[item.replacedByItemId ?? item.itemId];
                if (ex == null || item.id == null) return const SizedBox.shrink();

                final target = _targets[item.id!] ?? 100;
                final remaining = _remainingReps[item.id!] ?? target;
                final done = target - remaining;
                final progress = done / target;

                // 👇 Умное определение: планка — в секундах, остальное — в разах
                final isTimed = item.reps.contains('сек') || ex.name.toLowerCase().contains('планка');
                final unit = isTimed ? 'сек' : 'раз';
                final displayRemaining = isTimed ? '$remaining' : '$remaining';

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

                        // Кольцо прогресса и счетчик
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
                                    remaining == 0 ? '✓' : displayRemaining,
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

                        // Кнопки
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

              // Кнопка «Сдаться»
              if (!_finished)
                OutlinedButton(
                  onPressed: _declineChallenge,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: Colors.grey),
                    foregroundColor: Colors.grey,
                  ),
                  child: const Text('Завершить челлендж досрочно'),
                ),
              const SizedBox(height: 32),
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
// ═══ ФАЙЛ challenge_screen.dart ЗАВЕРШЁН ═══