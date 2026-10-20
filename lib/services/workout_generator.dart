import 'dart:math';
import '../models/exercise.dart';
import '../models/stretch.dart';
import '../models/user_profile.dart';
import '../models/workout_template.dart';
import 'database_helper.dart';
import 'week_analyzer.dart';

/// Умный генератор плана тренировок.
///
/// 📌 Особенности:
/// — 🧠 Фокусные зоны — ПРИОРИТЕТ
/// — 🧩 basePool — только если фокусных < 3
/// — ⚖️ Равномерное распределение
/// — 🚫 Фильтр ограничений
/// — 🎚 Фильтр сложности
/// — ❤️ Кардио `every_day` при тонусе / похудении
/// — 📈 Чередование упражнений внутри недели
class WorkoutGenerator {
  static final Random _random = Random();

  // ═══════════════════════════════════════════════════════════
  //  МАППИНГИ
  // ═══════════════════════════════════════════════════════════

  static const Map<String, String> _aliasMap = {
    'плечи': 'shoulders', 'спина': 'back', 'колени': 'knees',
    'шея': 'neck', 'поясница': 'lower_back', 'локти': 'elbows',
    'запястья': 'wrists', 'бёдра': 'hips', 'голеностоп': 'ankles',
    'ягодицы': 'glutes', 'пресс': 'abs', 'косые': 'obliques',
    'руки': 'arms', 'бицепс': 'biceps', 'трицепс': 'triceps',
    'ноги': 'legs', 'голень': 'calves', 'широчайшие': 'lats',
    'трапеции': 'traps', 'грудь': 'chest', 'кор': 'core',
    'кардио': 'cardio',
  };

  static const Map<String, List<String>> _limitationToBlockedZones = {
    'плечи': ['shoulders'], 'shoulders': ['shoulders'],
    'колени': ['knees', 'quads'], 'knees': ['knees', 'quads'],
    'спина': ['back', 'lats', 'lower_back'], 'back': ['back', 'lats', 'lower_back'],
    'поясница': ['lower_back'], 'lower_back': ['lower_back'],
    'шея': ['neck'], 'neck': ['neck'],
    'локти': ['elbows', 'biceps', 'triceps'], 'elbows': ['elbows', 'biceps', 'triceps'],
    'запястья': ['wrists'], 'wrists': ['wrists'],
    'бёдра': ['hips', 'glutes'], 'hips': ['hips', 'glutes'],
    'голеностоп': ['ankles', 'calves'], 'ankles': ['ankles', 'calves'],
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
  };

  static String _norm(String s) => _aliasMap[s] ?? s;

  static Set<String> _expandGroups(List<String> groups) {
    final result = <String>{};
    for (final g in groups) {
      final norm = _norm(g);
      final expanded = _zoneExpand[norm];
      if (expanded != null) {
        result.addAll(expanded);
      } else {
        result.add(norm);
      }
    }
    return result;
  }

  static Set<String> _buildBlockedZones(List<String> limitations) {
    final blocked = <String>{};
    for (final lim in limitations) {
      final zones = _limitationToBlockedZones[lim];
      if (zones != null) {
        blocked.addAll(zones);
      } else {
        blocked.add(_norm(lim));
      }
    }
    return blocked;
  }

  // ═══════════════════════════════════════════════════════════
  //  ГЛАВНЫЙ МЕТОД
  // ═══════════════════════════════════════════════════════════

