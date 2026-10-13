import '../models/stretch.dart';

/// База растяжки.
/// Часть А: 25 классических растяжек.
List<Stretch> getStretchesPartA() {
  return [
    // ═══════════════════════════════════════════════════════════
    //  ЯГОДИЦЫ (4)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Растяжка ягодиц сидя',
      category: 'classic',
      muscleGroup: 'glutes',
      durationSeconds: 30,
      bothSides: true,
      description: 'Классическая растяжка ягодиц в положении сидя.',
      technique: '1. Сядьте на пол, ноги вытянуты\n'
          '2. Согните правую ногу и поставьте стопу за левое бедро\n'
          '3. Обхватите правое колено руками\n'
          '4. Медленно притяните колено к левому плечу\n'
          '5. Задержитесь, дышите ровно',
      benefits: '• Снимает напряжение после силовой тренировки\n'
          '• Улучшает гибкость тазобедренных суставов\n'
          '• Помогает при сидячей работе',
      imagePath: 'assets/stretches/glute_stretch_seated.jpg',
    ),

    Stretch(
      name: 'Растяжка ягодиц лёжа',
      category: 'classic',
      muscleGroup: 'glutes',
      durationSeconds: 30,
      bothSides: true,
      description: 'Мягкая растяжка ягодиц в положении лёжа на спине.',
      technique: '1. Лягте на спину, ноги согнуты\n'
          '2. Положите правую щиколотку на левое колено\n'
          '3. Обхватите левое бедро руками\n'
          '4. Притяните ноги к груди\n'
          '5. Держите 30 секунд, затем смените сторону',
      benefits: '• Расслабляет ягодичные мышцы\n'
          '• Улучшает кровообращение в тазу\n'
          '• Отлично подходит перед сном',
      imagePath: 'assets/stretches/glute_stretch_lying.jpg',
    ),

    Stretch(
      name: 'Поза голубя',
      category: 'classic',
      muscleGroup: 'glutes',
      durationSeconds: 45,
      bothSides: true,
      description: 'Глубокая растяжка ягодиц и бёдер.',
      technique: '1. Встаньте на четвереньки\n'
          '2. Подайте правое колено вперёд, стопу к левой руке\n'
          '3. Левую ногу вытяните назад\n'
          '4. Медленно опуститесь на правое бедро\n'
          '5. Держите 45 секунд, затем смените',
      benefits: '• Глубокая растяжка ягодиц\n'
          '• Раскрывает тазобедренные суставы\n'
          '• Улучшает подвижность',
      imagePath: 'assets/stretches/pigeon_pose.jpg',
    ),

    Stretch(
      name: 'Растяжка ягодиц стоя',
      category: 'classic',
      muscleGroup: 'glutes',
      durationSeconds: 30,
      bothSides: true,
      description: 'Растяжка ягодиц в положении стоя с опорой.',
      technique: '1. Встаньте, держитесь за опору\n'
          '2. Положите правую щиколотку на левое колено\n'
          '3. Медленно присядьте на левой ноге\n'
          '4. Почувствуйте растяжение в правой ягодице\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Растягивает ягодицы\n'
          '• Развивает баланс\n'
          '• Можно делать в любом месте',
      imagePath: 'assets/stretches/glute_stretch_standing.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ЗАДНЯЯ ПОВЕРХНОСТЬ БЕДРА (4)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Наклон вперёд сидя',
      category: 'classic',
      muscleGroup: 'hamstrings',
      durationSeconds: 45,
      bothSides: false,
      description: 'Классическая растяжка задней поверхности бедра.',
      technique: '1. Сядьте на пол, ноги вытянуты вперёд\n'
          '2. Спину держите прямой\n'
          '3. Медленно наклонитесь вперёд\n'
          '4. Постарайтесь взяться за стопы\n'
          '5. Задержитесь 45 секунд, дышите ровно',
      benefits: '• Растягивает заднюю поверхность бедра\n'
          '• Улучшает гибкость\n'
          '• Помогает при болях в пояснице',
      imagePath: 'assets/stretches/seated_forward_bend.jpg',
    ),

    Stretch(
      name: 'Растяжка с ногой на опоре',
      category: 'classic',
      muscleGroup: 'hamstrings',
      durationSeconds: 30,
      bothSides: true,
      description: 'Растяжка задней поверхности бедра с возвышением.',
      technique: '1. Поставьте стопу на невысокую опору\n'
          '2. Нога прямая, носок на себя\n'
          '3. Наклонитесь корпусом к ноге\n'
          '4. Держите спину прямой\n'
          '5. 30 секунд, затем смените ногу',
      benefits: '• Растягивает заднюю поверхность бедра\n'
          '• Развивает баланс\n'
          '• Не требует коврика',
      imagePath: 'assets/stretches/leg_on_support.jpg',
    ),

    Stretch(
      name: 'Растяжка подколенного сухожилия лёжа',
      category: 'classic',
      muscleGroup: 'hamstrings',
      durationSeconds: 30,
      bothSides: true,
      description: 'Мягкая растяжка в положении лёжа.',
      technique: '1. Лягте на спину\n'
          '2. Поднимите правую ногу вверх\n'
          '3. Обхватите бедро руками\n'
          '4. Медленно выпрямите ногу\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Безопасная растяжка\n'
          '• Подходит для новичков\n'
          '• Снимает напряжение в ногах',
      imagePath: 'assets/stretches/lying_hamstring_stretch.jpg',
    ),

    Stretch(
      name: 'Наклон к прямым ногам стоя',
      category: 'classic',
      muscleGroup: 'hamstrings',
      durationSeconds: 30,
      bothSides: false,
      description: 'Растяжка задней поверхности бедра стоя.',
      technique: '1. Встаньте прямо, ноги вместе\n'
          '2. Медленно наклоняйтесь вниз\n'
          '3. Постарайтесь коснуться пола\n'
          '4. Колени чуть согнуты\n'
          '5. Держите 30 секунд',
      benefits: '• Растягивает заднюю поверхность бедра\n'
          '• Улучшает гибкость спины\n'
          '• Можно делать утром',
      imagePath: 'assets/stretches/standing_forward_bend.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ПЕРЕДНЯЯ ПОВЕРХНОСТЬ БЕДРА (3)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Растяжка квадрицепса стоя',
      category: 'classic',
      muscleGroup: 'quads',
      durationSeconds: 30,
      bothSides: true,
      description: 'Классическая растяжка передней поверхности бедра.',
      technique: '1. Встаньте прямо, держитесь за опору\n'
          '2. Согните правую ногу назад\n'
          '3. Обхватите стопу рукой\n'
          '4. Притяните пятку к ягодице\n'
          '5. Держите 30 секунд, смените ногу',
      benefits: '• Растягивает квадрицепс\n'
          '• Улучшает осанку\n'
          '• Помогает после бега',
      imagePath: 'assets/stretches/quad_stretch_standing.jpg',
    ),

    Stretch(
      name: 'Растяжка квадрицепса лёжа на боку',
      category: 'classic',
      muscleGroup: 'quads',
      durationSeconds: 30,
      bothSides: true,
      description: 'Мягкая растяжка квадрицепса в положении лёжа.',
      technique: '1. Лягте на левый бок\n'
          '2. Согните правую ногу назад\n'
          '3. Обхватите стопу правой рукой\n'
          '4. Притяните пятку к ягодице\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Безопасная растяжка\n'
          '• Подходит для новичков\n'
          '• Снимает напряжение в ногах',
      imagePath: 'assets/stretches/quad_stretch_lying.jpg',
    ),

    Stretch(
      name: 'Растяжка с коленом у груди',
      category: 'classic',
      muscleGroup: 'quads',
      durationSeconds: 30,
      bothSides: true,
      description: 'Растяжка передней поверхности бедра и поясницы.',
      technique: '1. Лягте на спину\n'
          '2. Прижмите правое колено к груди\n'
          '3. Вторая нога прямая на полу\n'
          '4. Обхватите колено руками\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Растягивает переднюю поверхность бедра\n'
          '• Снимает напряжение в пояснице\n'
          '• Можно делать перед сном',
      imagePath: 'assets/stretches/knee_to_chest.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ВНУТРЕННЯЯ ПОВЕРХНОСТЬ БЕДРА (2)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Бабочка',
      category: 'classic',
      muscleGroup: 'adductors',
      durationSeconds: 45,
      bothSides: false,
      description: 'Растяжка внутренней поверхности бедра. Одна из самых известных.',
      technique: '1. Сядьте на пол\n'
          '2. Соедините стопы, колени в стороны\n'
          '3. Обхватите стопы руками\n'
          '4. Медленно наклонитесь вперёд\n'
          '5. Держите 45 секунд',
      benefits: '• Растягивает внутреннюю поверхность бедра\n'
          '• Улучшает подвижность таза\n'
          '• Отлично перед растяжкой на шпагат',
      imagePath: 'assets/stretches/butterfly_stretch.jpg',
    ),

    Stretch(
      name: 'Растяжка лягушки',
      category: 'classic',
      muscleGroup: 'adductors',
      durationSeconds: 45,
      bothSides: false,
      description: 'Глубокая растяжка внутренней поверхности бедра.',
      technique: '1. Встаньте на четвереньки\n'
          '2. Разведите колени максимально в стороны\n'
          '3. Стопы разверните наружу\n'
          '4. Опуститесь на предплечья\n'
          '5. Держите 45 секунд',
      benefits: '• Глубокая растяжка бёдер\n'
          '• Раскрывает тазобедренные суставы\n'
          '• Помогает при сидячей работе',
      imagePath: 'assets/stretches/frog_stretch.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  СПИНА И ПОЯСНИЦА (4)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Кошка-корова',
      category: 'classic',
      muscleGroup: 'back',
      durationSeconds: 60,
      bothSides: false,
      description: 'Динамическая растяжка всей спины.',
      technique: '1. Встаньте на четвереньки\n'
          '2. На вдохе прогните спину (корова)\n'
          '3. На выдохе округлите спину (кошка)\n'
          '4. Работайте в медленном темпе\n'
          '5. 10 циклов',
      benefits: '• Разогревает спину\n'
          '• Улучшает гибкость позвоночника\n'
          '• Снимает напряжение',
      imagePath: 'assets/stretches/cat_cow.jpg',
    ),

    Stretch(
      name: 'Скручивание лёжа',
      category: 'classic',
      muscleGroup: 'back',
      durationSeconds: 30,
      bothSides: true,
      description: 'Растяжка поясницы через скручивание.',
      technique: '1. Лягте на спину, руки в стороны\n'
          '2. Согните колени\n'
          '3. Опустите колени вправо\n'
          '4. Голову поверните влево\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Растягивает поясницу\n'
          '• Снимает напряжение\n'
          '• Отлично после сидячей работы',
      imagePath: 'assets/stretches/lying_twist.jpg',
    ),

    Stretch(
      name: 'Наклон вперёд стоя',
      category: 'classic',
      muscleGroup: 'back',
      durationSeconds: 30,
      bothSides: false,
      description: 'Растяжка всей задней цепи тела.',
      technique: '1. Встаньте прямо, ноги на ширине плеч\n'
          '2. Медленно наклонитесь вперёд\n'
          '3. Руки свободно свисают\n'
          '4. Колени чуть согнуты\n'
          '5. Держите 30 секунд',
      benefits: '• Растягивает спину и ноги\n'
          '• Снимает напряжение\n'
          '• Успокаивает нервную систему',
      imagePath: 'assets/stretches/forward_bend.jpg',
    ),

    Stretch(
      name: 'Поза ребёнка',
      category: 'classic',
      muscleGroup: 'back',
      durationSeconds: 60,
      bothSides: false,
      description: 'Расслабляющая поза для спины.',
      technique: '1. Встаньте на колени\n'
          '2. Сядьте на пятки\n'
          '3. Наклонитесь вперёд, лбом в пол\n'
          '4. Руки вытяните вперёд\n'
          '5. Дышите глубоко 60 секунд',
      benefits: '• Расслабляет всю спину\n'
          '• Снимает стресс\n'
          '• Успокаивает',
      imagePath: 'assets/stretches/child_pose.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  РУКИ И ПЛЕЧИ (3)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Растяжка бицепса',
      category: 'classic',
      muscleGroup: 'biceps',
      durationSeconds: 20,
      bothSides: true,
      description: 'Растяжка двуглавой мышцы плеча.',
      technique: '1. Встаньте у стены\n'
          '2. Положите ладонь на стену пальцами вниз\n'
          '3. Медленно поверните корпус от стены\n'
          '4. Почувствуйте растяжение в бицепсе\n'
          '5. Держите 20 секунд, смените',
      benefits: '• Растягивает бицепс\n'
          '• Улучшает гибкость рук\n'
          '• После тренировки рук',
      imagePath: 'assets/stretches/bicep_stretch.jpg',
    ),

    Stretch(
      name: 'Растяжка трицепса',
      category: 'classic',
      muscleGroup: 'triceps',
      durationSeconds: 20,
      bothSides: true,
      description: 'Растяжка трёхглавой мышцы плеча.',
      technique: '1. Поднимите правую руку вверх\n'
          '2. Согните её в локте, кисть за головой\n'
          '3. Левой рукой прижмите локоть\n'
          '4. Почувствуйте растяжение в трицепсе\n'
          '5. Держите 20 секунд, смените',
      benefits: '• Растягивает трицепс\n'
          '• Улучшает подвижность плеча\n'
          '• После жимов и отжиманий',
      imagePath: 'assets/stretches/tricep_stretch.jpg',
    ),

    Stretch(
      name: 'Растяжка предплечья',
      category: 'classic',
      muscleGroup: 'forearms',
      durationSeconds: 20,
      bothSides: true,
      description: 'Растяжка мышц предплечья.',
      technique: '1. Вытяните правую руку вперёд\n'
          '2. Пальцами вниз\n'
          '3. Левой рукой потяните пальцы к себе\n'
          '4. Почувствуйте растяжение\n'
          '5. Держите 20 секунд, смените',
      benefits: '• Растягивает предплечье\n'
          '• Снимает напряжение после работы за компьютером\n'
          '• Профилактика туннельного синдрома',
      imagePath: 'assets/stretches/forearm_stretch.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ГОЛЕНЬ (2)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Растяжка голени у стены',
      category: 'classic',
      muscleGroup: 'calves',
      durationSeconds: 30,
      bothSides: true,
      description: 'Растяжка икроножной мышцы.',
      technique: '1. Встаньте лицом к стене\n'
          '2. Руки на стену\n'
          '3. Правую ногу отставьте назад\n'
          '4. Пятку прижмите к полу\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Растягивает икры\n'
          '• Снимает напряжение после ходьбы\n'
          '• Профилактика судорог',
      imagePath: 'assets/stretches/calf_stretch_wall.jpg',
    ),

    Stretch(
      name: 'Растяжка голени на ступеньке',
      category: 'classic',
      muscleGroup: 'calves',
      durationSeconds: 30,
      bothSides: true,
      description: 'Растяжка голени с использованием возвышения.',
      technique: '1. Встаньте на ступеньку\n'
          '2. Пятка свисает\n'
          '3. Медленно опустите пятку вниз\n'
          '4. Почувствуйте растяжение\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Глубокая растяжка голени\n'
          '• Улучшает гибкость стопы\n'
          '• Профилактика травм',
      imagePath: 'assets/stretches/calf_stretch_step.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ШЕЯ (2)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Наклоны головы',
      category: 'classic',
      muscleGroup: 'neck',
      durationSeconds: 30,
      bothSides: false,
      description: 'Мягкая растяжка мышц шеи.',
      technique: '1. Сядьте или встаньте прямо\n'
          '2. Медленно наклоните голову вправо\n'
          '3. Почувствуйте растяжение\n'
          '4. Вернитесь в центр\n'
          '5. То же влево, по 15 секунд',
      benefits: '• Снимает напряжение в шее\n'
          '• Улучшает подвижность\n'
          '• Помогает при головной боли',
      imagePath: 'assets/stretches/neck_stretch.jpg',
    ),

    Stretch(
      name: 'Повороты головы',
      category: 'classic',
      muscleGroup: 'neck',
      durationSeconds: 30,
      bothSides: false,
      description: 'Повороты головы для растяжки шеи.',
      technique: '1. Сядьте или встаньте прямо\n'
          '2. Медленно поверните голову вправо\n'
          '3. Задержитесь на 5 секунд\n'
          '4. Вернитесь в центр\n'
          '5. То же влево',
      benefits: '• Растягивает боковые мышцы шеи\n'
          '• Улучшает подвижность\n'
          '• Снимает напряжение',
      imagePath: 'assets/stretches/neck_rotation.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ВСЁ ТЕЛО (1)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Потягивание вверх',
      category: 'classic',
      muscleGroup: 'full_body',
      durationSeconds: 20,
      bothSides: false,
      description: 'Общее потягивание всего тела.',
      technique: '1. Встаньте прямо, ноги на ширине плеч\n'
          '2. Поднимите руки вверх\n'
          '3. Сцепите пальцы в замок\n'
          '4. Потянитесь вверх\n'
          '5. Держите 20 секунд, дышите ровно',
      benefits: '• Растягивает всё тело\n'
          '• Улучшает осанку\n'
          '• Бодрит',
      imagePath: 'assets/stretches/full_body_stretch.jpg',
    ),
  ];
}
/// Часть Б: 25 йога-поз.
List<Stretch> getStretchesPartB() {
  return [
    // ═══════════════════════════════════════════════════════════
    //  ЙОГА ДЛЯ СПИНЫ (5)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Поза кобры',
      category: 'yoga',
      muscleGroup: 'back',
      durationSeconds: 30,
      bothSides: false,
      description: 'Прогиб назад из положения лёжа. Раскрывает грудную клетку.',
      technique: '1. Лягте на живот, ладони под плечами\n'
          '2. Ноги прямые, стопы вместе\n'
          '3. На вдохе поднимите голову и грудь\n'
          '4. Руки чуть согнуты в локтях\n'
          '5. Смотрите вверх, дышите ровно',
      benefits: '• Укрепляет спину\n'
          '• Раскрывает грудную клетку\n'
          '• Улучшает осанку',
      imagePath: 'assets/yoga/cobra_pose.jpg',
    ),

    Stretch(
      name: 'Поза сфинкса',
      category: 'yoga',
      muscleGroup: 'back',
      durationSeconds: 30,
      bothSides: false,
      description: 'Мягкий прогиб назад на предплечьях. Проще кобры.',
      technique: '1. Лягте на живот\n'
          '2. Обопритесь на предплечья\n'
          '3. Локти под плечами\n'
          '4. Грудь раскрыта\n'
          '5. Дышите ровно 30 секунд',
      benefits: '• Мягкая растяжка спины\n'
          '• Раскрывает грудь\n'
          '• Подходит новичкам',
      imagePath: 'assets/yoga/sphinx_pose.jpg',
    ),

    Stretch(
      name: 'Скручивание сидя',
      category: 'yoga',
      muscleGroup: 'back',
      durationSeconds: 30,
      bothSides: true,
      description: 'Скручивание позвоночника в положении сидя.',
      technique: '1. Сядьте, ноги вытянуты\n'
          '2. Согните правую ногу, поставьте за левое бедро\n'
          '3. Левую руку за правое колено\n'
          '4. Поверните корпус вправо\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Растягивает позвоночник\n'
          '• Улучшает подвижность\n'
          '• Снимает напряжение',
      imagePath: 'assets/yoga/seated_twist.jpg',
    ),

    Stretch(
      name: 'Поза ребёнка',
      category: 'yoga',
      muscleGroup: 'back',
      durationSeconds: 60,
      bothSides: false,
      description: 'Классическая расслабляющая поза для спины.',
      technique: '1. Встаньте на колени\n'
          '2. Сядьте на пятки\n'
          '3. Наклонитесь вперёд, лбом в пол\n'
          '4. Руки вытяните вперёд\n'
          '5. Дышите глубоко 60 секунд',
      benefits: '• Расслабляет спину\n'
          '• Успокаивает ум\n'
          '• Снимает стресс',
      imagePath: 'assets/yoga/child_pose.jpg',
    ),

    Stretch(
      name: 'Наклон вперёд сидя',
      category: 'yoga',
      muscleGroup: 'back',
      durationSeconds: 45,
      bothSides: false,
      description: 'Пашчимоттанасана — растяжка всей задней цепи.',
      technique: '1. Сядьте, ноги вытянуты\n'
          '2. Спина прямая\n'
          '3. Наклонитесь вперёд\n'
          '4. Обхватите стопы руками\n'
          '5. Дышите 45 секунд',
      benefits: '• Растягивает спину и ноги\n'
          '• Успокаивает нервную систему\n'
          '• Улучшает пищеварение',
      imagePath: 'assets/yoga/seated_forward_bend.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ЙОГА ДЛЯ ГИБКОСТИ (5)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Собака мордой вниз',
      category: 'yoga',
      muscleGroup: 'hamstrings',
      durationSeconds: 45,
      bothSides: false,
      description: 'Адхо Мукха Шванасана — одна из главных асан.',
      technique: '1. Встаньте на четвереньки\n'
          '2. Поднимите таз вверх\n'
          '3. Тело — перевёрнутая буква V\n'
          '4. Пятки тянутся к полу\n'
          '5. Держите 45 секунд',
      benefits: '• Растягивает заднюю поверхность бедра\n'
          '• Укрепляет руки и спину\n'
          '• Бодрит',
      imagePath: 'assets/yoga/downward_dog.jpg',
    ),

    Stretch(
      name: 'Поза вытянутого угла',
      category: 'yoga',
      muscleGroup: 'adductors',
      durationSeconds: 30,
      bothSides: false,
      description: 'Упавиштха Конасана — растяжка внутренней поверхности бедра.',
      technique: '1. Сядьте, ноги широко в стороны\n'
          '2. Носки на себя\n'
          '3. Спина прямая\n'
          '4. Наклонитесь вперёд\n'
          '5. Держите 30 секунд',
      benefits: '• Растягивает бёдра\n'
          '• Улучшает гибкость\n'
          '• Подготовка к шпагату',
      imagePath: 'assets/yoga/wide_angle_pose.jpg',
    ),

    Stretch(
      name: 'Поза верблюда',
      category: 'yoga',
      muscleGroup: 'quads',
      durationSeconds: 30,
      bothSides: false,
      description: 'Уштрасана — глубокий прогиб назад.',
      technique: '1. Встаньте на колени\n'
          '2. Руки на пятки\n'
          '3. Прогнитесь назад\n'
          '4. Грудь раскрыта\n'
          '5. Держите 30 секунд',
      benefits: '• Растягивает переднюю поверхность тела\n'
          '• Раскрывает грудную клетку\n'
          '• Улучшает осанку',
      imagePath: 'assets/yoga/camel_pose.jpg',
    ),

    Stretch(
      name: 'Поза героя',
      category: 'yoga',
      muscleGroup: 'quads',
      durationSeconds: 30,
      bothSides: false,
      description: 'Вирасана — сидя на пятках, растягивает квадрицепсы.',
      technique: '1. Встаньте на колени\n'
          '2. Разведите стопы в стороны\n'
          '3. Сядьте между пятками\n'
          '4. Спина прямая\n'
          '5. Держите 30 секунд',
      benefits: '• Растягивает квадрицепсы\n'
          '• Улучшает осанку\n'
          '• Успокаивает',
      imagePath: 'assets/yoga/hero_pose.jpg',
    ),

    Stretch(
      name: 'Поза бабочки',
      category: 'yoga',
      muscleGroup: 'adductors',
      durationSeconds: 45,
      bothSides: false,
      description: 'Бада Конасана — раскрытие тазобедренных суставов.',
      technique: '1. Сядьте, стопы вместе\n'
          '2. Колени в стороны\n'
          '3. Спина прямая\n'
          '4. Наклонитесь вперёд\n'
          '5. Держите 45 секунд',
      benefits: '• Раскрывает таз\n'
          '• Растягивает бёдра\n'
          '• Улучшает кровообращение',
      imagePath: 'assets/yoga/butterfly_pose.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ЙОГА ДЛЯ РАССЛАБЛЕНИЯ (4)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Поза трупа',
      category: 'yoga',
      muscleGroup: 'full_body',
      durationSeconds: 120,
      bothSides: false,
      description: 'Шавасана — полное расслабление в конце практики.',
      technique: '1. Лягте на спину\n'
          '2. Руки вдоль тела, ладонями вверх\n'
          '3. Ноги слегка врозь\n'
          '4. Закройте глаза\n'
          '5. Дышите спокойно 1–2 минуты',
      benefits: '• Полное расслабление\n'
          '• Снимает стресс\n'
          '• Восстанавливает силы',
      imagePath: 'assets/yoga/savasana.jpg',
    ),

    Stretch(
      name: 'Ноги вверх на стене',
      category: 'yoga',
      muscleGroup: 'full_body',
      durationSeconds: 60,
      bothSides: false,
      description: 'Випарита Карани — мягкая инверсия.',
      technique: '1. Лягте у стены\n'
          '2. Поднимите ноги вверх\n'
          '3. Прижмите их к стене\n'
          '4. Руки вдоль тела\n'
          '5. Дышите 60 секунд',
      benefits: '• Улучшает кровообращение\n'
          '• Снимает усталость ног\n'
          '• Расслабляет',
      imagePath: 'assets/yoga/legs_up_wall.jpg',
    ),

    Stretch(
      name: 'Поза счастливого ребёнка',
      category: 'yoga',
      muscleGroup: 'back',
      durationSeconds: 45,
      bothSides: false,
      description: 'Ананда Баласана — расслабляющая поза для спины.',
      technique: '1. Лягте на спину\n'
          '2. Согните колени к груди\n'
          '3. Обхватите стопы руками\n'
          '4. Покачайтесь в стороны\n'
          '5. Держите 45 секунд',
      benefits: '• Расслабляет спину\n'
          '• Снимает напряжение\n'
          '• Растягивает поясницу',
      imagePath: 'assets/yoga/happy_baby.jpg',
    ),

    Stretch(
      name: 'Поза бабочки лёжа',
      category: 'yoga',
      muscleGroup: 'adductors',
      durationSeconds: 45,
      bothSides: false,
      description: 'Супта Бада Конасана — раскрытие бёдер лёжа.',
      technique: '1. Лягте на спину\n'
          '2. Стопы вместе, колени в стороны\n'
          '3. Руки вдоль тела\n'
          '4. Дышите глубоко\n'
          '5. Держите 45 секунд',
      benefits: '• Раскрывает бёдра\n'
          '• Расслабляет\n'
          '• Улучшает гибкость',
      imagePath: 'assets/yoga/reclining_butterfly.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ЙОГА ДЛЯ ЯГОДИЦ И БЁДЕР (4)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Поза голубя',
      category: 'yoga',
      muscleGroup: 'glutes',
      durationSeconds: 60,
      bothSides: true,
      description: 'Капотасана — глубокая растяжка ягодиц.',
      technique: '1. Встаньте на четвереньки\n'
          '2. Правое колено вперёд\n'
          '3. Левую ногу назад\n'
          '4. Опуститесь на бедро\n'
          '5. Держите 60 секунд, смените',
      benefits: '• Глубокая растяжка ягодиц\n'
          '• Раскрывает таз\n'
          '• Улучшает подвижность',
      imagePath: 'assets/yoga/pigeon_pose.jpg',
    ),

    Stretch(
      name: 'Поза ящерицы',
      category: 'yoga',
      muscleGroup: 'glutes',
      durationSeconds: 45,
      bothSides: true,
      description: 'Уттхана Пришватханасана — растяжка бёдер и ягодиц.',
      technique: '1. Встаньте на четвереньки\n'
          '2. Правую стопу поставьте к правой руке\n'
          '3. Левую ногу назад\n'
          '4. Опуститесь на предплечья\n'
          '5. Держите 45 секунд, смените',
      benefits: '• Растягивает бёдра\n'
          '• Раскрывает таз\n'
          '• Улучшает гибкость',
      imagePath: 'assets/yoga/lizard_pose.jpg',
    ),

    Stretch(
      name: 'Поза лягушки',
      category: 'yoga',
      muscleGroup: 'adductors',
      durationSeconds: 45,
      bothSides: false,
      description: 'Мандукасана — глубокая растяжка внутренней поверхности бедра.',
      technique: '1. Встаньте на четвереньки\n'
          '2. Разведите колени в стороны\n'
          '3. Стопы наружу\n'
          '4. Опуститесь на предплечья\n'
          '5. Держите 45 секунд',
      benefits: '• Раскрывает бёдра\n'
          '• Растягивает пах\n'
          '• Улучшает подвижность',
      imagePath: 'assets/yoga/frog_pose.jpg',
    ),

    Stretch(
      name: 'Поза воина II',
      category: 'yoga',
      muscleGroup: 'quads',
      durationSeconds: 30,
      bothSides: true,
      description: 'Вирабхадрасана II — укрепляет ноги и раскрывает бёдра.',
      technique: '1. Встаньте, ноги широко\n'
          '2. Правую стопу разверните вправо\n'
          '3. Согните правое колено\n'
          '4. Руки в стороны\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Укрепляет ноги\n'
          '• Раскрывает бёдра\n'
          '• Развивает выносливость',
      imagePath: 'assets/yoga/warrior_2.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  УТРЕННЯЯ ЙОГА (3)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Поза горы',
      category: 'yoga',
      muscleGroup: 'full_body',
      durationSeconds: 30,
      bothSides: false,
      description: 'Тадасана — базовая поза стоя, улучшает осанку.',
      technique: '1. Встаньте прямо, стопы вместе\n'
          '2. Руки вдоль тела\n'
          '3. Макушка тянется вверх\n'
          '4. Плечи назад и вниз\n'
          '5. Дышите ровно 30 секунд',
      benefits: '• Улучшает осанку\n'
          '• Успокаивает ум\n'
          '• Развивает баланс',
      imagePath: 'assets/yoga/mountain_pose.jpg',
    ),

    Stretch(
      name: 'Поза воина I',
      category: 'yoga',
      muscleGroup: 'quads',
      durationSeconds: 30,
      bothSides: true,
      description: 'Вирабхадрасана I — укрепляет ноги и вытягивает позвоночник.',
      technique: '1. Встаньте, ноги широко\n'
          '2. Правую стопу разверните вправо\n'
          '3. Согните правое колено\n'
          '4. Руки вверх\n'
          '5. Держите 30 секунд, смените',
      benefits: '• Укрепляет ноги\n'
          '• Вытягивает позвоночник\n'
          '• Развивает баланс',
      imagePath: 'assets/yoga/warrior_1.jpg',
    ),

    Stretch(
      name: 'Поза дерева',
      category: 'yoga',
      muscleGroup: 'full_body',
      durationSeconds: 30,
      bothSides: true,
      description: 'Врикшасана — баланс на одной ноге.',
      technique: '1. Встаньте прямо\n'
          '2. Правую стопу на левое бедро\n'
          '3. Руки вместе над головой\n'
          '4. Держите баланс\n'
          '5. 30 секунд, смените',
      benefits: '• Развивает баланс\n'
          '• Укрепляет ноги\n'
          '• Улучшает концентрацию',
      imagePath: 'assets/yoga/tree_pose.jpg',
    ),

    // ═══════════════════════════════════════════════════════════
    //  ЙОГА ДЛЯ КОРА (4)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Планка йога',
      category: 'yoga',
      muscleGroup: 'core',
      durationSeconds: 45,
      bothSides: false,
      description: 'Кумбхакасана — планка для укрепления кора.',
      technique: '1. Упор на ладони и носки\n'
          '2. Тело — прямая линия\n'
          '3. Напрягите пресс\n'
          '4. Дышите ровно\n'
          '5. Держите 45 секунд',
      benefits: '• Укрепляет кор\n'
          '• Улучшает осанку\n'
          '• Развивает выносливость',
      imagePath: 'assets/yoga/plank_pose.jpg',
    ),

    Stretch(
      name: 'Боковая планка йога',
      category: 'yoga',
      muscleGroup: 'core',
      durationSeconds: 30,
      bothSides: true,
      description: 'Васиштхасана — планка на боку.',
      technique: '1. Лягте на бок\n'
          '2. Обопритесь на локоть\n'
          '3. Поднимите таз\n'
          '4. Тело — прямая линия\n'
          '5. 30 секунд, смените',
      benefits: '• Укрепляет косые\n'
          '• Развивает баланс\n'
          '• Улучшает стабильность',
      imagePath: 'assets/yoga/side_plank_pose.jpg',
    ),

    Stretch(
      name: 'Поза лодки',
      category: 'yoga',
      muscleGroup: 'core',
      durationSeconds: 30,
      bothSides: false,
      description: 'Навасана — баланс на ягодицах, укрепляет пресс.',
      technique: '1. Сядьте на пол\n'
          '2. Отклонитесь назад\n'
          '3. Поднимите ноги\n'
          '4. Руки вперёд\n'
          '5. Держите 30 секунд',
      benefits: '• Укрепляет пресс\n'
          '• Улучшает баланс\n'
          '• Развивает кор',
      imagePath: 'assets/yoga/boat_pose.jpg',
    ),

    Stretch(
      name: 'Поза моста',
      category: 'yoga',
      muscleGroup: 'core',
      durationSeconds: 30,
      bothSides: false,
      description: 'Сету Бандха Сарвангасана — мост из положения лёжа.',
      technique: '1. Лягте на спину\n'
          '2. Согните колени\n'
          '3. Стопы на полу\n'
          '4. Поднимите таз\n'
          '5. Держите 30 секунд',
      benefits: '• Укрепляет спину\n'
          '• Раскрывает грудь\n'
          '• Улучшает гибкость',
      imagePath: 'assets/yoga/bridge_pose.jpg',
    ),
  ];
}

