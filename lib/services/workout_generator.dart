import 'dart:math';
import '../models/exercise.dart';
import '../models/stretch.dart';
import '../models/user_profile.dart';
import '../models/workout_day.dart';
import 'database_helper.dart';
import 'week_analyzer.dart';

class WorkoutGenerator {
  static final Random _random = Random();

  static const Map<String, String> _aliasMap = {
    'плечи': 'shoulders', 'спина': 'back', 'колени': 'knees', 'шея': 'neck',
    'поясница': 'lower_back', 'локти': 'elbows', 'запястья': 'wrists',
    'бёдра': 'hips', 'голеностоп': 'ankles', 'ягодицы': 'glutes',
    'пресс': 'abs', 'косые': 'obliques', 'руки': 'arms', 'бицепс': 'biceps',
    'трицепс': 'triceps', 'ноги': 'legs', 'голень': 'calves', 'стопы': 'feet',
    'широчайшие': 'lats', 'трапеции': 'traps', 'грудь': 'chest',
    'кор': 'core', 'кардио': 'cardio',
  };

  static const Map<String, List<String>> _zoneExpand = {
    'arms': ['arms', 'biceps', 'triceps'],
    'legs': ['legs', 'quads', 'hamstrings', 'calves'],
    'back': ['back', 'lats', 'traps', 'lower_back'],
    'core': ['core', 'abs', 'obliques', 'lower_back'],
    'abs': ['abs', 'obliques'],
    'chest': ['chest'],
    'glutes': ['glutes', 'hamstrings'],
    'shoulders': ['shoulders', 'traps'],
    'calves': ['calves', 'legs'],
    'feet': ['feet', 'calves'],
  };

  static String _norm(String s) => _aliasMap[s] ?? s;

  static Set<String> _expandGroups(List<String> groups) {
    final result = <String>{};
    for (final g in groups) {
      final norm = _norm(g);
      final expanded = _zoneExpand[norm];
      if (expanded != null) result.addAll(expanded);
      else result.add(norm);
    }
    return result;
  }

  static Set<String> _buildBlockedZones(List<String> limitations) {
    final blocked = <String>{};
    for (final lim in limitations) {
      blocked.add(_norm(lim));
    }
    return blocked;
  }