  static Future<List<WorkoutTemplate>> generateWeekPlan(
    UserProfile profile, {
    bool smart = true,
  }) async {
    if (profile.id == null) {
      throw Exception('Profile ID обязателен');
    }

    int setsAdjustment = 0;
    Set<int> recentExerciseIds = {};

    if (smart) {
      try {
        final missed = await WeekAnalyzer.missedLastWeek(profile.id!);
        if (missed >= 2) {
          setsAdjustment = -1;
        }

        // ⚠️ Разный интервал в зависимости от цели
        int daysLimit = 14;
        if (profile.goal == 'strength' || profile.goal == 'gain_mass') {
          daysLimit = 6;
        } else if (profile.goal == 'tone' || profile.goal == 'lose_weight') {
          daysLimit = 3;
        }

        recentExerciseIds = await DatabaseHelper.instance
            .getRecentExerciseIds(
          profileId: profile.id!,
          daysLimit: daysLimit,
        );
      } catch (_) {}
    }

    final focusGroups = _getFocusGroups(profile);

    final cardioMode = _computeCardioMode(
      focusGroups: focusGroups,
      goal: profile.goal,
    );

    final dayPlans = _distributeByCategoriesSmart(
      focusGroups: focusGroups,
      daysCount: profile.daysPerWeek,
      goal: profile.goal,
      limitations: profile.limitations,
      cardioMode: cardioMode,
    );

    final allExercises = await DatabaseHelper.instance.getExercises();
    final allStretches = await DatabaseHelper.instance.getStretches();

    final templates = <WorkoutTemplate>[];
    final usedExerciseIds = <int>{};

    for (int i = 0; i < dayPlans.length; i++) {
      final groups = dayPlans[i];
      final dayName = _getDayName(
        groups,
        i + 1,
        focusGroups: focusGroups,
      );

      final exercises = _pickExercisesSmart(
        allExercises: allExercises,
        muscleGroups: groups,
        equipment: profile.equipment,
        level: profile.level,
        limitations: profile.limitations,
        maxCount: _getExerciseCount(
          profile.sessionMinutes,
          profile.level,
        ),
        age: profile.age,
        recentExerciseIds: recentExerciseIds,
        usedExerciseIds: usedExerciseIds,
        goal: profile.goal,
        cardioMode: cardioMode,
        focusGroups: focusGroups, // ⚠️ Передаем фокус
      );

      for (final ex in exercises) {
        if (ex.id != null) usedExerciseIds.add(ex.id!);
      }

      final coolDown = _pickCoolDown(
        allStretches: allStretches,
        trainedGroups: groups,
        maxCount: 5,
      );

      final template = WorkoutTemplate(
        profileId: profile.id!,
        name: dayName,
        type: 'strength',
        estimatedMinutes: profile.sessionMinutes,
      );

      final templateId =
          await DatabaseHelper.instance.saveTemplate(template);

      final baseSets = _getSets(profile.level, profile.age);
      final finalSets = (baseSets + setsAdjustment).clamp(2, 5);

      int order = 1;
      for (final ex in exercises) {
        if (ex.id == null) continue;

        final isCardio = ex.muscleGroups.contains('cardio');
        final setsCount = isCardio ? 1 : finalSets;
        final repsStr =
            isCardio ? '5' : _getReps(profile.goal, profile.age);

        await DatabaseHelper.instance.addTemplateItem(TemplateItem(
          templateId: templateId,
          itemType: 'exercise',
          itemId: ex.id!,
          order: order++,
          sets: setsCount,
          reps: repsStr,
          restSeconds: _getRest(profile.goal, profile.age),
        ));
      }

      for (final stretch in coolDown) {
        if (stretch.id == null) continue;
        await DatabaseHelper.instance.addTemplateItem(TemplateItem(
          templateId: templateId,
          itemType: 'stretch',
          itemId: stretch.id!,
          order: order++,
          durationSeconds: stretch.durationSeconds,
          isCoolDown: true,
        ));
      }

      final saved =
          await DatabaseHelper.instance.getTemplateById(templateId);
      if (saved != null) templates.add(saved);
    }

    return templates;
  }
  // ═══ КОНЕЦ ГЛАВНОГО МЕТОДА generateWeekPlan ═══

  // ═══════════════════════════════════════════════════════════
  //  РЕЖИМ КАРДИО
  // ═══════════════════════════════════════════════════════════

  static String _computeCardioMode({
    required List<String> focusGroups,
    required String goal,
  }) {
    if (focusGroups.contains('cardio')) return 'every_day';

    switch (goal) {
      case 'lose_weight':
      case 'tone':
        return 'every_day';
      case 'gain_mass':
      case 'strength':
      default:
        return 'off';
    }
  }
  // ═══ КОНЕЦ БЛОКА «РЕЖИМ КАРДИО» ═══

  // ═══════════════════════════════════════════════════════════
  //  ФОКУСНЫЕ ЗОНЫ И РАСПРЕДЕЛЕНИЕ ПО ДНЯМ
  // ═══════════════════════════════════════════════════════════

  static List<String> _getFocusGroups(UserProfile profile) {
    if (profile.focusAreas.isNotEmpty) {
      return profile.focusAreas.map(_norm).toList();
    }

    if (profile.gender == 'female') {
      return ['glutes', 'abs', 'legs', 'arms'];
    } else {
      return ['chest', 'back', 'arms', 'legs'];
    }
  }

