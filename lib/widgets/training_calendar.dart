import 'package:flutter/material.dart';
import '../models/workout_day.dart';

/// Календарь месяца с отметками тренировок.
///
/// 🟢 зелёная точка — завершена (в день фактического выполнения)
/// 🟡 жёлтая точка — в процессе
/// 🔵 контурная синяя — запланирована
/// 🟠 оранжевая — просрочена (план уже прошёл)
/// 🔵 рамка — сегодня
///
/// Тап на день с тренировками → onDayTap (список тренировок дня).
/// Листание ← → загружает данные через onLoadMonth.
class TrainingCalendar extends StatefulWidget {
  final List<WorkoutDay> workouts;

  /// Тап по дню: передаёт ВСЕ тренировки этой даты (может быть несколько,
  /// например когда обе выполнены в один день, хотя планировались на разные).
  final ValueChanged<List<WorkoutDay>>? onDayTap;

  /// Колбэк загрузки тренировок за месяц.
  /// Возвращает список тренировок за (year, month).
  final Future<List<WorkoutDay>> Function(int year, int month)? onLoadMonth;

  const TrainingCalendar({
    super.key,
    required this.workouts,
    this.onDayTap,
    this.onLoadMonth,
  });

  @override
  State<TrainingCalendar> createState() => _TrainingCalendarState();
}

class _TrainingCalendarState extends State<TrainingCalendar> {
late DateTime _currentMonth;

/// Кэш: ключ "2026-10" → список тренировок.
final Map<String, List<WorkoutDay>> _cache = {};

/// Идёт загрузка месяца.
bool _loading = false;

// ═══ Цвета точек ═══
static const Color _green = Color(0xFF00B894);
static const Color _yellow = Color(0xFFFDCB6E);
static const Color _blue = Color(0xFF6C5CE7);
static const Color _overdue = Color(0xFFE17055);

@override
void initState() {
super.initState();
final now = DateTime.now();
_currentMonth = DateTime(now.year, now.month, 1);
// Первый месяц — данные уже пришли из родителя
_cache[_monthKey(_currentMonth)] = widget.workouts;
}

@override
void didUpdateWidget(TrainingCalendar oldWidget) {
super.didUpdateWidget(oldWidget);
// Родитель обновил данные для текущего месяца — обновляем кэш
if (widget.workouts != oldWidget.workouts) {
_cache[_monthKey(_currentMonth)] = widget.workouts;
}
}

String _monthKey(DateTime d) => '${d.year}-${d.month}';

/// Тренировки для отображаемого месяца.
List<WorkoutDay> get _currentWorkouts =>
_cache[_monthKey(_currentMonth)] ?? widget.workouts;

Future<void> _changeMonth(int delta) async {
final newMonth =
DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
final key = _monthKey(newMonth);

setState(() {
_currentMonth = newMonth;
_loading = widget.onLoadMonth != null && !_cache.containsKey(key);
});

// Уже в кэше — просто показываем
if (_cache.containsKey(key)) {
if (mounted) setState(() => _loading = false);
return;
}

// Загружаем из БД
if (widget.onLoadMonth != null) {
try {
final data = await widget.onLoadMonth!(
newMonth.year,
newMonth.month,
);
if (!mounted) return;
setState(() {
_cache[key] = data;
_loading = false;
});
} catch (e) {
if (!mounted) return;
setState(() {
_cache[key] = [];
_loading = false;
});
}
}
}

void _prevMonth() => _changeMonth(-1);
void _nextMonth() => _changeMonth(1);

String _monthName(int m) {
const names = [
'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];
return names[m - 1];
}

// ═══ 👈 ИЗМЕНЕНО: дата отображения — факт для завершённых ═══

/// Дата, по которой день отображается в календаре:
/// завершённые — по факту (completedAt), остальные — по плану.
/// Выполненная досрочно тренировка уходит из планового слота
/// и встаёт зелёной точкой на реальный день выполнения.
DateTime _displayDate(WorkoutDay w) {
if (w.status == 'completed') {
final c = w.completedAt ?? w.date;
return DateTime(c.year, c.month, c.day);
}
return DateTime(w.date.year, w.date.month, w.date.day);
}

/// Тренировки конкретного дня (может быть несколько — например,
/// когда обе завершены в один день, хотя планировались на разные).
List<WorkoutDay> _workoutsForDay(DateTime day) {
return _currentWorkouts
.where((w) {
final d = _displayDate(w);
return d.year == day.year && d.month == day.month && d.day == day.day;
})
.toList();
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);

// Первый день месяца и количество дней
final firstDay = _currentMonth;
final daysInMonth =
DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

// weekday: 1 = Пн, 7 = Вс. Сдвигаем так, чтобы Пн был 0
final firstWeekday = (firstDay.weekday - 1) % 7;

// Ячейки: пустые + дни
final cells = <Widget>[];

// Пустые ячейки в начале
for (int i = 0; i < firstWeekday; i++) {
cells.add(const SizedBox());
}

// Дни месяца
final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
for (int day = 1; day <= daysInMonth; day++) {
final date = DateTime(_currentMonth.year, _currentMonth.month, day);
final workouts = _workoutsForDay(date);
final isToday = date.year == today.year &&
date.month == today.month &&
date.day == today.day;

cells.add(_buildDayCell(context, day, workouts, isToday, today));
}

return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: theme.colorScheme.surface,
borderRadius: BorderRadius.circular(20),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// ═══ Заголовок: ← Октябрь 2026 → ═══
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
IconButton(
onPressed: _loading ? null : _prevMonth,
icon: const Icon(Icons.chevron_left_rounded),
color: theme.colorScheme.primary,
padding: EdgeInsets.zero,
constraints: const BoxConstraints(),
),
// Название месяца + индикатор загрузки
Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(
'${_monthName(_currentMonth.month)} '
'${_currentMonth.year}',
style: theme.textTheme.headlineMedium?.copyWith(
fontWeight: FontWeight.w700,
),
),
if (_loading) ...[
const SizedBox(width: 8),
SizedBox(
width: 14,
height: 14,
child: CircularProgressIndicator(
strokeWidth: 2,
color: theme.colorScheme.primary,
),
),
],
],
),
IconButton(
onPressed: _loading ? null : _nextMonth,
icon: const Icon(Icons.chevron_right_rounded),
color: theme.colorScheme.primary,
padding: EdgeInsets.zero,
constraints: const BoxConstraints(),
),
],
),
const SizedBox(height: 12),

