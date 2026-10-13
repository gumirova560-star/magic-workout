import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../models/stretch.dart';
import '../../models/workout_day.dart';
import '../../models/workout_template.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import 'replace_exercise_screen.dart';
import 'widgets/set_row.dart';
import 'widgets/rest_timer.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutTemplate template;
  final int profileId;

  const WorkoutDetailScreen({
    super.key,
    required this.template,
    required this.profileId,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  List<TemplateItem> _items = [];
  Map<int, Exercise> _exerciseMap = {};
  Map<int, Stretch> _stretchMap = {};

  int? _workoutDayId;
  bool _started = false;
  bool _loading = true;

  int? _activeRestSeconds;

  final Map<int, List<SetData>> _setsData = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  // ═══════════════════════════════════════════════════════════
  //  ЗАГРУЗКА
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadItems() async {
    setState(() => _loading = true);

    final items =
        await DatabaseHelper.instance.getTemplateItems(widget.template.id!);

    final exMap = <int, Exercise>{};
    final stMap = <int, Stretch>{};

    for (final item in items) {
      if (item.itemType == 'exercise') {
        final ex = await DatabaseHelper.instance.getExerciseById(item.itemId);
        if (ex != null) exMap[item.itemId] = ex;
      } else {
        final st = await DatabaseHelper.instance.getStretchById(item.itemId);
        if (st != null) stMap[item.itemId] = st;
      }
    }

    setState(() {
      _items = items;
      _exerciseMap = exMap;
      _stretchMap = stMap;
      _loading = false;
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  СТАРТ ТРЕНИРОВКИ
  // ═══════════════════════════════════════════════════════════

  Future<void> _startWorkout() async {
    final day = WorkoutDay(
      profileId: widget.profileId,
      templateId: widget.template.id,
      name: widget.template.name,
      type: widget.template.type,
      date: DateTime.now(),
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    final id = await DatabaseHelper.instance.createWorkoutDay(day);

    for (final item in _items) {
      final we = WorkoutExercise(
        workoutDayId: id,
        itemType: item.itemType,
        itemId: item.itemId,
        order: item.order,
        sets: item.sets,
        reps: item.reps,
        restSeconds: item.restSeconds,
        durationSeconds: item.durationSeconds,
        isCoolDown: item.isCoolDown,
      );

      final weId = await DatabaseHelper.instance.addWorkoutExercise(we);

      if (item.itemType == 'exercise' && !item.isCoolDown) {
        final sets = <SetData>[];
        for (int i = 0; i < item.sets; i++) {
          await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
            workoutExerciseId: weId,
            order: i + 1,
          ));
          sets.add(SetData());
        }
        _setsData[item.id!] = sets;
      }
    }

    setState(() {
      _workoutDayId = id;
      _started = true;
    });

    // ═══ Реакция феи ═══
    FairyReactionService().trigger('workout_started');

    _showMessage('Тренировка началась! 💪');
  }

  // ═══════════════════════════════════════════════════════════
  //  ЗАВЕРШЕНИЕ ТРЕНИРОВКИ
  // ═══════════════════════════════════════════════════════════

  Future<void> _finishWorkout() async {
    if (_workoutDayId == null) return;

    int completedSets = 0;
    for (final sets in _setsData.values) {
      for (final s in sets) {
        if (s.completed) completedSets++;
      }
    }

    if (completedSets == 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ничего не отмечено'),
          content: const Text('Вы не отметили ни одного подхода. Завершить?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Завершить')),
          ],
        ),
      );
      if (ok != true) return;
    }

    final day =
        await DatabaseHelper.instance.getWorkoutDayById(_workoutDayId!);
    if (day == null) return;

    final updated = day.copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
      durationMinutes: DateTime.now()
          .difference(day.startedAt ?? DateTime.now())
          .inMinutes,
    );

    await DatabaseHelper.instance.updateWorkoutDay(updated);

    if (!mounted) return;

    // ═══ Реакция феи ═══
    FairyReactionService().trigger('workout_completed');

    Navigator.pop(context, true);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  МЕНЮ УПРАЖНЕНИЯ
  // ═══════════════════════════════════════════════════════════

  Future<void> _openExerciseMenu(TemplateItem item, Exercise exercise) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _buildExerciseMenu(ctx, exercise),
    );

    if (result == null) return;

    switch (result) {
      case 'replace':
        await _replaceExercise(item, exercise);
        break;
      case 'edit':
        await _editExerciseParams(item);
        break;
      case 'delete':
        await _deleteExercise(item);
        break;
    }
  }

  Widget _buildExerciseMenu(BuildContext ctx, Exercise exercise) {
    final theme = Theme.of(ctx);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            exercise.name,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          _menuTile(
            ctx,
            icon: Icons.swap_horiz_rounded,
            title: 'Заменить упражнение',
            color: theme.colorScheme.primary,
            onTap: () => Navigator.pop(ctx, 'replace'),
          ),
          _menuTile(
            ctx,
            icon: Icons.tune_rounded,
            title: 'Изменить подходы и повторения',
            color: const Color(0xFF00B894),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          _menuTile(
            ctx,
            icon: Icons.delete_outline_rounded,
            title: 'Удалить из тренировки',
            color: theme.colorScheme.error,
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        leading: Icon(icon, color: color),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ЗАМЕНА
  // ═══════════════════════════════════════════════════════════

  Future<void> _replaceExercise(
      TemplateItem item, Exercise original) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _buildReasonSheet(ctx),
    );

    if (reason == null) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReplaceExerciseScreen(
          original: original,
          reasonCode: reason,
        ),
      ),
    );

    if (result == null) return;

    final newExercise = result['newExercise'] as Exercise;
    final permanent = result['permanent'] as bool;
    final reasonCode = result['reason'] as String;

    setState(() {
      _exerciseMap[newExercise.id!] = newExercise;
      final idx = _items.indexOf(item);
      if (idx >= 0) {
        _items[idx] = item.copyWith(
          itemId: newExercise.id!,
          replacedByItemId: newExercise.id,
          replacementReason: reasonCode,
          replacementPermanent: permanent,
        );
      }
    });

    _showMessage('Заменено на «${newExercise.name}»');
  }

  Widget _buildReasonSheet(BuildContext ctx) {
    final theme = Theme.of(ctx);

    final reasons = [
      ('no_equipment', 'Нет оборудования', Icons.block_rounded,
          theme.colorScheme.error),
      ('too_hard', 'Слишком тяжело', Icons.trending_down_rounded,
          const Color(0xFFE17055)),
      ('too_easy', 'Слишком легко', Icons.trending_up_rounded,
          const Color(0xFF00B894)),
      ('dislike', 'Не нравится', Icons.thumb_down_rounded,
          const Color(0xFFFDCB6E)),
      ('other', 'Другое (вручную)', Icons.search_rounded,
          theme.colorScheme.primary),
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Почему заменить?',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Приложение подберёт замену с учётом причины',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ...reasons.map((r) {
            final (code, label, icon, color) = r;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                leading: Icon(icon, color: color),
                title: Text(label),
                onTap: () => Navigator.pop(ctx, code),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ИЗМЕНЕНИЕ ПАРАМЕТРОВ
  // ═══════════════════════════════════════════════════════════

  Future<void> _editExerciseParams(TemplateItem item) async {
    final setsController = TextEditingController(text: '${item.sets}');
    final repsController = TextEditingController(text: item.reps);
    final restController =
        TextEditingController(text: '${item.restSeconds}');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить параметры'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Подходы',
                prefixIcon: Icon(Icons.repeat_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: repsController,
              decoration: const InputDecoration(
                labelText: 'Повторения (например, 10-12)',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: restController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Отдых (сек)',
                prefixIcon: Icon(Icons.timer_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final newSets = int.tryParse(setsController.text) ?? item.sets;
    final newReps = repsController.text.trim().isEmpty
        ? item.reps
        : repsController.text.trim();
    final newRest =
        int.tryParse(restController.text) ?? item.restSeconds;

    setState(() {
      final idx = _items.indexOf(item);
      if (idx >= 0) {
        _items[idx] = item.copyWith(
          sets: newSets,
          reps: newReps,
          restSeconds: newRest,
        );
      }
      _setsData[item.id!] = List.generate(newSets, (_) => SetData());
    });

    _showMessage('Параметры обновлены');
  }

  // ═══════════════════════════════════════════════════════════
  //  УДАЛЕНИЕ
  // ═══════════════════════════════════════════════════════════

  Future<void> _deleteExercise(TemplateItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить упражнение?'),
        content: const Text('Упражнение будет удалено из этой тренировки.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _items.remove(item);
      _setsData.remove(item.id);
    });

    _showMessage('Упражнение удалено');
  }

  // ═══════════════════════════════════════════════════════════
  //  UI
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
        actions: [
          if (_started)
            TextButton.icon(
              onPressed: _finishWorkout,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Завершить'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (_activeRestSeconds != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RestTimer(
                seconds: _activeRestSeconds!,
                onFinished: () => setState(() => _activeRestSeconds = null),
                onSkip: () => setState(() => _activeRestSeconds = null),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildInfoCard(context),
          ),
        ),
        if (!_started)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startWorkout,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Начать тренировку'),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildItemCard(context, _items[i]),
              childCount: _items.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final mainCount = _items.where((i) => !i.isCoolDown).length;
    final coolCount = _items.where((i) => i.isCoolDown).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _infoItem(context, Icons.fitness_center, '$mainCount', 'упражнений'),
          _infoDivider(),
          _infoItem(context, Icons.self_improvement, '$coolCount', 'заминка'),
          _infoDivider(),
          _infoItem(context, Icons.timer,
              '${widget.template.estimatedMinutes}', 'минут'),
        ],
      ),
    );
  }

  Widget _infoItem(
      BuildContext context, IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _infoDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildItemCard(BuildContext context, TemplateItem item) {
    if (item.itemType == 'exercise') {
      return _buildExerciseCard(context, item);
    } else {
      return _buildStretchCard(context, item);
    }
  }

  Widget _buildExerciseCard(BuildContext context, TemplateItem item) {
    final theme = Theme.of(context);
    final effectiveId = item.replacedByItemId ?? item.itemId;
    final ex = _exerciseMap[effectiveId];
    if (ex == null) return const SizedBox.shrink();

    _setsData.putIfAbsent(item.id!, () {
      return List.generate(item.sets, (_) => SetData());
    });

    final sets = _setsData[item.id!]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _openExerciseMenu(item, ex),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fitness_center,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          style: theme.textTheme.headlineMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.sets} подходов × ${item.reps}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ),
            if (ex.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                ex.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            for (int i = 0; i < sets.length; i++)
              SetRow(
                key: ValueKey('${item.id}_$i'),
                setNumber: i + 1,
                completed: sets[i].completed,
                initialWeight: sets[i].weight,
                initialReps: sets[i].reps,
                onChanged: (data) {
                  sets[i] = data;
                },
                onComplete: () {
                  if (_started && !item.isCoolDown) {
                    setState(
                        () => _activeRestSeconds = item.restSeconds);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStretchCard(BuildContext context, TemplateItem item) {
    final theme = Theme.of(context);
    final st = _stretchMap[item.itemId];
    if (st == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.self_improvement,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    st.name,
                    style: theme.textTheme.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${st.durationLabel}${st.bothSides ? " × 2 стороны" : ""}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00B894).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Заминка',
                style: TextStyle(
                  color: Color(0xFF00B894),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}