  static List<List<String>> _distributeByCategoriesSmart({
    required List<String> focusGroups,
    required int daysCount,
    required String goal,
    required List<String> limitations,
    required String cardioMode,
  }) {
    final blocked = _buildBlockedZones(limitations);

    final focus = focusGroups
        .map(_norm)
        .where((g) => g != 'cardio')
        .where((g) => !blocked.contains(g))
        .toList();

    final effectiveFocus = focus.isNotEmpty
        ? focus
        : ['glutes', 'abs', 'legs', 'arms'];

    final hasEnoughFocus = effectiveFocus.length >= 3;

    final basePool = hasEnoughFocus
        ? <String>[]
        : [
            'chest', 'back', 'lats', 'traps',
            'quads', 'hamstrings', 'calves',
          ]
              .where((g) => !effectiveFocus.contains(g))
              .where((g) => !blocked.contains(g))
              .toList()
        ..shuffle(_random);

    final plan = List.generate(daysCount, (_) => <String>[]);

    const focusPerDay = 3;

    for (int i = 0; i < daysCount; i++) {
      for (int j = 0; j < focusPerDay; j++) {
        final idx = (i * focusPerDay + j) % effectiveFocus.length;
        final g = effectiveFocus[idx];
        if (!plan[i].contains(g)) plan[i].add(g);
      }
    }

    int baseIdx = 0;
    for (int i = 0; i < daysCount; i++) {
      while (plan[i].length < 3 && baseIdx < basePool.length) {
        final g = basePool[baseIdx++];
        if (!plan[i].contains(g)) plan[i].add(g);
      }
    }

    for (int i = 0; i < daysCount && plan[i].length < 3; i++) {
      for (final g in effectiveFocus) {
        if (!plan[i].contains(g)) plan[i].add(g);
        if (plan[i].length >= 3) break;
      }
    }

    if (cardioMode == 'every_day') {
      for (int i = 0; i < daysCount; i++) {
        if (!plan[i].contains('cardio')) plan[i].add('cardio');
      }
    }

    return plan;
  }

  static String _getDayName(
    List<String> groups,
    int dayNumber, {
    required List<String> focusGroups,
  }) {
    final filteredGroups =
        groups.where((g) => g != 'cardio').toList();
    final normFocus = focusGroups.map(_norm).toList();

    final onlyFocus = filteredGroups
        .where((g) => normFocus.contains(g))
        .toList();

    final source = onlyFocus.isNotEmpty ? onlyFocus : filteredGroups;

    if (source.isEmpty) {
      return 'День $dayNumber';
    }

    final trimmed = source.take(3).toList();
    final labels = trimmed.map(_groupLabel).toList();
    final hasMore = source.length > 3;
    final suffix = hasMore ? ' и др.' : '';

    return 'День $dayNumber: ${labels.join(' + ')}$suffix';
  }

  static String _groupLabel(String code) {
    const map = {
      'glutes': 'ягодицы', 'abs': 'пресс', 'obliques': 'косые',
      'arms': 'руки', 'biceps': 'бицепс', 'triceps': 'трицепс',
      'shoulders': 'плечи', 'legs': 'ноги', 'quads': 'бёдра',
      'hamstrings': 'задняя поверхность', 'calves': 'голень',
      'back': 'спина', 'lats': 'широчайшие', 'traps': 'трапеции',
      'lower_back': 'поясница', 'chest': 'грудь', 'core': 'кор',
      'full_body': 'всё тело', 'cardio': 'кардио',
    };
    return map[code] ?? code;
  }
  // ═══ КОНЕЦ БЛОКА «ФОКУСНЫЕ ЗОНЫ И РАСПРЕДЕЛЕНИЕ» ═══

  // ═══════════════════════════════════════════════════════════
  //  БАЗОВОЕ / ИЗОЛИРУЮЩЕЕ / КАРДИО
  // ═══════════════════════════════════════════════════════════

  static const List<String> _compoundKeywords = [
    'присед', 'приседание', 'squat',
    'выпад', 'lunge',
    'становая', 'deadlift',
    'румынск', 'romanian',
    'жим', 'press',
    'bench press', 'жим лёжа', 'жим лежа',
    'тяга', 'row',
    'подтягив', 'pull-up', 'pullup',
    'отжимание', 'push-up', 'pushup',
    'берпи', 'burpee',
    'планка', 'plank',
    'скручивание', 'crunch',
  ];