// ═══ Дни недели ═══
const Row(
children: [
_WeekdayLabel('Пн'),
_WeekdayLabel('Вт'),
_WeekdayLabel('Ср'),
_WeekdayLabel('Чт'),
_WeekdayLabel('Пт'),
_WeekdayLabel('Сб'),
_WeekdayLabel('Вс'),
],
),
const SizedBox(height: 8),

// ═══ Сетка дней ═══
GridView.count(
crossAxisCount: 7,
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
mainAxisSpacing: 4,
crossAxisSpacing: 4,
children: cells,
),

// ═══ Легенда ═══
const SizedBox(height: 12),
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const _LegendDot(color: _green, label: 'Завершена'),
const SizedBox(width: 12),
const _LegendDot(color: _yellow, label: 'В процессе'),
const SizedBox(width: 12),
_LegendDot(
color: _blue,
label: 'План',
isBorder: true,
),
const SizedBox(width: 12),
const _LegendDot(color: _overdue, label: 'Просрочена'),
],
),
],
),
);
}
  // ═══ КОНЕЦ ЧАСТИ 1 ═══

  // ═══ 👈 ИЗМЕНЕНО: убран индикатор "›" (completedLater) —
  // факт и так стоит на своей дате, плановый слот пустой ═══
  Widget _buildDayCell(
      BuildContext context,
      int day,
      List<WorkoutDay> workouts,
      bool isToday,
      DateTime today,
      ) {
    final theme = Theme.of(context);

    // Приоритет: завершена > в процессе > просрочена > пропущена > запланирована
    Color? dotColor;
    bool hollow = false; // контурная точка для плана

    if (workouts.any((w) => w.status == 'completed')) {
      dotColor = _green;
    } else if (workouts.any((w) => w.status == 'in_progress')) {
      dotColor = _yellow;
    } else if (workouts.any((w) =>
    w.status == 'planned' &&
        w.date.isBefore(today))) {
      // Запланировано, но дата уже прошла — просрочка
      dotColor = _overdue;
    } else if (workouts.any((w) => w.status == 'skipped')) {
      dotColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (workouts.isNotEmpty) {
      dotColor = _blue;
      hollow = true; // будущая запланированная — контурная синяя
    }

    final hasWorkout = workouts.isNotEmpty;

    return GestureDetector(
      onTap: hasWorkout ? () => widget.onDayTap?.call(workouts) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            if (dotColor != null)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: hollow ? Colors.transparent : dotColor,
                  shape: BoxShape.circle,
                  border: hollow ? Border.all(color: dotColor, width: 1.2) : null,
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ═══ КОНЕЦ ЧАСТИ 2 ═══
// ═══════════════════════════════════════════════════════════
//  ЯЧЕЙКА ДНЯ НЕДЕЛИ
// ═══════════════════════════════════════════════════════════

class _WeekdayLabel extends StatelessWidget {
  final String text;

  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ЛЕГЕНДА
// ═══════════════════════════════════════════════════════════

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isBorder;

  const _LegendDot({
    required this.color,
    required this.label,
    this.isBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isBorder ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: isBorder ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
// ═══ КОНЕЦ ФАЙЛА training_calendar.dart ═══
