import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../models/stretch.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';

class HistoryDetailScreen extends StatefulWidget {
  final WorkoutDay workout;
  const HistoryDetailScreen({super.key, required this.workout});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  List<WorkoutExercise> _exercises = [];
  Map<int, Exercise> _exerciseMap = {};
  Map<int, Stretch> _stretchMap = {};
  Map<int, List<WorkoutSet>> _setsMap = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final exercises = await DatabaseHelper.instance.getWorkoutExercises(widget.workout.id!);
    final exMap = <int, Exercise>{}; final stMap = <int, Stretch>{}; final setsMap = <int, List<WorkoutSet>>{};

    for (final we in exercises) {
      if (we.itemType == 'exercise') {
        final effectiveId = we.replacedByItemId ?? we.itemId;
        final ex = await DatabaseHelper.instance.getExerciseById(effectiveId);
        if (ex != null) exMap[effectiveId] = ex;
        setsMap[we.id!] = await DatabaseHelper.instance.getWorkoutSets(we.id!);
      } else {
        final st = await DatabaseHelper.instance.getStretchById(we.itemId);
        if (st != null) stMap[we.itemId] = st;
      }
    }
    setState(() { _exercises = exercises; _exerciseMap = exMap; _stretchMap = stMap; _setsMap = setsMap; _loading = false; });
  }

  bool _isCardio(Exercise ex) {
    final coreGroups = ['abs', 'core', 'obliques'];
    if (ex.muscleGroups.any((m) => coreGroups.contains(m))) return false;
    if (ex.muscleGroups.contains('cardio')) return true;
    final lower = ex.name.toLowerCase();
    return lower.contains('бег') || lower.contains('дорожк') || lower.contains('скакалк') ||
        lower.contains('эллипс') || lower.contains('велотренаж') || lower.contains('велоэргометр') ||
        lower.contains('гребл') || lower.contains('степпер') || lower.contains('кардио');
  }

  bool _isTimed(String name) {
    final lower = name.toLowerCase();
    return lower.contains('планка') || lower.contains('plank') || _isCardioName(lower);
  }

  bool _isCardioName(String lowerName) {
    return lowerName.contains('бег') || lowerName.contains('дорожк') || lowerName.contains('скакалк') ||
        lowerName.contains('эллипс') || lowerName.contains('велотренаж') || lowerName.contains('велоэргометр') ||
        lowerName.contains('гребл') || lowerName.contains('степпер') || lowerName.contains('кардио');
  }

  String? _getBaseZone(Exercise ex) {
    final keywords = ['присед', 'приседание', 'squat', 'выпад', 'lunge', 'становая', 'deadlift',
      'румынск', 'romanian', 'жим', 'press', 'bench press', 'тяга', 'row', 'подтягив', 'pull-up',
      'pullup', 'отжимание', 'push-up', 'pushup', 'берпи', 'burpee', 'планка', 'plank', 'скручивание', 'crunch'];
    final lower = ex.name.toLowerCase();
    if (!keywords.any((kw) => lower.contains(kw))) return null;
    if (ex.muscleGroups.contains('glutes') || ex.muscleGroups.contains('legs')) return 'Ягодицы/Ноги';
    if (ex.muscleGroups.contains('chest')) return 'Грудь';
    if (ex.muscleGroups.contains('back')) return 'Спина';
    if (ex.muscleGroups.contains('arms')) return 'Руки';
    if (ex.muscleGroups.contains('abs') || ex.muscleGroups.contains('core')) return 'Пресс';
    return 'База';
  }

  String _formatDate(DateTime date) {
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.workout.name)),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(context),
          if (widget.workout.notes != null && widget.workout.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withOpacity(0.3))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notes_rounded, color: Colors.amber, size: 20), const SizedBox(width: 12),
                Expanded(child: Text(widget.workout.notes!, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          Text('Упражнения', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          ..._exercises.where((e) => !e.isCoolDown).map((e) => _buildExerciseItem(context, e)),
          if (_exercises.any((e) => e.isCoolDown)) ...[
            const SizedBox(height: 20),
            Text('Заминка', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            ..._exercises.where((e) => e.isCoolDown).map((e) => _buildStretchItem(context, e)),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final completedSets = _setsMap.values.expand((s) => s).where((s) => s.completed).length;
    final totalSets = _setsMap.values.expand((s) => s).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatDate(widget.workout.date), style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            _infoItem(context, Icons.timer_rounded, widget.workout.durationMinutes != null ? '${widget.workout.durationMinutes}' : '—', 'минут'),
            Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
            _infoItem(context, Icons.fitness_center, '$completedSets', 'подходов'),
            Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
            _infoItem(context, Icons.percent_rounded, totalSets > 0 ? '${(completedSets * 100 / totalSets).round()}' : '0', '%'),
          ]),
        ],
      ),
    );
  }

  Widget _infoItem(BuildContext context, IconData icon, String value, String label) {
    return Expanded(child: Column(children: [
      Icon(icon, color: Colors.white, size: 22), const SizedBox(height: 6),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]));
  }

  Widget _buildExerciseItem(BuildContext context, WorkoutExercise we) {
    final theme = Theme.of(context);
    final effectiveId = we.replacedByItemId ?? we.itemId;
    final ex = _exerciseMap[effectiveId];
    if (ex == null) return const SizedBox.shrink();

    final isCardio = _isCardio(ex);
    final isTimed = _isTimed(ex.name);
    final isTimeBased = isCardio || isTimed;
    final baseZone = _getBaseZone(ex);

    // Извлекаем целевое время из плана (например, из "70 сек" достаем "70")
    String targetTime = we.reps.replaceAll(RegExp(r'[^0-9]'), '');
    if (targetTime.isEmpty) targetTime = isTimed ? '60' : '15';

    String repsSuffix = ' повт.';
    if (isCardio) repsSuffix = ' мин';
    else if (isTimed) repsSuffix = ' сек';

    List<WorkoutSet> displaySets = _setsMap[we.id!] ?? [];
    if (displaySets.isEmpty) displaySets = List.generate(we.sets, (i) => WorkoutSet(workoutExerciseId: we.id!, order: i + 1, completed: false));
    final completed = displaySets.where((s) => s.completed).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(isCardio ? Icons.directions_run_rounded : Icons.fitness_center, color: theme.colorScheme.primary, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ex.name, style: theme.textTheme.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (baseZone != null && !isCardio) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('БАЗА - ${baseZone.toUpperCase()}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF6C5CE7))),
                  ),
                ],
                const SizedBox(height: 2),
                Text('Выполнено $completed из ${displaySets.length}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
              ])),
            ]),
            const SizedBox(height: 12),
            ...displaySets.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: s.completed ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Text('${s.order}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.completed ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5)))),
                const SizedBox(width: 10),
                if (!isTimeBased) ...[
                  Text(s.weight != null ? '${s.weight!.toStringAsFixed(s.weight! % 1 == 0 ? 0 : 1)} кг' : '— кг', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 12),
                ],
                // 👇 Берем из подхода, если есть. Иначе — из плана (targetTime).
                Text(
                  s.reps != null
                    ? '${s.reps}$repsSuffix'
                    : '$targetTime$repsSuffix',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                Icon(s.completed ? Icons.check_circle_rounded : Icons.circle_outlined, color: s.completed ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.2), size: 20),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStretchItem(BuildContext context, WorkoutExercise we) {
    final theme = Theme.of(context);
    final st = _stretchMap[we.itemId];
    if (st == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF00B894).withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.self_improvement, color: Color(0xFF00B894), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(st.name, style: theme.textTheme.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(st.durationLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ])),
        ]),
      ),
    );
  }
}