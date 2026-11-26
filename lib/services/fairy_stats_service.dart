import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import '../models/workout_day.dart';

/// Считает статистику для феи: streak по неделям, последняя тренировка.
class FairyStatsService {
  static const _keyStreakWeeks = 'fairy_streak_weeks';
  static const _keyLastWorkout = 'fairy_last_workout_date';

  /// Записать, что сегодня была тренировка.
  /// Проверяет, завершена ли текущая неделя.
  static Future<int> recordWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly(DateTime.now());

    await prefs.setString(_keyLastWorkout, today.toIso8601String());

    // Пересчитываем streak по неделям
    return await recalculateWeeklyStreak();
  }

  /// Пересчитывает streak по неделям (пересоздаёт из БД).
  static Future<int> recalculateWeeklyStreak() async {
    final prefs = await SharedPreferences.getInstance();

    final profiles = await DatabaseHelper.instance.getProfiles();
    if (profiles.isEmpty) {
      await prefs.setInt(_keyStreakWeeks, 0);
      return 0;
    }

    final profile = profiles.first;
    final daysPerWeek = profile.daysPerWeek;

    // Получаем все дни (лимит 1000, чтобы захватить все циклы)
    final days = await DatabaseHelper.instance.getWorkoutDays(
      profileId: profile.id!,
      limit: 1000,
    );

    if (days.isEmpty) {
      await prefs.setInt(_keyStreakWeeks, 0);
      return 0;
    }

    // Группируем дни по циклу и неделе (например, ключ "1_2" = Цикл 1, Неделя 2)
    final Map<String, List<WorkoutDay>> weeks = {};
    for (final d in days) {
      if (d.cycleNumber == null || d.weekNumber == null) continue;
      final key = '${d.cycleNumber}_${d.weekNumber}';
      weeks.putIfAbsent(key, () => []).add(d);
    }

    // Сортируем ключи недель по порядку (сначала циклы, потом недели внутри них)
    final sortedWeekKeys = weeks.keys.toList()..sort((a, b) {
      final partsA = a.split('_').map(int.parse).toList();
      final partsB = b.split('_').map(int.parse).toList();
      if (partsA[0] != partsB[0]) return partsA[0].compareTo(partsB[0]);
      return partsA[1].compareTo(partsB[1]);
    });

    // Серия считается только до последней «активной» недели — той, где уже есть
    // хотя бы один выполненный или пропущенный день. Будущие недели плана
    // (со статусом planned) в подсчёт не попадают и серию не ломают.
    int lastActiveIndex = -1;
    for (int i = 0; i < sortedWeekKeys.length; i++) {
      final weekDays = weeks[sortedWeekKeys[i]]!;
      if (weekDays.any((d) => d.status == 'completed' || d.status == 'skipped')) {
        lastActiveIndex = i;
      }
    }

    // 👇 ДИАГНОСТИКА: печатаем состояние каждой недели
    print('FairyStreak: daysPerWeek=$daysPerWeek, недель всего=${sortedWeekKeys.length}, последняя активная=$lastActiveIndex');
    for (int i = 0; i <= lastActiveIndex; i++) {
      final weekDays = weeks[sortedWeekKeys[i]]!;
      final completedCount = weekDays.where((d) => d.status == 'completed').length;
      final skippedCount = weekDays.where((d) => d.status == 'skipped').length;
      print('FairyStreak: неделя ${sortedWeekKeys[i]} — completed=$completedCount, skipped=$skippedCount, всего дней=${weekDays.length}');
    }

    int streak = 0;

    for (int i = 0; i <= lastActiveIndex; i++) {
      final weekDays = weeks[sortedWeekKeys[i]]!;

      final completedCount = weekDays.where((d) => d.status == 'completed').length;
      final hasSkipped = weekDays.any((d) => d.status == 'skipped');

      // Неделя считается завершенной, если выполнено нужное кол-во дней и нет пропусков
      final isWeekComplete = completedCount >= daysPerWeek && !hasSkipped;

      if (isWeekComplete) {
        streak++;
      } else if (i == lastActiveIndex) {
        // Текущая неделя ещё в процессе — серию не ломаем и не наращиваем
        break;
      } else {
        // Прошлая неделя не закрыта или в ней был пропуск — серия прервана
        streak = 0;
        break;
      }
    }

    print('FairyStreak: итог series=$streak');

    await prefs.setInt(_keyStreakWeeks, streak);
    return streak;
  }

  /// Текущий streak (в неделях).
  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStreakWeeks) ?? 0;
  }

  /// Сколько дней с последней тренировки.
  static Future<int> daysSinceLastWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString(_keyLastWorkout);
    if (lastStr == null) return -1;
    final last = DateTime.parse(lastStr);
    final today = _dateOnly(DateTime.now());
    return today.difference(last).inDays;
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// Понедельник недели, в которую входит дата.
  static DateTime _mondayOfWeek(DateTime dt) {
    final monday = dt.subtract(Duration(days: dt.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }
}