  static bool _isCompound(Exercise ex) {
    final lower = ex.name.toLowerCase();
    return _compoundKeywords.any((kw) => lower.contains(kw));
  }

  static bool _isCardio(Exercise ex) {
    return ex.muscleGroups.contains('cardio');
  }

  static bool _isDifficultyAllowed(Exercise e, String level) {
    if (level == 'beginner') {
      return e.difficulty == 'beginner';
    }
    if (level == 'intermediate') {
      return e.difficulty != 'advanced';
    }
    return true;
  }
  // ═══ КОНЕЦ БЛОКА «БАЗОВОЕ / ИЗОЛИРУЮЩЕЕ / КАРДИО» ═══

  // ═══════════════════════════════════════════════════════════
  //  УМНЫЙ ПОДБОР УПРАЖНЕНИЙ
  // ═══════════════════════════════════════════════════════════

  static List<Exercise> _pickExercisesSmart({
    required List<Exercise> allExercises,
    required List<String> muscleGroups,
    required String equipment,
    required String level,
    required List<String> limitations,
    required int maxCount,
    required int age,
    required Set<int> recentExerciseIds,
    required Set<int> usedExerciseIds,
    required String goal,
    required String cardioMode,
    required List<String> focusGroups, // ⚠️ Добавлен фокус
  }) {
    final blocked = _buildBlockedZones(limitations);

    // ═══ 0. Кардио в режиме every_day ═══
    if (cardioMode == 'every_day') {
      final cardioCandidates = allExercises
          .where(_isCardio)
          .where((e) => _matchesEquipment(e, equipment))
          .where((e) =>
              e.id == null || !usedExerciseIds.contains(e.id))
          .where((e) => _isDifficultyAllowed(e, level))
          .where((e) {
            if (e.contraindications
                .map(_norm)
                .any(blocked.contains)) {
              return false;
            }
            if (e.muscleGroups.isNotEmpty) {
              final primary = _norm(e.muscleGroups.first);
              if (blocked.contains(primary)) return false;
            }
            return true;
          })
          .toList()
        ..shuffle(_random);

      if (cardioCandidates.isNotEmpty) {
        final cardio = cardioCandidates.first;

        final strengthExercises = _pickStrengthOnly(
          allExercises: allExercises,
          muscleGroups: muscleGroups,
          equipment: equipment,
          level: level,
          blocked: blocked,
          maxCount: maxCount,
          recentExerciseIds: recentExerciseIds,
          usedExerciseIds: {
            ...usedExerciseIds,
            if (cardio.id != null) cardio.id!,
          },
          focusGroups: focusGroups, // ⚠️ Передаем фокус
        );

        return [...strengthExercises, cardio];
      }
    }

    // ═══ 1. Только силовые ═══
    return _pickStrengthOnly(
      allExercises: allExercises,
      muscleGroups: muscleGroups,
      equipment: equipment,
      level: level,
      blocked: blocked,
      maxCount: maxCount,
      recentExerciseIds: recentExerciseIds,
      usedExerciseIds: usedExerciseIds,
      focusGroups: focusGroups, // ⚠️ Передаем фокус
    );
  }
  // ═══ КОНЕЦ БЛОКА «УМНЫЙ ПОДБОР УПРАЖНЕНИЙ» ═══

  // ═══════════════════════════════════════════════════════════
  //  ⚖️ РАВНОМЕРНЫЙ ПОДБОР СИЛОВЫХ ПО ГРУППАМ
  // ═══════════════════════════════════════════════════════════

