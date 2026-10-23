import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import '../models/workout_day.dart';
import '../models/exercise.dart';

// ═══════════════════════════════════════════════════════════
//  СВОДКА ПО ПРОШЛОЙ НЕДЕЛЕ
// ═══════════════════════════════════════════════════════════

class WeekSummary {
  final int completedCount;
  final int missedCount;
  final List<String> completedNames;
  final List<String> missedNames;
  final int totalMinutes;

  WeekSummary({
    required this.completedCount,
    required this.missedCount,
    required this.completedNames,
    required this.missedNames,
    required this.totalMinutes,
  });

  bool get isEmpty => completedCount == 0 && missedCount == 0;
  bool get isFullWeek => missedCount == 0 && completedCount > 0;
  bool get isLazyWeek => missedCount >= completedCount;

  String get recommendation {
    if (isEmpty) return '';
    if (isFullWeek) return '💡 Рекомендую повысить вес на 5% — отличная неделя!';
    if (missedCount >= 2) return '💡 Рекомендую понизить вес на 10% — чтобы вернуться в ритм';
    if (missedCount == 1) return '💡 Неплохо! Оставь вес как есть или +2.5 кг, если легко';
    return '';
  }
}

// ═══════════════════════════════════════════════════════════
//  ТРЕНД ПО УПРАЖНЕНИЮ
// ═══════════════════════════════════════════════════════════

enum TrendDirection { up, stagnation, down, new_ }

class ExerciseTrend {
  final int exerciseId;
  final String exerciseName;
  final double? avgValueThisWeek;
  final double? avgValuePrevWeek;
  final int timesUsed;
  final TrendDirection direction;
  final bool isWeightBased;
  final bool isCardio;
  final bool isTimed;

  ExerciseTrend({
    required this.exerciseId,
    required this.exerciseName,
    required this.avgValueThisWeek,
    required this.avgValuePrevWeek,
    required this.timesUsed,
    required this.direction,
    required this.isWeightBased,
    required this.isCardio,
    required this.isTimed,
  });

  String get unit {
    if (isCardio) return 'мин';
    if (isTimed) return 'сек';
    return isWeightBased ? 'кг' : 'повт.';
  }

  String get recommendation {
    if (!isWeightBased) {
      switch (direction) {
        case TrendDirection.up:
          return '📈 Результат больше! Отличный прогресс';
        case TrendDirection.stagnation:
          return '⏸ Стагнация — попробуй добавить время или темп';
        case TrendDirection.down:
          return '📉 Результат меньше — пересмотри технику или отдохни';
        case TrendDirection.new_:
          return '🆕 Новое упражнение — набирай форму';
      }
    }
    switch (direction) {
      case TrendDirection.up:
        return '📈 Растёт! Продолжай в том же темпе';
      case TrendDirection.stagnation:
        return '⏸ Стагнация — попробуй +2.5 кг';
      case TrendDirection.down:
        return '📉 Падает — снизь вес на 10% и пересмотри технику';
      case TrendDirection.new_:
        return '🆕 Новое упражнение — набирай форму';
    }
  }

  int get colorValue {
    switch (direction) {
      case TrendDirection.up:
        return 0xFF00B894;
      case TrendDirection.stagnation:
        return 0xFFFDCB6E;
      case TrendDirection.down:
        return 0xFFE17055;
      case TrendDirection.new_:
        return 0xFF6C5CE7;
    }
  }

