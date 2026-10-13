import 'dart:math';
import '../models/exercise.dart';
import '../models/stretch.dart';
import '../models/user_profile.dart';
import '../models/workout_template.dart';
import 'database_helper.dart';

/// Генератор плана тренировок на основе профиля пользователя.
class WorkoutGenerator {
  static final Random _random = Random();

  // ═══════════════════════════════════════════════════════════
  //  ГЛАВНЫЙ МЕТОД — сгенерировать план на неделю
  // ═══════════════════════════════════════════════════════════

  static Future<List<WorkoutTemplate>> generateWeekPlan(
    UserProfile profile,
  ) async {
    // 1. Определить группы мышц по фокусным зонам профиля
    final focusGroups = _getFocusGroups(profile);

    // 2. Распределить группы по дням (с учётом ограничений)
    final dayPlans = _distributeByDays(
      focusGroups,
      profile.daysPerWeek,
      limitations: profile.limitations,
    );

    // 3. Загрузить ВСЕ данные ИЗ БАЗЫ (у них есть ID)
    final allExercises = await DatabaseHelper.instance.getExercises();
    final allStretches = await DatabaseHelper.instance.getStretches();

    // 4. Создать шаблоны
    final templates = <WorkoutTemplate>[];

    for (int i = 0; i < dayPlans.length; i++) {
      final groups = dayPlans[i];
      final dayName = _getDayName(groups, i + 1);

      // ═══ 4.1. Подобрать силовые упражнения ═══
      final exercises = _pickExercises(
        allExercises: allExercises,
        muscleGroups: groups,
        equipment: profile.equipment,
        level: profile.level,
        limitations: profile.limitations,
        maxCount: _getExerciseCount(profile.sessionMinutes),
        age: profile.age,
      );

      // ═══ 4.2. Подобрать заминку ═══
      final coolDown = _pickCoolDown(
        allStretches: allStretches,
        trainedGroups: groups,
        maxCount: 5,
      );

      // ═══ 4.3. Создать шаблон ═══
      final template = WorkoutTemplate(
        profileId: profile.id!,
        name: dayName,
        type: 'strength',
        estimatedMinutes: profile.sessionMinutes,
      );

      final templateId = await DatabaseHelper.instance.saveTemplate(template);

      // ═══ 4.4. Сохранить упражнения в шаблон ═══
      int order = 1;
      for (final ex in exercises) {
        if (ex.id == null) continue;
        await DatabaseHelper.instance.addTemplateItem(TemplateItem(
          templateId: templateId,
          itemType: 'exercise',
          itemId: ex.id!,
          order: order++,
          sets: _getSets(profile.level, profile.age),
          reps: _getReps(profile.goal, profile.age),
          restSeconds: _getRest(profile.goal, profile.age),
        ));
      }

      // ═══ 4.5. Сохранить заминку ═══
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
      final saved = await DatabaseHelper.instance.getTemplateById(templateId);
      if (saved != null) templates.add(saved);
    }

    return templates;
  }

  // ═══════════════════════════════════════════════════════════
  //  ОПРЕДЕЛЕНИЕ ГРУПП МЫШЦ
  // ═══════════════════════════════════════════════════════════

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

