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
import 'package:workout_tracker/services/week_analyzer.dart'; // 👈 НОВОЕ: для диагностики пропусков
import 'package:workout_tracker/models/user_profile.dart';
import 'package:workout_tracker/models/workout_day.dart';
import 'package:workout_tracker/models/exercise.dart';
import 'package:workout_tracker/data/base_exercises.dart';
import 'package:workout_tracker/screens/garden/garden_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────────────────
  // ХЕЛПЕРЫ
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
  }) async {
    final p = UserProfile(
      name: name, gender: gender, age: 30, height: 180, weight: 80,
      level: level, goal: goal, equipment: equipment,
      daysPerWeek: daysPerWeek, sessionMinutes: 45,
      focusAreas: focusAreas, limitations: limitations,
      createdAt: DateTime.now(),
    );
    p.id = await DatabaseHelper.instance.addProfile(p);
    return p;
  }

  bool isWeightExercise(Exercise ex) {
    final lower = ex.name.toLowerCase();
    if (lower.contains('бег') || lower.contains('дорожк') ||
        lower.contains('скакалк') || lower.contains('эллипс') ||
        lower.contains('планка') || lower.contains('стульчик')) return false;
    if (ex.muscleGroups.contains('cardio')) return false;
    return true;
  }

  // 👈 НОВОЕ: обычные силовые с сетами «по уровню» — исключаем кардио и
  // спец-форматы (скакалка/бой с тенью/берпи всегда 3 сета, кардио 1)
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
        await cleanDB();
        final profile = await createGymProfile();

        print('\n╔══════════════════════════════════════════════╗');
        print('║  ТЕСТ: 4 МЕСЯЦА ТРЕНИРОВОК (16 НЕДЕЛЬ)       ║');
        print('╚══════════════════════════════════════════════╝');

        const double baseWeightStart = 20.0;
        final Map<String, double> lastWeightByFamily = {};
        int totalDays = 0;
        int totalChallengeDays = 0;
        int totalStrengthDays = 0;

        for (int cycle = 1; cycle <= 4; cycle++) {
          final plan = await WorkoutGenerator.generateMonthPlan(profile);
          totalDays += plan.length;

          final challenges = plan.where((d) => d.type == 'challenge').toList();
          totalChallengeDays += challenges.length;
          expect(challenges.length, greaterThanOrEqualTo(1));

          // Проверка дублей внутри дня + сбор семейств по дням для кросс-дневной проверки
          int daysWithDuplicates = 0;
          final planDays = [...plan]..sort((a, b) => a.date.compareTo(b.date));
          final List<Set<String>> familiesByDay = [];
          for (final day in planDays) {
            final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            final families = <String>{};
            for (final we in exs) {
              if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
              final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
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

          // 👈 ИСПРАВЛЕНО: вместо абсолютного порога — доля повторов в соседних днях.
          // Легальные фолбэки (пул зоны исчерпан) допускаются; деградация до
          // «каждый день одно и то же» — нет.
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
                final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
                if (ex == null || !isWeightExercise(ex)) continue;
                final fam = getExerciseFamily(ex.name);
                final expected = lastWeightByFamily[fam];
                if (expected == null) continue;
                final sets = await DatabaseHelper.instance.getWorkoutSets(we.id!);
                final weights = sets.where((s) => s.weight != null && s.weight! > 0).map((s) => s.weight!).toList();
                if (weights.isEmpty) continue;
                final maxW = weights.reduce((a, b) => a > b ? a : b);
                expect(maxW, greaterThanOrEqualTo(expected));
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
              final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
              if (ex == null || !isWeightExercise(ex)) continue;
              final fam = getExerciseFamily(ex.name);
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
              lastWeightByFamily[fam] = targetWeight;
            }
            await DatabaseHelper.instance.updateWorkoutDay(
              day.copyWith(status: 'completed', completedAt: DateTime.now()),
            );
          }
        }

        expect(totalDays, greaterThanOrEqualTo(48));
        expect(totalChallengeDays, greaterThanOrEqualTo(4));
        // 👈 НОВОЕ: totalStrengthDays теперь используется по назначению
        expect(totalStrengthDays, greaterThanOrEqualTo(44),
            reason: 'Силовых дней должно быть не меньше 44 за 4 цикла');
        final maxFinalWeight = lastWeightByFamily.values.reduce((a, b) => a > b ? a : b);
        expect(maxFinalWeight, greaterThan(baseWeightStart + 5));
        print('✅ Прогрессия: $baseWeightStart → $maxFinalWeight кг');
      });

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
                final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
                if (ex == null) continue;

                // Инвентарь
                expect(WorkoutGenerator.matchesEquipment(ex, p.equipment), true,
                    reason: '${p.equipment}: "${ex.name}" требует не тот инвентарь');

                // Уровень
                if (p.level == 'beginner') {
                  expect(ex.difficulty, isNot('advanced'),
                      reason: 'Новичку дали advanced: ${ex.name}');
                }

                // 👈 ИСПРАВЛЕНО: та же логика подстрок, что и в генераторе
                // (c.contains(b) || b.contains(c)), иначе тест слабее генератора
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
    testWidgets('Планка: 60 → 80 → 100 → 60 (intermediate)', (tester) async {
      await cleanDB();
      final p = await createProfile();
      final plan = await WorkoutGenerator.generateMonthPlan(p);

      final expectedByWeek = {1: 60, 2: 80, 3: 100, 4: 60};
      int checked = 0;

      for (final day in plan.where((d) => d.type == 'strength')) {
        final week = day.weekNumber ?? 1;
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        for (final we in exs) {
          if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
          final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
          if (ex == null || !isTimedExercise(ex.name)) continue;

          final reps = RegExp(r'(\d+)').firstMatch(we.reps);
          final secs = int.tryParse(reps?.group(1) ?? '');
          if (secs == null) continue;

          // 👈 ИСПРАВЛЕНО: боковая планка получает 0.7 от базовой нормы
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
    });

    testWidgets('Планка beginner: 30 → 40 → 50 → 30', (tester) async {
      await cleanDB();
      final p = await createProfile(level: 'beginner', equipment: 'bodyweight');
      final plan = await WorkoutGenerator.generateMonthPlan(p);
      final expected = {1: 30, 2: 40, 3: 50, 4: 30};

      for (final day in plan.where((d) => d.type == 'strength')) {
        final week = day.weekNumber ?? 1;
        final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        for (final we in exs) {
          if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
          final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
          if (ex == null || !isTimedExercise(ex.name)) continue;
          final reps = RegExp(r'(\d+)').firstMatch(we.reps);
          final secs = int.tryParse(reps?.group(1) ?? '');
          if (secs == null) continue;
          // 👈 ИСПРАВЛЕНО: учтён коэффициент боковой планки
          final isSidePlank = ex.name.toLowerCase().contains('боковая планка');
          final expectedSecs = isSidePlank
              ? (expected[week]! * 0.7).round()
              : expected[week]!;
          expect(secs, expectedSecs, reason: '${ex.name}, week $week');
        }
      }
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
              // 👈 ИСПРАВЛЕНО: проверяем только обычные силовые — кардио всегда
              // 1 сет, скакалка/берпи/бой с тенью всегда 3, независимо от уровня
              final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
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

      // 👈 ИСПРАВЛЕНО: помечаем пропущенными дни с ПРОШЕДШЕЙ датой —
      // WeekAnalyzer считает пропуски по датам за последние дни
      final now = DateTime.now();
      final skipped = plan1.where((d) => d.weekNumber == 3).take(2).toList();
      for (final day in skipped) {
        await DatabaseHelper.instance.updateWorkoutDay(
          day.copyWith(
            status: 'skipped',
            date: now.subtract(const Duration(days: 3)),
          ),
        );
      }

      // 👈 НОВОЕ: диагностика — видит ли анализатор наши пропуски
      final missed = await WeekAnalyzer.missedLastWeek(p.id!);
      print('🔍 missedLastWeek = $missed (ожидалось >= 2)');

      final plan2 = await WorkoutGenerator.generateMonthPlan(p, smart: true);
      final week1 = plan2.firstWhere((d) => d.weekNumber == 1 && d.type == 'strength');
      final exs = await DatabaseHelper.instance.getWorkoutExercises(week1.id!);
      bool found = false;
      for (final we in exs) {
        if (we.isWarmup || we.isCoolDown) continue;
        // 👈 ИСПРАВЛЕНО: тот же фильтр обычных силовых
        final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
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
          final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
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

    testWidgets('Удаление возвращает энергию', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final profileId = p.id!;
      await GardenService.buyFlowerAtSlot(profileId: profileId, slotIndex: 0);

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
          final candidate = allEx.firstWhere((e) =>
          e.id != toReplace.itemId && isBaseExercise(e));

          await DatabaseHelper.instance.replaceExerciseInMonth(
            profileId: profileId,
            oldItemId: toReplace.itemId,
            newItemId: candidate.id!,
            reason: 'too_hard',
            permanent: true,
          );

          for (final day in plan) {
            final dayExs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
            // 👈 ИСПРАВЛЕНО: строка с replacedByItemId считается заменённой —
            // приложение читает её как newItemId (replacedByItemId ?? itemId)
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

      // 👈 ИСПРАВЛЕНО: результат первого прогона не сохраняем в переменную
      // (он не используется — анализатор ругался на `first`)
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
            // 👈 ИСПРАВЛЕНО: firstWhere бросает StateError с невнятным сообщением —
            // проверяем наличие порядка явно
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
      expect(() => WorkoutGenerator.generateMonthPlan(bad), throwsA(isA<Exception>()));
    });

    testWidgets('Покупка без энергии — цветок не появляется', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      final before = (await GardenService.getGarden(p.id!)).length;
      final success = await GardenService.buyFlowerAtSlot(profileId: p.id!, slotIndex: 0);
      expect(success, false);
      final after = (await GardenService.getGarden(p.id!)).length;
      expect(after, before);
    });

    testWidgets('Перемещение на занятую клетку → UNIQUE-конфликт',
            (tester) async {
          await cleanDB();
          final p = await createGymProfile();
          await GardenService.plantNextFlower(profileId: p.id!, flowerType: 'normal');
          await GardenService.plantNextFlower(profileId: p.id!, flowerType: 'normal');
          final garden = await GardenService.getGarden(p.id!);
          final occupied = garden.first['slotIndex'] as int;

          expect(
                () => GardenService.moveItem(p.id!, garden.last['slotIndex'] as int, occupied),
            throwsA(anything),
          );
        });
  });

  // ──────────────────────────────────────────────────────────
  // 15. UI: WIDGET-ТЕСТЫ
  // ──────────────────────────────────────────────────────────
  group('Widget-тесты UI', () {
    testWidgets('GardenScreen: тап по пустой клетке → меню', (tester) async {
      await cleanDB();
      final p = await createGymProfile();
      await tester.pumpWidget(MaterialApp(home: GardenScreen(profileId: p.id!)));
      // 👈 ИСПРАВЛЕНО: ждём асинхронную загрузку экрана
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final cells = find.byType(GestureDetector);
      if (cells.evaluate().isNotEmpty) {
        await tester.tap(cells.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 👈 ИСПРАВЛЕНО: ищем подстроку — не зависим от точного текста кнопки
        final menu = find.textContaining('лотос', findRichText: true);
        if (menu.evaluate().isEmpty) {
          print('🔍 Меню открылось, но текста с "лотос" нет — проверь реальный label');
        }
        expect(menu, findsWidgets,
            reason: 'После тапа по пустой клетке не нашли меню с «лотос»');
      }
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
  // 16. МИГРАЦИИ БД (skip — нужен отдельный инстанс)
  // ──────────────────────────────────────────────────────────
  group('Миграции БД', () {
    // ⚠️ НЕЛЬЗЯ протестировать через DatabaseHelper.instance (синглтон уже на 17).
    // Для реального теста нужен отдельный openDatabase с version: 16.
    // 👈 ИСПРАВЛЕНО: testWidgets принимает только skip: bool, без строки —
    // причина пропуска живёт в комментарии; fail сработает, если когда-нибудь
    // уберут skip и тест начнёт выполняться молча
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
            final ex = await DatabaseHelper.instance.getExerciseById(we.itemId);
            if (ex != null && isBaseExercise(ex)) bases1.add(ex.id!);
          }
        }
      }
      expect(bases1.length, greaterThan(0));

      // 👈 НОВОЕ: базы недели 4 цикла 1 должны сохраниться в цикле 2
      // (allow_base_change по умолчанию false → baseToKeepByDay)
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
}
