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
/// — 🧠 Умное распределение по категориям (Верх / Низ / Кор / Руки)
/// — 🔁 Базовые упражнения (присед, жим, тяга) повторяются из недели в неделю
/// — 🎲 Изолирующие меняются каждую неделю
/// — 🚫 Нет повторов упражнений между днями одной недели
/// — 📈 Прогрессия веса применяется при старте (в WorkoutDetailScreen)
class WorkoutGenerator {
  static final Random _random = Random();

  // ═══════════════════════════════════════════════════════════
  //  ГЛАВНЫЙ МЕТОД — сгенерировать план на неделю
  // ═══════════════════════════════════════════════════════════

  static Future<List<WorkoutTemplate>> generateWeekPlan(
    UserProfile profile, {
    bool smart = true,
  }) async {
    if (profile.id == null) {
      throw Exception('Profile ID обязателен');
    }

    // ═══ 0. Умный режим — анализ ═══
    int setsAdjustment = 0;
    Set<int> recentExerciseIds = {};

    if (smart) {
      try {
        // Пропуски на прошлой неделе
        final missed = await WeekAnalyzer.missedLastWeek(profile.id!);
        if (missed >= 2) {
          setsAdjustment = -1;
        }

        // Упражнения за последние 14 дней — для исключения повторов
        recentExerciseIds = await DatabaseHelper.instance
            .getRecentExerciseIds(
          profileId: profile.id!,
          daysLimit: 14,
        );
      } catch (_) {}
    }

    // ═══ 1. Группы мышц из профиля ═══
    final focusGroups = _getFocusGroups(profile);

    // ═══ 2. Умное распределение по категориям ═══
    final dayPlans = _distributeByCategoriesSmart(
      focusGroups: focusGroups,
      daysCount: profile.daysPerWeek,
      goal: profile.goal,
      limitations: profile.limitations,
    );

    // ═══ 3. Загрузка данных ═══
    final allExercises = await DatabaseHelper.instance.getExercises();
    final allStretches = await DatabaseHelper.instance.getStretches();

    // ═══ 4. Создание шаблонов ═══
    final templates = <WorkoutTemplate>[];
    final usedExerciseIds = <int>{}; // для исключения между днями

    for (int i = 0; i < dayPlans.length; i++) {
      final groups = dayPlans[i];
      final dayName = _getDayName(groups, i + 1);

      // 4.1 Умный подбор упражнений
      final exercises = _pickExercisesSmart(
        allExercises: allExercises,
        muscleGroups: groups,
        equipment: profile.equipment,
        level: profile.level,
        limitations: profile.limitations,
        maxCount: _getExerciseCount(profile.sessionMinutes),
        age: profile.age,
        recentExerciseIds: recentExerciseIds,
        usedExerciseIds: usedExerciseIds,
        goal: profile.goal,
      );

      // Запоминаем использованные
      for (final ex in exercises) {
        if (ex.id != null) usedExerciseIds.add(ex.id!);
      }

      // 4.2 Заминка
      final coolDown = _pickCoolDown(
        allStretches: allStretches,
        trainedGroups: groups,
        maxCount: 5,
      );

      // 4.3 Создать шаблон
      final template = WorkoutTemplate(
        profileId: profile.id!,
        name: dayName,
        type: 'strength',
        estimatedMinutes: profile.sessionMinutes,
      );

      final templateId = await DatabaseHelper.instance
          .saveTemplate(template);

      // 4.4 Упражнения
      final baseSets = _getSets(profile.level, profile.age);
      final finalSets = (baseSets + setsAdjustment).clamp(2, 5);

      int order = 1;
      for (final ex in exercises) {
        if (ex.id == null) continue;
        await DatabaseHelper.instance.addTemplateItem(TemplateItem(
          templateId: templateId,
          itemType: 'exercise',
          itemId: ex.id!,
          order: order++,
          sets: finalSets,
          reps: _getReps(profile.goal, profile.age),
          restSeconds: _getRest(profile.goal, profile.age),
        ));
      }

      // 4.5 Заминка
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

      // Перечитать шаблон с ID
      final saved = await DatabaseHelper.instance
          .getTemplateById(templateId);
      if (saved != null) templates.add(saved);
    }

    return templates;
  }

// ╔═══════════════════════════════════════════════════════════╗
// ║  ⚠️ ЧАСТЬ 2.1 ЗАКОНЧИЛАСЬ — ЖДИТЕ ЧАСТЬ 2.2              ║
// ╚═══════════════════════════════════════════════════════════╝
  // ═══════════════════════════════════════════════════════════
  //  УМНОЕ РАСПРЕДЕЛЕНИЕ ПО КАТЕГОРИЯМ
  // ═══════════════════════════════════════════════════════════

