// Тест v21: ограничения здоровья (knees).
// 1) Карта ограничения → зоны работает: knees блокирует legs и glutes.
// 2) exerciseBlockedByLimitations отсекает упражнения с 'knees'
//    в contraindications (зональная блокировка — отдельный механизм).
// 3) Сгенерированный месяц плана для профиля с knees не содержит
//    ни одного заблокированного упражнения (по противопоказаниям ИЛИ зоне).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:workout_tracker/data/base_exercises.dart';
import 'package:workout_tracker/models/exercise.dart';
import 'package:workout_tracker/models/user_profile.dart';
import 'package:workout_tracker/services/database_helper.dart';
import 'package:workout_tracker/services/workout_generator.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String basePath;
  _FakePathProvider(this.basePath);

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;

  @override
  Future<String?> getTemporaryPath() async => basePath;

  @override
  Future<String?> getApplicationSupportPath() async => basePath;
}

UserProfile _kneesProfile(int id) {
  return UserProfile(
    id: id,
    name: 'Knees Tester',
    gender: 'female',
    age: 30,
    height: 170,
    weight: 60,
    level: 'beginner',
    goal: 'fitness',
    equipment: 'none',
    daysPerWeek: 3,
    sessionMinutes: 45,
    trainingWeekdays: [1, 3, 5],
    focusAreas: [],
    limitations: ['knees'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('knees_test_db_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.syncExercises();
  });


  tearDownAll(() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.close();
    } catch (_) {}
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Карта ограничения knees → зоны', () {
    test('knees блокирует legs и glutes', () {
      final zones = zonesBlockedByLimitations(['knees']);
      expect(zones, contains('legs'));
      expect(zones, contains('glutes'));
    });

    test('knees НЕ блокирует верх тела и пресс', () {
      final zones = zonesBlockedByLimitations(['knees']);
      expect(zones, isNot(contains('chest')));
      expect(zones, isNot(contains('back')));
      expect(zones, isNot(contains('arms')));
      expect(zones, isNot(contains('shoulders')));
      expect(zones, isNot(contains('abs')));
      expect(zones, isNot(contains('knees')));
    });

    test('пустые ограничения — пустой список зон', () {
      expect(zonesBlockedByLimitations([]), isEmpty);
    });
  });

  group('exerciseBlockedByLimitations', () {
    test('блокирует упражнение с knees в противопоказаниях', () {
      final exercise = Exercise(
        name: 'Тест-упражнение для рук',
        muscleGroups: ['arms'],
        contraindications: ['knees'],
        equipment: [],
      );
      expect(exerciseBlockedByLimitations(exercise, ['knees']), isTrue);
    });

    test('пропускает безопасное упражнение', () {
      final safe = Exercise(
        name: 'Тест-отжимания',
        muscleGroups: ['chest'],
        contraindications: ['shoulders'],
        equipment: [],
      );
      expect(exerciseBlockedByLimitations(safe, ['knees']), isFalse);
    });

    test('комбинированный предикат: зона legs + knees = блок', () {
      // Зональная блокировка — ответственность генератора/экранов,
      // поэтому проверяем итоговое правило целиком.
      final exercise = Exercise(
        name: 'Тест-упражнение для ног',
        muscleGroups: ['legs'],
        contraindications: [],
        equipment: [],
      );
      final zonesBlocked = zonesBlockedByLimitations(['knees']);
      final blocked = exerciseBlockedByLimitations(exercise, ['knees']) ||
          exercise.muscleGroups.any((z) => zonesBlocked.contains(z.toLowerCase()));
      expect(blocked, isTrue);
    });
  });

  group('Месяц плана для профиля с knees', () {
    test('ни одно заблокированное упражнение не попало в план', () async {
      final profile = _kneesProfile(999);
      final insertedId = await DatabaseHelper.instance.addProfile(profile);

      final days = await WorkoutGenerator.generateMonthPlan(
        profile.copyWith(id: insertedId),
        smart: true,
      );
      expect(days, isNotEmpty, reason: 'План не должен быть пустым');
      // ── ДИАГНОСТИКА 2 (лёгкая): что внутри объекта дня ──
      for (final day in days.take(2)) {
        print('День: ${day.toString()}');
      }
      // ── конец диагностики ──

      // ── ДИАГНОСТИКА ──
      print('Всего дней в плане: ${days.length}');
      for (final day in days.take(3)) {
        final items = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        print('День id=${day.id}, date=${day.date}: '
            'items=${items.length}, '
            'types=${items.map((i) => i.itemType).toSet().toList()}');
        if (items.isNotEmpty) {
          final first = items.first;
          print('  Первый элемент: type=${first.itemType}, '
              'itemId=${first.itemId}');
        }
      }
      // ── конец диагностики ──

      final blockedZones = zonesBlockedByLimitations(['knees']);
      int checked = 0;

      for (final day in days) {
        final items = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        for (final item in items) {
          if (item.itemType != 'exercise') continue;
          final ex = await DatabaseHelper.instance.getExerciseById(item.itemId);
          if (ex == null) continue;
          checked++;

          final blocked = exerciseBlockedByLimitations(ex, ['knees']) ||
              ex.muscleGroups.any((z) => blockedZones.contains(z.toLowerCase()));

          expect(
            blocked,
            isFalse,
            reason: 'Упражнение "${ex.name}" (зоны: ${ex.muscleGroups.join(", ")}, '
                'противопоказания: ${ex.contraindications.join(", ")}) не должно '
                'попасть в план при ограничении knees',
          );
        }
      }

      expect(checked, greaterThan(0), reason: 'В плане должны быть упражнения');
    });


    test('забытые зоны не содержат заблокированных зон', () {
      final profile = _kneesProfile(999);
      final blockedZones = zonesBlockedByLimitations(profile.limitations);
      final focusZones = profile.focusAreas.map((e) => e.toLowerCase()).toList();
      final allZones = ['chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'];

      final forgottenZones = allZones
          .where((z) => !blockedZones.contains(z) && !focusZones.contains(z))
          .toList();

      expect(forgottenZones, isNot(contains('legs')));
      expect(forgottenZones, isNot(contains('glutes')));
      expect(forgottenZones, contains('chest'));
      expect(forgottenZones, contains('abs'));
    });
  });
}
