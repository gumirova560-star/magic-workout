import 'fairy_mood.dart';

/// Фразы феи-наставника: экраны, события, контекст, streak.
///
/// Поддерживает род:
///   {name}        — имя профиля
///   {он_она}      — он / она
///   {сделал_а}    — сделал / сделала
///   {готов_а}     — готов / готова
///   {устал_а}     — устал / устала
class FairyPhrases {
  FairyPhrases._();

  /// Пол профиля (мужской / женский).
  static bool _isMale(String? gender) {
    if (gender == null) return false;
    final g = gender.toLowerCase().trim();
    return g == 'male' ||
        g == 'м' ||
        g == 'мужской' ||
        g == 'муж' ||
        g == 'm';
  }

  // ═══════════════════════════════════════════════════════════
  //  ФРАЗЫ ПО ЭКРАНАМ (базовые)
  // ═══════════════════════════════════════════════════════════

  static const Map<String, List<String>> byScreen = {
    'profiles': [
      // ═══ Убрали «Создай профиль» — она в bySituation['no_profile'] ═══
      'Привет, {name}! Я твоя фея-тренер! 🧚',
      'Расскажи о себе, {name} — я узнаю тебя лучше!',
      'Профиль — это твой путь к цели, {name}!',
      'Сколько у тебя профилей, {name}? 😊',
    ],
    'workout': [
      'Давай составим план тренировок, {name}! 💪',
      '{готов_а}, {name}? Я подберу упражнения!',
      'Сегодня — отличный день для тренировки, {name}!',
    ],
    'yoga': [
      'Дыхание ровное, {name} 🧘',
      'Йога — это баланс, {name}.',
      'Потянись — тело скажет спасибо, {name}!',
    ],
    'progress': [
      'Смотри, как ты растёшь, {name}! 📈',
      'Твой прогресс вдохновляет, {name}!',
      'Ты стал сильнее, {name} — я вижу!',
    ],
    'history': [
      'Твои прошлые победы, {name}! 🏆',
      'Сколько {сделал_а}, {name} — молодец!',
      'История — твоя мотивация, {name}!',
    ],
    'settings': [
      'Настрой меня под себя, {name}! ⚙️',
      'Тёмная тема — для вечерних тренировок, {name}!',
      'Я подстроюсь под тебя, {name}!',
    ],
    'default': [
      'Привет, {name}! Я твоя фея-тренер! 🧚',
      'Рада тебя видеть, {name}!',
      '{готов_а} к новым победам, {name}?',
    ],
  };