  String get iconEmoji {
    switch (direction) {
      case TrendDirection.up:
        return '📈';
      case TrendDirection.stagnation:
        return '⏸';
      case TrendDirection.down:
        return '📉';
      case TrendDirection.new_:
        return '🆕';
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  АНАЛИЗАТОР
// ═══════════════════════════════════════════════════════════

class WeekAnalyzer {
  WeekAnalyzer._();

  static DateTime currentWeekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  static Future<WeekSummary> analyzeLastWeek(int profileId) async {
    final days = await DatabaseHelper.instance.getWorkoutDays(profileId: profileId, limit: 100);
    final thisMonday = currentWeekStart();
    final lastMonday = thisMonday.subtract(const Duration(days: 7));

    final lastWeek = days.where((d) {
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      return !dDate.isBefore(lastMonday) && dDate.isBefore(thisMonday);
    }).toList();

    final completed = lastWeek.where((d) => d.status == 'completed').toList();
    final missed = lastWeek.where((d) => d.status != 'completed').toList();
    final totalMinutes = completed.fold<int>(0, (sum, d) => sum + (d.durationMinutes ?? 0));

    return WeekSummary(
      completedCount: completed.length,
      missedCount: missed.length,
      completedNames: completed.map((d) => d.name).toList(),
      missedNames: missed.map((d) => d.name).toList(),
      totalMinutes: totalMinutes,
    );
  }

  static Future<Set<String>> completedInTwoWeeks(int profileId) async {
    final days = await DatabaseHelper.instance.getWorkoutDays(profileId: profileId, limit: 100);
    final thisMonday = currentWeekStart();
    final from = thisMonday.subtract(const Duration(days: 14));
    final to = thisMonday.add(const Duration(days: 7));
    final set = <String>{};
    for (final d in days) {
      if (d.status != 'completed') continue;
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      if (!dDate.isBefore(from) && dDate.isBefore(to)) set.add(d.name);
    }
    return set;
  }

  static Future<Set<int>> completedTemplateIdsInTwoWeeks(int profileId) async {
    final days = await DatabaseHelper.instance.getWorkoutDays(profileId: profileId, limit: 100);
    final thisMonday = currentWeekStart();
    final from = thisMonday.subtract(const Duration(days: 14));
    final to = thisMonday.add(const Duration(days: 7));
    final set = <int>{};
    for (final d in days) {
      if (d.status != 'completed' || d.templateId == null) continue;
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      if (!dDate.isBefore(from) && dDate.isBefore(to)) set.add(d.templateId!);
    }
    return set;
  }

  static Future<({Set<int> fullyDone, Set<int> partial})> workoutStatusInTwoWeeks(int profileId) async {
    final db = DatabaseHelper.instance;
    final days = await db.getWorkoutDays(profileId: profileId, limit: 100);
    final thisMonday = currentWeekStart();
    final from = thisMonday.subtract(const Duration(days: 14));
    final to = thisMonday.add(const Duration(days: 7));
    final fullyDone = <int>{};
    final partial = <int>{};

    for (final day in days) {
      if (day.templateId == null) continue;
      final dDate = DateTime(day.date.year, day.date.month, day.date.day);
      if (dDate.isBefore(from) || !dDate.isBefore(to)) continue;
      final exercises = await db.getWorkoutExercises(day.id!);
      if (exercises.isEmpty) continue;
      int totalSets = 0;
      int doneSets = 0;
      for (final we in exercises) {
        if (we.itemType != 'exercise' || we.isCoolDown) continue;
        for (final s in await db.getWorkoutSets(we.id!)) { totalSets++; if (s.completed) doneSets++; }
      }
      if (totalSets == 0) continue;
      if (doneSets == totalSets) fullyDone.add(day.templateId!);
      else if (doneSets > 0) partial.add(day.templateId!);
    }
    partial.removeAll(fullyDone);
    return (fullyDone: fullyDone, partial: partial);
  }

  static Future<int> missedLastWeek(int profileId) async => (await analyzeLastWeek(profileId)).missedCount;

  static Future<List<ExerciseTrend>> analyzeExerciseTrends(int profileId) async {
    final db = DatabaseHelper.instance;
    final days = await db.getWorkoutDays(profileId: profileId, limit: 200);
    if (days.isEmpty) return [];

    int maxCycle = 0;
    for (final d in days) {
      if (d.status == 'completed' && d.cycleNumber != null) {
        if (d.cycleNumber! > maxCycle) maxCycle = d.cycleNumber!;
      }
    }

    if (maxCycle == 0) return [];

    final currentCycleDays = days.where((d) => d.cycleNumber == maxCycle && d.status == 'completed').toList();
    bool hasWeek3 = currentCycleDays.any((d) => d.weekNumber == 3);

    if (!hasWeek3) return [];

    final week1Sets = <int, List<WorkoutSet>>{};
    final week3Sets = <int, List<WorkoutSet>>{};

    for (final day in currentCycleDays) {
      final exercises = await db.getWorkoutExercises(day.id!);
      for (final we in exercises) {
        if (we.itemType != 'exercise' || we.isCoolDown) continue;
        final exId = we.replacedByItemId ?? we.itemId;
        final sets = (await db.getWorkoutSets(we.id!)).where((s) => s.completed).toList();
        if (sets.isEmpty) continue;

        if (day.weekNumber == 1) {
          week1Sets.putIfAbsent(exId, () => []);
          week1Sets[exId]!.addAll(sets);
        } else if (day.weekNumber == 3) {
          week3Sets.putIfAbsent(exId, () => []);
          week3Sets[exId]!.addAll(sets);
        }
      }
    }

    final trends = <ExerciseTrend>[];
    final allExIds = {...week1Sets.keys, ...week3Sets.keys};

    for (final exId in allExIds) {
      final ex = await db.getExerciseById(exId);
      if (ex == null) continue;

      final sets1 = week1Sets[exId] ?? [];
      final sets3 = week3Sets[exId] ?? [];

      if (sets1.isEmpty && sets3.isEmpty) continue;

      final hasWeight = (sets1.isNotEmpty ? sets1.any((s) => s.weight != null && s.weight! > 0) : false) ||
                        (sets3.isNotEmpty ? sets3.any((s) => s.weight != null && s.weight! > 0) : false);

      double? avg1, avg3;

      if (hasWeight) {
        avg1 = _avg(sets1.where((s) => s.weight != null).map((s) => s.weight!));
        avg3 = _avg(sets3.where((s) => s.weight != null).map((s) => s.weight!));
      } else {
        avg1 = _avg(sets1.where((s) => s.reps != null).map((s) => s.reps!.toDouble()));
        avg3 = _avg(sets3.where((s) => s.reps != null).map((s) => s.reps!.toDouble()));
      }

      if (avg1 == null && avg3 != null) {
        avg1 = avg3;
      } else if (avg1 != null && avg3 == null) {
        avg3 = avg1;
      }

      TrendDirection dir;
      if (avg1 == null || avg3 == null) {
        dir = TrendDirection.new_;
      } else {
        final diff = avg3 - avg1;
        final threshold = hasWeight ? 1.0 : 1.5;
        if (diff >= threshold) dir = TrendDirection.up;
        else if (diff <= -threshold) dir = TrendDirection.down;
        else dir = TrendDirection.stagnation;
      }

      final isCardio = _isCardio(ex);
      final isTimed = _isTimed(ex.name);

      trends.add(ExerciseTrend(
        exerciseId: exId, exerciseName: ex.name,
        avgValueThisWeek: avg3, avgValuePrevWeek: avg1,
        timesUsed: sets1.length + sets3.length, direction: dir, isWeightBased: hasWeight,
        isCardio: isCardio, isTimed: isTimed,
      ));
    }

    trends.sort((a, b) {
      int order(TrendDirection d) {
        if (d == TrendDirection.up) return 0;
        if (d == TrendDirection.new_) return 1;
        if (d == TrendDirection.stagnation) return 2;
        return 3;
      }
      final cmp = order(a.direction).compareTo(order(b.direction));
      if (cmp != 0) return cmp;
      return (b.avgValueThisWeek ?? 0).compareTo(a.avgValueThisWeek ?? 0);
    });

    return trends;
  }

  static double? _avg(Iterable<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // 👇 ИСПРАВЛЕННЫЕ МЕТОДЫ ОПРЕДЕЛЕНИЯ ТИПА
  static bool _isCardio(Exercise ex) {
    final lower = ex.name.toLowerCase();

    if (lower.contains('бег') || lower.contains('дорожк') || lower.contains('скакалк') ||
        lower.contains('эллипс') || lower.contains('велотренаж') || lower.contains('велоэргометр') ||
        lower.contains('гребл') || lower.contains('степпер') || lower.contains('кардио') ||
        lower.contains('канат') || lower.contains('скалолаз')) {
      return true;
    }

    final coreGroups = ['abs', 'core', 'obliques'];
    if (ex.muscleGroups.any((m) => coreGroups.contains(m))) return false;

    return ex.muscleGroups.contains('cardio');
  }

  static bool _isTimed(String name) {
    final lower = name.toLowerCase();
    return lower.contains('планка') || lower.contains('plank') || _isCardioName(lower) ||
           lower.contains('канат') || lower.contains('скалолаз');
  }

  static bool _isCardioName(String lowerName) {
    return lowerName.contains('бег') || lowerName.contains('дорожк') || lowerName.contains('скакалк') ||
        lowerName.contains('эллипс') || lowerName.contains('велотренаж') || lowerName.contains('велоэргометр') ||
        lowerName.contains('гребл') || lowerName.contains('степпер') || lowerName.contains('кардио');
  }
}