  static List<Exercise> _pickStrengthOnly({
    required List<Exercise> allExercises,
    required List<String> muscleGroups,
    required String equipment,
    required String level,
    required Set<String> blocked,
    required int maxCount,
    required Set<int> recentExerciseIds,
    required Set<int> usedExerciseIds,
    required List<String> focusGroups, // ⚠️ Добавлен фокус
  }) {
    if (maxCount <= 0) return [];

    // ═══ 1. Разворачиваем составные зоны дня ═══
    final expandedDay = _expandGroups(muscleGroups);

    // ═══ 2. База: силовые, по группам дня ═══
    var filtered = allExercises.where((e) {
      if (_isCardio(e)) return false;
      return e.muscleGroups.any(expandedDay.contains);
    }).toList();

    // ═══ 3. Оборудование ═══
    filtered = filtered
        .where((e) => _matchesEquipment(e, equipment))
        .toList();

    // ═══ 4. Сложность ═══
    filtered = filtered
        .where((e) => _isDifficultyAllowed(e, level))
        .toList();

    // ═══ 5. Ограничения ═══
    if (blocked.isNotEmpty) {
      filtered = filtered.where((e) {
        final hasContra =
            e.contraindications.map(_norm).any(blocked.contains);
        if (hasContra) return false;
        if (e.muscleGroups.isNotEmpty) {
          final primary = _norm(e.muscleGroups.first);
          if (blocked.contains(primary)) return false;
        }
        return true;
      }).toList();
    }

    // ═══ 6. Исключить использованные и недавние ═══
    filtered = filtered
        .where((e) => e.id == null || !usedExerciseIds.contains(e.id))
        .where((e) => e.id == null || !recentExerciseIds.contains(e.id)) // ⚠️ Жесткий отсев недавних
        .toList();

    // ═══ 7. Дедупликация по нормализованному имени ═══
    final usedNormalized = <String>{};
    final unique = <Exercise>[];
    for (final ex in filtered) {
      final norm = _normalizeName(ex.name);
      if (usedNormalized.contains(norm)) continue;
      usedNormalized.add(norm);
      unique.add(ex);
    }

    // ═══ 8. Равномерное распределение по группам ═══
    final picked = <Exercise>[];
    final usedIds = <int>{};

    final groupsList =
        muscleGroups.where((g) => g != 'cardio').toList();

    if (groupsList.isEmpty) return picked;

    final perGroup = (maxCount / groupsList.length).ceil();

    for (final group in groupsList) {
      final expanded = _expandGroups([group]);

      final groupExs = unique
          .where((e) => e.muscleGroups.any(expanded.contains))
          .where((e) => e.id != null && !usedIds.contains(e.id))
          .toList()
        ..shuffle(_random);

      // ⚠️ Сортируем: фокусные и базовые — в приоритете
      final normFocus = focusGroups.map(_norm).toList();

      groupExs.sort((a, b) {
        // 1. Проверяем, относится ли к фокусной зоне
        bool isFocusA = a.muscleGroups.any((g) => normFocus.contains(g));
        bool isFocusB = b.muscleGroups.any((g) => normFocus.contains(g));

        if (isFocusA != isFocusB) {
          return isFocusA ? -1 : 1;
        }

        // 2. Проверяем, является ли упражнение базовым
        bool isCompoundA = _isCompound(a);
        bool isCompoundB = _isCompound(b);

        if (isCompoundA != isCompoundB) {
          return isCompoundA ? -1 : 1; // Базовые выше
        }

        return 0;
      });

      int taken = 0;
      for (final ex in groupExs) {
        if (taken >= perGroup) break;
        if (picked.length >= maxCount) break;
        picked.add(ex);
        usedIds.add(ex.id!);
        taken++;
      }
    }

    // ═══ 9. Если осталось место — добираем из других групп дня ═══
    if (picked.length < maxCount) {
      final rest = unique
          .where((e) => e.id != null && !usedIds.contains(e.id))
          .toList()
        ..shuffle(_random);

      for (final ex in rest) {
        if (picked.length >= maxCount) break;
        picked.add(ex);
        usedIds.add(ex.id!);
      }
    }

    // ═══ 10. Перемешать, оставив первый базовый первым ═══
    if (picked.length > 2) {
      final head = picked.first;
      final tail = picked.sublist(1)..shuffle(_random);
      return [head, ...tail];
    }

    return picked;
  }
  // ═══ КОНЕЦ БЛОКА «РАВНОМЕРНЫЙ ПОДБОР СИЛОВЫХ» ═══

  static bool _matchesEquipment(Exercise e, String equipment) {
    if (equipment == 'gym') return true;
    if (equipment == 'bodyweight') {
      return e.equipment.contains('bodyweight');
    }
    if (equipment == 'dumbbells') {
      return e.equipment.contains('bodyweight') ||
          e.equipment.contains('dumbbells') ||
          e.equipment.contains('resistance_band');
    }
    return true;
  }
  // ═══ КОНЕЦ БЛОКА «ОБОРУДОВАНИЕ» ═══

