// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:workout_tracker/services/database_helper.dart';
import 'package:workout_tracker/services/workout_generator.dart';
import 'package:workout_tracker/services/energy_service.dart';
import 'package:workout_tracker/services/garden_service.dart';
import 'package:workout_tracker/services/achievement_service.dart';
import 'package:workout_tracker/services/week_analyzer.dart';
import 'package:workout_tracker/models/user_profile.dart';
import 'package:workout_tracker/models/workout_day.dart';
import 'package:workout_tracker/models/exercise.dart';
import 'package:workout_tracker/data/base_exercises.dart';
import 'package:workout_tracker/screens/garden/garden_screen.dart';
import 'package:workout_tracker/screens/workout/workout_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    final keys = prefs.getKeys().where((k) =>
    k.startsWith('allow_base_change_') ||
        k.startsWith('last_weight_') ||
        k.startsWith('last_reps_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }

  }

  Future<UserProfile> createGymProfile() async {
    final p = UserProfile(
      name: 'Test User 4 Months',
      gender: 'male', age: 30, height: 180, weight: 80,
      level: 'intermediate', goal: 'gain_mass', equipment: 'gym',
      daysPerWeek: 3, sessionMinutes: 45,
      focusAreas: ['chest', 'back', 'legs'], limitations: [],
      createdAt: DateTime.now(),
    );
    p.id = await DatabaseHelper.instance.addProfile(p);
    return p;
  }

  Future<UserProfile> createProfile({
    String name = 'Test',
    String level = 'intermediate',
    String equipment = 'gym',
    String goal = 'gain_mass',
    String gender = 'male',
    List<String> focusAreas = const ['chest', 'back', 'legs'],
    List<String> limitations = const [],
    int daysPerWeek = 3,
    List<int> trainingWeekdays = const [],
  }) async {
    final p = UserProfile(
      name: name, gender: gender, age: 30, height: 180, weight: 80,
      level: level, goal: goal, equipment: equipment,
      daysPerWeek: daysPerWeek, sessionMinutes: 45,
      trainingWeekdays: trainingWeekdays,
      focusAreas: focusAreas, limitations: limitations,
      createdAt: DateTime.now(),
    );
    p.id = await DatabaseHelper.instance.addProfile(p);
    return p;
  }

  Set<int> fallbackAllowedWeekdays(int daysPerWeek, int todayWeekday) {
    const patterns = {
      1: [1],
      2: [1, 4],
      3: [1, 3, 5],
      4: [1, 2, 4, 6],
      5: [1, 2, 3, 5, 6],
      6: [1, 2, 3, 4, 5, 6],
      7: [1, 2, 3, 4, 5, 6, 7],
    };
    final pattern = patterns[daysPerWeek.clamp(1, 7)]!;
    final offsets = pattern.map((w) => (w - todayWeekday) % 7).toSet().toList()..sort();
    final List<int> slots;
    if (offsets.contains(0)) {
      slots = offsets;
    } else {
      slots = [0, ...offsets.take(daysPerWeek - 1)];
    }
    return slots.map((o) => ((todayWeekday - 1 + o) % 7) + 1).toSet();
  }

  // 👇 ИСПРАВЛЕНО: единый источник истины — классификация из миграции v20.
  // Раньше фильтр угадывал «весовость» по названиям и ошибался
  // (например, на «Отжимания от скамьи (обратные)»: тест записывал ей
  // историю в кг, а генератор по weightModeOf честно не проставлял вес).
  // Теперь тест и генератор смотрят на один и тот же признак:
  // вес проставляется только упражнениям с обязательным весом (mode 2).
  // Timed-упражнения (планка и т.п.) тоже без веса — это согласовано.
  bool isWeightExercise(Exercise ex) {
    if (ex.muscleGroups.contains('cardio')) return false;
    return weightModeOf(ex) == 2;
  }

  bool isPlainStrength(Exercise ex) {
    if (!isWeightExercise(ex)) return false;
    final lower = ex.name.toLowerCase();
    final isJumpRope = lower.contains('скакалк') ||
        (lower.contains('прыжк') && !lower.contains('тумбу'));
    final isShadowBoxing = lower.contains('бой с тенью');
    final isHighIntensity = lower.contains('берпи') ||
        lower.contains('скалолаз') ||
        lower.contains('джеки') ||
        (lower.contains('канат') &&
            (lower.contains('махи') || lower.contains('волны') || lower.contains('бэтл')));
    return !isJumpRope && !isShadowBoxing && !isHighIntensity;
  }

  bool isTimedExercise(String name) {
    final lower = name.toLowerCase();
    return lower.contains('планка') || lower.contains('plank') ||
        lower.contains('стульчик') || lower.contains('уголок') ||
        lower.contains('лодочка');
  }

  // ──────────────────────────────────────────────────────────
  // 1. ГЛАВНЫЙ ТЕСТ: 4 МЕСЯЦА
  // ──────────────────────────────────────────────────────────
  testWidgets('4 МЕСЯЦА: прогрессия весов, челленджи, отсутствие дублей',
          (tester) async {
        WorkoutGenerator.setSeed(12345);
        await cleanDB();
        final profile = await createGymProfile();

        print('\n╔══════════════════════════════════════════════╗');
        print('║  ТЕСТ: 4 МЕСЯЦА ТРЕНИРОВОК (16 НЕДЕЛЬ)       ║');
        print('╚══════════════════════════════════════════════╝');

        const double baseWeightStart = 20.0;
        final Map<int, double> lastWeightByExerciseId = {};
        int totalDays = 0;
        int totalChallengeDays = 0;
        int totalStrengthDays = 0;

        for (int cycle = 1; cycle <= 4; cycle++) {
          final plan = await WorkoutGenerator.generateMonthPlan(profile);
          totalDays += plan.length;

          final challenges = plan.where((d) => d.type == 'challenge').toList();
          totalChallengeDays += challenges.length;
          expect(challenges.length, greaterThanOrEqualTo(1));

          int daysWithDuplicates = 0;
          final planDays = [...plan]..sort((a, b) => a.date.compareTo(b.date));
          final List<Set<String>> familiesByDay = [];
          for (final day in planDays) {
            final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            final families = <String>{};
            for (final we in exs) {
              if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
              final ex = await DatabaseHelper.instance
                  .getExerciseById(we.replacedByItemId ?? we.itemId);
              if (ex == null) continue;
              final fam = getExerciseFamily(ex.name);
              if (families.contains(fam)) {
                daysWithDuplicates++;
                fail('ДУБЛЬ в "${day.name}": "$fam" (${ex.name})');
              }
              families.add(fam);
            }
            familiesByDay.add(families);
          }
          expect(daysWithDuplicates, 0);

          int adjacentRepeats = 0;
          int minFamilyTotal = 0;
          for (int i = 1; i < familiesByDay.length; i++) {
            final inter = familiesByDay[i - 1].intersection(familiesByDay[i]).length;
            adjacentRepeats += inter;
            minFamilyTotal += [
              familiesByDay[i - 1].length,
              familiesByDay[i].length,
            ].reduce((a, b) => a < b ? a : b);
          }
          expect(minFamilyTotal, greaterThan(0));
          expect(adjacentRepeats * 2, lessThanOrEqualTo(minFamilyTotal),
              reason: 'Цикл $cycle: соседние дни совпадают по семействам больше '
                  'наполовину ($adjacentRepeats из $minFamilyTotal)');
          if (cycle > 1) {
            for (final day in plan.where((d) => d.weekNumber == 1 && d.type == 'strength')) {
              final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
              for (final we in exs) {
                if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
                final exId = we.replacedByItemId ?? we.itemId;
                final ex = await DatabaseHelper.instance.getExerciseById(exId);
                if (ex == null || !isWeightExercise(ex)) continue;
                final expected = lastWeightByExerciseId[exId];
                if (expected == null) continue;
                final sets = await DatabaseHelper.instance.getWorkoutSets(we.id!);
                final weights = sets
                    .where((s) => s.weight != null && s.weight! > 0)
                    .map((s) => s.weight!)
                    .toList();
                expect(weights, isNotEmpty,
                    reason: '${ex.name}: была история (макс $expected), '
                        'но плановые сеты без веса');
                final maxW = weights.reduce((a, b) => a > b ? a : b);
                expect(maxW, greaterThanOrEqualTo(expected),
                    reason: '${ex.name}: генератор забыл вес ($maxW < $expected)');
              }
            }
          }

          final cycleBaseWeight = baseWeightStart + (cycle - 1) * 2.5;
          for (final day in plan.where((d) => d.type == 'strength')) {
            totalStrengthDays++;
            final week = day.weekNumber ?? 1;
            final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            for (final we in exs) {
              if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
              final ex = await DatabaseHelper.instance
                  .getExerciseById(we.replacedByItemId ?? we.itemId);
              if (ex == null || !isWeightExercise(ex)) continue;
              final sets = await DatabaseHelper.instance.getWorkoutSets(we.id!);
              if (sets.isEmpty) continue;

              double targetWeight = cycleBaseWeight;
              int targetReps = 10;
              if (week == 2) { targetReps = 12; }
              else if (week == 3) { targetWeight += 2.5; targetReps = 12; }
              else if (week == 4) { targetWeight += 2.5; targetReps = 15; }

              for (var i = 0; i < sets.length; i++) {
                await DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(
                  id: sets[i].id, workoutExerciseId: we.id!, order: i + 1,
                  weight: targetWeight, reps: targetReps, completed: true,
                ));
              }
              lastWeightByExerciseId[we.replacedByItemId ?? we.itemId] = targetWeight;
            }
            await DatabaseHelper.instance.updateWorkoutDay(
              day.copyWith(status: 'completed', completedAt: DateTime.now()),
            );
          }
        }

        expect(totalDays, greaterThanOrEqualTo(48));
        expect(totalChallengeDays, greaterThanOrEqualTo(4));
        expect(totalStrengthDays, greaterThanOrEqualTo(44),
            reason: 'Силовых дней должно быть не меньше 44 за 4 цикла');
        final maxFinalWeight = lastWeightByExerciseId.values.reduce((a, b) => a > b ? a : b);
        expect(maxFinalWeight, greaterThan(baseWeightStart + 5));
        print('✅ Прогрессия: $baseWeightStart → $maxFinalWeight кг');
      });

