import 'fairy_mood.dart';

/// Фразы феи-наставника: экраны, события, контекст, streak.
class FairyPhrases {
  FairyPhrases._();

  /// Пол профиля (мужской / женский).
  static bool _isMale(String? gender) {
    if (gender == null) return false;
    final g = gender.toLowerCase().trim();
    return g == 'male' || g == 'м' || g == 'мужской' || g == 'муж' || g == 'm';
  }

  // ═══════════════════════════════════════════════════════════
  //  ФРАЗЫ ПО ЭКРАНАМ (базовые)
  // ═══════════════════════════════════════════════════════════

  static const Map<String, List<String>> byScreen = {
    'profiles': [
      'Привет, {name}! Я твоя фея-тренер! 🧚',
      'Расскажи о себе, {name} — я узнаю тебя лучше!',
      'Профиль — это твой путь к цели, {name}!',
    ],
    'workout': [
      '{name}, что сегодня тренируем? 💪',
      '{готов_а} к тренировке, {name}? 🔥',
      'Сегодня — отличный день для тренировки, {name}!',
    ],
    'workout_detail': [
      'Поехали, {name}! 💪',
      'Приступим, {name}! 🔥',
      '{name}, вперёд — к результатам! 🚀',
    ],
    'catalog': [
      'Здесь можно изучить все упражнения! 📚',
      '{name}, выбирай упражнения и добавляй в план!',
    ],
    'yoga': [
      'Время расслабиться, {name} 🧘',
      'Дыхание ровное, {name} — начнём!',
      '{name}, йога — это гармония тела и души.',
    ],
    'progress': [
      'Смотри, как ты растёшь, {name}! 📈',
      'Твой прогресс вдохновляет, {name}!',
      'Ты {сделал_а} огромный шаг вперёд, {name}!',
    ],
    'history': [
      'Твои прошлые победы, {name}! 🏆',
      'Сколько {сделал_а}, {name} — молодец!',
      'История — твоя мотивация, {name}!',
    ],
    'settings': [
      'Настрой меня под себя, {name}! ⚙️',
      'Тёмная тема — для вечерних тренировок, {name}!',
    ],
    'default': [
      'Привет, {name}! Я твоя фея-тренер! 🧚',
      'Рада тебя видеть, {name}!',
    ],
  };

