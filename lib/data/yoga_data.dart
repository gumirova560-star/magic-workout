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
      YogaStepData('Кошка-корова', 60, false, 'Разминка для спины'),
      YogaStepData('Поза сфинкса', 30, false, 'Мягкий прогиб'),
      YogaStepData('Поза кобры', 30, false, 'Укрепляет спину'),
      YogaStepData('Скручивание сидя', 30, true, 'По 30 сек на сторону'),
      YogaStepData('Наклон вперёд сидя', 45, false, 'Растяжка задней цепи'),
      YogaStepData('Поза ребёнка', 60, false, 'Расслабление'),
      YogaStepData('Поза трупа', 120, false, 'Завершение'),
    ],

    // ═══ 1. Йога для гибкости (30 мин) ═══
    [
      YogaStepData('Поза горы', 30, false, 'Настройка'),
      YogaStepData('Кошка-корова', 60, false, 'Разогрев'),
      YogaStepData('Собака мордой вниз', 45, false, 'Растяжка задней цепи'),
      YogaStepData('Поза вытянутого угла', 30, false, 'Раскрытие бёдер'),
      YogaStepData('Поза бабочки', 45, false, 'Внутренняя поверхность бедра'),
      YogaStepData('Поза верблюда', 30, false, 'Раскрытие груди'),
      YogaStepData('Поза голубя', 60, true, 'По 60 сек на сторону'),
      YogaStepData('Наклон вперёд сидя', 45, false, 'Растяжка'),
      YogaStepData('Поза трупа', 120, false, 'Завершение'),
    ],

    // ═══ 2. Йога для расслабления (20 мин) ═══
    [
      YogaStepData('Поза горы', 30, false, 'Настройка'),
      YogaStepData('Скручивание сидя', 30, true, 'По 30 сек на сторону'),
      YogaStepData('Поза счастливого ребёнка', 45, false, 'Расслабление'),
      YogaStepData('Поза бабочки лёжа', 45, false, 'Раскрытие бёдер'),
      YogaStepData('Ноги вверх на стене', 60, false, 'Инверсия'),
      YogaStepData('Поза трупа', 180, false, 'Глубокое расслабление'),
    ],

    // ═══ 3. Йога для ягодиц и бёдер (25 мин) ═══
    [
      YogaStepData('Кошка-корова', 60, false, 'Разогрев'),
      YogaStepData('Поза голубя', 60, true, 'По 60 сек на сторону'),
      YogaStepData('Поза ящерицы', 45, true, 'По 45 сек на сторону'),
      YogaStepData('Поза лягушки', 45, false, 'Глубокая растяжка'),
      YogaStepData('Поза бабочки', 45, false, 'Внутренняя поверхность бедра'),
      YogaStepData('Поза воина II', 30, true, 'По 30 сек на сторону'),
      YogaStepData('Поза счастливого ребёнка', 45, false, 'Завершение'),
      YogaStepData('Поза трупа', 90, false, 'Расслабление'),
    ],

    // ═══ 4. Утренняя йога (15 мин) ═══
    [
      YogaStepData('Поза горы', 30, false, 'Настройка'),
      YogaStepData('Кошка-корова', 60, false, 'Разогрев'),
      YogaStepData('Собака мордой вниз', 45, false, 'Пробуждение'),
      YogaStepData('Поза воина I', 30, true, 'По 30 сек на сторону'),
      YogaStepData('Поза дерева', 30, true, 'По 30 сек на сторону'),
      YogaStepData('Наклон вперёд стоя', 30, false, 'Растяжка'),
      YogaStepData('Поза горы', 30, false, 'Завершение'),
    ],

    // ═══ 5. Йога для пресса и кора (20 мин) ═══
    [
      YogaStepData('Кошка-корова', 60, false, 'Разогрев'),
      YogaStepData('Планка йога', 45, false, 'Кор'),
      YogaStepData('Боковая планка йога', 30, true, 'По 30 сек на сторону'),
      YogaStepData('Поза лодки', 30, false, 'Пресс'),
      YogaStepData('Поза моста', 30, false, 'Спина и кор'),
      YogaStepData('Поза кобры', 30, false, 'Прогиб'),
      YogaStepData('Поза ребёнка', 60, false, 'Отдых'),
      YogaStepData('Поза трупа', 90, false, 'Завершение'),
    ],

    // ═══ 6. Йога перед сном (15 мин) ═══
    [
      YogaStepData('Скручивание сидя', 30, true, 'По 30 сек на сторону'),
      YogaStepData('Поза счастливого ребёнка', 45, false, 'Расслабление'),
      YogaStepData('Поза бабочки лёжа', 45, false, 'Раскрытие бёдер'),
      YogaStepData('Ноги вверх на стене', 90, false, 'Снятие усталости'),
      YogaStepData('Поза трупа', 180, false, 'Сон'),
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