  static Future<List<WorkoutDay>> generateMonthPlan(UserProfile profile, {bool smart = true}) async {
    if (profile.id == null) throw Exception('Profile ID обязателен');

    final maxCycle = await DatabaseHelper.instance.getMaxCycleNumber(profile.id!);
    final newCycle = maxCycle + 1;

    // Ищем базовые из прошлого цикла (Неделя 4)
    final List<Exercise> baseToKeep = [];
    if (maxCycle > 0) {
      final prevWeeks = await DatabaseHelper.instance.getWorkoutDaysByWeek(
          profileId: profile.id!, weekNumber: 4, cycleNumber: maxCycle);
      if (prevWeeks.isNotEmpty) {
        for (final pd in prevWeeks) {
          final exs = await DatabaseHelper.instance.getWorkoutExercises(pd.id!);
          for (final we in exs) {
            if (we.itemType == 'exercise' && !we.isCoolDown) {
              final ex = await DatabaseHelper.instance.getExerciseById(we.replacedByItemId ?? we.itemId);
              if (ex != null && _isCompound(ex) && !baseToKeep.any((e) => e.id == ex.id)) {
                baseToKeep.add(ex);
              }
            }
          }
        }
      }
    }

    await DatabaseHelper.instance.deleteMonthPlan(profile.id!);

    int setsAdjustment = 0;
    if (smart) {
      try {
        final missed = await WeekAnalyzer.missedLastWeek(profile.id!);
        if (missed >= 2) setsAdjustment = -1;
      } catch (_) {}
    }

    final focusGroups = _getFocusGroups(profile);
    final cardioMode = _computeCardioMode(focusGroups, profile.goal);
    final dayPlans = _createDayTemplates(focusGroups, profile.daysPerWeek, profile.limitations);

    final allExercises = await DatabaseHelper.instance.getExercises();
    final allStretches = await DatabaseHelper.instance.getStretches();

    final week1Exercises = <List<Exercise>>[];
    final usedExerciseIds = <int>{};
    for (final ex in baseToKeep) { if (ex.id != null) usedExerciseIds.add(ex.id!); }

    final bool isNewbieShort = (profile.level == 'beginner' && profile.sessionMinutes <= 45);
    final int baseCountTarget = isNewbieShort ? 2 : 3;
    final Set<int> usedBaseIdsForWeek = {};

    // 1. Формируем каркас (Базы + Изоляция)
    for (int i = 0; i < dayPlans.length; i++) {
      final exercises = _pickExercisesSmart(
        allExercises: allExercises,
        baseToKeep: baseToKeep,
        muscleGroups: dayPlans[i],
        equipment: profile.equipment,
        level: profile.level,
        limitations: profile.limitations,
        maxCount: _getExerciseCount(profile.sessionMinutes, profile.level),
        age: profile.age,
        usedExerciseIds: usedExerciseIds,
        cardioMode: cardioMode,
        usedBaseIdsForWeek: usedBaseIdsForWeek,
        baseCountTarget: baseCountTarget,
      );
      for (final ex in exercises) if (ex.id != null) usedExerciseIds.add(ex.id!);
      week1Exercises.add(exercises);
    }

    final createdDays = <WorkoutDay>[];

    // 2. Создаем 4 недели
    for (int week = 1; week <= 4; week++) {
      final Set<int> usedCardioThisWeek = {};

      for (int dayIndex = 0; dayIndex < dayPlans.length; dayIndex++) {
        final dayGroups = dayPlans[dayIndex];
        final baseExercises = week1Exercises[dayIndex];

        final dayCardios = <Exercise>[];
        if (cardioMode == 'every_day') {
          final uniqueCardio = allExercises.where((e) {
            if (e.id == null || usedCardioThisWeek.contains(e.id)) return false;
            if (!_isCardio(e)) return false;
            if (!_matchesEquipment(e, profile.equipment)) return false;
            return true;
          }).toList()..shuffle(_random);

          final fallbackCardio = allExercises.where((e) {
            if (e.id == null) return false;
            if (!_isCardio(e)) return false;
            if (!_matchesEquipment(e, profile.equipment)) return false;
            return true;
          }).toList()..shuffle(_random);

          final cardioCandidates = [...uniqueCardio, ...fallbackCardio];
          int cardioCount = (profile.goal == 'lose_weight') ? 3 : 1;

          final Set<String> addedCardioNames = {};
          for (final ex in cardioCandidates) {
            if (dayCardios.length >= cardioCount) break;
            final normName = _normalizeName(ex.name);
            if (addedCardioNames.contains(normName)) continue;
            dayCardios.add(ex);
            addedCardioNames.add(normName);
            if (ex.id != null) usedCardioThisWeek.add(ex.id!);
          }
        }

        // УМНОЕ ЧЕРЕДОВАНИЕ СИЛОВЫХ И КАРДИО (ТОЛЬКО ДЛЯ ПОХУДЕНИЯ)
        final uniqueExercises = <Exercise>[];
        final Set<String> addedNames = {};

        if (profile.goal == 'lose_weight') {
          int baseIndex = 0;
          int cardioIndex = 0;
          int counter = 0;

          while (baseIndex < baseExercises.length || cardioIndex < dayCardios.length) {
            if (counter > 0 && counter % 3 == 0 && cardioIndex < dayCardios.length) {
              uniqueExercises.add(dayCardios[cardioIndex++]);
            } else if (baseIndex < baseExercises.length) {
              uniqueExercises.add(baseExercises[baseIndex++]);
            } else if (cardioIndex < dayCardios.length) {
              uniqueExercises.add(dayCardios[cardioIndex++]);
            }
            counter++;
          }
        } else {
          final finalExercisesList = [...baseExercises, ...dayCardios];
          for (final ex in finalExercisesList) {
            final normName = _normalizeName(ex.name);
            if (!addedNames.contains(normName)) {
              uniqueExercises.add(ex);
              addedNames.add(normName);
            }
          }
        }

        final dayDate = DateTime.now().add(Duration(days: (week - 1) * 7 + dayIndex));
        final dayName = 'День ${dayIndex + 1}: ${dayGroups.where((g) => g != 'cardio').map(_groupLabel).join(' + ')}';

        final day = WorkoutDay(
          profileId: profile.id!,
          name: 'Неделя $week: $dayName',
          type: 'strength',
          weekNumber: week,
          cycleNumber: newCycle,
          status: 'planned',
          durationMinutes: profile.sessionMinutes,
          date: dayDate,
        );

        final dayId = await DatabaseHelper.instance.createWorkoutDay(day);
        final baseSets = _getSets(profile.level);
        final finalSets = (baseSets + setsAdjustment).clamp(2, 5);
        final progression = _getProgressionParams(week, profile.goal, profile.level, finalSets, _getRest(profile.goal), _getReps(profile.goal));

        int order = 1;
        for (final ex in uniqueExercises) {
          final lowerName = ex.name.toLowerCase();
          final isJumpRope = lowerName.contains('скакалк') || (lowerName.contains('прыжк') && !lowerName.contains('тумбу'));

          // ОПРЕДЕЛЯЕМ ИНТЕРВАЛЬНОЕ КАРДИО (ВИИТ)
          final isHighIntensityCardio = lowerName.contains('канат') || lowerName.contains('берпи') ||
                                        lowerName.contains('скалолаз') || lowerName.contains('джеки') ||
                                        lowerName.contains('колен');
          final isShadowBoxing = lowerName.contains('бой с тенью');
          final isBoxJump = lowerName.contains('тумбу');

          final isCardio = ex.muscleGroups.contains('cardio');

          int setsCount;
          String repsStr;

          if (isJumpRope) {
            setsCount = 3;
            repsStr = '2 мин';
          } else if (isShadowBoxing) {
            setsCount = 3;
            repsStr = '3 мин';
          } else if (isBoxJump) {
            setsCount = 3;
            repsStr = '12 повт';
          } else if (isHighIntensityCardio) {
            setsCount = 3;
            repsStr = '30 сек';
          } else if (isCardio) {
            setsCount = 1;
            repsStr = '${progression.cardioMinutes} мин';
          } else if (_isTimedExercise(ex.name)) {
            setsCount = progression.sets;
            repsStr = '${progression.timedSeconds} сек';
          } else {
            setsCount = progression.sets;
            repsStr = progression.reps;
          }

          final workoutExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
            workoutDayId: dayId, itemType: 'exercise', itemId: ex.id!,
            order: order++, sets: setsCount, reps: repsStr, restSeconds: progression.rest,
          ));

          if (!isCardio && !isJumpRope) {
            final lastSets = await DatabaseHelper.instance.getLastWorkoutExerciseSets(profileId: profile.id!, exerciseId: ex.id!, daysLimit: 60);
            double? baseWeight;
            if (lastSets.isNotEmpty) {
              baseWeight = lastSets.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
              if (baseWeight == 0) baseWeight = null;
            }

            for (int s = 1; s <= setsCount; s++) {
              double? targetWeight = null;
              if (week == 1 && baseWeight != null) targetWeight = baseWeight;
              await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
                workoutExerciseId: workoutExId, order: s, weight: targetWeight, reps: null, completed: false,
              ));
            }
          } else if (isJumpRope || isHighIntensityCardio || isShadowBoxing) {
            for (int s = 1; s <= setsCount; s++) {
              await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: workoutExId, order: s, weight: null, reps: null, completed: false));
            }
          }
        }

        final coolDown = _pickCoolDown(allStretches, dayGroups, 5);
        for (final stretch in coolDown) {
          final stretchExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
            workoutDayId: dayId, itemType: 'stretch', itemId: stretch.id!,
            order: order++, durationSeconds: stretch.durationSeconds, isCoolDown: true,
          ));
          await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: stretchExId, order: 1, completed: false));
        }
        createdDays.add(day.copyWith(id: dayId));
      }
    }
    return createdDays;
  }
