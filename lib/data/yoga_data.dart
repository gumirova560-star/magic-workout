import '../models/yoga_session.dart';

/// База йога-сессий.
/// 7 готовых сессий + шаги к ним.
///
/// ⚠️ Шаги ссылаются на йога-позы по ИМЕНИ (stretchName).
/// При первой инициализации базы код найдёт ID позы по имени
/// и создаст запись YogaStep с правильным stretchId.

// ═══════════════════════════════════════════════════════════
//  7 ЙОГА-СЕССИЙ
// ═══════════════════════════════════════════════════════════

List<YogaSession> getYogaSessionsData() {
  return [
    YogaSession(
      name: 'Йога для спины',
      focus: 'back',
      durationMinutes: 25,
      description:
          'Мягкая практика для снятия напряжения в спине. Особенно полезна после сидячей работы.',
    ),

    YogaSession(
      name: 'Йога для гибкости',
      focus: 'flexibility',
      durationMinutes: 30,
      description:
          'Растяжка всего тела для улучшения подвижности и гибкости. Подходит для среднего уровня.',
    ),

    YogaSession(
      name: 'Йога для расслабления',
      focus: 'relax',
      durationMinutes: 20,
      description:
          'Спокойная практика для снятия стресса и восстановления. Можно делать в любое время.',
    ),

    YogaSession(
      name: 'Йога для ягодиц и бёдер',
      focus: 'glutes',
      durationMinutes: 25,
      description:
          'Раскрытие тазобедренных суставов и глубокая растяжка ягодиц. Хорошо после дня ног.',
    ),

    YogaSession(
      name: 'Утренняя йога',
      focus: 'morning',
      durationMinutes: 15,
      description:
          'Бодрящая короткая практика для пробуждения тела и ума.',
    ),

    YogaSession(
      name: 'Йога для пресса и кора',
      focus: 'core',
      durationMinutes: 20,
      description:
          'Укрепление мышц кора и пресса через статические позы.',
    ),

    YogaSession(
      name: 'Йога перед сном',
      focus: 'relax',
      durationMinutes: 15,
      description:
          'Спокойная практика для расслабления и подготовки ко сну.',
    ),
  ];
}

// ═══════════════════════════════════════════════════════════
//  ШАГИ ДЛЯ КАЖДОЙ СЕССИИ
// ═══════════════════════════════════════════════════════════

