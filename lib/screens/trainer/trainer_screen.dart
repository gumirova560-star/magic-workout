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
int? _expandedIndex;
String _searchQuery = '';
final TextEditingController _searchController = TextEditingController();

// 👇 Два поля обратной связи
final TextEditingController _questionController = TextEditingController();
final TextEditingController _ideaController = TextEditingController();
bool _isSendingQuestion = false;
bool _isSendingIdea = false;

// 👇 Персонализация
String get _name => widget.profile?.name ?? 'друг';
bool get _isMale => widget.profile?.gender == 'male';
String get _coped => _isMale ? 'справился' : 'справилась';
String get _didNot => _isMale ? 'не доделал' : 'не доделала';
String get _could => _isMale ? 'смог' : 'смогла';

String get _bodyTypeLabel {
switch (widget.profile?.bodyType) {
case 'pear': return 'Груша';
case 'apple': return 'Яблоко';
case 'hourglass': return 'Песочные часы';
case 'rectangle': return 'Прямоугольник';
case 'inverted_triangle': return 'Перевернутый треугольник';
default: return 'не выбран';
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
'type': type, // 'question' | 'idea'
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
content: Text(msg, style: const TextStyle(fontSize: 14, height: 1.4)),
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
// ═══ КОНЕЦ ЧАСТИ 1 из 4 ═══
// Скажи «часть 2», чтобы получить продолжение — _faqGroups (Разминка, Блоки, Прогрессия).
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
'a': 'База — это многосуставные движения (приседания, мосты, жимы). Они дают основной стимул для роста силы. Изоляция — точечная проработка одной мышцы (махи, разгибания). В блоках я ставлю базу первой, а затем добиваю её изоляцией.',
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
'a': 'Вот как я строю план:\n\n• База: в течение цикла (4 недели) не меняю, чтобы ты $_could спокойно прогрессировать в весе. Раз в 2 цикла предложу замену.\n• Изоляция: меняю каждую тренировку и слежу, чтобы одни и те же не повторялись два дня подряд.',
},
{
'q': 'Могу ли я менять упражнения в плане?',
'a': 'Конечно! Если упражнение не подходит (нет оборудования, тяжело или не нравится), нажми на три точки рядом и выбери «Заменить упражнение». Я подберу альтернативу с учётом причины. Изменения можно применить на один день или на весь месяц.',
},
],
},
{
'title': '📈 Прогрессия и вес',
'icon': Icons.trending_up_rounded,
'color': const Color(0xFF00B894),
'items': [
{
'q': 'Почему план строится на месяц?',
'a': 'Месяц (4 недели) — это классический цикл периодизации. Я постепенно повышаю нагрузку, а на 4-й неделе делаю разгрузку, чтобы тело восстановилось. Такой цикл даёт стабильный прогресс без выгорания.',
},
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
'a': 'На изоляции главное — техника и жжение в мышце, а не вес. Если сделала больше 15 повторов — я это запомню. Если меньше — оставлю 15 для закрепления.',
},
{
'q': 'Почему планки и упражнения на время не растут?',
'a': 'Они растут, но по другой схеме: 60 → 80 → 100 секунд. Если время на предыдущей неделе не было выполнено, я не буду прыгать выше, пока ты не выложишься на 100%.',
},
],
},
// ═══ КОНЕЦ ЧАСТИ 2 из 4 ═══
// Скажи «часть 3», чтобы получить продолжение — группы «Цель и профиль», «Безопасность», «О приложении» + build-методы.
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
'a': 'У тебя в профиле выбран тип фигуры «$_bodyTypeLabel». Это значит, что я автоматически подбираю упражнения так, чтобы подчеркнуть достоинства именно этого типа (например, сделать акцент на ягодицы, плечи или талию). Фокусные зоны — это те мышцы, которые мы прорабатываем в первую очередь.',
},
{
'q': 'Как уровень (Новичок/Средний/Продвинутый) влияет на план?',
'a': '$_name, твой уровень определяет количество подходов и сложность упражнений. Новичкам — 2 подхода и базовые движения. Среднему уровню — 3 подхода и больше изоляции. Продвинутым — 4 подхода и более сложные вариации.',
},
{
'q': 'Почему кардио стоит в конце тренировки?',
'a': 'Чтобы не тратить силы на бег до силовой работы. Сначала мы выкладываемся на базе и изоляции, а кардио в конце помогает «дожечь» калории и разогнать пульс.',
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
{
'title': '🧚 О приложении',
'icon': Icons.auto_awesome_rounded,
'color': const Color(0xFFA29BFE),
'items': [
{
'q': 'Что такое анализ упражнений?',
'a': 'Я сравниваю неделю 1 и неделю 3 текущего цикла и показываю, где ты растёшь, где стагнация, а где результат падает. Плюс даю рекомендацию по каждому упражнению. Открывается из экрана «Прогресс».',
},
{
'q': 'Что такое фото трансформации?',
'a': 'Делай фото до/после по месяцам с трёх ракурсов — я храню их и показываю прогресс. Это отличный способ увидеть изменения, когда весы стоят на месте. Открывается из экрана «Прогресс».',
},
{
'q': 'Что такое достижения?',
'a': 'Маленькие награды за серии, подходы и объём. Они помогают не бросать и замечать прогресс. Смотри их в разделе достижений — там видно, что уже открыто, а к чему ты идёшь.',
},
{
'q': 'Что такое шаблоны?',
'a': 'Можешь сохранить тренировку как шаблон и использовать позже — например, свою любимую силовую. Открывается из экрана «Тренировки» → меню «Из шаблона».',
},
],
},
];