  /// Определить группы мышц из профиля.
  static List<String> _getFocusGroups(UserProfile profile) {
    if (profile.focusAreas.isNotEmpty) {
      return profile.focusAreas;
    }

    if (profile.gender == 'female') {
      return ['glutes', 'abs', 'legs', 'arms'];
    } else {
      return ['chest', 'back', 'arms', 'legs'];
    }
  }

  /// Умное распределение по категориям.
  ///
  /// Логика:
  /// — 3 дня: Верх / Низ / Кор+Руки
  /// — 4 дня: Верх / Низ / Кор+Руки / Full Body
  /// — 5 дней: Верх / Низ / Кор / Руки / Full Body
  /// — 6 дней: Верх / Низ / Кор / Руки / Full Body / Full Body
  /// — 2 дня: Верх / Низ
  static List<List<String>> _distributeByCategoriesSmart({
    required List<String> focusGroups,
    required int daysCount,
    required String goal,
    required List<String> limitations,
  }) {
    // ═══ Категории с группами ═══
    const upper = ['chest', 'back', 'shoulders', 'lats', 'traps'];
    const lower = ['glutes', 'legs', 'quads', 'hamstrings', 'calves'];
    const core = ['abs', 'obliques', 'core', 'lower_back'];
    const arms = ['biceps', 'triceps', 'arms'];

    // ═══ План на неделю ═══
    List<List<String>> plan;

    switch (daysCount) {
      case 2:
        plan = [upper, lower];
        break;
      case 3:
        plan = [upper, lower, [...core, ...arms]];
        break;
      case 4:
        plan = [upper, lower, [...core, ...arms], [...upper, ...lower]];
        break;
      case 5:
        plan = [upper, lower, core, arms, [...upper, ...lower]];
        break;
      case 6:
      default:
        plan = [
          upper,
          lower,
          core,
          arms,
          [...upper, ...lower],
          [...core, ...arms],
        ];
        break;
    }

    // ═══ Обрезка по daysCount (если нужно) ═══
    if (plan.length > daysCount) {
      plan = plan.sublist(0, daysCount);
    }

    // ═══ Фильтрация по limitations ═══
    if (limitations.isNotEmpty) {
      for (int i = 0; i < plan.length; i++) {
        final filtered = plan[i]
            .where((g) => !limitations.contains(g))
            .toList();

        // Если всё убрали — оставить хотя бы что-то неопасное
        plan[i] = filtered.isNotEmpty ? filtered : ['full_body'];
      }
    }

    // ═══ Приоритезация по focusGroups ═══
    // Если есть focus-группа, попавшая в день — усилить её приоритет
    for (int i = 0; i < plan.length; i++) {
      final relevant = plan[i]
          .where((g) => focusGroups.contains(g))
          .toList();

      if (relevant.isNotEmpty) {
        // Упорядочить так, чтобы focus-группы были первыми
        final rest = plan[i].where((g) => !focusGroups.contains(g)).toList();
        plan[i] = [...relevant, ...rest];
      }
    }

    return plan;
  }

  /// Название дня по группам.
  static String _getDayName(List<String> groups, int dayNumber) {
    final labels = groups.map(_groupLabel).toList();
    return 'День $dayNumber: ${labels.join(' + ')}';
  }

  /// Русская метка группы.
  static String _groupLabel(String code) {
    const map = {
      'glutes': 'ягодицы',
      'abs': 'пресс',
      'obliques': 'косые',
      'arms': 'руки',
      'biceps': 'бицепс',
      'triceps': 'трицепс',
      'shoulders': 'плечи',
      'legs': 'ноги',
      'quads': 'бёдра',
      'hamstrings': 'задняя поверхность',
      'calves': 'голень',
      'back': 'спина',
      'lats': 'широчайшие',
      'traps': 'трапеции',
      'lower_back': 'поясница',
      'chest': 'грудь',
      'core': 'кор',
      'full_body': 'всё тело',
    };
    return map[code] ?? code;
  }

// ╔═══════════════════════════════════════════════════════════╗
// ║  ⚠️ ЧАСТЬ 2.2 ЗАКОНЧИЛАСЬ — ЖДИТЕ ЧАСТЬ 2.3              ║
// ╚═══════════════════════════════════════════════════════════╝
  // ═══════════════════════════════════════════════════════════
  //  БАЗОВОЕ ИЛИ ИЗОЛИРУЮЩЕЕ УПРАЖНЕНИЕ
  // ═══════════════════════════════════════════════════════════

