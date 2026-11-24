import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/workout_day.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../data/base_exercises.dart';                    // 👈 ДОБАВЛЕНО
import '../../services/workout_generator.dart' hide DatabaseHelper; // 👈 ДОБАВЛЕНО
import 'challenge_setup_screen.dart';
import 'challenge_amrap_screen.dart';
import 'challenge_plank_screen.dart';
import 'challenge_cardio_screen.dart';
import 'workout_detail_screen.dart';

enum ChallengeType { reps300, amrap, plank, cardio }

class ChallengeWheelScreen extends StatefulWidget {
  final WorkoutDay day;
  final int profileId;
  final List<WorkoutExercise> items;
  final Map<int, Exercise> exerciseMap;

  const ChallengeWheelScreen({
    super.key,
    required this.day,
    required this.profileId,
    required this.items,
    required this.exerciseMap,
  });

  @override
  State<ChallengeWheelScreen> createState() => _ChallengeWheelScreenState();
}

class _ChallengeWheelScreenState extends State<ChallengeWheelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isRolling = false;
  ChallengeType? _result;

  final _types = ChallengeType.values;

  double _currentAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_isRolling) return;

    final random = Random();
    final resultIndex = random.nextInt(_types.length);
    final resultType = _types[resultIndex];

    final sweepAngle = 2 * pi / _types.length;
    final spins = 5 + random.nextInt(4);
    final targetAngle = (spins * 2 * pi) - (resultIndex * sweepAngle + sweepAngle / 2);

    setState(() {
      _isRolling = true;
      _result = null;
    });

    final tween = Tween<double>(begin: 0, end: targetAngle);
    final animation = tween.animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    void listener() {
      setState(() {
        _currentAngle = animation.value;
      });
    }
    animation.addListener(listener);

    _controller.forward(from: 0).then((_) {
      animation.removeListener(listener);
      if (!mounted) return;
      setState(() {
        _isRolling = false;
        _result = resultType;
        _currentAngle = targetAngle % (2 * pi);
      });
    });
  }

  String get _title {
    switch (_result) {
      case ChallengeType.reps300: return 'Марафон: 300 повторений';
      case ChallengeType.amrap: return 'Круг на время (10 минут)';
      case ChallengeType.plank: return 'Планка-марафон (5 минут)';
      case ChallengeType.cardio: return 'Кардио-взрыв (HIIT)';
      case null: return '';
    }
  }

  String get _subtitle {
    switch (_result) {
      case ChallengeType.reps300: return '3 упражнения по 100 раз. Можно подходами.';
      case ChallengeType.amrap: return '10 минут. Сделай как можно больше кругов.';
      case ChallengeType.plank: return 'Суммарное время в планке и статике.';
      case ChallengeType.cardio: return 'Интервалы высокой интенсивности.';
      case null: return '';
    }
  }

  Color get _color {
    switch (_result) {
      case ChallengeType.reps300: return const Color(0xFFFFB800);
      case ChallengeType.amrap: return const Color(0xFFE17055);
      case ChallengeType.plank: return const Color(0xFF00B894);
      case ChallengeType.cardio: return const Color(0xFF6C5CE7);
      case null: return const Color(0xFF6C5CE7);
    }
  }

  Future<void> _start() async {
    if (_result == null) return;

    if (_result == ChallengeType.reps300) {
      final profile = await DatabaseHelper.instance.getProfileById(widget.profileId);
      final allEx = await DatabaseHelper.instance.getExercises();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChallengeSetupScreen(
            day: widget.day,
            profile: profile,
            allExercises: allEx,
          ),
        ),
      );
      return;
    }

    Widget screen;
    switch (_result!) {
      case ChallengeType.amrap:
        screen = ChallengeAmrapScreen(day: widget.day, profileId: widget.profileId, items: widget.items, exerciseMap: widget.exerciseMap);
        break;
      case ChallengeType.plank:
        screen = ChallengePlankScreen(day: widget.day, profileId: widget.profileId, items: widget.items, exerciseMap: widget.exerciseMap);
        break;
      case ChallengeType.cardio:
        screen = ChallengeCardioScreen(day: widget.day, profileId: widget.profileId, items: widget.items, exerciseMap: widget.exerciseMap);
        break;
      case ChallengeType.reps300:
        return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ══════════════════════════════════════════════════════════════════
  // 👇 ИЗМЕНЕНО: теперь при отказе генерируем «забытые зоны»
  // ══════════════════════════════════════════════════════════════════
  Future<void> _decline() async {
    final updated = widget.day.copyWith(type: 'strength');
    await DatabaseHelper.instance.updateWorkoutDay(updated);

    // 👇 Загружаем профиль и генерируем упражнения, чтобы день не был пустым
    final profile = await DatabaseHelper.instance.getProfileById(widget.profileId);
    if (profile != null) {
      await _generateForgottenZonesWorkout(updated, profile);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          workoutDay: updated,
          profileId: widget.profileId,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 👇 ДУБЛИКАТ МЕТОДА ИЗ workout_screen.dart
  //    (генерирует 3 базы + до 6 изоляций на «забытые зоны»)
  // ══════════════════════════════════════════════════════════════════
  Future<void> _generateForgottenZonesWorkout(WorkoutDay day, UserProfile profile) async {
    final existing = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
    for (final e in existing) {
      if (e.id != null) await DatabaseHelper.instance.deleteWorkoutExercise(e.id!);
    }

    final allExercises = await DatabaseHelper.instance.getExercises();
    // 👇 v21: ограничения → зоны через карту из base_exercises.dart.
    // Раньше 'knees'/'neck'/'shoulders' с кодами зон не совпадали
    // и фильтр зон не срабатывал никогда.
    final blockedZones = zonesBlockedByLimitations(profile.limitations);

    bool isExerciseAllowed(Exercise e) {
      // 👇 v21: точное пересечение кодов вместо substring-матчинга
      if (exerciseBlockedByLimitations(e, profile.limitations)) return false;
      if (!WorkoutGenerator.matchesEquipment(e, profile.equipment)) return false;
      if (profile.level == 'beginner') {
        final lowerName = e.name.toLowerCase();
        if (lowerName.contains('штанг') || lowerName.contains('на одной ноге') || lowerName.contains('в висе')) return false;
        if (e.difficulty == 'advanced') return false;
      }
      return true;
    }

    final bases = allExercises.where((e) {
      if (!isBaseExercise(e)) return false;
      final zone = getExerciseZone(e);
      if (blockedZones.contains(zone)) return false;
      if (!isExerciseAllowed(e)) return false;
      return true;
    }).toList()..shuffle();

    final selectedBases = bases.take(3).toList();

    int order = 1;
    for (final ex in selectedBases) {
      final we = WorkoutExercise(
        workoutDayId: day.id!,
        itemType: 'exercise',
        itemId: ex.id!,
        order: order++,
        sets: 3,
        reps: '10-12',
      );
      final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
      for (int s = 1; s <= 3; s++) {
        await DatabaseHelper.instance.addWorkoutSet(
          WorkoutSet(workoutExerciseId: newId, order: s, completed: false),
        );
      }
    }

    final allZones = ['chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'];
    final focusZones = profile.focusAreas.map((e) => e.toLowerCase()).toList();

    final forgottenZones = allZones.where((z) =>
    !blockedZones.contains(z) && !focusZones.contains(z)
    ).toList();

    int added = 0;
    final Set<int> usedIds = selectedBases.map((e) => e.id!).toSet();

    for (final zone in forgottenZones) {
      if (added >= 6) break;
      final zoneExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (usedIds.contains(e.id)) return false;
        if (isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
        if (!isExerciseAllowed(e)) return false;
        return e.muscleGroups.contains(zone);
      }).toList()..shuffle();

      for (final ex in zoneExs.take(2)) {
        if (added >= 6) break;
        usedIds.add(ex.id!);

        final we = WorkoutExercise(
          workoutDayId: day.id!,
          itemType: 'exercise',
          itemId: ex.id!,
          order: order++,
          sets: 3,
          reps: '15',
        );
        final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
        for (int s = 1; s <= 3; s++) {
          await DatabaseHelper.instance.addWorkoutSet(
            WorkoutSet(workoutExerciseId: newId, order: s, completed: false),
          );
        }
        added++;
      }
    }
  }
  // ══════════════════════════════════════════════════════════════════
  // 👆 КОНЕЦ ДУБЛИКАТА
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('День Челленджа')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 300,
                width: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 30,
                      child: Transform.rotate(
                        angle: _currentAngle,
                        child: const _WheelPainter(
                          size: 240,
                          colors: [
                            Color(0xFFFFB800),
                            Color(0xFFE17055),
                            Color(0xFF00B894),
                            Color(0xFF6C5CE7),
                          ],
                          labels: ['300\nраз', 'Круг\nна время', 'Планка\n5 мин', 'HIIT\nвзрыв'],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 60,
                        color: theme.colorScheme.primary,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              if (_result != null) ...[
                Text(_title, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(_subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)), textAlign: TextAlign.center),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Погнали!'),
                    style: ElevatedButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _spinWheel,
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Крутить еще раз'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _decline,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отказаться и сделать обычную тренировку'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRolling ? null : _spinWheel,
                    icon: const Icon(Icons.casino_rounded),
                    label: Text(_isRolling ? 'Крутим...' : 'Крутить колесо'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _decline,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отказаться и сделать обычную тренировку'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Колесо
// ─────────────────────────────────────────────────────────────
class _WheelPainter extends StatelessWidget {
  final double size;
  final List<Color> colors;
  final List<String> labels;

  const _WheelPainter({
    required this.size,
    required this.colors,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _WheelCustomPainter(colors: colors, labels: labels),
      ),
    );
  }
}

class _WheelCustomPainter extends CustomPainter {
  final List<Color> colors;
  final List<String> labels;

  _WheelCustomPainter({required this.colors, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = 2 * pi / colors.length;

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()..color = colors[i];
      final startAngle = -pi / 2 + i * sweepAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }

    for (int i = 0; i < colors.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1.1,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final midAngle = -pi / 2 + i * sweepAngle + sweepAngle / 2;
      final textRadius = radius * 0.6;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(midAngle + pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textRadius - textPainter.height / 2),
      );
      canvas.restore();
    }

    final innerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, innerBorderPaint);

    final outerBorderRect = Rect.fromCircle(center: center, radius: radius - 6);
    final outerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
      ).createShader(outerBorderRect);

    canvas.drawCircle(center, radius - 6, outerBorderPaint);

    final glarePath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius - 12),
        -pi / 2 - 0.5,
        1.0,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: (radius - 12) * 0.5),
        -pi / 2 + 0.5,
        -1.0,
        false,
      );

    final glarePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(glarePath, glarePaint);

    final centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.15, centerPaint);

    final centerBorderPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * 0.15, centerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
// ⏸ КОНЕЦ ФАЙЛА challenge_dice_screen.dart