  static FairyMood screenMood(String screenKey) {
    switch (screenKey) {
      case 'workout':
      case 'workout_detail':
        return FairyMood.wink;
      case 'yoga':
        return FairyMood.yoga; // Лотос
      case 'progress':
      case 'history':
        return FairyMood.party;
      case 'settings':
        return FairyMood.think;
      case 'catalog':
        return FairyMood.wink;
      default:
        return FairyMood.happy;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ФРАЗЫ ПО СОБЫТИЯМ
  // ═══════════════════════════════════════════════════════════

  static const Map<String, String> byEvent = {
    'profile_created': 'Ура, профиль создан, {name}! 🎉',
    'profile_updated': 'Обновила твои данные, {name}! ✅',
    'plan_generated': 'План создан, {name}! Погнали феячить! 🧚✨',
    'plan_updated': 'План обновлён, {name}! Время феячить! 🔥',
    'profile_changed_ask': '{name}, ты {изменил_а} профиль, не забудь обновить план! 💡',
    'workout_started': 'Отлично, {name}! Первый подход — твой! 💪',
    'exercise_completed': 'Упражнение готово, {name}! 💪',
    'workout_deleted': 'Удалила тренировку.',
    'history_cleared': 'История очищена, {name}. Начнём заново! 🧚',
    'theme_changed': 'Красиво, {name}! Мне нравится! 🎨',

    // 👇 НОВЫЕ СОБЫТИЯ ДЛЯ ТРЕНИРОВОК
    'workout_completed': 'Супер, {name}! Ты {сделал_а} это! План выполнен на 100%! 🎉',
    'workout_partial': 'Не расстраивайся, {name}! Даже часть тренировки — это шаг вперёд. Главное — ты пришёл! 💪',
    'workout_overperformed': 'Вот это мощь, {name}! Ты поднял больше, чем мы планировали! Настоящий герой! 🔥',
  };

  static FairyMood eventMood(String eventKey) {
    switch (eventKey) {
      case 'profile_created':
      case 'plan_generated':
      case 'plan_updated':
      case 'workout_completed':
      case 'workout_overperformed': // 👈 Превысил план — восторг
        return FairyMood.party;
      case 'workout_partial': // 👈 Недоделал — просто поддержка
        return FairyMood.happy;
      case 'profile_changed_ask':
      case 'history_cleared':
        return FairyMood.think;
      case 'workout_started':
      case 'exercise_completed':
      case 'theme_changed':
        return FairyMood.wink;
      default:
        return FairyMood.happy;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ФРАЗЫ ПО КОНТЕКСТУ
  // ═══════════════════════════════════════════════════════════

  static const List<String> morning = [
    'Доброе утро, {name}! ☀️ Зарядка?',
    'Утро — лучшее время для тренировки, {name}!',
  ];

  static const List<String> afternoon = [
    'Добрый день, {name}! Как настроение?',
    'Самое время для тренировки, {name}! 💪',
  ];

  static const List<String> evening = [
    'Добрый вечер, {name}! Лёгкая йога? 🧘',
    'Вечер — для расслабления, {name}.',
  ];

  static const List<String> night = [
    'Поздно, {name}! Пора спать 😴',
    'Отдых — часть тренировки, {name}!',
  ];

  static const Map<String, List<String>> byGoal = {
    'lose_weight': [
      'Кардио-день, {name}! Погнали! 🔥',
      'Меньше отдыха — больше результата, {name}!',
    ],
    'gain_mass': [
      'Тяжелее — значит, сильнее, {name}! 💪',
      'Поешь после тренировки, {name}! 🍗',
    ],
    'tone': [
      'Тонус — твоя цель, {name}! ✨',
      'Мягко, но регулярно, {name}!',
    ],
    'strength': [
      'Ты растёшь в силе, {name}! 💪',
      'Больше вес — больше результат, {name}!',
    ],
  };

  // ═══════════════════════════════════════════════════════════
  //  STREAK
  // ═══════════════════════════════════════════════════════════

  static const List<String> streak3 = [
    'Ты в огне, {name}! 🔥 3 дня подряд!',
    'Ни дня без тренировки, {name}!',
  ];

  static const List<String> streak7 = [
    '🏆 Неделя тренировок, {name}! Ты чемпион!',
    'Целая неделя! {name}, ты супер! 💎',
  ];

  static const List<String> streak30 = [
    '💎 Месяц, {name}! Ты легенда!',
    'Месяц дисциплины, {name}! Горжусь!',
  ];

  static const List<String> comeback = [
    'Скучаю, {name}! Давай лёгкую тренировку?',
    'Ты давно не заходил, {name} 🥺',
  ];

  // ═══════════════════════════════════════════════════════════
  //  СИТУАЦИИ
  // ═══════════════════════════════════════════════════════════

  static const Map<String, List<String>> bySituation = {
    'pre_workout': [
      'Погнали феячить, {name}! 🧚✨',
      '{name}, время феячить! 🧚🔥',
    ],
    'no_profile': [
      'Создай профиль, {name} — я подберу план! 🧚',
      'Без профиля я не смогу подобрать тренировки, {name}.',
    ],
    'no_plan': [
      '{name}, профиль готов! 🎉 Составим план?',
      'Готова к плану, {name}? Нажми «Создать план» 🧚',
    ],
    'has_plan_not_started': [
      'План ждёт тебя, {name}! Начнём тренировку?',
      'Не откладывай, {name} — тренировка готова! 🔥',
    ],
    'in_progress': [
      'Продолжай, {name}! Ты справляешься! 💪',
      'Отличный темп, {name}!',
    ],
  };

  static FairyMood situationMood(String situation) {
    switch (situation) {
      case 'pre_workout':
        return FairyMood.party;
      case 'no_profile':
      case 'no_plan':
        return FairyMood.think;
      case 'has_plan_not_started':
      case 'in_progress':
        return FairyMood.wink;
      default:
        return FairyMood.happy;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ОНБОРДИНГ
  // ═══════════════════════════════════════════════════════════

  static const List<Map<String, String>> onboarding = [
    {
      'title': 'Привет! Я твоя фея-тренер!',
      'text': 'Я помогу тебе составить план, буду следить за прогрессом и подсказывать, что делать.',
    },
    {
      'title': 'Создай профиль 🧚',
      'text': 'Расскажи о себе — пол, возраст, цели. Я подберу тренировки именно под тебя!',
    },
    {
      'title': 'Получи план 💪',
      'text': 'Нажми «Создать план» — я соберу программу на неделю по твоим целям и инвентарю.',
    },
    {
      'title': 'Погнали! 🎉',
      'text': 'Я всегда рядом — внизу экрана. Тапни по мне, если нужна подсказка!',
    },
  ];

  // ═══════════════════════════════════════════════════════════
  //  ХЕЛПЕРЫ
  // ═══════════════════════════════════════════════════════════

  static String apply(
    String template,
    String? name, {
    String? gender,
  }) {
    final n = (name == null || name.trim().isEmpty) ? 'друг' : name.trim();
    final isMale = _isMale(gender);

    return template
        .replaceAll('{name}', n)
        .replaceAll('{он_она}', isMale ? 'он' : 'она')
        .replaceAll('{сделал_а}', isMale ? 'сделал' : 'сделала')
        .replaceAll('{готов_а}', isMale ? 'готов' : 'готова')
        .replaceAll('{устал_а}', isMale ? 'устал' : 'устала')
        .replaceAll('{изменил_а}', isMale ? 'изменил' : 'изменила')
        .replaceAll('{обновил_а}', isMale ? 'обновил' : 'обновила')
        .replaceAll('{выбрал_а}', isMale ? 'выбрал' : 'выбрала')
        .replaceAll('{начал_а}', isMale ? 'начал' : 'начала')
        .replaceAll('{закончил_а}', isMale ? 'закончил' : 'закончила')
        .replaceAll('{рад_а}', isMale ? 'рад' : 'рада')
        .replaceAll('{должен_должна}', isMale ? 'должен' : 'должна');
  }

  static List<String> forScreen(
    String screen, {
    String? name,
    String? gender,
  }) {
    final list = byScreen[screen] ?? byScreen['default']!;
    return list.map((t) => apply(t, name, gender: gender)).toList();
  }

  static List<({String text, FairyMood mood})> forScreenWithMood(
    String screen, {
    String? name,
    String? gender,
  }) {
    final mood = screenMood(screen);
    return forScreen(screen, name: name, gender: gender)
        .map((t) => (text: t, mood: mood))
        .toList();
  }

  static List<String> forSituation(
    String situation, {
    String? name,
    String? gender,
  }) {
    final list = bySituation[situation] ?? [];
    return list.map((t) => apply(t, name, gender: gender)).toList();
  }

  static List<({String text, FairyMood mood})> forSituationWithMood(
    String situation, {
    String? name,
    String? gender,
  }) {
    final mood = situationMood(situation);
    return forSituation(situation, name: name, gender: gender)
        .map((t) => (text: t, mood: mood))
        .toList();
  }

  static String contextualPhrase({
    required int hour,
    String? name,
    String? goal,
    int? streakDays,
    String? gender,
  }) {
    if (hour >= 23 || hour < 6) {
      return _pick(night, name, gender);
    }
    if (streakDays != null) {
      if (streakDays >= 30) return _pick(streak30, name, gender);
      if (streakDays >= 7) return _pick(streak7, name, gender);
      if (streakDays >= 3) return _pick(streak3, name, gender);
    }
    if (goal != null && byGoal.containsKey(goal)) {
      return _pick(byGoal[goal]!, name, gender);
    }
    if (hour < 12) return _pick(morning, name, gender);
    if (hour < 18) return _pick(afternoon, name, gender);
    return _pick(evening, name, gender);
  }

  static FairyMood contextualMood({
    required int hour,
    int? streakDays,
  }) {
    if (hour >= 23 || hour < 6) return FairyMood.sleepy;
    if (streakDays != null && streakDays >= 7) return FairyMood.party;
    if (hour < 12) return FairyMood.wink;
    if (hour < 18) return FairyMood.happy;
    return FairyMood.sleepy;
  }

  static String _pick(
    List<String> list,
    String? name,
    String? gender,
  ) {
    if (list.isEmpty) return '';
    final t = list[DateTime.now().millisecondsSinceEpoch % list.length];
    return apply(t, name, gender: gender);
  }

  static String eventPhrase(
    String eventKey, {
    String? name,
    String? gender,
  }) {
    final t = byEvent[eventKey];
    if (t == null) return '';
    return apply(t, name, gender: gender);
  }
}