  // ═══════════════════════════════════════════════════════════
  //  ПОДБОР ЗАМИНКИ
  // ═══════════════════════════════════════════════════════════

  static List<Stretch> _pickCoolDown({
    required List<Stretch> allStretches,
    required List<String> trainedGroups,
    required int maxCount,
  }) {
    final relevant = allStretches.where((s) {
      return trainedGroups.contains(s.muscleGroup) ||
          s.muscleGroup == 'full_body' ||
          s.muscleGroup == 'back';
    }).toList();

    relevant.shuffle(_random);
    return relevant.take(maxCount).toList();
  }
  // ═══ КОНЕЦ БЛОКА «ПОДБОР ЗАМИНКИ» ═══

  // ═══════════════════════════════════════════════════════════
  //  ПАРАМЕТРЫ: ПОДХОДЫ / ПОВТОРЫ / ОТДЫХ
  // ═══════════════════════════════════════════════════════════

  /// Количество подходов по уровню.
  ///  — beginner:     2 подхода
  ///  — intermediate: 3 подхода
  ///  — advanced:     4 подхода
  static int _getSets(String level, int age) {
    switch (level) {
      case 'beginner':
        return 2;
      case 'intermediate':
        return 3;
      case 'advanced':
        return 4;
      default:
        return 3;
    }
  }

  static String _getReps(String goal, int age) {
    switch (goal) {
      case 'strength':
        return '6-8';
      case 'gain_mass':
        return '8-10';
      case 'lose_weight':
        return '15-20';
      case 'tone':
      default:
        return '12-15';
    }
  }

  static int _getRest(String goal, int age) {
    switch (goal) {
      case 'strength':
        return 120;
      case 'gain_mass':
        return 90;
      case 'lose_weight':
        return 45;
      case 'tone':
      default:
        return 60;
    }
  }
  // ═══ КОНЕЦ БЛОКА «ПАРАМЕТРЫ» ═══

  // ═══════════════════════════════════════════════════════════
  //  НОРМАЛИЗАЦИЯ НАЗВАНИЙ
  // ═══════════════════════════════════════════════════════════

  static String _normalizeName(String name) {
    var s = name.toLowerCase();

    const removals = [
      'на одной ноге',
      'на одной руке',
      'на двух ногах',
      'на двух руках',
      'одной ногой',
      'одной рукой',
      'с гантелями',
      'с гантелью',
      'с гантелей',
      'со штангой',
      'с гирей',
      'с эспандером',
      'с резинкой',
      'с бодибаром',
      'с блином',
      'с мячом',
      'в наклоне',
      'с упором',
      'на скамье',
      'сидя',
      'стоя',
      'лёжа',
      'лежа',
    ];

    for (final r in removals) {
      s = s.replaceAll(r, '');
    }

    s = s.replaceAll(RegExp(r'[,\-—–()\[\]:;]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }
  // ═══ КОНЕЦ БЛОКА «НОРМАЛИЗАЦИЯ НАЗВАНИЙ» ═══

  // ═══════════════════════════════════════════════════════════
  //  КОЛИЧЕСТВО УПРАЖНЕНИЙ
  // ═══════════════════════════════════════════════════════════

  /// Количество упражнений в дне.
  ///
  /// ⚠️ 1 блок ≈ 20 минут. В блоке:
  ///   — beginner:     2 упражнения;
  ///   — intermediate: 3 упражнения;
  ///   — advanced:     3 упражнения.
  ///
  /// Примеры при 60 мин:
  ///   beginner     → 3 блока × 2 = 6
  ///   intermediate → 3 блока × 3 = 9
  ///   advanced     → 3 блока × 3 = 9
  ///
  /// Минимум 3, максимум 15.
  static int _getExerciseCount(int sessionMinutes, String level) {
    final blocks = sessionMinutes ~/ 20;
    final perBlock = level == 'beginner' ? 2 : 3;
    final total = blocks * perBlock;
    return total.clamp(3, 15);
  }
  // ═══ КОНЕЦ БЛОКА «КОЛИЧЕСТВО УПРАЖНЕНИЙ» ═══

} // ═══ КОНЕЦ КЛАССА WorkoutGenerator ═══
// ═══ ФАЙЛ workout_generator.dart ЗАВЕРШЁН ═══