// ═══ ЧАСТЬ 1 ЗАКОНЧИЛАСЬ ═══
  static List<Exercise> _pickExercisesSmart({
    required List<Exercise> allExercises,
    required List<Exercise> baseToKeep,
    required List<String> muscleGroups,
    required String equipment, required String level, required List<String> limitations,
    required int maxCount, required int age, required Set<int> usedExerciseIds,
    required String cardioMode, required Set<int> usedBaseIdsForWeek,
    required int baseCountTarget,
  }) {
    final blocked = _buildBlockedZones(limitations);
    final dayExercises = <Exercise>[];
    final addedIds = <int>{};
    final Set<String> baseGroupsTaken = {};

    for (final group in muscleGroups) {
      if (group == 'cardio') continue;
      if (dayExercises.length >= baseCountTarget) break;

      final expandedTarget = _expandGroups([group]);
      Exercise? selectedBase;

      for (final base in baseToKeep) {
        if (base.id == null) continue;
        if (usedBaseIdsForWeek.contains(base.id) || addedIds.contains(base.id)) continue;
        final baseGroups = _expandGroups(base.muscleGroups);
        if (baseGroups.any((bg) => baseGroupsTaken.contains(bg))) continue;
        if (baseGroups.any((bg) => expandedTarget.contains(bg))) {
          selectedBase = base;
          break;
        }
      }

      if (selectedBase == null) {
        final dbBases = allExercises.where((e) {
          if (e.id == null) return false;
          if (usedBaseIdsForWeek.contains(e.id) || addedIds.contains(e.id)) return false;
          if (!_isCompound(e)) return false;
          if (!_matchesEquipment(e, equipment) || !_isDifficultyAllowed(e, level)) return false;
          final eGroups = _expandGroups(e.muscleGroups);
          if (eGroups.any((eg) => baseGroupsTaken.contains(eg))) return false;
          return eGroups.any((eg) => expandedTarget.contains(eg));
        }).toList()..shuffle(_random);
        if (dbBases.isNotEmpty) selectedBase = dbBases.first;
      }

      if (selectedBase == null) {
         final fallback = allExercises.where((e) {
          if (e.id == null) return false;
          if (usedBaseIdsForWeek.contains(e.id) || addedIds.contains(e.id)) return false;
          if (!_isCompound(e)) return false;
          if (!_matchesEquipment(e, equipment) || !_isDifficultyAllowed(e, level)) return false;
          final eGroups = _expandGroups(e.muscleGroups);
          if (eGroups.any((eg) => baseGroupsTaken.contains(eg))) return false;
          return true;
        }).toList()..shuffle(_random);
        if (fallback.isNotEmpty) selectedBase = fallback.first;
      }

      if (selectedBase != null && selectedBase.id != null) {
        dayExercises.add(selectedBase);
        usedBaseIdsForWeek.add(selectedBase.id!);
        addedIds.add(selectedBase.id!);
        baseGroupsTaken.addAll(_expandGroups(selectedBase.muscleGroups));
      }
    }

    while (dayExercises.length < baseCountTarget) {
       final remaining = allExercises.where((e) {
          if (e.id == null) return false;
          if (usedBaseIdsForWeek.contains(e.id) || addedIds.contains(e.id)) return false;
          if (!_isCompound(e)) return false;
          if (!_matchesEquipment(e, equipment) || !_isDifficultyAllowed(e, level)) return false;
          final eGroups = _expandGroups(e.muscleGroups);
          if (eGroups.any((eg) => baseGroupsTaken.contains(eg))) return false;
          return true;
       }).toList()..shuffle(_random);

       if (remaining.isNotEmpty) {
         dayExercises.add(remaining.first);
         usedBaseIdsForWeek.add(remaining.first.id!);
         addedIds.add(remaining.first.id!);
         baseGroupsTaken.addAll(_expandGroups(remaining.first.muscleGroups));
       } else {
         break;
       }
    }

    final neededIsolationCount = maxCount - dayExercises.length;
    if (neededIsolationCount > 0) {
      final expandedTarget = _expandGroups(muscleGroups);
      final isolation = allExercises.where((e) {
        if (e.id == null || usedExerciseIds.contains(e.id) || addedIds.contains(e.id)) return false;
        if (_isCompound(e)) return false;
        if (_isCardio(e)) return false;
        if (!_matchesEquipment(e, equipment) || !_isDifficultyAllowed(e, level)) return false;
        final lower = e.name.toLowerCase();
        if (equipment != 'bodyweight' && (lower.contains('вакуум') || lower.contains('vacuum'))) return false;
        return e.muscleGroups.any((eg) => expandedTarget.contains(_norm(eg)));
      }).toList()..shuffle(_random);

      int added = 0;
      for (final ex in isolation) {
        if (added >= neededIsolationCount) break;
        if (dayExercises.any((d) => _normalizeName(d.name) == _normalizeName(ex.name))) continue;
        dayExercises.add(ex);
        addedIds.add(ex.id!);
        usedExerciseIds.add(ex.id!);
        added++;
      }
    }

    if (dayExercises.length < maxCount) {
      final anyIsolation = allExercises.where((e) {
        if (e.id == null || usedExerciseIds.contains(e.id) || addedIds.contains(e.id)) return false;
        if (_isCompound(e)) return false;
        if (_isCardio(e)) return false;
        if (!_matchesEquipment(e, equipment) || !_isDifficultyAllowed(e, level)) return false;
        final lower = e.name.toLowerCase();
        if (equipment != 'bodyweight' && (lower.contains('вакуум') || lower.contains('vacuum'))) return false;
        return true;
      }).toList()..shuffle(_random);

      for (final ex in anyIsolation) {
        if (dayExercises.length >= maxCount) break;
        if (dayExercises.any((d) => _normalizeName(d.name) == _normalizeName(ex.name))) continue;
        dayExercises.add(ex);
        addedIds.add(ex.id!);
      }
    }

    return dayExercises;
  }

  static List<String> _getFocusGroups(UserProfile profile) {
    if (profile.goal == 'lose_weight') {
      final list = profile.focusAreas.map(_norm).toList();
      if (!list.contains('cardio')) list.add('cardio');
      return list;
    }
    if (profile.focusAreas.isNotEmpty) return profile.focusAreas.map(_norm).toList();
    if (profile.gender == 'female') return ['glutes', 'abs', 'legs', 'arms'];
    return ['chest', 'back', 'arms', 'legs'];
  }

  static String _computeCardioMode(List<String> focus, String goal) {
    if (focus.contains('cardio')) return 'every_day';
    if (goal == 'lose_weight' || goal == 'tone') return 'every_day';
    return 'off';
  }

  static List<List<String>> _createDayTemplates(List<String> focus, int days, List<String> limitations) {
    final blocked = _buildBlockedZones(limitations);
    final pool = focus.where((g) => g != 'cardio' && !blocked.contains(g)).toList();
    if (pool.isEmpty) pool.addAll(['glutes', 'abs', 'legs']);

    final plans = List.generate(days, (_) => <String>[]);
    for (int i = 0; i < days; i++) {
      for (int j = 0; j < 3; j++) {
        final g = pool[(i * 3 + j) % pool.length];
        if (!plans[i].contains(g)) plans[i].add(g);
      }
    }
    return plans;
  }

  static bool _isCompound(Exercise ex) {
    const keywords = [
      'присед', 'приседание', 'squat', 'выпад', 'lunge', 'становая', 'deadlift',
      'румынск', 'romanian', 'жим', 'press', 'bench press', 'жим лёжа', 'жим лежа',
      'тяга', 'row', 'подтягив', 'pull-up', 'pullup', 'отжимание', 'push-up', 'pushup',
      'берпи', 'burpee', 'планка', 'plank', 'скручивание', 'crunch', 'зашаг',
    ];
    final lower = ex.name.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  // 👇 ОБНОВЛЕНО: добавлены новые кардио
  static bool _isTimedExercise(String name) {
    const keywords = [
      'планка', 'plank', 'бег', 'дорожк', 'скакалк', 'ходьб', 'велотренаж',
      'эллипс', 'гребл', 'кардио', 'канат', 'скалолаз',
    ];
    final lower = name.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  // 👇 ОБНОВЛЕНО: Сначала проверяем название (чтобы бег с коленями не улетел в изоляцию)
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

  static bool _matchesEquipment(Exercise e, String equipment) {
    if (equipment == 'gym') return true;
    if (equipment == 'bodyweight') return e.equipment.contains('bodyweight');
    if (equipment == 'dumbbells') {
      return e.equipment.contains('bodyweight') || e.equipment.contains('dumbbells') || e.equipment.contains('resistance_band');
    }
    return true;
  }

  static bool _isDifficultyAllowed(Exercise e, String level) {
    if (level == 'beginner') return e.difficulty == 'beginner';
    if (level == 'intermediate') return e.difficulty != 'advanced';
    return true;
  }

  static String _normalizeName(String name) {
    var s = name.toLowerCase();
    const removals = [
      'на одной ноге', 'на одной руке', 'на двух ногах', 'на двух руках',
      'на одну ногу', 'на одну руку', 'одной ногой', 'одной рукой',
      'на 1 ноге', 'на 1 руке', 'с одной ногой', 'с одной рукой',
      'с гантелями', 'с гантелью', 'с гантелей', 'с одной гантелью',
      'со штангой', 'с штангой', 'с гирей', 'с эспандером', 'с резинкой',
      'с бодибаром', 'с блином', 'с мячом', 'с фитболом', 'в наклоне',
      'с упором', 'на скамье', 'на полу', 'на коленях', 'сидя', 'стоя',
      'лёжа', 'лежа', 'вис', 'вися', 'правой', 'левой', 'собственным весом', 'свой вес'
    ];
    for (final r in removals) s = s.replaceAll(r, '');
    s = s.replaceAll('упражнение', '');
    s = s.replaceAll('подходы', '');
    s = s.replaceAll('мостик', 'мост');
    s = s.replaceAll('хип траст', 'мост');
    s = s.replaceAll('hip thrust', 'мост');
    s = s.replaceAll('подъем таза', 'мост');
    s = s.replaceAll('ягодичный', '');
    s = s.replaceAll('болгарский', 'выпад');
    s = s.replaceAll('боковая планка', 'планка');
    s = s.replaceAll(RegExp(r'[,\-—–()\[\]:;]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  static String _groupLabel(String code) {
    const map = {
      'glutes': 'ягодицы', 'abs': 'пресс', 'obliques': 'косые', 'arms': 'руки',
      'biceps': 'бицепс', 'triceps': 'трицепс', 'shoulders': 'плечи', 'legs': 'ноги',
      'quads': 'бёдра', 'hamstrings': 'задняя поверхность', 'calves': 'голень',
      'back': 'спина', 'lats': 'широчайшие', 'traps': 'трапеции', 'lower_back': 'поясница',
      'chest': 'грудь', 'core': 'кор', 'full_body': 'всё тело', 'cardio': 'кардио',
      'feet': 'стопы',
    };
    return map[code] ?? code;
  }

  static List<Stretch> _pickCoolDown(List<Stretch> all, List<String> groups, int max) {
    final rel = all.where((s) => groups.contains(s.muscleGroup) || s.muscleGroup == 'full_body' || s.muscleGroup == 'back').toList();
    rel.shuffle(_random);
    return rel.take(max).toList();
  }

  static int _getSets(String level) {
    switch (level) {
      case 'beginner': return 2;
      case 'intermediate': return 3;
      case 'advanced': return 4;
      default: return 3;
    }
  }

  // 👇 ОБНОВЛЕНО: Для тонуса теперь 15-18, для похудения 15-20
  static String _getReps(String goal) {
    switch (goal) {
      case 'strength': return '6-8';
      case 'gain_mass': return '8-10';
      case 'lose_weight': return '15-20';
      case 'tone': return '15-18'; // Изменено с 12-15
      default: return '15-20';
    }
  }

  static int _getRest(String goal) {
    switch (goal) {
      case 'strength': return 120;
      case 'gain_mass': return 90;
      case 'lose_weight': return 45;
      case 'tone': default: return 60;
    }
  }

  static _ProgressionParams _getProgressionParams(int week, String goal, String level, int baseSets, int baseRest, String baseReps) {
    int sets = baseSets;
    String reps = baseReps;
    int rest = baseRest;
    int timedSeconds = 60;
    int cardioMinutes = 15;

    if (goal == 'lose_weight') { cardioMinutes = 15 + (week * 5); rest = 45; }

    if (goal == 'tone') {
      if (week == 1) reps = '15-18'; // Обновлено
      else if (week == 2) reps = '18';
      else if (week == 3) reps = '20';
      else if (week == 4) reps = '15'; // Обновлено
    } else {
      if (week == 1) {
        if (goal == 'strength' || goal == 'gain_mass') reps = '10-12';
      } else if (week == 2) {
        if (goal == 'strength' || goal == 'gain_mass') reps = '10-12';
        else reps = '18';
        timedSeconds = 70;
      } else if (week == 3) {
        if (goal == 'strength' || goal == 'gain_mass') reps = '12-14';
        else reps = '20';
        timedSeconds = 80;
      } else if (week == 4) {
        if (goal == 'strength' || goal == 'gain_mass') reps = '10-12';
        else reps = '15';
        timedSeconds = 60;
      }
    }

    return _ProgressionParams(sets: sets, reps: reps, rest: rest, timedSeconds: timedSeconds, cardioMinutes: cardioMinutes);
  }

  static int _getExerciseCount(int sessionMinutes, String level) {
    int count = (sessionMinutes / 7.5).round();
    if (level == 'beginner') count = (count * 0.8).round();
    else if (level == 'advanced') count = (count * 1.2).round();
    return ((count / 3).ceil() * 3).clamp(3, 15);
  }
}

class _ProgressionParams {
  final int sets;
  final int rest;
  final String reps;
  final int timedSeconds;
  final int cardioMinutes;
  _ProgressionParams({required this.sets, required this.rest, required this.reps, required this.timedSeconds, required this.cardioMinutes});
}
// ═══ ФАЙЛ workout_generator.dart ЗАВЕРШЁН ═══