  static FairyMood screenMood(String screenKey) {
    switch (screenKey) {
      case 'workout':
        return FairyMood.wink;
      case 'yoga':
        return FairyMood.think;
      case 'progress':
        return FairyMood.party;
      case 'history':
        return FairyMood.party;
      case 'settings':
        return FairyMood.think;
      case 'profiles':
        return FairyMood.happy;
      default:
        return FairyMood.happy;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ФРАЗЫ ПО СОБЫТИЯМ
  // ═══════════════════════════════════════════════════════════

  static const Map<String, String> byEvent = {
    'profile_created': 'Отлично, {name}! Я запомнила тебя! 🎉',
    'profile_updated': 'Обновила твои данные, {name}! ✅',
    'plan_generated': 'План готов, {name}! Начнём? 💪',
    'workout_started': 'Погнали, {name}! Ты справишься! 🔥',
    'workout_completed': 'Супер, {name}! Ты {сделал_а} это! 🎉',
    'exercise_completed': 'Упражнение готово, {name}! 💪',
    'workout_deleted': 'Удалила тренировку.',
    'history_cleared': 'История очищена, {name}. Начнём заново! 🧚',
    'theme_changed': 'Красиво, {name}! Мне нравится! 🎨',
  };

  static FairyMood eventMood(String eventKey) {
    switch (eventKey) {
      case 'profile_created':
        return FairyMood.party;
      case 'profile_updated':
        return FairyMood.happy;
      case 'plan_generated':
        return FairyMood.party;
      case 'workout_started':
        return FairyMood.wink;
      case 'workout_completed':
        return FairyMood.party;
      case 'exercise_completed':
        return FairyMood.wink;
      case 'workout_deleted':
        return FairyMood.think;
      case 'history_cleared':
        return FairyMood.think;
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
    'Кофе, разминка — и вперёд, {name}! ☕',
  ];

  static const List<String> afternoon = [
    'Добрый день, {name}! Как настроение?',
    'Самое время для тренировки, {name}! 💪',
    'Хорошего дня, {name}! Потренируемся?',
  ];

  static const List<String> evening = [
    'Добрый вечер, {name}! Лёгкая йога? 🧘',
    'Вечер — для расслабления, {name}.',
    'Как прошёл день, {name}?',
  ];

  static const List<String> night = [
    'Поздно, {name}! Пора спать 😴',
    'Отдых — часть тренировки, {name}!',
    'До завтра, {name}! 🌙',
  ];

  static const Map<String, List<String>> byGoal = {
    'lose_weight': [
      'Кардио-день, {name}! Погнали! 🔥',
      'Меньше отдыха — больше результата, {name}!',
      'Ты сжигаешь калории, {name}! 💪',
    ],
    'gain_mass': [
      'Тяжелее — значит, сильнее, {name}! 💪',
      'Поешь после тренировки, {name}! 🍗',
      'Прогрессия — твой друг, {name}!',
    ],
    'tone': [
      'Тонус — твоя цель, {name}! ✨',
      'Мягко, но регулярно, {name}!',
      'Каждый день — шаг к форме, {name}!',
    ],
    'strength': [
      'Ты растёшь в силе, {name}! 💪',
      'Больше вес — больше результат, {name}!',
      'Сила — это уверенность, {name}!',
    ],
  };

  // ═══════════════════════════════════════════════════════════
  //  STREAK
  // ═══════════════════════════════════════════════════════════

  static const List<String> streak3 = [
    'Ты в огне, {name}! 🔥 3 дня подряд!',
    'Ни дня без тренировки, {name}! Так держать!',
    'Дисциплина — твоё супер-оружие, {name}!',
  ];

  static const List<String> streak7 = [
    '🏆 Неделя тренировок, {name}! Ты чемпион!',
    '{name}, 7 дней подряд! Невероятно!',
    'Целая неделя! {name}, ты супер! 💎',
  ];

  static const List<String> streak30 = [
    '💎 Месяц, {name}! Ты легенда!',
    '{name}, 30 дней! Это подвиг! 🏆',
    'Месяц дисциплины, {name}! Горжусь!',
  ];

  static const List<String> comeback = [
    'Скучаю, {name}! Давай лёгкую тренировку?',
    'Ты давно не заходил, {name} 🥺',
    'Всё ещё жду тебя, {name}! 🧚',
  ];

  // ═══════════════════════════════════════════════════════════
  //  СИТУАЦИИ
  // ═══════════════════════════════════════════════════════════

  static const Map<String, List<String>> bySituation = {
    'no_profile': [
      // ═══ Единственное место, где появляется «Создай профиль» ═══
      'Создай профиль, {name} — я подберу план! 🧚',
      '{name}, расскажи о себе — и начнём!',
      'Без профиля я не смогу подобрать тренировки, {name}.',
    ],
    'no_plan': [
      'Профиль есть, {name}! Теперь нажми «Создать план»!',
      '{name}, план готовится в один клик — попробуй!',
      'Пора составить план, {name}! 💪',
    ],
    'has_plan_not_started': [
      'План ждёт тебя, {name}! Начнём тренировку?',
      '{name}, {готов_а} начать? Открой «Мой план»!',
      'Не откладывай, {name} — тренировка готова! 🔥',
    ],
    'in_progress': [
      'Продолжай, {name}! Ты справляешься! 💪',
      '{name}, ещё немного — и всё!',
      'Отличный темп, {name}!',
    ],
  };

  static FairyMood situationMood(String situation) {
    switch (situation) {
      case 'no_profile':
        return FairyMood.think;
      case 'no_plan':
        return FairyMood.think;
      case 'has_plan_not_started':
        return FairyMood.wink;
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
      'text': 'Я помогу тебе составить план, '
          'буду следить за прогрессом и подсказывать, что делать.',
    },
    {
      'title': 'Создай профиль 🧚',
      'text': 'Расскажи о себе — пол, возраст, цели. '
          'Я подберу тренировки именно под тебя!',
    },
    {
      'title': 'Получи план 💪',
      'text': 'Нажми «Создать план» — я соберу программу '
          'на неделю по твоим целям и инвентарю.',
    },
    {
      'title': 'Следи за прогрессом 📈',
      'text': 'В разделе «Прогресс» — графики роста, '
          'история тренировок, статистика.',
    },
    {
      'title': 'Погнали! 🎉',
      'text': 'Я всегда рядом — внизу экрана. '
          'Тапни по мне, если нужна подсказка!',
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
        .replaceAll('{устал_а}', isMale ? 'устал' : 'устала');
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