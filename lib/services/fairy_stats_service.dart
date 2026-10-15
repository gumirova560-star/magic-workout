import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

/// Считает статистику для феи: streak по неделям, последняя тренировка.
class FairyStatsService {
  static const _keyStreakWeeks = 'fairy_streak_weeks';
  static const _keyLastWorkout = 'fairy_last_workout_date';

  /// Записать, что сегодня была тренировка.
  /// Проверяет, завершена ли текущая неделя.
  /// Возвращает обновлённый streak (в неделях).
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

    // Получаем все завершённые дни за последние 52 недели
    final days = await DatabaseHelper.instance.getWorkoutDays(
      profileId: profile.id!,
      limit: 500,
    );

    final completedDays = days
        .where((d) => d.status == 'completed')
        .map((d) => _dateOnly(d.date))
        .toList();

    // ═══ Считаем streak: идём от прошлой недели назад ═══
    int streak = 0;
    DateTime weekStart = _mondayOfWeek(DateTime.now());

    // Идём по неделям назад
    for (int i = 0; i < 52; i++) {
      // Текущая неделя — ещё не закончилась, пропускаем (не считаем её)
      if (i == 0) {
        weekStart = weekStart.subtract(const Duration(days: 7));
        continue;
      }

      final weekEnd = weekStart.add(const Duration(days: 7));
      final count = completedDays
          .where((d) => !d.isBefore(weekStart) && d.isBefore(weekEnd))
          .length;

      if (count >= daysPerWeek) {
        streak++;
      } else {
        break;
      }

      weekStart = weekStart.subtract(const Duration(days: 7));
    }

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