  /// Базовые упражнения (многосуставные) — определяем по ключевым словам.
  static const List<String> _compoundKeywords = [
    // Приседания / ноги
    'присед', 'приседание', 'squat',
    'выпад', 'lunge',
    'становая', 'deadlift',
    'румынск', 'romanian',

    // Жим
    'жим', 'press',
    'bench press', 'жим лёжа', 'жим лежа',

    // Тяга
    'тяга', 'row',
    'подтягив', 'pull-up', 'pullup',

    // Общие многосуставные
    'отжимание', 'push-up', 'pushup',
    'берпи', 'burpee',
    'планка', 'plank',
    'скручивание', 'crunch',
  ];

  /// Является ли упражнение базовым (многосуставным).
  static bool _isCompound(Exercise ex) {
    final lower = ex.name.toLowerCase();
    return _compoundKeywords.any((kw) => lower.contains(kw));
  }

  // ═══════════════════════════════════════════════════════════
  //  УМНЫЙ ПОДБОР УПРАЖНЕНИЙ (ГИБРИД)
  // ═══════════════════════════════════════════════════════════

  /// Умный подбор упражнений:
  /// — 2 базовых на группу (приоритет)
  /// — изолирующие — новые (не из последних 14 дней)
  /// — без повторов с другими днями (usedExerciseIds)
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
  }) {
    // ═══ 1. Фильтр по группам мышц ═══
    var filtered = allExercises.where((e) {
      return e.muscleGroups.any(muscleGroups.contains);
    }).toList();

    // ═══ 2. Фильтр по оборудованию ═══
    filtered = filtered.where((e) => _matchesEquipment(e, equipment)).toList();

    // ═══ 3. Фильтр по ограничениям ═══
    if (limitations.isNotEmpty) {
      filtered = filtered
          .where((e) => !e.contraindications.any(limitations.contains))
          .toList();
    }

    // ═══ 4. Фильтр по возрасту ═══
   // ═══ Фильтр по возрасту — ОТКЛЮЧЁН ═══
       // Возраст не учитывается при подборе упражнений.

    // ═══ 5. Исключить уже использованные в этой неделе ═══
    filtered = filtered
        .where((e) => e.id == null || !usedExerciseIds.contains(e.id))
        .toList();

    // ═══ 6. Разделить на базовые и изолирующие ═══
    final compounds = filtered.where(_isCompound).toList();
    final isolations = filtered.where((e) => !_isCompound(e)).toList();
 // ═══ 6.1. Убрать дубликаты по нормализованному имени ═══
    final usedNormalized = <String>{};

    List<Exercise> dedup(List<Exercise> list) {
      final result = <Exercise>[];
      for (final ex in list) {
        final norm = _normalizeName(ex.name);
        if (usedNormalized.contains(norm)) continue;
        usedNormalized.add(norm);
        result.add(ex);
      }
      return result;
    }

    final compoundsUnique = dedup(compounds);
    final isolationsUnique = dedup(isolations);
    // ═══ 7. Сортировка по matchScore ═══
    compoundsUnique.sort((a, b) =>
            _matchScore(b, level).compareTo(_matchScore(a, level)));
        isolationsUnique.sort((a, b) =>
            _matchScore(b, level).compareTo(_matchScore(a, level)));

    // ═══ 8. Выбор базовых (до 2, приоритет — из истории) ═══
    final picked = <Exercise>[];
    final usedIds = <int>{};

    // 8.1 Приоритет — базовые из истории (для прогрессии)
   final fromHistory = compoundsUnique
           .where((e) => e.id != null && recentExerciseIds.contains(e.id))
           .toList();
    fromHistory.shuffle(_random);

    for (final ex in fromHistory) {
      if (picked.length >= 2) break;
      if (ex.id == null || usedIds.contains(ex.id)) continue;
      picked.add(ex);
      usedIds.add(ex.id!);
    }

    // 8.2 Добить базовыми (новыми)
   final newCompounds = compoundsUnique
             .where((e) => e.id != null && !usedIds.contains(e.id))
             .toList()
           ..shuffle(_random);

      for (final ex in newCompounds) {
        if (picked.length >= 2) break;
        if (ex.id == null) continue;
        picked.add(ex);
        usedIds.add(ex.id!);
      }

    // ═══ 9. Добить изолирующими (НЕ из последних 14 дней — разнообразие) ═══
     final freshIsolations = isolationsUnique
            .where((e) => e.id != null && !recentExerciseIds.contains(e.id))
            .toList()
          ..shuffle(_random);

    for (final ex in freshIsolations) {
      if (picked.length >= maxCount) break;
      if (ex.id == null || usedIds.contains(ex.id)) continue;
      picked.add(ex);
      usedIds.add(ex.id!);
    }

    // ═══ 10. Если не хватило — добить любыми изолирующими ═══
    final rest = isolationsUnique
              .where((e) => e.id != null && !usedIds.contains(e.id))
              .toList()
            ..shuffle(_random);

      for (final ex in rest) {
        if (picked.length >= maxCount) break;
        if (ex.id == null) continue;
        picked.add(ex);
        usedIds.add(ex.id!);
      }

      // ═══ 11. Если всё ещё мало — добить базовыми ═══
        final restCompounds = compoundsUnique
            .where((e) => e.id != null && !usedIds.contains(e.id))
            .toList()
          ..shuffle(_random);

        for (final ex in restCompounds) {
          if (picked.length >= maxCount) break;
          if (ex.id == null) continue;
          picked.add(ex);
          usedIds.add(ex.id!);
        }

    // ═══ 12. Перемешать, чтобы базовые не были всегда первыми ═══
    // Оставляем первый базовый первым (разминка)
    if (picked.length > 2) {
      final head = picked.first;
      final tail = picked.sublist(1)..shuffle(_random);
      return [head, ...tail];
    }

    return picked;
  }

  /// Проверка соответствия оборудования.
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
    return true; // mixed — всё
  }

  /// Оценка соответствия уровню.
  static int _matchScore(Exercise e, String level) {
    if (e.difficulty == level) return 3;
    if (level == 'intermediate' && e.difficulty == 'beginner') return 2;
    if (level == 'advanced' && e.difficulty == 'intermediate') return 2;
    return 1;
  }

