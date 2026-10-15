import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import '../models/workout_day.dart';

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

    if (isFullWeek) {
      return '💡 Рекомендую повысить вес на 5% — отличная неделя!';
    }

    if (missedCount >= 2) {
      return '💡 Рекомендую понизить вес на 10% — чтобы вернуться в ритм';
    }

    if (missedCount == 1) {
      return '💡 Неплохо! Оставь вес как есть или +2.5 кг, если легко';
    }

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

  ExerciseTrend({
    required this.exerciseId,
    required this.exerciseName,
    required this.avgValueThisWeek,
    required this.avgValuePrevWeek,
    required this.timesUsed,
    required this.direction,
    required this.isWeightBased,
  });

  String get unit => isWeightBased ? 'кг' : 'повт.';

  String get recommendation {
    if (!isWeightBased) {
      switch (direction) {
        case TrendDirection.up:
          return '📈 Повторений больше! Отличный прогресс';
        case TrendDirection.stagnation:
          return '⏸ Стагнация — попробуй +2 повторения';
        case TrendDirection.down:
          return '📉 Меньше повторений — пересмотри технику';
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

  // ═══ Прошлая неделя ═══

  static Future<WeekSummary> analyzeLastWeek(int profileId) async {
    final days = await DatabaseHelper.instance.getWorkoutDays(
      profileId: profileId,
      limit: 100,
    );

    final thisMonday = currentWeekStart();
    final lastMonday = thisMonday.subtract(const Duration(days: 7));

    final lastWeek = days.where((d) {
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      return !dDate.isBefore(lastMonday) && dDate.isBefore(thisMonday);
    }).toList();

    final completed = lastWeek.where((d) => d.status == 'completed').toList();
    final missed = lastWeek.where((d) => d.status != 'completed').toList();

    final totalMinutes = completed.fold<int>(
      0,
      (sum, d) => sum + (d.durationMinutes ?? 0),
    );

    return WeekSummary(
      completedCount: completed.length,
      missedCount: missed.length,
      completedNames: completed.map((d) => d.name).toList(),
      missedNames: missed.map((d) => d.name).toList(),
      totalMinutes: totalMinutes,
    );
  }

  // ═══ Выполненные ID ═══

  static Future<Set<String>> completedInTwoWeeks(int profileId) async {
    final days = await DatabaseHelper.instance.getWorkoutDays(
      profileId: profileId,
      limit: 100,
    );

    final thisMonday = currentWeekStart();
    final from = thisMonday.subtract(const Duration(days: 14));
    final to = thisMonday.add(const Duration(days: 7));

    final set = <String>{};
    for (final d in days) {
      if (d.status != 'completed') continue;
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      final inWindow = !dDate.isBefore(from) && dDate.isBefore(to);
      if (inWindow) set.add(d.name);
    }
    return set;
  }

  static Future<Set<int>> completedTemplateIdsInTwoWeeks(int profileId) async {
    final days = await DatabaseHelper.instance.getWorkoutDays(
      profileId: profileId,
      limit: 100,
    );

    final thisMonday = currentWeekStart();
    final from = thisMonday.subtract(const Duration(days: 14));
    final to = thisMonday.add(const Duration(days: 7));

    final set = <int>{};
    for (final d in days) {
      if (d.status != 'completed') continue;
      if (d.templateId == null) continue;
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      final inWindow = !dDate.isBefore(from) && dDate.isBefore(to);
      if (inWindow) set.add(d.templateId!);
    }
    return set;
  }

  // ═══════════════════════════════════════════════════════════
  //  ⚠️ СТАТУС ВЫПОЛНЕНИЯ ПО ШАБЛОНАМ (по сетам!)
  // ═══════════════════════════════════════════════════════════
  //
  //  Для каждого дня считаем:
  //    totalSets — сколько всего подходов во всех «настоящих»
  //                упражнениях (itemType == 'exercise', не coolDown).
  //    doneSets  — сколько из них completed.
  //
  //  Возвращаем две группы templateId:
  //    fullyDone — все подходы отмечены (done == total).
  //    partial   — часть отмечена (0 < done < total).
  //
  //  ⚠️ Не смотрим на day.status — потому что день может быть
  //     'completed', но внутри не все подходы отмечены.

  static Future<({Set<int> fullyDone, Set<int> partial})>
      workoutStatusInTwoWeeks(int profileId) async {
    final db = DatabaseHelper.instance;

    final days = await db.getWorkoutDays(
      profileId: profileId,
      limit: 100,
    );

    final thisMonday = currentWeekStart();
    final from = thisMonday.subtract(const Duration(days: 14));
    final to = thisMonday.add(const Duration(days: 7));

    final fullyDone = <int>{};
    final partial = <int>{};

    for (final day in days) {
      if (day.templateId == null) continue;

      final dDate = DateTime(day.date.year, day.date.month, day.date.day);
      final inWindow = !dDate.isBefore(from) && dDate.isBefore(to);
      if (!inWindow) continue;

      final exercises = await db.getWorkoutExercises(day.id!);
      if (exercises.isEmpty) continue;

      int totalSets = 0;
      int doneSets = 0;

      for (final we in exercises) {
        if (we.itemType != 'exercise') continue;
        if (we.isCoolDown) continue;

        final sets = await db.getWorkoutSets(we.id!);
        for (final s in sets) {
          totalSets++;
          if (s.completed) doneSets++;
        }
      }

      if (totalSets == 0) continue;

      debugPrint('📊 day=${day.id} tmpl=${day.templateId} '
          'name="${day.name}" status=${day.status} '
          'sets=$doneSets/$totalSets');

      if (doneSets == totalSets) {
        fullyDone.add(day.templateId!);
      } else if (doneSets > 0) {
        partial.add(day.templateId!);
      }
    }

    // ⚠️ Полное выполнение важнее частичного
    partial.removeAll(fullyDone);

    return (fullyDone: fullyDone, partial: partial);
  }

  static Future<int> missedLastWeek(int profileId) async {
    final summary = await analyzeLastWeek(profileId);
    return summary.missedCount;
  }

  // ═══════════════════════════════════════════════════════════
  //  АНАЛИЗ ТРЕНДОВ ПО УПРАЖНЕНИЯМ (с логами)
  // ═══════════════════════════════════════════════════════════

  static Future<List<ExerciseTrend>> analyzeExerciseTrends(
    int profileId,
  ) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 analyzeExerciseTrends: profileId=$profileId');

    final db = DatabaseHelper.instance;
    final days = await db.getWorkoutDays(profileId: profileId, limit: 100);

    debugPrint('🔍 Всего дней: ${days.length}');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week1Start = today.subtract(const Duration(days: 7));
    final week2Start = today.subtract(const Duration(days: 14));

    debugPrint('🔍 Сегодня: $today');
    debugPrint('🔍 Week1: $week1Start .. $today');
    debugPrint('🔍 Week2: $week2Start .. $week1Start');

    // ═══ Собираем записи ═══
    final records = <int, List<_SetRecord>>{};

    for (final day in days) {
      debugPrint('🔍 Day id=${day.id} status=${day.status} '
          'name="${day.name}" date=${day.date}');
      if (day.status != 'completed') {
        debugPrint('   ⏭ Пропущен (не completed)');
        continue;
      }

      final exercises = await db.getWorkoutExercises(day.id!);
      debugPrint('   🔍 Упражнений в дне: ${exercises.length}');

      for (final we in exercises) {
        if (we.itemType != 'exercise' || we.isCoolDown) {
          debugPrint('   ⏭ weId=${we.id} пропущен (type=${we.itemType}, '
              'coolDown=${we.isCoolDown})');
          continue;
        }
        final exId = we.replacedByItemId ?? we.itemId;
        debugPrint('   🔍 weId=${we.id} exId=$exId');

        final sets = await db.getWorkoutSets(we.id!);
        for (final s in sets) {
          debugPrint('      🔍 set id=${s.id} weight=${s.weight} '
              'reps=${s.reps} completed=${s.completed}');
          if (!s.completed) {
            debugPrint('      ⏭ пропущен (completed=false)');
            continue;
          }
          if (s.weight == null && s.reps == null) {
            debugPrint('      ⏭ пропущен (weight и reps = null)');
            continue;
          }

          records.putIfAbsent(exId, () => []);
          records[exId]!.add(_SetRecord(
            date: day.date,
            weight: s.weight,
            reps: s.reps,
          ));
          debugPrint('      ✅ добавлен');
        }
      }
    }

    debugPrint('🔍 ИТОГО записей: ${records.length} упражнений');
    for (final e in records.entries) {
      debugPrint('   exId=${e.key} → ${e.value.length} записей');
    }

    // ═══ Считаем тренд ═══
    final trends = <ExerciseTrend>[];

    for (final entry in records.entries) {
      final exId = entry.key;
      final recs = entry.value;

      if (recs.length < 2) {
        debugPrint('   ⏭ exId=$exId пропущен (< 2 записей)');
        continue;
      }

      final hasWeight = recs.any((r) => r.weight != null);
      debugPrint('   🔍 exId=$exId hasWeight=$hasWeight '
          '(всего ${recs.length} записей)');

      final week1 = recs
          .where((r) =>
              !r.date.isBefore(week1Start) && !r.date.isAfter(today))
          .toList();

      final week2 = recs
          .where((r) =>
              !r.date.isBefore(week2Start) && r.date.isBefore(week1Start))
          .toList();

      debugPrint('      week1: ${week1.length} записей');
      debugPrint('      week2: ${week2.length} записей');

      double? avg1;
      double? avg2;

      if (hasWeight) {
        avg1 = _avg(
            week1.where((r) => r.weight != null).map((r) => r.weight!));
        avg2 = _avg(
            week2.where((r) => r.weight != null).map((r) => r.weight!));
      } else {
        avg1 = _avg(week1
            .where((r) => r.reps != null)
            .map((r) => r.reps!.toDouble()));
        avg2 = _avg(week2
            .where((r) => r.reps != null)
            .map((r) => r.reps!.toDouble()));
      }

      debugPrint('      avg1=$avg1, avg2=$avg2');

      TrendDirection dir;
      if (avg1 == null || avg2 == null) {
        dir = TrendDirection.new_;
      } else {
        final diff = avg1 - avg2;
        final threshold = hasWeight ? 2.5 : 2.0;
        debugPrint('      diff=$diff, threshold=$threshold');
        if (diff >= threshold) {
          dir = TrendDirection.up;
        } else if (diff <= -threshold) {
          dir = TrendDirection.down;
        } else {
          dir = TrendDirection.stagnation;
        }
      }

      final ex = await db.getExerciseById(exId);
      if (ex == null) {
        debugPrint('   ⏭ exId=$exId — упражнение не найдено в БД');
        continue;
      }

      debugPrint('   ✅ Тренд: "${ex.name}" dir=$dir');

      trends.add(ExerciseTrend(
        exerciseId: exId,
        exerciseName: ex.name,
        avgValueThisWeek: avg1,
        avgValuePrevWeek: avg2,
        timesUsed: recs.length,
        direction: dir,
        isWeightBased: hasWeight,
      ));
    }

    debugPrint('🔍 ИТОГО трендов: ${trends.length}');
    debugPrint('═══════════════════════════════════════');

    trends.sort((a, b) {
      int order(TrendDirection d) {
        switch (d) {
          case TrendDirection.up:
            return 0;
          case TrendDirection.new_:
            return 1;
          case TrendDirection.stagnation:
            return 2;
          case TrendDirection.down:
            return 3;
        }
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
}

// ═══════════════════════════════════════════════════════════
//  ВНУТРЕННЯЯ МОДЕЛЬ
// ═══════════════════════════════════════════════════════════

class _SetRecord {
  final DateTime date;
  final double? weight;
  final int? reps;

  _SetRecord({required this.date, this.weight, this.reps});
}