// ═══════════════════════════════════════════════════════════
//  BUILD
// ═══════════════════════════════════════════════════════════

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);

// 👇 Фильтрация по поиску
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
title: const Text('Шпаргалка от Феи'),
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
colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.7)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(24),
boxShadow: [
BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8)),
],
),
child: Row(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Image.asset('assets/fairy/fairy_wink.png', width: 72, height: 72, fit: BoxFit.contain),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Привет, $_name!', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
const SizedBox(height: 6),
const Text(
'Я собрала для тебя популярные вопросы по группам. Нажми на любой, чтобы узнать ответ.',
style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
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
hintStyle: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
suffixIcon: _searchQuery.isNotEmpty
? IconButton(
icon: const Icon(Icons.close_rounded, size: 20),
onPressed: () {
_searchController.clear();
setState(() => _searchQuery = '');
},
)
: null,
filled: true,
fillColor: theme.colorScheme.primary.withOpacity(0.05),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: BorderSide.none,
),
),
);
}

Widget _buildEmptySearch(ThemeData theme) {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 40),
child: Column(
children: [
Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.primary.withOpacity(0.4)),
const SizedBox(height: 12),
Text(
'Ничего не нашлось',
style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
),
const SizedBox(height: 6),
Text(
'Попробуй другой запрос или напиши мне вопрос внизу',
textAlign: TextAlign.center,
style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
),
],
),
);
}
// ═══ КОНЕЦ ЧАСТИ 3 из 4 ═══
// Скажи «часть 4», чтобы получить финал — _buildGroup, _buildFaqTile, _buildFooter, _buildFeedbackField + закрытие класса.
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(group['icon'] as IconData, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  group['title'] as String,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(items.length, (i) {
            final item = items[i];
            // 👇 Уникальный индекс для раскрытия, чтобы не сбивался при поиске
            final globalIndex = _faqGroups.indexOf(group) * 1000 + i;
            final isExpanded = _expandedIndex == globalIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildFaqTile(
                context,
                question: item['q'] as String,
                answer: item['a'] as String,
                isExpanded: isExpanded,
                onTap: () {
                  setState(() {
                    _expandedIndex = isExpanded ? null : globalIndex;
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
            ? theme.colorScheme.primary.withOpacity(0.12)
            : theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withOpacity(0.15),
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

  // ═══════════════════════════════════════════════════════════
  //  ПОДВАЛ: ПОДПИСЬ ФЕИ + ДВА ПОЛЯ ОБРАТНОЙ СВЯЗИ
  // ═══════════════════════════════════════════════════════════

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Image.asset(
            'assets/fairy/fairy_happy.png',
            width: 80, height: 80, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, size: 64, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'С заботой о тебе,\nтвоя Фея',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.primary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
            ),
            child: Text(
              'P.S. Если не нашла ответа — задай вопрос или оставь пожелание ниже. Я обязательно прочитаю! 🧚‍♀️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ═══ ПОЛЕ 1: ВОПРОС ═══
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

          // ═══ ПОЛЕ 2: ПОЖЕЛАНИЕ ПО УЛУЧШЕНИЮ ═══
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
        border: Border.all(color: accent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
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
                    hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: accent.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isSending ? null : () => _sendFeedback(text: controller.text, type: type),
                icon: isSending
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// ═══ КОНЕЦ ЧАСТИ 4 из 4 — ФАЙЛ trainer_screen.dart ЗАВЕРШЁН ═══