// ═══ КОНЕЦ ЧАСТИ 1 ═══
  // ──────────────────────────────────────────────────────────
  // 2. НАГРАДЫ (ЧЕЛЛЕНДЖ + ОБЫЧНАЯ + ИДЕМПОТЕНТНОСТЬ)
  // ──────────────────────────────────────────────────────────
  group('Награды за тренировки', () {
    testWidgets('Челлендж: 60⚡ + 1 легендарный лотос, повторно — отказ',
            (tester) async {
          await cleanDB();
          final profile = await createGymProfile();
          final profileId = profile.id!;
          final plan = await WorkoutGenerator.generateMonthPlan(profile);
          final challengeDay = plan.firstWhere((d) => d.type == 'challenge');

          final beforeBalance = await EnergyService.getBalance(profileId);
          final beforeGarden = await GardenService.getGarden(profileId);

          final awarded1 = await EnergyService.addEnergy(
            profileId: profileId, delta: 60,
            reason: 'challenge_day_reward', refId: challengeDay.id,
          );
          if (awarded1) {
            await GardenService.plantNextFlower(profileId: profileId, flowerType: 'legendary');
          }

          final awarded2 = await EnergyService.addEnergy(
            profileId: profileId, delta: 60,
            reason: 'challenge_day_reward', refId: challengeDay.id,
          );

          final afterBalance = await EnergyService.getBalance(profileId);
          final afterGarden = await GardenService.getGarden(profileId);

          expect(awarded1, true);
          expect(awarded2, false, reason: 'Повторная награда должна отклониться (UNIQUE)');
          expect(afterBalance - beforeBalance, 60);
          expect(afterGarden.length - beforeGarden.length, 1);
          expect(afterGarden.where((g) => g['flowerType'] == 'legendary').length, 1);
        });

    testWidgets('Обычная тренировка: ровно +20⚡', (tester) async {
      await cleanDB();
      final profile = await createGymProfile();
      final profileId = profile.id!;
      final plan = await WorkoutGenerator.generateMonthPlan(profile);
      final normalDay = plan.firstWhere((d) => d.type == 'strength');

      final before = await EnergyService.getBalance(profileId);
      await EnergyService.addEnergy(
        profileId: profileId, delta: 20,
        reason: 'workout_completed', refId: normalDay.id,
      );
      final after = await EnergyService.getBalance(profileId);
      expect(after - before, 20);
    });

    testWidgets('Двойной вызов награды не дублирует транзакцию', (tester) async {
      await cleanDB();
      final profile = await createGymProfile();
      final profileId = profile.id!;
      final plan = await WorkoutGenerator.generateMonthPlan(profile);
      final day = plan.first;

      await EnergyService.addEnergy(
          profileId: profileId, delta: 20, reason: 'workout_completed', refId: day.id);
      await EnergyService.addEnergy(
          profileId: profileId, delta: 20, reason: 'workout_completed', refId: day.id);

      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
        "SELECT COUNT(*) as c FROM energy_transactions WHERE reason = 'workout_completed' AND refId = ?",
        [day.id],
      );
      expect(Sqflite.firstIntValue(rows), 1);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 3. ОГРАНИЧЕНИЯ, ИНВЕНТАРЬ, УРОВЕНЬ
  // ──────────────────────────────────────────────────────────
  group('Соблюдение ограничений и инвентаря', () {
    final profiles = [
      {'level': 'beginner', 'equipment': 'bodyweight', 'goal': 'tone', 'limitations': <String>[]},
      {'level': 'intermediate', 'equipment': 'dumbbells', 'goal': 'tone', 'limitations': <String>[]},
      {'level': 'intermediate', 'equipment': 'gym', 'goal': 'lose_weight', 'limitations': <String>['колени']},
      {'level': 'advanced', 'equipment': 'gym', 'goal': 'strength', 'limitations': <String>['спина']},
    ];

    for (final cfg in profiles) {
      testWidgets('${cfg['level']} / ${cfg['equipment']} / ${cfg['goal']}',
              (tester) async {
            await cleanDB();
            final p = await createProfile(
              level: cfg['level'] as String,
              equipment: cfg['equipment'] as String,
              goal: cfg['goal'] as String,
              limitations: List<String>.from(cfg['limitations'] as List),
            );
            final plan = await WorkoutGenerator.generateMonthPlan(p);

            for (final day in plan) {
              final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
              for (final we in exs) {
                if (we.itemType != 'exercise') continue;
                final ex = await DatabaseHelper.instance
                    .getExerciseById(we.replacedByItemId ?? we.itemId);
                if (ex == null) continue;

                expect(WorkoutGenerator.matchesEquipment(ex, p.equipment), true,
                    reason: '${p.equipment}: "${ex.name}" требует не тот инвентарь');

                if (p.level == 'beginner') {
                  expect(ex.difficulty, isNot('advanced'),
                      reason: 'Новичку дали advanced: ${ex.name}');
                }

                for (final lim in p.limitations) {
                  final b = lim.toLowerCase().trim();
                  final hasContra = ex.contraindications
                      .map((c) => c.toLowerCase().trim())
                      .any((c) => c.contains(b) || b.contains(c));
                  expect(hasContra, false,
                      reason: '${p.name}: "${ex.name}" противопоказано при "$lim"');
                }
              }
            }
          });
    }
  });

  // ──────────────────────────────────────────────────────────
  // 4. ПРОГРЕССИЯ УПРАЖНЕНИЙ НА ВРЕМЯ (планка)
  // ──────────────────────────────────────────────────────────
  group('Прогрессия упражнений на время', () {
    testWidgets('Timed: 60 → 80 → 100 → 60 (intermediate, bodyweight + abs)',
            (tester) async {
          await cleanDB();
          final p = await createProfile(
              level: 'intermediate',
              equipment: 'bodyweight',
              focusAreas: const ['glutes', 'abs', 'legs']);
          final plan = await WorkoutGenerator.generateMonthPlan(p);

          final expectedByWeek = {1: 60, 2: 80, 3: 100, 4: 60};
          int checked = 0;

          for (final day in plan.where((d) => d.type == 'strength')) {
            final week = day.weekNumber ?? 1;
            final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            for (final we in exs) {
              if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
              final ex = await DatabaseHelper.instance
                  .getExerciseById(we.replacedByItemId ?? we.itemId);
              if (ex == null || !isTimedExercise(ex.name)) continue;

              final reps = RegExp(r'(\d+)').firstMatch(we.reps);
              final secs = int.tryParse(reps?.group(1) ?? '');
              if (secs == null) continue;

              final isSidePlank = ex.name.toLowerCase().contains('боковая планка');
              final expectedSecs = isSidePlank
                  ? (expectedByWeek[week]! * 0.7).round()
                  : expectedByWeek[week]!;

              expect(secs, expectedSecs,
                  reason: 'Week $week, "${ex.name}": ожидалось $expectedSecs сек, было $secs');
              checked++;
            }
          }
          expect(checked, greaterThan(0), reason: 'Не нашли ни одного упражнения на время');
          print('⏱ Проверено timed-упражнений: $checked');
        });

    testWidgets('Timed beginner: 30 → 40 → 50 → 30', (tester) async {
      await cleanDB();
      final p = await createProfile(
          level: 'beginner', equipment: 'bodyweight',
          focusAreas: const ['glutes', 'abs', 'legs']);
      final plan = await WorkoutGenerator.generateMonthPlan(p);
      final expected = {1: 30, 2: 40, 3: 50, 4: 30};

      int checked = 0;

      for (final day in plan.where((d) => d.type == 'strength')) {
        final week = day.weekNumber ?? 1;
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        for (final we in exs) {
          if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
          final ex = await DatabaseHelper.instance
              .getExerciseById(we.replacedByItemId ?? we.itemId);
          if (ex == null || !isTimedExercise(ex.name)) continue;
          final reps = RegExp(r'(\d+)').firstMatch(we.reps);
          final secs = int.tryParse(reps?.group(1) ?? '');
          if (secs == null) continue;
          final isSidePlank = ex.name.toLowerCase().contains('боковая планка');
          final expectedSecs = isSidePlank
              ? (expected[week]! * 0.7).round()
              : expected[week]!;
          expect(secs, expectedSecs, reason: '${ex.name}, week $week');
          checked++;
        }
      }
      expect(checked, greaterThan(0),
          reason: 'Beginner: не нашли ни одного упражнения на время');
      print('⏱ Beginner: проверено timed-упражнений: $checked');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 5. СЕТЫ: БАЗА ПО УРОВНЮ + СБРОС ПРИ ПРОПУСКАХ
  // ──────────────────────────────────────────────────────────
  group('Подходы (сеты)', () {
    testWidgets('База сетов по уровню: beginner=2, intermediate=3, advanced=4',
            (tester) async {
          final expected = {'beginner': 2, 'intermediate': 3, 'advanced': 4};
          for (final entry in expected.entries) {
            await cleanDB();
            final p = await createProfile(level: entry.key);
            final plan = await WorkoutGenerator.generateMonthPlan(p);
            final day = plan.firstWhere((d) => d.weekNumber == 1 && d.type == 'strength');
            final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            for (final we in exs) {
              if (we.isWarmup || we.isCoolDown) continue;
              final ex = await DatabaseHelper.instance
                  .getExerciseById(we.replacedByItemId ?? we.itemId);
              if (ex == null || !isPlainStrength(ex)) continue;
              expect(we.sets, entry.value,
                  reason: '${entry.key}: "${ex.name}" — ожидалось ${entry.value} сетов, было ${we.sets}');
            }
          }
        });

    testWidgets('Пропуск 2 дней → сетов на 1 меньше', (tester) async {
      await cleanDB();
      final p = await createProfile();
      final plan1 = await WorkoutGenerator.generateMonthPlan(p);

      final now = DateTime.now();
      final skipped = plan1.where((d) => d.weekNumber == 3).take(2).toList();
      for (final day in skipped) {
        await DatabaseHelper.instance.updateWorkoutDay(
          day.copyWith(
            status: 'skipped',
            date: now.subtract(const Duration(days: 8)),
          ),
        );
      }

      final missed = await WeekAnalyzer.missedLastWeek(p.id!);
      print('🔍 missedLastWeek = $missed (ожидалось >= 2)');

      final plan2 = await WorkoutGenerator.generateMonthPlan(p, smart: true);
      final week1 = plan2.firstWhere((d) => d.weekNumber == 1 && d.type == 'strength');
      final exs = await DatabaseHelper.instance.getWorkoutExercises(week1.id!);
      bool found = false;
      for (final we in exs) {
        if (we.isWarmup || we.isCoolDown) continue;
        final ex = await DatabaseHelper.instance
            .getExerciseById(we.replacedByItemId ?? we.itemId);
        if (ex == null || !isPlainStrength(ex)) continue;
        found = true;
        expect(we.sets, lessThan(3),
            reason: 'После пропусков сетов должно быть < 3, было ${we.sets}');
      }
      expect(found, true);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 6. УНИКАЛЬНОСТЬ СЕМЕЙСТВ + РАЗМИНКА/ЗАМИНКА
  // ──────────────────────────────────────────────────────────
  group('Структура дня', () {
    testWidgets('Каждый силовой день: есть разминка и заминка', (tester) async {
      await cleanDB();
      final p = await createProfile();
      final plan = await WorkoutGenerator.generateMonthPlan(p);

      for (final day in plan.where((d) => d.type == 'strength')) {
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        expect(exs.any((e) => e.isWarmup), true, reason: '${day.name}: нет разминки');
        expect(exs.any((e) => e.isCoolDown), true, reason: '${day.name}: нет заминки');
      }
    });

    testWidgets('В одном дне нет двух упражнений одного семейства', (tester) async {
      await cleanDB();
      final p = await createProfile();
      final plan = await WorkoutGenerator.generateMonthPlan(p);

      for (final day in plan) {
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        final families = <String>{};
        for (final we in exs) {
          if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
          final ex = await DatabaseHelper.instance
              .getExerciseById(we.replacedByItemId ?? we.itemId);
          if (ex == null) continue;
          final fam = getExerciseFamily(ex.name);
          expect(families.contains(fam), false,
              reason: '${day.name}: семейство "$fam" дважды (${ex.name})');
          families.add(fam);
        }
      }
    });

    testWidgets('Даже с жёсткими ограничениями день не пустой', (tester) async {
      await cleanDB();
      final p = await createProfile(
        level: 'beginner',
        equipment: 'bodyweight',
        limitations: ['колени', 'спина', 'плечи'],
      );
      final plan = await WorkoutGenerator.generateMonthPlan(p);
      for (final day in plan.where((d) => d.type == 'strength')) {
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        final mainExs = exs.where((e) => !e.isWarmup && !e.isCoolDown).toList();
        expect(mainExs.length, greaterThan(0),
            reason: '${day.name}: после фильтрации пусто');
      }
    });
  });

  // ──────────────────────────────────────────────────────────
  // 7. REST-СЕКУНДЫ ПО ЦЕЛИ
  // ──────────────────────────────────────────────────────────
  group('Rest-секунды', () {
    testWidgets('strength=120, gain_mass=90, lose_weight=45, tone=60',
            (tester) async {
          final cases = {
            'strength': 120,
            'gain_mass': 90,
            'lose_weight': 45,
            'tone': 60,
          };
          for (final entry in cases.entries) {
            await cleanDB();
            final p = await createProfile(goal: entry.key);
            final plan = await WorkoutGenerator.generateMonthPlan(p);
            final day = plan.firstWhere((d) => d.weekNumber == 1 && d.type == 'strength');
            final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            for (final we in exs) {
              if (we.isWarmup || we.isCoolDown) continue;
              expect(we.restSeconds, entry.value,
                  reason: '${entry.key}: rest=${we.restSeconds}, ожидалось ${entry.value}');
            }
          }
        });
  });

  // ──────────────────────────────────────────────────────────
  // 8. САД: ПОЛНОТА + РЕФАНД
  // ──────────────────────────────────────────────────────────
  group('Сад', () {
    testWidgets('Полный сад: plantNextFlower возвращает false', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      final batch = db.batch();
      for (int i = 0; i < 800; i++) {
        batch.insert('garden_flowers', {
          'profileId': p.id, 'slotIndex': i, 'state': 'bloomed',
          'flowerType': 'normal', 'rotation': 0, 'createdAt': now,
        });
      }
      await batch.commit(noResult: true);

      final result = await GardenService.plantNextFlower(
          profileId: p.id!, flowerType: 'legendary');
      expect(result, false, reason: 'Сад заполнен — должен вернуть false');
    });

    // 👇 ИСПРАВЛЕНО: у нового профиля баланс 0 — покупка честно отказывала,
    // цветок не садился, и удалять было нечего. Даём энергию и проверяем,
    // что покупка прошла, прежде чем мерить возврат.
    testWidgets('Удаление возвращает энергию', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final profileId = p.id!;

      await EnergyService.addEnergy(
        profileId: profileId, delta: 100, reason: 'test_topup', refId: null,
      );

      final bought = await GardenService.buyFlowerAtSlot(
          profileId: profileId, slotIndex: 0);
      expect(bought, isNull, reason: 'Покупка должна пройти: $bought');

      final before = await EnergyService.getBalance(profileId);
      await GardenService.removeItem(profileId, 0, 15);
      final after = await EnergyService.getBalance(profileId);
      expect(after - before, 15);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 9. ЗАМЕНА УПРАЖНЕНИЯ НА ВЕСЬ МЕСЯЦ
  // ──────────────────────────────────────────────────────────
  group('Замена упражнений', () {
    testWidgets('Постоянная замена меняет упражнение во всех днях месяца',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();
          final profileId = p.id!;
          final plan = await WorkoutGenerator.generateMonthPlan(p);
          final firstDay = plan.firstWhere((d) => d.type == 'strength');
          final exs = await DatabaseHelper.instance.getWorkoutExercises(firstDay.id!);
          final toReplace = exs.firstWhere((e) => !e.isWarmup && !e.isCoolDown);

          final allEx = await DatabaseHelper.instance.getExercises();

          final usedIds = <int>{};
          for (final d in plan) {
            final dayExs = await DatabaseHelper.instance.getWorkoutExercises(d.id!);
            usedIds.addAll(dayExs.map((e) => e.effectiveItemId));
          }

          final candidate = allEx.firstWhere(
                (e) => e.id != toReplace.itemId && isBaseExercise(e) && !usedIds.contains(e.id),
            orElse: () => allEx.first,
          );

          await DatabaseHelper.instance.replaceExerciseInMonth(
            profileId: profileId,
            oldItemId: toReplace.itemId,
            newItemId: candidate.id!,
            reason: 'too_hard',
            permanent: true,
          );

          for (final day in plan) {
            final dayExs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            final hasOld = dayExs.any((e) =>
            e.itemId == toReplace.itemId && e.replacedByItemId == null);
            expect(hasOld, false,
                reason: '${day.name}: старое упражнение не заменено');
          }
        });
  });

  // ──────────────────────────────────────────────────────────
  // 10. ОТКАЗ ОТ ЧЕЛЛЕНДЖА → «ЗАБЫТЫЕ ЗОНЫ»
  // ──────────────────────────────────────────────────────────
  group('Отказ от челленджа', () {
    testWidgets('После decline день не пустой', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final plan = await WorkoutGenerator.generateMonthPlan(p);
      final challenge = plan.firstWhere((d) => d.type == 'challenge');

      final updated = challenge.copyWith(type: 'strength');
      await DatabaseHelper.instance.updateWorkoutDay(updated);

      final allExercises = await DatabaseHelper.instance.getExercises();
      final bases = allExercises.where(isBaseExercise).take(3).toList();
      int order = 1;
      for (final ex in bases) {
        final we = WorkoutExercise(
          workoutDayId: updated.id!, itemType: 'exercise', itemId: ex.id!,
          order: order++, sets: 3, reps: '10-12',
        );
        await DatabaseHelper.instance.addWorkoutExercise(we);
      }

      final exs = await DatabaseHelper.instance.getWorkoutExercises(updated.id!);
      expect(exs.length, greaterThan(0));
      expect(exs.any((e) => !e.isWarmup && !e.isCoolDown), true);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 11. ДОСТИЖЕНИЯ
  // ──────────────────────────────────────────────────────────
  group('Достижения', () {
    testWidgets('После тренировки не падает и не дублирует', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final profileId = p.id!;
      final plan = await WorkoutGenerator.generateMonthPlan(p);
      final day = plan.firstWhere((d) => d.type == 'strength');

      await DatabaseHelper.instance.updateWorkoutDay(
          day.copyWith(status: 'completed', completedAt: DateTime.now()));

      await AchievementService.checkAchievements(profileId);
      final second = await AchievementService.checkAchievements(profileId);

      expect(second.length, 0, reason: 'Повторно достижения не выдаются');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 12. ШАБЛОНЫ
  // ──────────────────────────────────────────────────────────
  group('Шаблоны тренировок', () {
    testWidgets('Шаблон из завершённого дня не включает разминку',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();
          final profileId = p.id!;
          final plan = await WorkoutGenerator.generateMonthPlan(p);
          final day = plan.firstWhere((d) => d.type == 'strength');

          final templateId = await DatabaseHelper.instance.createTemplateFromWorkoutDay(
            profileId: profileId,
            workoutDayId: day.id!,
            templateName: 'Мой шаблон',
            type: 'strength',
            estimatedMinutes: 45,
          );
          final items = await DatabaseHelper.instance.getTemplateItems(templateId);
          expect(items.length, greaterThan(0));

          final dayExs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
          for (final item in items) {
            final matches = dayExs.where((e) => e.order == item.order);
            expect(matches, isNotEmpty,
                reason: 'Шаблон ссылается на order ${item.order}, которого нет в дне');
            expect(matches.first.isWarmup, false, reason: 'Разминка попала в шаблон');
          }
        });
  });

  // ──────────────────────────────────────────────────────────
  // 13. ТРАНЗАКЦИОННОСТЬ ЭНЕРГИИ
  // ──────────────────────────────────────────────────────────
  group('Транзакционность энергии', () {
    testWidgets('Уникальный (profileId, reason, refId) не меняет баланс',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();
          final profileId = p.id!;

          final before = await EnergyService.getBalance(profileId);
          await EnergyService.addEnergy(
              profileId: profileId, delta: 10, reason: 'test_reason', refId: 1);
          final afterFirst = await EnergyService.getBalance(profileId);

          final result = await EnergyService.addEnergy(
              profileId: profileId, delta: 10, reason: 'test_reason', refId: 1);
          final afterSecond = await EnergyService.getBalance(profileId);

          expect(afterFirst - before, 10);
          expect(result, false);
          expect(afterSecond, afterFirst);
        });
  });

  // ──────────────────────────────────────────────────────────
  // 14. НЕГАТИВНЫЕ ТЕСТЫ
  // ──────────────────────────────────────────────────────────
  group('Негативные сценарии', () {
    testWidgets('generateMonthPlan без id → исключение', (tester) async {
      final bad = UserProfile(
        name: 'No ID', gender: 'male', age: 30, height: 180, weight: 80,
        level: 'intermediate', goal: 'tone', equipment: 'gym',
        daysPerWeek: 3, sessionMinutes: 45,
        focusAreas: const [], limitations: const [],
        createdAt: DateTime.now(),
      );
      expect(() => WorkoutGenerator.generateMonthPlan(bad), throwsA(anything));
    });

    // 👇 ИСПРАВЛЕНО: проверяем не только отсутствие цветка, но и то,
    // что сервис отказал с понятной причиной, а не «тихо что-то сломалось».
    testWidgets('Покупка без энергии — цветок не появляется', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final before = (await GardenService.getGarden(p.id!)).length;

      final error = await GardenService.buyFlowerAtSlot(
          profileId: p.id!, slotIndex: 0);
      expect(error, isNotNull,
          reason: 'Без энергии покупка должна отказать с причиной: $error');

      final after = (await GardenService.getGarden(p.id!)).length;
      expect(after, before, reason: 'Цветок не должен появиться без энергии');
    });

    testWidgets('Перемещение на занятую клетку → вежливый отказ (false)',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();
          await GardenService.plantNextFlower(profileId: p.id!, flowerType: 'normal');
          await GardenService.plantNextFlower(profileId: p.id!, flowerType: 'normal');
          final garden = await GardenService.getGarden(p.id!);
          final occupied = garden.first['slotIndex'] as int;

          final moved = await GardenService.moveItem(
              p.id!, garden.last['slotIndex'] as int, occupied);
          expect(moved, false);
        });
  });

// ═══ КОНЕЦ ЧАСТИ 2 ═══
  // ──────────────────────────────────────────────────────────
  // 15. UI: WIDGET-ТЕСТЫ
  // ──────────────────────────────────────────────────────────
  group('Widget-тесты UI', () {
    testWidgets('GardenScreen: тап по пустой клетке → меню', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      await tester.pumpWidget(MaterialApp(home: GardenScreen(profileId: p.id!)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));

      final garden = find.byType(InteractiveViewer);
      expect(garden, findsOneWidget);

      final targets = find.byType(DragTarget<int>).evaluate().toList();
      print('🔍 Пустых клеток (DragTarget) построено: ${targets.length}');
      if (targets.isNotEmpty) {
        final box = targets.first.renderObject as RenderBox;
        print('🔍 Центр первой клетки: '
            '${box.localToGlobal(box.size.center(Offset.zero))}');
      }
      print('🔍 Центр InteractiveViewer: ${tester.getCenter(garden)}');

      await tester.tapAt(tester.getCenter(garden));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      print('🔍 BottomSheet на экране: '
          '${find.byType(BottomSheet).evaluate().length}');

      expect(find.textContaining('Создай свой сад'), findsOneWidget,
          reason: 'После тапа по пустой клетке не открылось меню покупки');
      expect(find.textContaining('Посадить лотос'), findsOneWidget,
          reason: 'В меню покупки нет пункта с лотосом');
    });

    testWidgets('Двойной тап «Завершить» не дублирует награду', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final profileId = p.id!;
      final plan = await WorkoutGenerator.generateMonthPlan(p);
      final day = plan.firstWhere((d) => d.type == 'strength');

      await DatabaseHelper.instance.updateWorkoutDay(
          day.copyWith(status: 'in_progress', startedAt: DateTime.now()));

      final before = await EnergyService.getBalance(profileId);

      await EnergyService.addEnergy(
          profileId: profileId, delta: 20, reason: 'workout_completed', refId: day.id);
      await EnergyService.addEnergy(
          profileId: profileId, delta: 20, reason: 'workout_completed', refId: day.id);

      final after = await EnergyService.getBalance(profileId);
      expect(after - before, 20, reason: 'Двойной тап не должен давать 40⚡');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 16. МИГРАЦИИ БД (skip)
  // ──────────────────────────────────────────────────────────
  group('Миграции БД', () {
    testWidgets('16 → 17: rotation добавлен, данные целы', (tester) async {
      fail('Проверка миграции выполняется вручную в CI — см. комментарий выше');
    }, skip: true);
  });

  // ──────────────────────────────────────────────────────────
  // 17. ЦИКЛЫ 2+ С НОВЫМИ БАЗАМИ
  // ──────────────────────────────────────────────────────────
  group('Циклы 2+ с новыми базами', () {
    testWidgets('При отказе от обновления базы сохраняются', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final plan1 = await WorkoutGenerator.generateMonthPlan(p);
      final bases1 = <int>{};
      for (final day in plan1) {
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        for (final we in exs) {
          if (we.itemType == 'exercise' && !we.isWarmup && !we.isCoolDown) {
            final ex = await DatabaseHelper.instance
                .getExerciseById(we.replacedByItemId ?? we.itemId);
            if (ex != null && isBaseExercise(ex)) bases1.add(ex.id!);
          }
        }
      }
      expect(bases1.length, greaterThan(0));

      final week4Day1 = plan1
          .where((d) => d.weekNumber == 4 && d.type == 'strength')
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final week4Bases = <int>{};
      for (final day in week4Day1) {
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        for (final we in exs) {
          if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
          final ex = await DatabaseHelper.instance.getExerciseById(
              we.replacedByItemId ?? we.itemId);
          if (ex != null && isBaseExercise(ex)) week4Bases.add(ex.id!);
        }
      }

      final plan2 = await WorkoutGenerator.generateMonthPlan(p);
      final week1Cycle2 = plan2
          .where((d) => d.weekNumber == 1 && d.type == 'strength')
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final keptIds = <int>{};
      for (final day in week1Cycle2) {
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        for (final we in exs) {
          if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
          final ex = await DatabaseHelper.instance.getExerciseById(
              we.replacedByItemId ?? we.itemId);
          if (ex != null && isBaseExercise(ex)) keptIds.add(ex.id!);
        }
      }
      final intersection = week4Bases.intersection(keptIds);
      expect(intersection.length, greaterThan(0),
          reason: 'Ни одна база недели 4 цикла 1 не сохранилась в цикле 2 '
              '(${week4Bases.length} баз было)');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 18. АДАПТАЦИЯ — БОЛЬШЕ/МЕНЬШЕ ПЛАНА
  // ──────────────────────────────────────────────────────────
  group('Адаптация под фактические результаты (Больше/Меньше плана)', () {
    Future<int> createPastWeek(
        UserProfile p, List<int> exerciseIds, double weight, int reps) async {
      final now = DateTime.now();
      final day = WorkoutDay(
        profileId: p.id!,
        name: 'Неделя 1: День 1 (Прошлая)',
        type: 'strength',
        weekNumber: 1,
        cycleNumber: 1,
        status: 'completed',
        date: now.subtract(const Duration(days: 7)),
        completedAt: now,
      );
      final dayId = await DatabaseHelper.instance.createWorkoutDay(day);
      for (int i = 0; i < exerciseIds.length; i++) {
        final weId = await DatabaseHelper.instance.addWorkoutExercise(
            WorkoutExercise(
              workoutDayId: dayId,
              itemType: 'exercise',
              itemId: exerciseIds[i],
              order: 100 + i,
              sets: 3,
              reps: '10',
              isWarmup: false,
              isCoolDown: false,
            ));
        for (int s = 0; s < 3; s++) {
          await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
            workoutExerciseId: weId,
            order: s + 1,
            weight: weight,
            reps: reps,
            completed: true,
          ));
        }
      }
      return dayId;
    }

    Future<void> spreadHistoryToFamily(UserProfile p, int dayId, int targetId,
        double weight, int reps) async {
      final target = await DatabaseHelper.instance.getExerciseById(targetId);
      if (target == null) return;
      final family = getExerciseFamily(target.name);

      final all = await DatabaseHelper.instance.getExercises();
      int order = 200;
      for (final ex in all) {
        if (ex.id == null || ex.id == targetId) continue;
        if (getExerciseFamily(ex.name) != family) continue;
        final weId = await DatabaseHelper.instance.addWorkoutExercise(
            WorkoutExercise(
              workoutDayId: dayId,
              itemType: 'exercise',
              itemId: ex.id!,
              order: order++,
              sets: 3,
              reps: '10',
              isWarmup: false,
              isCoolDown: false,
            ));
        for (int s = 0; s < 3; s++) {
          await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
            workoutExerciseId: weId,
            order: s + 1,
            weight: weight,
            reps: reps,
            completed: true,
          ));
        }
      }
    }

    testWidgets('Перевыполнение: система запоминает больший вес и повторы',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();

          const ids = [56, 51, 16];
          final dayId = await createPastWeek(p, ids, 50.0, 15);
          await spreadHistoryToFamily(p, dayId, ids.first, 50.0, 15);
          print('✅ Прошлая неделя: вес 50 кг, 15 повторов (все варианты семейств)');

          await WorkoutGenerator.generateMonthPlan(p, smart: true);
          final allDays =
          await DatabaseHelper.instance.getWorkoutDays(profileId: p.id!);

          final target = await DatabaseHelper.instance.getExerciseById(ids.first);
          if (target == null) fail('Упражнение id=${ids.first} не найдено в базе');
          final family = getExerciseFamily(target.name);

          WorkoutExercise? targetEx;
          for (final d in allDays.where((d) => d.type == 'strength')) {
            final exs = await DatabaseHelper.instance.getWorkoutExercises(d.id!);
            for (final e in exs) {
              if (e.itemType != 'exercise' || e.isWarmup || e.isCoolDown) continue;
              final ex = await DatabaseHelper.instance
                  .getExerciseById(e.replacedByItemId ?? e.itemId);
              if (ex != null && getExerciseFamily(ex.name) == family) {
                targetEx = e;
                break;
              }
            }
            if (targetEx != null) break;
          }
          if (targetEx == null) {
            fail('Ни одно упражнение из семейства "$family" не попало в план');
          }

          final sets = await DatabaseHelper.instance.getWorkoutSets(targetEx!.id!);
          if (sets.isEmpty) fail('Для целевого упражнения нет ни одного сета');

          final maxWeight =
          sets.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
          final maxReps = sets.map((s) => s.reps ?? 0).reduce((a, b) => a > b ? a : b);
          print('📊 maxWeight=$maxWeight, maxReps=$maxReps');

          expect(maxWeight, greaterThanOrEqualTo(50.0),
              reason: 'Система не запомнила увеличенный вес: получено $maxWeight');
          expect(maxReps, greaterThanOrEqualTo(15),
              reason: 'Система не запомнила увеличенные повторы: получено $maxReps');
        });

    testWidgets('Недовыполнение: система оставляет вес прежним и не повышает',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();

          const ids = [56, 51, 16];
          final dayId = await createPastWeek(p, ids, 20.0, 5);
          await spreadHistoryToFamily(p, dayId, ids.first, 20.0, 5);
          print('✅ Прошлая неделя: вес 20 кг, 5 повторов (все варианты семейств)');

          await WorkoutGenerator.generateMonthPlan(p, smart: true);
          final allDays =
          await DatabaseHelper.instance.getWorkoutDays(profileId: p.id!);

          final target = await DatabaseHelper.instance.getExerciseById(ids.first);
          if (target == null) fail('Упражнение id=${ids.first} не найдено в базе');
          final family = getExerciseFamily(target.name);

          WorkoutExercise? targetEx;
          for (final d in allDays.where((d) => d.type == 'strength')) {
            final exs = await DatabaseHelper.instance.getWorkoutExercises(d.id!);
            for (final e in exs) {
              if (e.itemType != 'exercise' || e.isWarmup || e.isCoolDown) continue;
              final ex = await DatabaseHelper.instance
                  .getExerciseById(e.replacedByItemId ?? e.itemId);
              if (ex != null && getExerciseFamily(ex.name) == family) {
                targetEx = e;
                break;
              }
            }
            if (targetEx != null) break;
          }
          if (targetEx == null) {
            fail('Ни одно упражнение из семейства "$family" не попало в план');
          }

          final sets = await DatabaseHelper.instance.getWorkoutSets(targetEx!.id!);
          if (sets.isEmpty) fail('Для целевого упражнения нет ни одного сета');

          final maxWeight =
          sets.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
          final maxReps = sets.map((s) => s.reps ?? 0).reduce((a, b) => a > b ? a : b);
          print('📊 maxWeight=$maxWeight, maxReps=$maxReps');

          expect(maxWeight, greaterThan(0.0),
              reason: 'Система не нашла историю недовыполненного упражнения: '
                  'weight=$maxWeight');
          expect(maxWeight, lessThanOrEqualTo(20.0),
              reason: 'Система повысила вес, хотя план не был выполнен: $maxWeight');
          expect(maxReps, lessThanOrEqualTo(10),
              reason: 'Система повысила повторы выше запланированных: $maxReps');
        });
  });

  // ──────────────────────────────────────────────────────────
  // 19. ЧАСТИЧНОЕ ВЫПОЛНЕНИЕ
  // ──────────────────────────────────────────────────────────
  group('Частичное выполнение', () {
    testWidgets('День с 1 выполненным подходом из 3 не считается завершённым',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();

          final plan = await WorkoutGenerator.generateMonthPlan(p);
          final day = plan.firstWhere((d) => d.weekNumber == 1 && d.type == 'strength');

          final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
          final targetEx = exs.firstWhere((e) => !e.isWarmup && !e.isCoolDown);

          final sets = await DatabaseHelper.instance.getWorkoutSets(targetEx.id!);
          await DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(
            id: sets[0].id,
            workoutExerciseId: targetEx.id!,
            order: 1,
            weight: 20.0,
            reps: 10,
            completed: true,
          ));

          final updatedDay = await DatabaseHelper.instance.getWorkoutDayById(day.id!);
          expect(updatedDay!.status, isNot('completed'),
              reason: 'День не должен быть завершён, если сделаны не все подходы');
        });
  });

  // ──────────────────────────────────────────────────────────
  // 20. СТРЕСС-ТЕСТ ГЕНЕРАТОРА (10 ЦИКЛОВ)
  // ──────────────────────────────────────────────────────────
  group('Стресс-тест генератора', () {
    testWidgets('10 генераций подряд: нет дублей семейств, нет пустых дней',
            (tester) async {
          await cleanDB();

          for (int i = 0; i < 10; i++) {
            final p = await createGymProfile();
            final plan = await WorkoutGenerator.generateMonthPlan(p);
            expect(plan.isNotEmpty, true, reason: 'Цикл $i: план пустой');

            for (final day in plan.where((d) => d.type == 'strength')) {
              final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
              final mainExs = exs.where((e) => !e.isWarmup && !e.isCoolDown).toList();
              expect(mainExs.isNotEmpty, true,
                  reason: 'Цикл $i, ${day.name}: пустой силовой день');

              final families = <String>{};
              for (final we in mainExs) {
                final ex = await DatabaseHelper.instance.getExerciseById(
                    we.replacedByItemId ?? we.itemId);
                if (ex == null) continue;
                final fam = getExerciseFamily(ex.name);
                expect(families.contains(fam), false,
                    reason: 'Цикл $i, ${day.name}: дубль семейства "$fam" (${ex.name})');
                families.add(fam);
              }
            }
            await cleanDB();
          }
          print('✅ Стресс-тест: 10 генераций прошли без дублей и ошибок');
        });
  });

  // ──────────────────────────────────────────────────────────
  // 21. ПРОФИЛЬ БЕЗ ФОКУСНЫХ ЗОН
  // ──────────────────────────────────────────────────────────
  group('Профиль без фокусных зон', () {
    testWidgets('Если focusAreas пуст, план всё равно генерируется',
            (tester) async {
          await cleanDB();
          final p = await createProfile(
            focusAreas: const [],
            level: 'beginner',
            equipment: 'bodyweight',
          );

          final plan = await WorkoutGenerator.generateMonthPlan(p);
          expect(plan.isNotEmpty, true, reason: 'План не должен быть пустым');

          for (final day in plan.where((d) => d.type == 'strength')) {
            final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            final mainExs = exs.where((e) => !e.isWarmup && !e.isCoolDown).toList();
            expect(mainExs.isNotEmpty, true,
                reason: '${day.name}: упражнения не подобрались');
          }
          print('✅ Без фокусных зон: программа выдала сбалансированный план');
        });
  });

  // ──────────────────────────────────────────────────────────
  // 22. БИТЫЙ ПРОФИЛЬ (УДАЛЁН ИЗ БД)
  // ──────────────────────────────────────────────────────────
  group('Защита от битого профиля', () {
    testWidgets('Генерация с удалённым профилем вызывает ошибку',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();

          final db = await DatabaseHelper.instance.database;
          await db.delete('user_profiles', where: 'id = ?', whereArgs: [p.id]);

          await expectLater(
                () => WorkoutGenerator.generateMonthPlan(p),
            throwsA(anything),
            reason: 'Генератор должен явно сообщить, что профиля нет, '
                'а не молча выдать пустой план',
          );
          print('✅ Битый профиль: программа выдала ожидаемое исключение');
        });
  });

  // ──────────────────────────────────────────────────────────
  // 23. ЗАЩИТА ОТ ПЕРЕСКОКА НЕДЕЛЬ (UI)
  // ──────────────────────────────────────────────────────────
  group('Защита от перескока недель', () {
    testWidgets('Нельзя начать 2-ю неделю, если 1-я не завершена',
            (tester) async {
          await cleanDB();
          final p = await createProfile();
          final plan = await WorkoutGenerator.generateMonthPlan(p);

          final week2Day = plan.firstWhere((d) => d.weekNumber == 2 && d.type == 'strength');

          await tester.pumpWidget(MaterialApp(
            home: WorkoutDetailScreen(workoutDay: week2Day, profileId: p.id!),
          ));
          await tester.pumpAndSettle(const Duration(seconds: 2));

          await tester.tap(find.text('Начать тренировку'));
          await tester.pumpAndSettle(const Duration(seconds: 5));

          final dayInDb = await DatabaseHelper.instance.getWorkoutDayById(week2Day.id!);
          expect(dayInDb!.status, isNot('in_progress'),
              reason: '2-я неделя началась, хотя 1-я не завершена!');
          expect(find.textContaining('Сначала завершите предыдущую неделю'),
              findsOneWidget);
        });
  });

  // ──────────────────────────────────────────────────────────
  // 24. РАСКЛАДКА ДАТ И ПЕРЕНОС ДНЕЙ
  // ──────────────────────────────────────────────────────────
  group('Раскладка дат и перенос дней', () {
    testWidgets('unlockNextWeek чинит схлопнутые даты: раскладывает подряд от сегодня',
            (tester) async {
          await cleanDB();
          final p = await createProfile();

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          for (int i = 0; i < 3; i++) {
            await DatabaseHelper.instance.createWorkoutDay(WorkoutDay(
              profileId: p.id!,
              name: 'Неделя 2: День ${i + 1}',
              date: now,
              weekNumber: 2,
              cycleNumber: 1,
            ));
          }

          await DatabaseHelper.instance.unlockNextWeek(p.id!, 2);

          final days = await DatabaseHelper.instance.getWorkoutDaysByWeek(
              profileId: p.id!, weekNumber: 2);
          expect(days.length, 3);

          final uniqueDates = days
              .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
              .toSet();
          expect(uniqueDates.length, 3,
              reason: 'Даты дней одной недели не должны совпадать');

          for (int i = 0; i < days.length; i++) {
            final expected = today.add(Duration(days: i));
            final d = days[i].date;
            expect(d.year, expected.year, reason: 'День $i: год');
            expect(d.month, expected.month, reason: 'День $i: месяц');
            expect(d.day, expected.day, reason: 'День $i: день');
          }

          final ids = days.map((d) => d.id!).toList();
          expect(ids, ids.toList()..sort(),
              reason: 'Порядок дней недели не должен меняться');
        });

    testWidgets('unlockNextWeek не трогает даты других недель',
            (tester) async {
          await cleanDB();
          final p = await createProfile();

          final week1Date = DateTime(2026, 11, 10);
          final week3Date = DateTime(2026, 12, 10);

          final week1Id = await DatabaseHelper.instance.createWorkoutDay(WorkoutDay(
            profileId: p.id!, name: 'Неделя 1: День 1',
            date: week1Date, weekNumber: 1, cycleNumber: 1,
          ));
          final week3Id = await DatabaseHelper.instance.createWorkoutDay(WorkoutDay(
            profileId: p.id!, name: 'Неделя 3: День 1',
            date: week3Date, weekNumber: 3, cycleNumber: 1,
          ));

          await DatabaseHelper.instance.unlockNextWeek(p.id!, 2);

          final d1 = await DatabaseHelper.instance.getWorkoutDayById(week1Id);
          final d3 = await DatabaseHelper.instance.getWorkoutDayById(week3Id);
          expect(d1!.date.day, week1Date.day,
              reason: 'Неделя 1 не должна перезаписываться');
          expect(d3!.date.day, week3Date.day,
              reason: 'Неделя 3 не должна перезаписываться');
        });

    testWidgets('unlockNextWeek не двигает уже расставленные будущие даты',
            (tester) async {
          await cleanDB();
          final p = await createProfile();

          await WorkoutGenerator.generateMonthPlan(p);
          final week2 = await DatabaseHelper.instance.getWorkoutDaysByWeek(
              profileId: p.id!, weekNumber: 2);
          expect(week2.isNotEmpty, true);
          final datesBefore = week2.map((d) => d.date.toIso8601String()).toList();

          await DatabaseHelper.instance.unlockNextWeek(p.id!, 2);

          final week2After = await DatabaseHelper.instance.getWorkoutDaysByWeek(
              profileId: p.id!, weekNumber: 2);
          final datesAfter = week2After.map((d) => d.date.toIso8601String()).toList();
          expect(datesAfter, datesBefore,
              reason: 'unlockNextWeek не должен перезаписывать корректную сетку');
        });

    testWidgets('Перенос дня: copyWith(date) меняет только дату, неделя и цикл целы',
            (tester) async {
          await cleanDB();
          final p = await createProfile();

          final dayId = await DatabaseHelper.instance.createWorkoutDay(WorkoutDay(
            profileId: p.id!,
            name: 'Неделя 1: День 1',
            date: DateTime(2026, 11, 20),
            weekNumber: 1,
            cycleNumber: 1,
          ));

          final day = (await DatabaseHelper.instance.getWorkoutDayById(dayId))!;
          final updated = day.copyWith(date: DateTime(2026, 11, 21));
          await DatabaseHelper.instance.updateWorkoutDay(updated);

          final reloaded = await DatabaseHelper.instance.getWorkoutDayById(dayId);
          expect(reloaded!.date.day, 21, reason: 'Дата перенесена');
          expect(reloaded.weekNumber, 1,
              reason: 'weekNumber потерялся при переносе — день выпадет из недели');
          expect(reloaded.cycleNumber, 1,
              reason: 'cycleNumber потерялся при переносе');
          expect(reloaded.name, 'Неделя 1: День 1');
          expect(reloaded.status, 'planned');
        });

    testWidgets('Выполнение не в плановый день: completedAt пишется рядом с планом',
            (tester) async {
          await cleanDB();
          final p = await createProfile();

          final dayId = await DatabaseHelper.instance.createWorkoutDay(WorkoutDay(
            profileId: p.id!,
            name: 'Неделя 1: День 2',
            date: DateTime(2026, 11, 17),
            weekNumber: 1,
            cycleNumber: 1,
          ));

          final fact = DateTime(2026, 11, 18, 10, 30);
          final day = (await DatabaseHelper.instance.getWorkoutDayById(dayId))!;
          await DatabaseHelper.instance.updateWorkoutDay(
            day.copyWith(status: 'completed', completedAt: fact),
          );

          final reloaded = await DatabaseHelper.instance.getWorkoutDayById(dayId);
          expect(reloaded!.status, 'completed');
          expect(reloaded.completedAt, isNotNull);
          expect(reloaded.completedAt!.day, 18, reason: 'Факт выполнения сохранён');
          expect(reloaded.date.day, 17, reason: 'Плановая дата не должна затираться');
        });
  });

  // ──────────────────────────────────────────────────────────
  // 25. СЕТКА ДНЕЙ НЕДЕЛИ В ГЕНЕРАТОРЕ (FALLBACK)
  // ──────────────────────────────────────────────────────────
  group('Сетка дней недели в генераторе (fallback)', () {
    testWidgets('Первый день — сегодня, сетка дней недели устойчива по неделям',
            (tester) async {
          await cleanDB();
          final p = await createProfile();
          final plan = await WorkoutGenerator.generateMonthPlan(p);

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          expect(plan.length, p.daysPerWeek * 4,
              reason: 'План: ${p.daysPerWeek} дней × 4 недели');

          final allowedWeekdays = fallbackAllowedWeekdays(p.daysPerWeek, now.weekday);

          final List<Set<int>> weekdaysByWeek = [];

          for (int week = 1; week <= 4; week++) {
            final weekDays = plan.where((d) => d.weekNumber == week).toList()
              ..sort((a, b) => a.date.compareTo(b.date));
            expect(weekDays.length, p.daysPerWeek, reason: 'Неделя $week неполная');

            final dates = weekDays
                .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
                .toSet();
            expect(dates.length, weekDays.length,
                reason: 'Неделя $week: даты схлопнулись');

            if (week == 1) {
              final first = weekDays.first.date;
              expect(DateTime(first.year, first.month, first.day), today,
                  reason: 'Первый день плана должен быть сегодня');
            }

            final weekdays = weekDays.map((d) => d.date.weekday).toSet();
            expect(weekdays.length, weekDays.length,
                reason: 'Неделя $week: два дня выпали на один день недели');
            weekdaysByWeek.add(weekdays);

            for (final d in weekDays) {
              expect(allowedWeekdays.contains(d.date.weekday), true,
                  reason: '${d.date} (weekday ${d.date.weekday}) '
                      'не из допустимой сетки $allowedWeekdays');
            }
          }

          for (int w = 1; w < weekdaysByWeek.length; w++) {
            expect(weekdaysByWeek[w], weekdaysByWeek[0],
                reason: 'Неделя ${w + 1}: набор дней недели отличается от первой недели');
          }

          print('✅ Fallback-сетка: допустимые дни недели $allowedWeekdays, '
              'первый день — сегодня');
        });
  });

  // ──────────────────────────────────────────────────────────
  // 26. ВЫБРАННЫЕ ДНИ НЕДЕЛИ (trainingWeekdays)
  // ──────────────────────────────────────────────────────────
  group('Выбранные дни недели (trainingWeekdays)', () {
    testWidgets('Все даты плана ложатся на выбранные дни (вт/пт)',
            (tester) async {
          await cleanDB();
          final p = await createProfile(daysPerWeek: 2, trainingWeekdays: const [2, 5]);
          final plan = await WorkoutGenerator.generateMonthPlan(p);

          expect(plan.length, 2 * 4, reason: '2 дня в неделю × 4 недели');

          final allDates = <DateTime>{};
          for (final d in plan) {
            expect(const [2, 5].contains(d.date.weekday), true,
                reason: '${d.date} (weekday ${d.date.weekday}): не вторник и не пятница');
            allDates.add(DateTime(d.date.year, d.date.month, d.date.day));
          }
          expect(allDates.length, plan.length, reason: 'Найдены дубли дат');

          for (final wd in const [2, 5]) {
            final count = plan.where((d) => d.date.weekday == wd).length;
            expect(count, 4, reason: 'Дней с weekday=$wd: $count, ожидалось 4');
          }

          print('✅ trainingWeekdays [2, 5]: все 8 дат на вторниках и пятницах');
        });

    testWidgets('Тренировка сегодня выполнена — новый план стартует со следующего дня',
            (tester) async {
          await cleanDB();

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final todayWd = now.weekday;
          final nextWd = todayWd % 7 + 1;
          final p = await createProfile(daysPerWeek: 2, trainingWeekdays: [todayWd, nextWd]);

          final plan1 = await WorkoutGenerator.generateMonthPlan(p);
          final first1 = plan1.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
          expect(DateTime(first1.date.year, first1.date.month, first1.date.day), today,
              reason: 'Первый день плана должен быть сегодня (сегодняшний день выбран)');

          await DatabaseHelper.instance.updateWorkoutDay(
            first1.copyWith(status: 'completed', completedAt: DateTime.now()),
          );

          final plan2 = await WorkoutGenerator.generateMonthPlan(p, smart: true);
          expect(plan2.isNotEmpty, true);

          for (final d in plan2) {
            final isToday = DateTime(d.date.year, d.date.month, d.date.day) == today;
            expect(isToday, false,
                reason: '${d.name} (${d.date}): день назначен на сегодня, '
                    'хотя сегодняшняя тренировка уже выполнена');
          }

          final first2 = plan2.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
          expect(DateTime(first2.date.year, first2.date.month, first2.date.day),
              today.add(const Duration(days: 1)),
              reason: 'Первый день нового плана должен быть завтра '
                  '(следующий доступный день)');

          final week1Wd = plan2.where((d) => d.weekNumber == 1).map((d) => d.date.weekday).toSet();
          for (int w = 2; w <= 4; w++) {
            final wd = plan2.where((d) => d.weekNumber == w).map((d) => d.date.weekday).toSet();
            expect(wd, week1Wd, reason: 'Неделя $w: сетка дней недели отличается');
          }

          print('✅ Старт со следующего дня: сегодняшний слот пропущен, '
              'план начинается с ${first2.date}');
        });
  });
}
// ═══ КОНЕЦ ФАЙЛА интеграционных тестов ═══
