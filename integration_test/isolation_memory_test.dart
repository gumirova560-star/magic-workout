// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:workout_tracker/services/database_helper.dart';
import 'package:workout_tracker/services/workout_generator.dart';
import 'package:workout_tracker/models/user_profile.dart';
import 'package:workout_tracker/models/workout_day.dart';

// ──────────────────────────────────────────────────────────
// ХЕЛПЕРЫ (скопированы из progression_4_months_test.dart)
// ──────────────────────────────────────────────────────────
Future<void> cleanDB() async {
  final db = await DatabaseHelper.instance.database;
  for (final t in [
    'workout_sets', 'workout_exercises', 'workout_days',
    'daily_challenges', 'garden_flowers', 'energy_transactions',
    'user_profiles', 'workout_templates', 'template_items', 'replacement_logs',
  ]) {
    await db.delete(t);
  }
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys()
      .where((k) => k.startsWith('allow_base_change_'))
      .toList();
  for (final k in keys) {
    await prefs.remove(k);
  }
}

Future<UserProfile> createGymProfile() async {
  final p = UserProfile(
    name: 'Test Isolation Memory',
    gender: 'male', age: 30, height: 180, weight: 80,
    level: 'intermediate', goal: 'gain_mass', equipment: 'gym',
    daysPerWeek: 3, sessionMinutes: 45,
    focusAreas: ['chest', 'back', 'legs'], limitations: [],
    createdAt: DateTime.now(),
  );
  p.id = await DatabaseHelper.instance.addProfile(p);
  return p;
}

// ──────────────────────────────────────────────────────────
// ТЕСТ: изоляции запоминают веса и повторы
// ──────────────────────────────────────────────────────────
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Изоляции: система запоминает веса и повторы', (tester) async {
    await cleanDB();
    final p = await createGymProfile();

    // ШАГ 1: Ручное создание «прошлой» недели (ДО генерации)
    final now = DateTime.now();
    final dateWeekAgo = now.subtract(const Duration(days: 7));

    final day1 = WorkoutDay(
      profileId: p.id!,
      name: 'Неделя 1: День 1 (Прошлая)',
      type: 'strength',
      weekNumber: 1,
      cycleNumber: 1, // критично: maxCycle станет 1
      status: 'completed',
      date: dateWeekAgo,
      completedAt: now,
    );
    final day1Id = await DatabaseHelper.instance.createWorkoutDay(day1);

    // 60 = Сведение рук в тренажёре (изоляция),
    // 56 и 58 = базовые, чтобы день выглядел реалистично
    final exerciseIds = [56, 60, 58];

    for (int i = 0; i < exerciseIds.length; i++) {
      final exId = exerciseIds[i];
      final weId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
        workoutDayId: day1Id,
        itemType: 'exercise',
        itemId: exId,
        order: 100 + i,
        sets: 3,
        reps: '10',
        isWarmup: false,
        isCoolDown: false,
      ));

      // Заведомо высокие показатели для изоляции
      for (int s = 0; s < 3; s++) {
        await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
          workoutExerciseId: weId,
          order: s + 1,
          weight: 50.0,
          reps: 15,
          completed: true,
        ));
      }
    }

    print('✅ Прошлая неделя создана: itemId=$exerciseIds, вес 50 кг, 15 повторов');

    // ШАГ 2: Генерация нового плана
    await WorkoutGenerator.generateMonthPlan(p, smart: true);

    final allDays =
    await DatabaseHelper.instance.getWorkoutDays(profileId: p.id!);

    // ШАГ 3: Ищем целевую ИЗОЛЯЦИЮ во ВСЕХ днях нового плана
    const targetItemId = 60; // Сведение рук в тренажёре

    int foundDayId = -1;
    for (final d in allDays.where((d) => d.type == 'strength')) {
      final exs = await DatabaseHelper.instance.getWorkoutExercises(d.id!);
      final has = exs.any((e) => e.itemId == targetItemId);
      if (has) {
        foundDayId = d.id!;
        print('📍 itemId=$targetItemId найден в: неделя ${d.weekNumber}, день id=${d.id}');
        break;
      }
    }

    if (foundDayId == -1) {
      fail('Изоляция itemId=$targetItemId не найдена ни в одном силовом дне нового плана');
    }

    final targetExs =
    await DatabaseHelper.instance.getWorkoutExercises(foundDayId);
    final targetEx = targetExs.firstWhere((e) => e.itemId == targetItemId);

    final sets = await DatabaseHelper.instance.getWorkoutSets(targetEx.id!);
    print('📊 Найдено сетов: ${sets.length}');

    if (sets.isEmpty) {
      fail('Для изоляции itemId=$targetItemId не найдено ни одного сета');
    }

    final maxWeight = sets.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
    final maxReps = sets.map((s) => s.reps ?? 0).reduce((a, b) => a > b ? a : b);
    print('📊 maxWeight=$maxWeight, maxReps=$maxReps');

    expect(maxWeight, greaterThanOrEqualTo(50.0),
        reason: 'Система НЕ запомнила вес изоляции: ожидается >= 50.0, получено $maxWeight');
    expect(maxReps, greaterThanOrEqualTo(15),
        reason: 'Система НЕ запомнила повторы изоляции: ожидается >= 15, получено $maxReps');
  });
}
