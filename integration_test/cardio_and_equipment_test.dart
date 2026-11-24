// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:workout_tracker/services/database_helper.dart';
import 'package:workout_tracker/services/workout_generator.dart';
import 'package:workout_tracker/models/user_profile.dart';
import 'package:workout_tracker/models/workout_day.dart';
import 'package:workout_tracker/models/exercise.dart';
import 'package:workout_tracker/screens/workout/workout_detail_screen.dart';
import 'package:workout_tracker/data/base_exercises.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Детерминированная генерация — как в основном тесте
  WorkoutGenerator.setSeed(12345);

  // ───────────────── ХЕЛПЕРЫ ─────────────────

  Future<void> cleanDB() async {
    // Список таблиц — из основного теста. exercise_replacements здесь нет:
    // такой таблицы в базе нет, DELETE по ней ронял тест с "no such table".
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

  Future<UserProfile> createProfile({
    String name = 'Test',
    String level = 'intermediate',
    String equipment = 'gym',
    String goal = 'tone',
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
    // Профиль обязан быть в базе: без id генератор падает с «Profile ID обязателен»
    p.id = await DatabaseHelper.instance.addProfile(p);
    return p;
  }

  bool isCardioLike(Exercise e) {
    final lower = e.name.toLowerCase();
    const cardioWords = [
      'бег', 'дорожк', 'скакалк', 'эллипс', 'велотренаж',
      'велоэргометр', 'гребл', 'степпер', 'кардио', 'скалолаз',
    ];
    if (cardioWords.any((w) => lower.contains(w))) return true;
    if (lower.contains('канат') &&
        (lower.contains('махи') ||
            lower.contains('волны') ||
            lower.contains('бэтл'))) {
      return true;
    }
    const coreGroups = ['abs', 'core', 'obliques'];
    if (e.muscleGroups.any((m) => coreGroups.contains(m))) return false;
    return e.muscleGroups.contains('cardio');
  }

  Future<List<Exercise>> dayExercises(WorkoutDay day) async {
    final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
    final result = <Exercise>[];
    for (final we in exs) {
      if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
      final ex = await DatabaseHelper.instance
          .getExerciseById(we.replacedByItemId ?? we.itemId);
      if (ex != null) result.add(ex);
    }
    return result;
  }

  Future<List<Exercise>> allPlanExercises(UserProfile p) async {
    final plan = await WorkoutGenerator.generateMonthPlan(p);
    final result = <Exercise>{};
    for (final day in plan) {
      result.addAll(await dayExercises(day));
    }
    return result.toList();
  }

  void checkNoWords(List<Exercise> exs, List<String> words, String label) {
    final offenders = <String>[];
    for (final ex in exs) {
      final lower = ex.name.toLowerCase();
      for (final w in words) {
        if (lower.contains(w)) {
          offenders.add('${ex.name} (слово «$w»)');
          break;
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '$label: в план попали упражнения, не подходящие '
            'по инвентарю: ${offenders.join('; ')}');
  }

  Future<void> checkCardioCounts(
      UserProfile p, {
        required int expected,
        bool forbidCardio = false,
      }) async {
    final plan = await WorkoutGenerator.generateMonthPlan(p);
    expect(plan, isNotEmpty);

    for (final day in plan) {
      if (day.type == 'challenge') continue;
      final exs = await dayExercises(day);
      final cardio = exs.where(isCardioLike).toList();

      if (forbidCardio) {
        expect(cardio, isEmpty,
            reason: '${day.name}: при силе/массе кардио не должно '
                'попадать в план, а попало: ${cardio.map((e) => e.name).join(', ')}');
        continue;
      }

      final isCardioOnlyDay = exs.isNotEmpty && exs.every(isCardioLike);
      if (isCardioOnlyDay) {
        expect(cardio.length, inInclusiveRange(2, 6),
            reason: '${day.name}: на кардио-дне должно быть 2–6 кардио, '
                'а было ${cardio.length}');
      } else {
        expect(cardio.length, expected,
            reason: '${day.name}: ожидалось $expected кардио, '
                'а было ${cardio.length}');
      }
    }
  }

  /// Помечает день выполненным и пишет фактический результат —
  /// «Прошлый раз: 20 кг × 15 повт.» на следующей неделе должен показать именно его.
  Future<void> completeDayWithRecord(WorkoutDay day) async {
    final updated =
    day.copyWith(status: 'completed', completedAt: DateTime.now());
    await DatabaseHelper.instance.updateWorkoutDay(updated);

    final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
    for (final we in exs) {
      if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
      await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
        workoutExerciseId: we.id!,
        order: 1,
        weight: 20,
        reps: 15,
        completed: true,
      ));
    }
  }

  /// Ждёт, пока экран долирузится: крутит pump, пока на экране спиннер.
  /// Гарантированно выходит не дольше maxIterations — тест не зависнет,
  /// если спиннер не исчезает или его никогда не было.
  Future<void> pumpUntilLoaded(WidgetTester tester,
      {int maxIterations = 20}) async {
    for (int i = 0; i < maxIterations; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
  }

  /// Диагностический дамп: печатает все тексты на экране.
  /// По нему видно, загрузился ли экран, есть ли карточки изоляций
  /// и в каком формате рендерятся плашки.
  void dumpScreen(WidgetTester tester, String label) {
    final texts = tester.widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    print('═══ $label: ${texts.length} текстов ═══');
    for (final t in texts.take(40)) {
      print('  • $t');
    }
  }

  /// Растягивает тестовый вьюпорт, чтобы CustomScrollView построил все
  /// карточки (ленивый SliverList строит только видимое).
  void bigViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 16000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  setUp(() async {
    await cleanDB();
    // 👇 Обновляем каталог упражнений: добавляет недостающие кардио,
    // обновляет поля существующих, id истории не ломает.
    await DatabaseHelper.instance.syncExercises();
  });

  // ───────────────── ДИАГНОСТИКА КАРДИО-БАЗЫ ─────────────────

  group('Дамп кардио из базы', () {
    test('печать всех кардио-упражнений с атрибутами', () async {
      final exs = await DatabaseHelper.instance.getExercises();
      const words = [
        'бег', 'дорожк', 'скакалк', 'эллипс', 'велотренаж',
        'гребл', 'степпер', 'кардио', 'скалолаз', 'джеки',
        'берпи', 'бой с тенью',
      ];
      final cardio = exs
          .where((e) => words.any((w) => e.name.toLowerCase().contains(w)))
          .toList();
      print('кардио в базе: ${cardio.length}');
      for (final e in cardio) {
        print('${e.name} | eq=${e.equipment} | diff=${e.difficulty} | groups=${e.muscleGroups}');
      }
      // Дамп-тест не должен падать: он печатает, а не проверяет
      expect(cardio, isNotEmpty);
    });
  });

  // ───────────────── КАРДИО-НОРМЫ ПО ЦЕЛЯМ ─────────────────

  group('Кардио-нормы по целям', () {
    test('Похудение intermediate: по 3 кардио в силовых днях', () async {
      final profile = await createProfile(
          level: 'intermediate', equipment: 'gym', goal: 'lose_weight');
      await checkCardioCounts(profile, expected: 3);
    });

    test('Похудение beginner: по 2 кардио в силовых днях', () async {
      final profile = await createProfile(
          level: 'beginner', equipment: 'bodyweight', goal: 'lose_weight');
      await checkCardioCounts(profile, expected: 2);
    });

    test('Тон intermediate: по 1 кардио в силовых днях', () async {
      final profile = await createProfile(
          level: 'intermediate', equipment: 'gym', goal: 'tone');
      await checkCardioCounts(profile, expected: 1);
    });

    test('Сила: кардио в план не попадает', () async {
      final profile = await createProfile(
          level: 'intermediate', equipment: 'gym', goal: 'strength');
      await checkCardioCounts(profile, expected: 0, forbidCardio: true);
    });

    test('Масса: кардио в план не попадает', () async {
      final profile = await createProfile(
          level: 'advanced', equipment: 'gym', goal: 'gain_mass');
      await checkCardioCounts(profile, expected: 0, forbidCardio: true);
    });
  });

  // ───────────────── ИНВЕНТАРЬ ─────────────────

  group('Инвентарь: запрещённые слова в названиях', () {
    /// «Домашние» упражнения, недопустимые в зале и смешанном режиме.
    const gymForbidden = [
      'полотенц', 'мячик', 'пальц', 'внешней стороны стопы', 'вакуум',
      'танц', 'бой с тенью', 'джеки', 'джампинг джек',
    ];

    /// Тренажёры и тяжёлый инвентарь — недопустимы дома.
    const homeForbidden = [
      'тренажер', 'тренажёр', 'блок', 'кроссовер', 'смит', 'т-гриф',
      'бабочка', 'тумбу', 'тумба', 'платформ', 'паттерн', 'босу',
      'полусфер', 'жим ногами', 'гакк',
    ];

    test('Зал: нет упражнений для дома', () async {
      final profile = await createProfile(
          level: 'intermediate', equipment: 'gym', goal: 'tone');
      checkNoWords(await allPlanExercises(profile), gymForbidden, 'Зал');
    });

    test('Смешанный: нет упражнений для дома', () async {
      final profile = await createProfile(
          level: 'intermediate', equipment: 'mixed', goal: 'tone');
      checkNoWords(await allPlanExercises(profile), gymForbidden, 'Смешанный');
    });

    test('Свой вес: нет инвентаря вообще', () async {
      final profile = await createProfile(
          level: 'beginner', equipment: 'bodyweight', goal: 'tone');
      checkNoWords(
          await allPlanExercises(profile),
          [...homeForbidden, 'гантел', 'штанг', 'гирей', 'блин', 'гриф', 'резинк'],
          'Свой вес');
    });

    test('Гантели: нет штанги, гири, блинов, тренажёров', () async {
      final profile = await createProfile(
          level: 'intermediate', equipment: 'dumbbells', goal: 'tone');
      checkNoWords(await allPlanExercises(profile),
          [...homeForbidden, 'штанг', 'гирей', 'блин', 'гриф'], 'Гантели');
    });
  });

  // ───────────────── ПЛАШКИ НА ЭКРАНЕ ТРЕНИРОВКИ ─────────────────

  group('Плашки на экране тренировки', () {
    testWidgets('Неделя 1: у изоляций без истории плашка «Новое упражнение»',
            (tester) async {
          bigViewport(tester); // 👈 растягиваем вьюпорт ДО pumpWidget
          await cleanDB();
          final p = await createProfile(
              level: 'intermediate', equipment: 'gym', goal: 'tone');

          final plan = await WorkoutGenerator.generateMonthPlan(p);
          final day1 = plan.firstWhere((d) => d.weekNumber == 1 && d.type == 'strength');

          await tester.pumpWidget(MaterialApp(
            home: WorkoutDetailScreen(workoutDay: day1, profileId: p.id!),
          ));
          await pumpUntilLoaded(tester);
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 800));

          dumpScreen(tester, 'Неделя 1');

          expect(find.text('Новое упражнение'), findsWidgets,
              reason: 'В первом цикле у изоляций нет истории — должна быть '
                  'плашка «Новое упражнение»');
          expect(find.textContaining('Прошлый раз:'), findsNothing);
        });

    testWidgets('Неделя 2: у изоляции с сеянной историей плашка «Прошлый раз»',
            (tester) async {
          bigViewport(tester); // 👈 растягиваем вьюпорт ДО pumpWidget
          await cleanDB();
          final p = await createProfile(
              level: 'intermediate', equipment: 'gym', goal: 'tone');

          final plan = await WorkoutGenerator.generateMonthPlan(p);
          final day2 = plan.firstWhere((d) => d.weekNumber == 2 && d.type == 'strength');

          // Сеем историю в неделю 1 ТОГО ЖЕ цикла: день с теми же упражнениями,
          // что в day2, и сетами 20 кг × 15. _getSmartPrevSets найдёт её
          // через прошлую неделю, _lastRecords наполнится — плашка обязана быть.
          final histDay = WorkoutDay(
            profileId: p.id!,
            name: 'День 1 (история)',
            type: 'strength',
            weekNumber: 1,
            cycleNumber: 1,
            status: 'completed',
            durationMinutes: 45,
            date: DateTime.now().subtract(const Duration(days: 7)),
          );
          final histDayId = await DatabaseHelper.instance.createWorkoutDay(histDay);

          final exs = await DatabaseHelper.instance.getWorkoutExercises(day2.id!);
          int seeded = 0;
          for (final we in exs) {
            if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) continue;
            final histExId = await DatabaseHelper.instance.addWorkoutExercise(
              WorkoutExercise(
                workoutDayId: histDayId,
                itemType: 'exercise',
                itemId: we.replacedByItemId ?? we.itemId,
                order: seeded + 1,
                sets: 3,
                reps: '15',
              ),
            );
            await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
              workoutExerciseId: histExId,
              order: 1,
              weight: 20,
              reps: 15,
              completed: true,
            ));
            seeded++;
          }
          print('засеяно упражнений: $seeded');
          expect(seeded, greaterThan(0), reason: 'В дне должны быть упражнения');

          await tester.pumpWidget(MaterialApp(
            home: WorkoutDetailScreen(workoutDay: day2, profileId: p.id!),
          ));
          await pumpUntilLoaded(tester);
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 800));

          dumpScreen(tester, 'Прошлый раз (сеянная история)');

          expect(find.textContaining('Прошлый раз:'), findsWidgets,
              reason: 'У изоляций с историей недели 1 должна быть плашка '
                  'с прошлым результатом');
          expect(find.textContaining('20 кг × 15 повт.'), findsWidgets);
          expect(find.textContaining('твоя Фея'), findsWidgets);
        });

    testWidgets('Циклы 2–4: у повторившихся изоляций плашка без сеяния',
            (tester) async {
          bigViewport(tester); // 👈 растягиваем вьюпорт один раз на весь тест
          await cleanDB();
          final p = await createProfile(
              level: 'intermediate', equipment: 'gym', goal: 'tone');

          // ── Цикл 1: выполняем все силовые дни с рекордом 20×15 ──
          final plan1 = await WorkoutGenerator.generateMonthPlan(p);
          for (final d in plan1.where((d) => d.type == 'strength')) {
            await completeDayWithRecord(d);
          }

          // ── Циклы 2–4: на каждом считаем повторы изоляций и плашки ──
          for (int cycle = 2; cycle <= 4; cycle++) {
            final plan = await WorkoutGenerator.generateMonthPlan(p);

            // Снимаем изоляции всех силовых дней цикла (не-базы, не-кардио)
            final isolationIdsByDay = <int, Set<int>>{};
            final exNames = <int, String>{};
            for (final d in plan.where((d) => d.type == 'strength')) {
              final exs = await DatabaseHelper.instance.getWorkoutExercises(d.id!);
              for (final we in exs) {
                if (we.itemType != 'exercise' || we.isWarmup || we.isCoolDown) {
                  continue;
                }
                final exId = we.replacedByItemId ?? we.itemId;
                final ex = await DatabaseHelper.instance.getExerciseById(exId);
                if (ex == null) continue;
                exNames[exId] = ex.name;
                if (!isBaseExercise(ex) && !isCardioLike(ex)) {
                  isolationIdsByDay.putIfAbsent(d.id!, () => {}).add(exId);
                }
              }
            }

            // Историю считаем ДО выполнения дней этого цикла — иначе
            // создадим совпадения сами себе
            final day = plan.firstWhere((d) =>
            d.cycleNumber == cycle && d.weekNumber == 1 && d.type == 'strength');
            final dayIsoIds = isolationIdsByDay[day.id] ?? {};
            int withHistory = 0;
            for (final exId in dayIsoIds) {
              final sets = await DatabaseHelper.instance.getLastWorkoutExerciseSets(
                  profileId: p.id!, exerciseId: exId);
              if (sets.isNotEmpty) {
                withHistory++;
                print('  цикл $cycle: изоляция с историей — ${exNames[exId] ?? exId}');
              }
            }
            print('── цикл $cycle: изоляций в дне ${dayIsoIds.length}, '
                'с историей $withHistory');

            await tester.pumpWidget(MaterialApp(
              home: WorkoutDetailScreen(workoutDay: day, profileId: p.id!),
            ));
            await pumpUntilLoaded(tester);
            await tester.pump(const Duration(seconds: 1));
            await tester.pump(const Duration(milliseconds: 800));

            dumpScreen(tester, 'Цикл $cycle, неделя 1');

            final hasBanner =
                find.textContaining('Прошлый раз:').evaluate().isNotEmpty;
            print('── цикл $cycle: плашка «Прошлый раз» на экране: $hasBanner');

            // Сходимость экрана с базой: если изоляции с историей есть,
            // плашки обязаны появиться; если нет — отсутствие плашек ожидаемо
            if (withHistory > 0) {
              expect(hasBanner, isTrue,
                  reason: 'Цикл $cycle: есть $withHistory изоляций с историей, '
                      'но плашки «Прошлый раз» на экране нет');
            } else {
              print('── цикл $cycle: ни одна изоляция не повторилась — '
                  'плашек нет, это ожидаемо');
            }

            // Чистим виджет-дерево перед следующим циклом
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 300));

            // Выполняем все силовые дни — следующий цикл получит полную историю
            for (final d in plan.where((d) => d.type == 'strength')) {
              await completeDayWithRecord(d);
            }
          }
        });
  });
}
