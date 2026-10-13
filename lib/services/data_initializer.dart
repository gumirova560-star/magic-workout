import '../data/exercises_data.dart';
import '../data/stretches_data.dart';
import '../data/yoga_data.dart';
import '../models/yoga_session.dart';
import 'database_helper.dart';

/// Наполняет базу данных начальными данными.
/// Вызывается один раз — при первом запуске приложения.
class DataInitializer {
  static Future<void> initialize() async {
    final db = DatabaseHelper.instance;

    // ═══ Принудительно открываем базу до runApp ═══
    // Это устраняет гонку на Web, когда экраны стартуют раньше базы
    await db.database;
    print('🔥 База открыта');

    // ═══ Проверяем, есть ли уже данные ═══
    final isEmpty = await db.isDatabaseEmpty();
    if (!isEmpty) {
      print('✅ База данных уже заполнена');
      return;
    }

    print('⏳ Первая инициализация базы...');

    // ═══ 1. Силовые упражнения (73) ═══
    final exercises = getExercisesData();
    for (final exercise in exercises) {
      await db.addExercise(exercise);
    }
    print('✅ Загружено упражнений: ${exercises.length}');

    // ═══ 2. Растяжка + йога + дыхание (55) ═══
    final stretches = getStretchesData();
    for (final stretch in stretches) {
      await db.addStretch(stretch);
    }
    print('✅ Загружено растяжек/йоги: ${stretches.length}');

    // ═══ 3. Йога-сессии (7) + шаги ═══
    final sessions = getYogaSessionsData();
    final stepsData = getYogaStepsData();

    for (int i = 0; i < sessions.length; i++) {
      final sessionId = await db.addYogaSession(sessions[i]);

      if (i < stepsData.length) {
        final steps = stepsData[i];
        for (int j = 0; j < steps.length; j++) {
          final stepData = steps[j];

          final stretch = await db.getStretchByName(stepData.stretchName);
          if (stretch?.id == null) {
            print('⚠️ Поза не найдена: ${stepData.stretchName}');
            continue;
          }

          await db.addYogaStep(YogaStep(
            sessionId: sessionId,
            stretchId: stretch!.id!,
            order: j + 1,
            durationSeconds: stepData.durationSeconds,
            bothSides: stepData.bothSides,
            notes: stepData.notes,
          ));
        }
      }
    }
    print('✅ Загружено йога-сессий: ${sessions.length}');

    print('🎉 База данных готова к работе!');
  }
}