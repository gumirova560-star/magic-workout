import 'package:shared_preferences/shared_preferences.dart';

/// Считает статистику для феи: streak, последняя тренировка.
class FairyStatsService {
  static const _keyStreak = 'fairy_streak';
  static const _keyLastWorkout = 'fairy_last_workout_date';

  /// Записать, что сегодня была тренировка.
  /// Возвращает обновлённый streak.
  static Future<int> recordWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly(DateTime.now());
    final lastStr = prefs.getString(_keyLastWorkout);

    int streak = prefs.getInt(_keyStreak) ?? 0;

    if (lastStr == null) {
      // Первая тренировка
      streak = 1;
    } else {
      final last = DateTime.parse(lastStr);
      final diff = today.difference(last).inDays;

      if (diff == 0) {
        // Уже тренировался сегодня — ничего не меняем
        return streak;
      } else if (diff == 1) {
        // Вчера была — streak + 1
        streak += 1;
      } else {
        // Пропуск — сброс
        streak = 1;
      }
    }

    await prefs.setInt(_keyStreak, streak);
    await prefs.setString(_keyLastWorkout, today.toIso8601String());
    return streak;
  }

  /// Текущий streak.
  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString(_keyLastWorkout);
    if (lastStr == null) return 0;

    final last = DateTime.parse(lastStr);
    final today = _dateOnly(DateTime.now());
    final diff = today.difference(last).inDays;

    // Если больше 1 дня — streak сброшен
    if (diff > 1) return 0;

    return prefs.getInt(_keyStreak) ?? 0;
  }

  /// Сколько дней с последней тренировки.
  static Future<int> daysSinceLastWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString(_keyLastWorkout);
    if (lastStr == null) return -1; // Никогда
    final last = DateTime.parse(lastStr);
    final today = _dateOnly(DateTime.now());
    return today.difference(last).inDays;
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}