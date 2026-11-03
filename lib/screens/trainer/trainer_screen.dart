import 'package:flutter/material.dart';

class TrainerScreen extends StatefulWidget {
  const TrainerScreen({super.key});

  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  // Индекс открытого вопроса (null, если все закрыты)
  int? _expandedIndex;

  final List<Map<String, String>> _faq = [
    {
      'q': 'Почему план строится на месяц?',
      'a': 'Месяц (4 недели) — это классический цикл периодизации. Мы постепенно повышаем нагрузку (вес или повторы), а на 4-й неделе делаем разгрузку, чтобы ты восстановилась и не перетренировалась. Такой цикл дает стабильный прогресс без выгорания.',
    },
    {
      'q': 'Как цель влияет на план?',
      'a': 'Цель меняет количество подходов, отдых и кардио. Если цель «Похудение», программа добавляет больше кардио и сокращает отдых. Если «Сила» или «Масса» — увеличивает вес и отдых между подходами, а кардио оставляет минимальным.',
    },
    {
      'q': 'Что такое фокусные зоны и тип фигуры?',
      'a': 'Тип фигуры (Груша, Яблоко, Песочные часы и т.д.) задает базовый акцент на определенные группы мышц (например, для «Груши» — ягодицы и плечи для баланса). Фокусные зоны — это те мышцы, которые ты хочешь подчеркнуть. Приложение автоматически подбирает упражнения под эти зоны.',
    },
    {
      'q': 'Как мой уровень (Новичок/Средний/Продвинутый) влияет на план?',
      'a': 'Уровень определяет количество подходов и сложность упражнений. Новичкам программа дает 2 подхода и базовые движения. Среднему уровню — 3 подхода и больше изоляции. Продвинутым — 4 подхода и более сложные вариации (например, с одной ногой).',
    },
    {
      'q': 'Как растет вес и меняются повторы?',
      'a': 'Это зависит от твоей цели!\n\n• Для «Тонуса» и «Похудения»: вес растет на 3-й неделе, а повторы сохраняются с 2-й недели (если ты справилась).\n• Для «Силы» и «Массы»: вес растет уже на 2-й и 3-й неделе, а повторы могут оставаться базовыми для адаптации.\n\nЕсли был провал на прошлой неделе — повторы не растут, а вес может остаться прежним, чтобы ты закрепила технику.',
    },
    {
      'q': 'Что делать, если я не доделала повторы на прошлой неделе?',
      'a': 'Если ты не выполнила норму, программа не будет накидывать тебе еще больше. На следующей неделе повторы останутся базовыми (15), а вес не вырастет, пока ты не закрепишь результат. Слушай свое тело!',
    },
    {
      'q': 'Как работают изоляции (махи, разгибания)?',
      'a': 'На изоляции мы не гонимся за весом. Главное — техника и жжение в мышце. Если ты сделала больше 15 повторов — программа запомнит это. Если меньше — оставит 15, чтобы ты догнала план.',
    },
    {
      'q': 'Почему планки и упражнения на время не растут?',
      'a': 'Они растут, но по другой схеме: 60 → 80 → 100 секунд. Если ты не доделала время на предыдущей неделе, программа не прыгнет выше, пока ты не выложишься на 100%.',
    },
    {
      'q': 'Почему кардио стоит в конце тренировки?',
      'a': 'Чтобы не тратить силы на бег до силовой работы. Сначала мы выкладываемся на базе и изоляции, а кардио в конце помогает «дожечь» калории и разогнать пульс.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шпаргалка от Феи'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 👇 Шапка с Феей
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Частые вопросы', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Нажми на вопрос, чтобы узнать ответ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 👇 Список вопросов-аккордеонов
          ...List.generate(_faq.length, (index) {
            final isExpanded = _expandedIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildFaqTile(
                context,
                question: _faq[index]['q']!,
                answer: _faq[index]['a']!,
                isExpanded: isExpanded,
                onTap: () {
                  setState(() {
                    _expandedIndex = isExpanded ? null : index; // Открываем новый или закрываем текущий
                  });
                },
              ),
            );
          }),

          const SizedBox(height: 30),

          // 👇 Подпись Феи
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'С верой в тебя, твоя Фея 🧚‍♀️',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.1),
          width: isExpanded ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isExpanded ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    answer,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      height: 1.5,
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
}