/// Шаги, сгруппированные по индексу сессии в getYogaSessionsData().
/// [stretchName] — точное имя йога-позы из stretches_data.dart.
List<List<YogaStepData>> getYogaStepsData() {
  return [
    // ═══ 0. Йога для спины (25 мин) ═══
    [
      const YogaStepData('Кошка-корова', 60, false, 'Разминка для спины'),
      const YogaStepData('Поза сфинкса', 30, false, 'Мягкий прогиб'),
      const YogaStepData('Поза кобры', 30, false, 'Укрепляет спину'),
      const YogaStepData('Скручивание сидя', 30, true, 'По 30 сек на сторону'),
      const YogaStepData('Наклон вперёд сидя', 45, false, 'Растяжка задней цепи'),
      const YogaStepData('Поза ребёнка', 60, false, 'Расслабление'),
      const YogaStepData('Поза трупа', 120, false, 'Завершение'),
    ],

    // ═══ 1. Йога для гибкости (30 мин) ═══
    [
      const YogaStepData('Поза горы', 30, false, 'Настройка'),
      const YogaStepData('Кошка-корова', 60, false, 'Разогрев'),
      const YogaStepData('Собака мордой вниз', 45, false, 'Растяжка задней цепи'),
      const YogaStepData('Поза вытянутого угла', 30, false, 'Раскрытие бёдер'),
      const YogaStepData('Поза бабочки', 45, false, 'Внутренняя поверхность бедра'),
      const YogaStepData('Поза верблюда', 30, false, 'Раскрытие груди'),
      const YogaStepData('Поза голубя', 60, true, 'По 60 сек на сторону'),
      const YogaStepData('Наклон вперёд сидя', 45, false, 'Растяжка'),
      const YogaStepData('Поза трупа', 120, false, 'Завершение'),
    ],

    // ═══ 2. Йога для расслабления (20 мин) ═══
    [
      const YogaStepData('Поза горы', 30, false, 'Настройка'),
      const YogaStepData('Скручивание сидя', 30, true, 'По 30 сек на сторону'),
      const YogaStepData('Поза счастливого ребёнка', 45, false, 'Расслабление'),
      const YogaStepData('Поза бабочки лёжа', 45, false, 'Раскрытие бёдер'),
      const YogaStepData('Ноги вверх на стене', 60, false, 'Инверсия'),
      const YogaStepData('Поза трупа', 180, false, 'Глубокое расслабление'),
    ],

    // ═══ 3. Йога для ягодиц и бёдер (25 мин) ═══
    [
      const YogaStepData('Кошка-корова', 60, false, 'Разогрев'),
      const YogaStepData('Поза голубя', 60, true, 'По 60 сек на сторону'),
      const YogaStepData('Поза ящерицы', 45, true, 'По 45 сек на сторону'),
      const YogaStepData('Поза лягушки', 45, false, 'Глубокая растяжка'),
      const YogaStepData('Поза бабочки', 45, false, 'Внутренняя поверхность бедра'),
      const YogaStepData('Поза воина II', 30, true, 'По 30 сек на сторону'),
      const YogaStepData('Поза счастливого ребёнка', 45, false, 'Завершение'),
      const YogaStepData('Поза трупа', 90, false, 'Расслабление'),
    ],

    // ═══ 4. Утренняя йога (15 мин) ═══
    [
      const YogaStepData('Поза горы', 30, false, 'Настройка'),
      const YogaStepData('Кошка-корова', 60, false, 'Разогрев'),
      const YogaStepData('Собака мордой вниз', 45, false, 'Пробуждение'),
      const YogaStepData('Поза воина I', 30, true, 'По 30 сек на сторону'),
      const YogaStepData('Поза дерева', 30, true, 'По 30 сек на сторону'),
      const YogaStepData('Наклон вперёд стоя', 30, false, 'Растяжка'),
      const YogaStepData('Поза горы', 30, false, 'Завершение'),
    ],

    // ═══ 5. Йога для пресса и кора (20 мин) ═══
    [
      const YogaStepData('Кошка-корова', 60, false, 'Разогрев'),
      const YogaStepData('Планка йога', 45, false, 'Кор'),
      const YogaStepData('Боковая планка йога', 30, true, 'По 30 сек на сторону'),
      const YogaStepData('Поза лодки', 30, false, 'Пресс'),
      const YogaStepData('Поза моста', 30, false, 'Спина и кор'),
      const YogaStepData('Поза кобры', 30, false, 'Прогиб'),
      const YogaStepData('Поза ребёнка', 60, false, 'Отдых'),
      const YogaStepData('Поза трупа', 90, false, 'Завершение'),
    ],

    // ═══ 6. Йога перед сном (15 мин) ═══
    [
      const YogaStepData('Скручивание сидя', 30, true, 'По 30 сек на сторону'),
      const YogaStepData('Поза счастливого ребёнка', 45, false, 'Расслабление'),
      const YogaStepData('Поза бабочки лёжа', 45, false, 'Раскрытие бёдер'),
      const YogaStepData('Ноги вверх на стене', 90, false, 'Снятие усталости'),
      const YogaStepData('Поза трупа', 180, false, 'Сон'),
    ],
  ];
}

// ═══════════════════════════════════════════════════════════
//  ВСПОМОГАТЕЛЬНЫЙ КЛАСС
// ═══════════════════════════════════════════════════════════

/// Промежуточное описание шага йога-сессии.
/// Ссылается на йога-позу по ИМЕНИ (а не по ID).
/// При инициализации базы код преобразует это в YogaStep.
class YogaStepData {
  final String stretchName; // точное имя из stretches_data.dart
  final int durationSeconds;
  final bool bothSides;
  final String? notes;

  const YogaStepData(
    this.stretchName,
    this.durationSeconds,
    this.bothSides, [
    this.notes,
  ]);
}