/// Часть В: 5 дыхательных упражнений.
List<Stretch> getStretchesPartC() {
  return [
    // ═══════════════════════════════════════════════════════════
    //  ДЫХАТЕЛЬНЫЕ УПРАЖНЕНИЯ (5)
    // ═══════════════════════════════════════════════════════════

    Stretch(
      name: 'Дыхание 4-7-8',
      category: 'yoga',
      muscleGroup: 'breathing',
      durationSeconds: 120,
      bothSides: false,
      description:
          'Успокаивающее дыхание. Помогает заснуть и снять тревогу.',
      technique: '1. Сядьте удобно, спина прямая\n'
          '2. Вдох через нос — 4 секунды\n'
          '3. Задержка дыхания — 7 секунд\n'
          '4. Медленный выдох через рот — 8 секунд\n'
          '5. Повторите 4–6 циклов',
      benefits: '• Успокаивает нервную систему\n'
          '• Помогает при бессоннице\n'
          '• Снижает тревожность',
      imagePath: 'assets/yoga/breathing_478.jpg',
    ),

    Stretch(
      name: 'Дыхание квадратом',
      category: 'yoga',
      muscleGroup: 'breathing',
      durationSeconds: 120,
      bothSides: false,
      description:
          'Дыхание с равными фазами. Улучшает концентрацию и баланс.',
      technique: '1. Сядьте удобно\n'
          '2. Вдох — 4 секунды\n'
          '3. Задержка — 4 секунды\n'
          '4. Выдох — 4 секунды\n'
          '5. Задержка — 4 секунды\n'
          '6. Повторите 6–8 циклов',
      benefits: '• Улучшает фокус\n'
          '• Снимает стресс\n'
          '• Балансирует нервную систему',
      imagePath: 'assets/yoga/box_breathing.jpg',
    ),

    Stretch(
      name: 'Уджайи (победоносное дыхание)',
      category: 'yoga',
      muscleGroup: 'breathing',
      durationSeconds: 180,
      bothSides: false,
      description:
          'Классическое дыхание йоги. Выполняется во время практики асан.',
      technique: '1. Сядьте с прямой спиной\n'
          '2. Слегка сузьте голосовую щель\n'
          '3. Дышите через нос с лёгким шипением\n'
          '4. Вдох и выдох равной длины\n'
          '5. Продолжайте 3 минуты',
      benefits: '• Согревает тело\n'
          '• Успокаивает ум\n'
          '• Углубляет практику асан',
      imagePath: 'assets/yoga/ujjayi_breathing.jpg',
    ),

    Stretch(
      name: 'Капалабхати (дыхание огня)',
      category: 'yoga',
      muscleGroup: 'breathing',
      durationSeconds: 60,
      bothSides: false,
      description:
          'Бодрящее дыхание. Активирует и заряжает энергией.',
      technique: '1. Сядьте с прямой спиной\n'
          '2. Резкие выдохи через нос\n'
          '3. Живот активно работает\n'
          '4. Вдох — пассивный\n'
          '5. 20–30 циклов, потом отдых',
      benefits: '• Бодрит\n'
          '• Разогревает тело\n'
          '• Укрепляет пресс',
      imagePath: 'assets/yoga/kapalabhati.jpg',
    ),

    Stretch(
      name: 'Полное йоговское дыхание',
      category: 'yoga',
      muscleGroup: 'breathing',
      durationSeconds: 180,
      bothSides: false,
      description:
          'Основа пранаямы. Включает живот, грудную клетку и ключицы.',
      technique: '1. Сядьте или лягте удобно\n'
          '2. Вдох: сначала живот, потом грудь, потом ключицы\n'
          '3. Выдох: в обратном порядке\n'
          '4. Дыхание медленное и плавное\n'
          '5. 5–10 циклов',
      benefits: '• Увеличивает объём лёгких\n'
          '• Расслабляет\n'
          '• Улучшает самочувствие',
      imagePath: 'assets/yoga/full_yogic_breath.jpg',
    ),
  ];
}

/// Финальная функция — объединяет все части растяжки.
List<Stretch> getStretchesData() {
  return [
    ...getStretchesPartA(),
    ...getStretchesPartB(),
    ...getStretchesPartC(),
  ];
}
