import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'fairy_stats_service.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int target;
  final String type;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.type,
  });
}

class AchievementService {
  static const List<Achievement> allAchievements = [
    // === Тренировки ===
    Achievement(
      id: 'first_workout',
      title: 'Первый шаг',
      description: 'Завершите первую тренировку',
      icon: '🥇',
      target: 1,
      type: 'workouts',
    ),
    Achievement(
      id: 'five_workouts',
      title: 'В ритме',
      description: 'Завершите 5 тренировок',
      icon: '🔥',
      target: 5,
      type: 'workouts',
    ),
    Achievement(
      id: 'twenty_workouts',
      title: 'Марафонец',
      description: 'Завершите 20 тренировок',
      icon: '🏃',
      target: 20,
      type: 'workouts',
    ),
    // === Йога ===
    Achievement(
      id: 'first_yoga',
      title: 'Дзен',
      description: 'Завершите первую йога-сессию',
      icon: '🧘',
      target: 1,
      type: 'yoga',
    ),
    // === Дни подряд ===
    Achievement(
      id: 'streak_3',
      title: 'Стабильность',
      description: 'Тренируйтесь 3 дня подряд',
      icon: '⚡',
      target: 3,
      type: 'streak',
    ),
    // === Недели подряд (по плану) ===
    Achievement(
      id: 'week_streak_1',
      title: 'Неделя силы',
      description: 'Выполните всю неделю по плану',
      icon: '📅',
      target: 1,
      type: 'week_streak',
    ),
    Achievement(
      id: 'week_streak_2',
      title: 'Две недели дисциплины',
      description: 'Выполняйте план 2 недели подряд',
      icon: '🗓️',
      target: 2,
      type: 'week_streak',
    ),
    Achievement(
      id: 'week_streak_4',
      title: 'Месяц силы',
      description: 'Выполняйте план 4 недели подряд',
      icon: '🏆',
      target: 4,
      type: 'week_streak',
    ),
    Achievement(
      id: 'week_streak_12',
      title: 'Квартал чемпиона',
      description: '3 месяца без пропусков',
      icon: '👑',
      target: 12,
      type: 'week_streak',
    ),
    // === Подходы ===
    Achievement(
      id: 'sets_100',
      title: 'Трудяга',
      description: 'Выполните 100 подходов',
      icon: '💪',
      target: 100,
      type: 'sets',
    ),
  ];

  static const String _keyPrefix = 'achievement_unlocked_';

  /// Проверяет все достижения и возвращает те, которые только что открылись
  static Future<List<Achievement>> checkAchievements(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final newlyUnlocked = <Achievement>[];

    // Получаем статистику
    final streak = await FairyStatsService.getStreak();
    final weekStreak = await getWeekStreak(profileId);

    final history = await DatabaseHelper.instance.getWorkoutDays(profileId: profileId, limit: 1000);
    final completedWorkouts = history.where((d) => d.status == 'completed').toList();
    final totalWorkouts = completedWorkouts.length;
    final totalYoga = completedWorkouts.where((d) => d.type == 'yoga').length;

    int totalSets = 0;
    for (final day in completedWorkouts) {
      final exercises = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
      for (final ex in exercises) {
        final sets = await DatabaseHelper.instance.getWorkoutSets(ex.id!);
        totalSets += sets.where((s) => s.completed).length;
      }
    }

    // Проверяем каждый бейдж
    for (final ach in allAchievements) {
      final isUnlocked = prefs.getBool('$_keyPrefix${ach.id}') ?? false;

      if (!isUnlocked) {
        bool earned = false;
        switch (ach.type) {
          case 'workouts': earned = totalWorkouts >= ach.target; break;
          case 'yoga': earned = totalYoga >= ach.target; break;
          case 'streak': earned = streak >= ach.target; break;
          case 'week_streak': earned = weekStreak >= ach.target; break;
          case 'sets': earned = totalSets >= ach.target; break;
        }

        if (earned) {
          await prefs.setBool('$_keyPrefix${ach.id}', true);
          newlyUnlocked.add(ach);
        }
      }
    }

    return newlyUnlocked;
  }

  /// Получить список всех достижений с их статусом (открыто/закрыто)
  static Future<List<Map<String, dynamic>>> getAchievementsWithStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return allAchievements.map((a) {
      final isUnlocked = prefs.getBool('$_keyPrefix${a.id}') ?? false;
      return {
        'achievement': a,
        'isUnlocked': isUnlocked,
      };
    }).toList();
  }

  /// Считает количество последовательных недель, где выполнены ВСЕ тренировки из плана.
  static Future<int> getWeekStreak(int profileId) async {
    final profile = await DatabaseHelper.instance.getProfileById(profileId);
    if (profile == null) return 0;

    // 1. Узнаем план (сколько тренировок нужно на неделе)
    final targetDays = profile.daysPerWeek > 0 ? profile.daysPerWeek : 1;

    // 2. Берем все завершенные тренировки
    final history = await DatabaseHelper.instance.getWorkoutDays(profileId: profileId, limit: 1000);
    final completed = history.where((d) => d.status == 'completed').toList();
    if (completed.isEmpty) return 0;

    // 3. Группируем по неделям (считаем уникальные дни тренировок)
    final Map<String, Set<int>> weekDays = {};
    for (final day in completed) {
      final weekKey = '${day.date.year}-${_getWeekOfYear(day.date)}';
      weekDays.putIfAbsent(weekKey, () => {});
      weekDays[weekKey]!.add(day.date.day);
    }

    // 4. Оставляем только те недели, где выполнено >= плана
    final validWeeks = weekDays.entries
        .where((e) => e.value.length >= targetDays)
        .map((e) => e.key)
        .toList()..sort();

    if (validWeeks.isEmpty) return 0;

    final now = DateTime.now();
    int checkYear = now.year;
    int checkWeek = _getWeekOfYear(now);

    int streak = 0;

    // ⚠️ ПРОВЕРЯЕМ И ТЕКУЩУЮ НЕДЕЛЮ!
    // Если план выполнен (например, 2 тренировки за 2 дня), бейдж выскочит сразу.
    while (true) {
      final key = '$checkYear-$checkWeek';
      if (validWeeks.contains(key)) {
        streak++;
        checkWeek--;
        if (checkWeek == 0) {
          checkYear--;
          checkWeek = 52;
        }
      } else {
        break; // Если нашли неделю, где не выполнен план — серия прервана
      }
    }

    return streak;
  }

  /// ⚠️ Сброс всех достижений (для тестов)
  static Future<void> resetAllAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    for (final a in allAchievements) {
      await prefs.remove('$_keyPrefix${a.id}');
    }
  }

  static int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = firstDayOfYear.weekday - 1;
    return ((date.difference(firstDayOfYear).inDays + daysOffset) / 7).ceil();
  }
}