// ╔═══════════════════════════════════════════════════════════╗
// ║  ⚠️ ЧАСТЬ 2.3 ЗАКОНЧИЛАСЬ — ЖДИТЕ ЧАСТЬ 2.4              ║
// ╚═══════════════════════════════════════════════════════════╝
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

  // ═══════════════════════════════════════════════════════════
  //  ПАРАМЕТРЫ: ПОДХОДЫ / ПОВТОРЫ / ОТДЫХ
  // ═══════════════════════════════════════════════════════════

    static int _getSets(String level, int age) {
        switch (level) {
          case 'beginner':
            return 3;
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
  // ═══════════════════════════════════════════════════════════
  //  НОРМАЛИЗАЦИЯ НАЗВАНИЙ (для исключения дубликатов)
  // ═══════════════════════════════════════════════════════════

  /// Приводит название упражнения к «базовому» виду:
  /// убирает уточнения («на одной ноге», «с гантелями» и т.п.).
  ///
  /// Примеры:
  ///   «Ягодичный мостик» + «Ягодичный мостик на одной ноге»
  ///     → обе → «ягодичный мостик»
  ///   «Подъём на ступнях» + «Подъём на одной ноге»
  ///     → обе → «подъём на ступнях» (или «подъём на»)
  static String _normalizeName(String name) {
    var s = name.toLowerCase();

    // ═══ Уточнения — убрать ═══
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

    // ═══ Убрать знаки и лишние пробелы ═══
    s = s.replaceAll(RegExp(r'[,\-—–()\[\]:;]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }
  static int _getExerciseCount(int sessionMinutes) {
    if (sessionMinutes <= 30) return 4;
    if (sessionMinutes <= 45) return 6;
    if (sessionMinutes <= 60) return 7;
    return 8;
  }
}