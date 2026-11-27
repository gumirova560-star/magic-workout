import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';

class TrainerScreen extends StatefulWidget {
  final UserProfile? profile;
  const TrainerScreen({super.key, this.profile});

  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  String? _expandedIndex;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _ideaController = TextEditingController();
  bool _isSendingQuestion = false;
  bool _isSendingIdea = false;

  String get _name => widget.profile?.name ?? 'друг';
  bool get _isMale => widget.profile?.gender == 'male';
  String get _coped => _isMale ? 'справился' : 'справилась';
  String get _didNot => _isMale ? 'не доделал' : 'не доделала';
  String get _could => _isMale ? 'смог' : 'смогла';
  String get _did => _isMale ? 'сделал' : 'сделала';
  String get _found => _isMale ? 'нашёл' : 'нашла';
  String get _completed => _isMale ? 'выполнил' : 'выполнила';
  String get _missed => _isMale ? 'пропустил' : 'пропустила';

  String get _bodyTypeLabel {
    switch (widget.profile?.bodyType) {
      case 'pear':
        return 'Груша';
      case 'apple':
        return 'Яблоко';
      case 'hourglass':
        return 'Песочные часы';
      case 'rectangle':
        return 'Прямоугольник';
      case 'inverted_triangle':
        return 'Перевернутый треугольник';
      default:
        return 'не выбран';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _questionController.dispose();
    _ideaController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback({required String text, required String type}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      if (type == 'question') {
        _isSendingQuestion = true;
      } else {
        _isSendingIdea = true;
      }
    });

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'name': _name,
        'profileId': widget.profile?.id,
        'message': trimmed,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _isSendingQuestion = false;
        _isSendingIdea = false;
      });

      if (type == 'question') {
        _questionController.clear();
      } else {
        _ideaController.clear();
      }
      FocusScope.of(context).unfocus();

      final responses = type == 'question'
          ? [
        'Спасибо за вопрос! Я обязательно прочитаю и постараюсь ответить. С верой в тебя, твоя Фея 🧚‍♀️',
        'Приняла твой вопрос! Обещаю подумать. А пока — продолжай тренироваться 💪',
        'Спасибо, что спрашиваешь! Вопросы помогают мне становиться лучше. 🧚‍♀️',
      ]
          : [
        'Ого, спасибо за идею! Такие сообщения делают меня лучше. ✨',
        'Записала твоё пожелание! Обещаю подумать. Спасибо, что помогаешь мне расти 🧚‍♀️',
        'Спасибо! Я прочитаю и постараюсь сделать приложение ещё удобнее. 💫',
      ];
      final msg = responses[DateTime.now().millisecond % responses.length];

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            Image.asset('assets/fairy/fairy_happy.png', width: 40, height: 40),
            const SizedBox(width: 8),
            const Expanded(child: Text('Спасибо!')),
          ]),
          content: Text(msg, style: const TextStyle(fontSize: 13, height: 1.4)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отлично!'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingQuestion = false;
        _isSendingIdea = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ГРУППЫ ВОПРОСОВ
  // ═══════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get _faqGroups => [
    {
      'title': '🔥 Разминка',
      'icon': Icons.local_fire_department_rounded,
      'color': const Color(0xFFFFB800),
      'items': [
        {
          'q': 'Зачем нужна разминка?',
          'a': 'Разминка разогревает суставы и мышцы, снижает риск травм. Это 3 минуты махов и вращений — не пропускай. Она не влияет на статус дня, но я очень рекомендую делать её перед каждой тренировкой.',
        },
        {
          'q': 'Разминка обязательна?',
          'a': 'Формально — нет, день засчитается и без неё. Но мышцам и суставам нужно подготовиться к нагрузке. Даже 3 минуты дают большую разницу: лучше пойдёт основная часть, меньше риск потянуть что-то.',
        },
      ],
    },
    {
      'title': '🏋️ Блоки и упражнения',
      'icon': Icons.fitness_center_rounded,
      'color': const Color(0xFF6C5CE7),
      'items': [
        {
          'q': 'Что такое база и изоляция?',
          'a': 'База — это многосуставные движения (приседания, мосты, жимы). Они дают основной стимул для роста силы. Изоляция — точечная проработка одной мышцы (махи, разгибания). В блоках я ставлю базу первой, а затем добиваю её изоляцией.\n\n$_name, а если ты тренируешься дома — всё работает немного иначе: вместо базы и изоляции я собираю день по движениям — жим, тяга, присед, мостик-тяга, выпад и кор. Каждая тренировка — это всё тело сразу, а на твои фокусные зоны я добавляю 1–2 дополнительных упражнения в конец.',
        },
        {
          'q': 'Что такое блоки и как они работают?',
          'a': 'Блок — это круговая тренировка. Внутри 3 упражнения: база + изоляция на антагониста + изоляция на рабочую мышцу. Делаешь 3 круга подряд. Экономит время и отлично разгоняет пульс.',
        },
        {
          'q': 'Почему в блоке именно 3 упражнения?',
          'a': '$_name, это золотая середина. База даёт стимул для роста силы, две изоляции добивают мышцу и её антагониста. Три упражнения — оптимальный объём, чтобы не переутомиться и успеть восстановиться между кругами.',
        },
        {
          'q': 'Как меняются база и изоляция?',
          'a': 'Вот как я строю план:\n\n• База: в течение цикла (4 недели) не меняю, чтобы ты $_could спокойно прогрессировать в весе. Раз в 2 цикла предложу замену.\n• Изоляция: меняю каждую тренировку и слежу, чтобы одни и те же не повторялись два дня подряд.\n\nДома база меняется чаще: каждый день — новые движения, но все они проходят через одни и те же паттерны, так что каждое упражнение вернётся через несколько тренировок.',
        },
        {
          'q': 'Могу ли я менять упражнения в плане?',
          'a': 'Конечно! Нажми на упражнение — в меню есть «Заменить упражнение» с выбором причины (нет оборудования, тяжело, легко, не нравится) и быстрый значок замены прямо на карточке — тот же экран замены, но без вопросов о причине.\n\nВ обоих случаях покажу аналоги, фильтр по инвентарю и поиск. Для базовых спрошу в конце: «Только сегодня» или «Навсегда» — замена закрепится во всём месяце. Для изоляции замена ставится на один день: на следующей тренировке вернётся запланированное. И я никогда не предложу упражнение, запрещённое твоими ограничениями.',
        },
      ],
    },
    {
      'title': '📅 План тренировок',
      'icon': Icons.calendar_month_rounded,
      'color': const Color(0xFF0984E3),
      'items': [
        {
          'q': 'Как устроен план тренировок?',
          'a': '$_name, план создаётся сразу на месяц — это один цикл из 4 недель. Первые три недели нагрузка растёт: добавляются подходы, а на 3-й неделе, если ты $_completed норму, — рабочий вес. Четвёртая неделя — разгрузочная: вес откатывается назад, чтобы организм восстановился. Базовые упражнения внутри цикла чередуются — каждое возвращается раз в два цикла, а изоляции не повторяются около двух недель. Чтобы перейти к следующей неделе, нужно закрыть все дни предыдущей.\n\nДома каждый день — это «Всё тело» (дни A, B, C), и в каждом прорабатывается вся фигура целиком. А ещё, $_name, через два завершённых цикла я подниму твой уровень на ступень выше — план станет сложнее вместе с тобой.',
        },
        {
          'q': 'От чего зависит мой план?',
          'a': 'Видишь ли, $_name, план собирается лично под тебя. Тип фигуры подсказывает акцентные зоны (например, «Груша» — плечи и ягодицы, «Яблоко» — пресс и ноги). Уровень задаёт сложность и количество фокусных зон. Цель меняет структуру: при похудении больше кардио и короче отдых. Инвентарь определяет пул упражнений, а ограничения по здоровью исключают опасные движения. И, конечно, план ляжет именно на выбранные тобой дни недели.',
        },
        {
          'q': 'Можно ли выбрать «Кардио-день»?',
          'a': 'Если ты тренируешься от трёх дней в неделю — да. При двух днях в неделю каждой тренировке нужнее силовая часть.',
        },
        {
          'q': 'Не смогу тренироваться в выбранный день — что делать?',
          'a': 'Ничего страшного, $_name: тренировку можно перенести прямо из плана на другой день. План живой, подстроится.',
        },
      ],
    },
    {
      'title': '📈 Прогрессия и вес',
      'icon': Icons.trending_up_rounded,
      'color': const Color(0xFF00B894),
      'items': [
        {
          'q': 'Как растёт вес и меняются повторы?',
          'a': '$_name, это зависит от цели:\n\n• Тонус и похудение — вес повышаю на 3-й неделе, повторы сохраняю с 2-й (если ты $_coped).\n• Сила и масса — вес повышаю на 2-й и 3-й неделе, повторы остаются базовыми для адаптации.\n\nЕсли ты $_didNot норму — вес не вырастет, пока техника не закрепится.',
        },
        {
          'q': 'Что делать, если не удалось выполнить норму повторов?',
          'a': 'Понимаешь, $_name, если норма не выполнена, я не буду накидывать ещё больше. На следующей неделе повторы останутся базовыми (15), а вес не вырастет, пока техника не будет закреплена. Слушай своё тело!',
        },
        {
          'q': 'Как работают изоляции (махи, разгибания)?',
          'a': 'На изоляции главное — техника и жжение в мышце, а не вес. Если ты $_did больше 15 повторов — я это запомню. Если меньше — оставлю 15 для закрепления.',
        },
        {
          'q': 'Почему планки и упражнения на время не растут?',
          'a': 'Они растут, но по другой схеме: 60 → 80 → 100 секунд. Если время на предыдущей неделе не было выполнено, я не буду прыгать выше, пока ты не выложишься на 100%. Если ты дома и уже $_isAdvancedLabel — у тебя своя волна: планки стартуют с 2 минут и растут 120 → 140 → 160 секунд.',
        },
      ],
    },
    {
      'title': '🎯 Цель и профиль',
      'icon': Icons.tune_rounded,
      'color': const Color(0xFF0984E3),
      'items': [
        {
          'q': 'Как цель влияет на план?',
          'a': 'Видишь ли, $_name, цель меняет количество подходов, отдых и кардио. Если цель «Похудение» — добавляю больше кардио и сокращаю отдых. Если «Сила» или «Масса» — увеличиваю вес и отдых между подходами.',
        },
        {
          'q': 'Что такое фокусные зоны и тип фигуры?',
          'a': 'У тебя в профиле выбран тип фигуры «$_bodyTypeLabel». Это значит, что я автоматически подбираю упражнения так, чтобы подчеркнуть достоинства именно этого типа (например, сделать акцент на ягодицы, плечи или талию). Фокусные зоны — это те мышцы, которые мы прорабатываем в первую очередь. Новичкам доступно 2 зоны, остальным — 3.\n\n$_name, если ты тренируешься дома — у тебя всегда 2 зоны независимо от уровня: домашние дни и так покрывают всё тело, поэтому больше зон там просто не нужно.',
        },
        {
          'q': 'Как уровень (Новичок/Средний/Продвинутый) влияет на план?',
          'a': '$_name, твой уровень определяет количество подходов и сложность упражнений. Новичкам — 2 подхода и базовые движения. Среднему уровню — 3 подхода и больше изоляции. Продвинутым — 4 подхода и более сложные вариации.\n\nИ самое приятное: после двух завершённых циклов уровень растёт автоматически — $_levelProgressText. Мне не придётся тебя ни о чём спрашивать, план сам станет сложнее.\n\nЕсли ты дома и уровень «Продвинутый» — у тебя особая волна: повторы 20 → 22 → 25 → 20 по неделям, а планки и упражнения на время стартуют с 2 минут (120 → 140 → 160 секунд).',
        },
        {
          'q': 'Почему кардио стоит в конце тренировки?',
          'a': 'Чтобы не тратить силы на бег до силовой работы. Сначала мы выкладываемся на базе и изоляции, а кардио в конце помогает «дожечь» калории и разогнать пульс.',
        },
      ],
    },
    {
      'title': '⚡ Энергия и усталость',
      'icon': Icons.bolt_rounded,
      'color': const Color(0xFFFDCB6E),
      'items': [
        {
          'q': 'Как получить энергию?',
          'a': '$_name, сразу после создания профиля я дарю 30 ⚡ приветственных. Дальше вот мои источники: за вход в приложение каждый день — 5 ⚡, завершённая тренировка — +20 ⚡, день челленджа в 3-й неделе — +60 ⚡ и Золотой Лотос в сад, ежедневный мини-челлендж — +15 ⚡ и цветок 🌸, сессия йоги — +15 ⚡. Всю историю начислений видно на экране «Жизненная энергия».',
        },
        {
          'q': 'На что тратить энергию?',
          'a': 'В Саду Феи: лотосы, тропинки, скамейки, фонтаны и другие украшения — от 10 до 100 ⚡. Завядший цветок оживляет за 30 ⚡. Убранный предмет возвращает свою цену полностью.',
        },
        {
          'q': 'Почему цветок завял?',
          'a': '$_name, это честная часть игры: если вчерашний мини-челлендж остался незавершённым, один цветок в саду засыпает. Нажми на него — и он расцветёт снова за 30 ⚡ Жизненной Энергии. Даже если ты $_missed несколько дней, завянет только один цветок, а не весь сад. Завядший цветок нельзя убрать или переставить — только оживить.',
        },
        {
          'q': 'Куда делись мои элементы? Как посмотреть историю?',
          'a': 'На экране «Жизненная энергия» видно все начисления и траты с причинами: покупки в саду, оживление цветка, награды за тренировки и челленджи. Если кажется, что что-то списалось зря — сверь с историей, там каждая транзакция.',
        },
      ],
    },
    {
      'title': '🌻 Сад Феи',
      'icon': Icons.local_florist_rounded,
      'color': const Color(0xFF00B894),
      'items': [
        {
          'q': 'Как работает Сад Феи?',
          'a': 'Сад — это твой прогресс, ставший наглядным, $_name. Цветы растут за выполненные челленджи и тренировки, а за энергию можно покупать декор: скамейки, кусты, качели, фонтаны, фонари, арки. Нажми на свободную клетку — откроется магазин. Зажми предмет и перетащи — переместишь его на другое место. Тропинку можно положить даже под готовый объект.',
        },
        {
          'q': 'Что за Золотой Лотос?',
          'a': 'Самый ценный цветок в саду 🌟 — он вырастает за пройденный день челленджа в 3-й неделе месяца. Обычные цветы растут за ежедневные мини-челленджи.',
        },
        {
          'q': 'Можно ли поделиться садом?',
          'a': 'Конечно, $_name! Иконка «Поделиться» вверху — я соберу красивую картинку-историю с твоим садом, и её можно отправить друзьям или выложить в соцсети. Сад — это тоже твой прогресс, им можно гордиться!',
        },
        {
          'q': 'Можно ли начать сад заново?',
          'a': 'Да, $_name — иконка корзины вверху экрана сада. Но учти: при полной очистке энергия за предметы не возвращается, а вот если убирать предметы по одному — цена возвращается целиком.',
        },
      ],
    },
    {
      'title': '📊 Прогресс и фото',
      'icon': Icons.analytics_rounded,
      'color': const Color(0xFF6C5CE7),
      'items': [
        {
          'q': 'Где посмотреть мой прогресс?',
          'a': 'Во вкладке «Прогресс», $_name. Сверху — три цифры: сколько тренировок завершено, суммарное время и общий объём (тоннаж). Ниже — график по дням недели: он считает факт, поэтому если тренировка сдвинулась, она попадёт в свой реальный день. Дальше календарь месяца со статусами, и в конце — выпадающий список упражнений с графиком веса по каждому.',
        },
        {
          'q': 'Что такое анализ упражнений?',
          'a': 'Это раздел в «Прогрессе». Он делится на «Силовой прогресс» (веса) и «Функциональный» (время, повторения, кардио). По каждому упражнению видно, сколько раз оно встречалось, средний результат прошлой и текущей недели и рекомендацию: расти, держать темп или притормозить. Анализ появляется, когда закрыта 3-я неделя цикла — до этого сравнивать просто не с чем.',
        },
        {
          'q': 'Как работают фото трансформации?',
          'a': 'Раз в месяц делай фото с трёх ракурсов: спереди, сбоку и сзади. И понимаешь, $_name, главное — снимать в одинаковых условиях: тот же свет, та же поза, то же время суток. Тогда разница между «до» и «после» будет честной. Фото можно перезагрузить, открыть на весь экран и приблизить пальцами. Они хранятся прямо в приложении и никуда не отправляются.',
        },
        {
          'q': 'Что такое достижения?',
          'a': 'Маленькие награды за серии, подходы и объём. Они помогают не бросать и замечать прогресс. Смотри их в разделе достижений — там видно, что уже открыто, а к чему ты идёшь.',
        },
      ],
    },
    {
      'title': '🩺 Безопасность и травмы',
      'icon': Icons.health_and_safety_rounded,
      'color': const Color(0xFFE17055),
      'items': [
        {
          'q': 'Что делать, если я не знаю, как делать упражнение правильно?',
          'a': 'Безопасность — превыше всего. У каждого упражнения есть иконка «i» (Детали). Нажми на неё, чтобы посмотреть технику, картинку и частые ошибки. Если что-то непонятно — лучше уменьшить вес или попросить тренера в зале проверить форму. Не делай через боль!',
        },
        {
          'q': 'У меня есть травма или ограничения. Что делать?',
          'a': '$_name, безопасность — прежде всего! Если есть травмы, обязательно укажи их в настройках профиля (в разделе «Ограничения»). Я автоматически исключу упражнения, которые могут навредить. Если боль острая — лучше проконсультироваться с врачом перед началом тренировок.',
        },
      ],
    },
  ];

  // ═══════════════════════════════════════════════════════════
  //  ГЕНДЕРНЫЕ ФРАГМЕНТЫ ДЛЯ ОТВЕТОВ
  // ═══════════════════════════════════════════════════════════

  /// Подпись текущего уровня для ответа про планки:
  /// «уже $_isAdvancedLabel» → «уже продвинут» / «уже продвинута».
  String get _isAdvancedLabel => _isMale ? 'продвинут' : 'продвинута';

  /// Текст автоперехода уровня через 2 цикла (зависит от текущего уровня).
  String get _levelProgressText {
    switch (widget.profile?.level) {
      case 'beginner':
        return 'ты перейдёшь с «Новичка» на «Средний»';
      case 'intermediate':
        return 'ты перейдёшь с «Среднего» на «Продвинутый»';
      default:
        return 'ты закрепишься на уровне «Продвинутый»';
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final query = _searchQuery.trim().toLowerCase();
    final filteredGroups = _faqGroups.map((group) {
      final items = (group['items'] as List).where((item) {
        if (query.isEmpty) return true;
        final q = (item['q'] as String).toLowerCase();
        final a = (item['a'] as String).toLowerCase();
        return q.contains(query) || a.contains(query);
      }).toList();
      return {...group, 'items': items};
    }).where((g) => (g['items'] as List).isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шпаргалка от Феи', style: TextStyle(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context, theme),
          const SizedBox(height: 16),
          _buildSearchField(theme),
          const SizedBox(height: 20),
          if (filteredGroups.isEmpty)
            _buildEmptySearch(theme)
          else
            ...List.generate(filteredGroups.length, (gi) {
              final group = filteredGroups[gi];
              return _buildGroup(context, theme, group);
            }),
          const SizedBox(height: 30),
          _buildFooter(context, theme),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/fairy/fairy_wink.png', width: 90, height: 90, fit: BoxFit.contain),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Привет, $_name!', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  'Я собрала для тебя популярные вопросы по группам. Нажми на любой, чтобы узнать ответ.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Найти ответ...',
        hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        )
            : null,
        filled: true,
        fillColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildEmptySearch(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'Ничего не нашлось',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 6),
          Text(
            'Попробуй другой запрос или напиши мне вопрос внизу',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, ThemeData theme, Map<String, dynamic> group) {
    final color = group['color'] as Color;
    final items = group['items'] as List;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(group['icon'] as IconData, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  group['title'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final itemKey = '${group['title']}#$i';
            final isExpanded = _expandedIndex == itemKey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildFaqTile(
                context,
                question: item['q'] as String,
                answer: item['a'] as String,
                isExpanded: isExpanded,
                onTap: () {
                  setState(() {
                    _expandedIndex = isExpanded ? null : itemKey;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFaqTile(BuildContext context, {
    required String question,
    required String answer,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isExpanded
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withValues(alpha: 0.15),
          width: isExpanded ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isExpanded ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 10),
                  Text(
                    answer,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Image.asset(
            'assets/fairy/fairy_happy.png',
            width: 110,
            height: 110,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, size: 48, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 10),
          Text(
            'С заботой о тебе,\nтвоя Фея',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.primary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
            ),
            child: Text(
              'P.S. Если не $_found ответа — задай вопрос или оставь пожелание ниже. Я обязательно прочитаю! 🧚‍♀️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildFeedbackField(
            theme: theme,
            title: 'Есть вопрос?',
            hint: 'Напиши вопрос Фее...',
            controller: _questionController,
            isSending: _isSendingQuestion,
            type: 'question',
            accent: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),

          _buildFeedbackField(
            theme: theme,
            title: 'Пожелание по улучшению',
            hint: 'Что можно сделать лучше?',
            controller: _ideaController,
            isSending: _isSendingIdea,
            type: 'idea',
            accent: const Color(0xFF00B894),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackField({
    required ThemeData theme,
    required String title,
    required String hint,
    required TextEditingController controller,
    required bool isSending,
    required String type,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: accent.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isSending ? null : () => _sendFeedback(text: controller.text, type: type),
                icon: isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// ═══ КОНЕЦ ФАЙЛА trainer_screen.dart ═══