  /// Распределить группы мышц по дням недели.
  /// ГАРАНТИРУЕТ разные пары для каждого дня.
  /// Учитывает ограничения — исключает опасные группы.
  static List<List<String>> _distributeByDays(
    List<String> focusGroups,
    int daysCount, {
    List<String> limitations = const [],
  }) {
    // Все возможные пары
    final allPairs = <List<String>>[
      ['glutes', 'abs'],
      ['arms', 'shoulders'],
      ['back', 'chest'],
      ['legs', 'calves'],
      ['hamstrings', 'glutes'],
      ['biceps', 'triceps'],
      ['abs', 'obliques'],
      ['lats', 'traps'],
      ['quads', 'hamstrings'],
      ['chest', 'triceps'],
      ['glutes', 'legs'],
      ['back', 'lats'],
    ];

    // Исключаем пары, содержащие группы из ограничений
    final safePairs = allPairs.where((pair) {
      return !pair.any((g) => limitations.contains(g));
    }).toList();

    // Если после фильтрации пусто — берём все (защита)
    final sourcePairs = safePairs.isNotEmpty ? safePairs : allPairs;

    final focusSet = focusGroups.toSet();
    final result = <List<String>>[];
    final used = <int>{};

    for (int i = 0; i < daysCount; i++) {
      int? picked;

      // 1. Ищем пару с фокус-группой
      for (int j = 0; j < sourcePairs.length; j++) {
        if (used.contains(j)) continue;
        if (sourcePairs[j].any((g) => focusSet.contains(g))) {
          picked = j;
          break;
        }
      }

      // 2. Если не нашли — любая неиспользованная
      if (picked == null) {
        for (int j = 0; j < sourcePairs.length; j++) {
          if (!used.contains(j)) {
            picked = j;
            break;
          }
        }
      }

      // 3. Если все использованы — циклически
      if (picked == null) {
        picked = i % sourcePairs.length;
      }

      used.add(picked);
      result.add(List<String>.from(sourcePairs[picked]));
    }

    return result;
  }

  static String _getDayName(List<String> groups, int dayNumber) {
    final labels = groups.map(_groupLabel).toList();
    return 'День $dayNumber: ${labels.join(' + ')}';
  }

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
    };
    return map[code] ?? code;
  }

  // ═══════════════════════════════════════════════════════════
  //  ПОДБОР СИЛОВЫХ УПРАЖНЕНИЙ
  // ═══════════════════════════════════════════════════════════

  static List<Exercise> _pickExercises({
    required List<Exercise> allExercises,
    required List<String> muscleGroups,
    required String equipment,
    required String level,
    required List<String> limitations,
    required int maxCount,
    required int age,
  }) {
    // 1. Фильтр по группам мышц
    var filtered = allExercises.where((e) {
      return e.muscleGroups.any(muscleGroups.contains);
    }).toList();

    // 2. Фильтр по инвентарю
    filtered = filtered.where((e) {
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
    }).toList();

    // 3. Фильтр по ограничениям
    if (limitations.isNotEmpty) {
      filtered = filtered
          .where((e) => !e.contraindications.any(limitations.contains))
          .toList();
    }

    // 4. Фильтр по возрасту
    if (age >= 45) {
      filtered = filtered.where((e) => e.difficulty != 'advanced').toList();
    }
    if (age >= 60) {
      filtered = filtered.where((e) => e.difficulty == 'beginner').toList();
    }

    // 5. Сортировка по уровню соответствия
    filtered.sort((a, b) {
      final aScore = _matchScore(a, level);
      final bScore = _matchScore(b, level);
      return bScore.compareTo(aScore);
    });

    // 6. Перемешать верхнюю часть и взять нужное количество
    final top = filtered.take(min(20, filtered.length)).toList();
    top.shuffle(_random);

    return top.take(maxCount).toList();
  }

  static int _matchScore(Exercise e, String level) {
    if (e.difficulty == level) return 3;
    if (level == 'intermediate' && e.difficulty == 'beginner') return 2;
    if (level == 'advanced' && e.difficulty == 'intermediate') return 2;
    return 1;
  }

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
  //  ПАРАМЕТРЫ УПРАЖНЕНИЙ
  // ═══════════════════════════════════════════════════════════

  static int _getSets(String level, int age) {
    if (age >= 60) return 2;
    if (age >= 45) return 3;
    switch (level) {
      case 'beginner':
        return 3;
      case 'intermediate':
        return 4;
      case 'advanced':
        return 5;
      default:
        return 3;
    }
  }

  static String _getReps(String goal, int age) {
    if (age >= 60) return '10-12';
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
    if (age >= 60) return 90;
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

  static int _getExerciseCount(int sessionMinutes) {
    if (sessionMinutes <= 30) return 4;
    if (sessionMinutes <= 45) return 6;
    if (sessionMinutes <= 60) return 7;
    return 8;
  }
}