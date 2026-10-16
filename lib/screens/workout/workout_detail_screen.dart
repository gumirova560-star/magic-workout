import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/fairy_mood.dart';
import '../../models/exercise.dart';
import '../../models/stretch.dart';
import '../../models/workout_day.dart';
import '../../models/workout_template.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import '../../widgets/fairy_bubble.dart';
import 'replace_exercise_screen.dart';
import 'widgets/set_row.dart';
import 'widgets/rest_timer.dart';

/// Экран тренировки — 3 режима:
/// 🆕 createNew — из шаблона, ещё не начата
/// ⏳ inProgress — продолжение текущей
/// ✅ viewCompleted — просмотр завершённой + «Сохранить как шаблон»
///
/// ⚠️ Кардио — вне блоков. Показывается отдельной секцией после
///    силовых, перед заминкой.
class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutTemplate? template;
  final WorkoutDay? workoutDay;
  final int profileId;

  const WorkoutDetailScreen({
    super.key,
    this.template,
    this.workoutDay,
    required this.profileId,
  }) : assert(template != null || workoutDay != null,
            'Нужен template или workoutDay');

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  List<TemplateItem> _items = [];
  Map<int, Exercise> _exerciseMap = {};
  Map<int, Stretch> _stretchMap = {};

  int? _workoutDayId;
  bool _started = false;
  bool _completed = false;
  bool _loading = true;

  // ⚠️ Блоки включены?
  bool _hasBlocks = false;
  bool _blocksReady = false;
  final Map<int, int> _pendingBlocks = {};

  // ⚠️ Свёрнутые круги (ключи: "blockNum_circleNum")
  final Set<String> _collapsedCircles = {};

  int? _activeRestSeconds;

  final Map<int, List<SetData>> _setsData = {};
  final Map<int, List<int>> _setIds = {};
  final Map<int, int> _weIds = {};

  WorkoutDay? _day;
  UserProfile? _profile;

  bool get _isViewMode => _completed;
  bool get _isInProgressMode => _started && !_completed;
  bool get _isNewMode => !_started && !_completed;

  String get _title =>
      widget.workoutDay?.name ?? widget.template?.name ?? 'Тренировка';

  @override
  void initState() {
    super.initState();
    _day = widget.workoutDay;
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    _profile = await DatabaseHelper.instance
        .getProfileById(widget.profileId);

    if (widget.workoutDay != null) {
      await _loadExistingDay(widget.workoutDay!);
    } else {
      await _loadFromTemplate();
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  // ═══════════════════════════════════════════════════════════
  //  КАРДИО — определение
  // ═══════════════════════════════════════════════════════════

  static const List<String> _cardioWords = [
    'бег', 'дорожк', 'велотренаж', 'эллипс', 'эллиптич',
    'скакалк', 'гребл', 'ходьб', 'кардио', 'степпер',
    'treadmill', 'bike', 'rower', 'elliptical', 'jump rope',
  ];

  bool _isCardio(Exercise ex) {
    final lower = ex.name.toLowerCase();
    return _cardioWords.any((w) => lower.contains(w));
  }

  // ═══════════════════════════════════════════════════════════
  //  СВОРАЧИВАНИЕ КРУГОВ
  // ═══════════════════════════════════════════════════════════

  String _circleKey(int blockNum, int circleNum) =>
      '${blockNum}_$circleNum';

  bool _isCircleCollapsed(int blockNum, int circleNum) =>
      _collapsedCircles.contains(_circleKey(blockNum, circleNum));

  void _toggleCircle(int blockNum, int circleNum) {
    final key = _circleKey(blockNum, circleNum);
    setState(() {
      if (_collapsedCircles.contains(key)) {
        _collapsedCircles.remove(key);
      } else {
        _collapsedCircles.add(key);
      }
    });
  }

  /// ⚠️ Проверить, все ли подходы в круге выполнены.
  bool _isCircleComplete(List<TemplateItem> blockItems, int circle) {
    for (final item in blockItems) {
      final sets = _setsData[item.id!];
      if (sets == null) return false;
      if (circle >= sets.length) continue;
      if (!sets[circle].completed) return false;
    }
    return true;
  }

  /// ⚠️ Количество выполненных подходов в круге.
  int _completedInCircle(List<TemplateItem> blockItems, int circle) {
    int count = 0;
    for (final item in blockItems) {
      final sets = _setsData[item.id!];
      if (sets == null) continue;
      if (circle >= sets.length) continue;
      if (sets[circle].completed) count++;
    }
    return count;
  }

  // ═══════════════════════════════════════════════════════════
  //  ЗАГРУЗКА ИЗ ШАБЛОНА
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadFromTemplate() async {
    final items = await DatabaseHelper.instance
        .getTemplateItems(widget.template!.id!);

    final exMap = <int, Exercise>{};
    final stMap = <int, Stretch>{};

    for (final item in items) {
      if (item.itemType == 'exercise') {
        final ex =
            await DatabaseHelper.instance.getExerciseById(item.itemId);
        if (ex != null) exMap[item.itemId] = ex;
      } else {
        final st =
            await DatabaseHelper.instance.getStretchById(item.itemId);
        if (st != null) stMap[item.itemId] = st;
      }
    }

    _items = items;
    _exerciseMap = exMap;
    _stretchMap = stMap;

    for (final item in items) {
      if (item.id == null) continue;
      if (item.itemType == 'exercise' && !item.isCoolDown) {
        final ex = exMap[item.replacedByItemId ?? item.itemId];
        final isCardio = ex != null && _isCardio(ex);

        // ⚠️ Для кардио — 1 подход с 5 мин
        final setsCount = isCardio ? 1 : item.sets;
        final defaultReps = isCardio ? 5 : _parseReps(item.reps);

        _setsData[item.id!] = List.generate(
          setsCount,
          (_) => SetData(reps: defaultReps),
        );
      } else if (item.isCoolDown) {
        _setsData[item.id!] = [SetData()];
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ЗАГРУЗКА ИЗ БД (существующий день)
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadExistingDay(WorkoutDay day) async {
    _workoutDayId = day.id;
    _completed = day.status == 'completed';
    _started = day.status == 'completed' || day.status == 'in_progress';

    final workoutExs = await DatabaseHelper.instance
        .getWorkoutExercises(day.id!);

    _hasBlocks = workoutExs.any((we) => we.blockNumber != null);

    _pendingBlocks.clear();
    for (int i = 0; i < workoutExs.length; i++) {
      final bn = workoutExs[i].blockNumber;
      if (bn != null) {
        _pendingBlocks[i] = bn;
      }
    }

    final items = <TemplateItem>[];
    final exMap = <int, Exercise>{};
    final stMap = <int, Stretch>{};

    for (final we in workoutExs) {
      final item = TemplateItem(
        id: we.id,
        templateId: day.templateId ?? 0,
        itemType: we.itemType,
        itemId: we.itemId,
        order: we.order,
        sets: we.sets,
        reps: we.reps,
        restSeconds: we.restSeconds,
        durationSeconds: we.durationSeconds,
        isCoolDown: we.isCoolDown,
        replacedByItemId: we.replacedByItemId,
        replacementReason: we.replacementReason,
        replacementPermanent: we.replacementPermanent,
      );
      items.add(item);

      if (we.itemType == 'exercise') {
        final effId = we.replacedByItemId ?? we.itemId;
        final ex = await DatabaseHelper.instance.getExerciseById(effId);
        if (ex != null) exMap[effId] = ex;
      } else {
        final st = await DatabaseHelper.instance.getStretchById(we.itemId);
        if (st != null) stMap[we.itemId] = st;
      }
    }

    final setsData = <int, List<SetData>>{};
    final setIds = <int, List<int>>{};
    final weIds = <int, int>{};

    for (final item in items) {
      if (item.id == null) continue;
      final sets =
          await DatabaseHelper.instance.getWorkoutSets(item.id!);

      final list = <SetData>[];
      final ids = <int>[];
      for (final s in sets) {
        list.add(SetData(
          weight: s.weight,
          reps: s.reps,
          completed: s.completed,
        ));
        ids.add(s.id!);
      }

      setsData[item.id!] = list;
      setIds[item.id!] = ids;
      weIds[item.id!] = item.id!;
    }

    _items = items;
    _exerciseMap = exMap;
    _stretchMap = stMap;
    _setsData.addAll(setsData);
    _setIds.addAll(setIds);
    _weIds.addAll(weIds);
  }

  int? _parseReps(String repsStr) {
    final match = RegExp(r'(\d+)(?:-(\d+))?').firstMatch(repsStr);
    if (match == null) return null;
    final high = match.group(2);
    if (high != null) return int.tryParse(high);
    return int.tryParse(match.group(1) ?? '');
  }

  // ═══════════════════════════════════════════════════════════
  //  ПРОГРЕССИЯ ПО ЦЕЛИ
  // ═══════════════════════════════════════════════════════════

  Future<double?> _computeRecommendedWeight({
    required int exerciseId,
    required String targetRepsStr,
    required String goal,
  }) async {
    final sets = await DatabaseHelper.instance.getLastWorkoutExerciseSets(
      profileId: widget.profileId,
      exerciseId: exerciseId,
    );

    if (sets.isEmpty) return null;

    final targetReps = _parseReps(targetRepsStr) ?? 12;
    final allDone = sets.every((s) => (s.reps ?? 0) >= targetReps);

    final lastWeight = sets
            .map((s) => s.weight)
            .whereType<double>()
            .firstOrNull ??
        0.0;

    if (lastWeight <= 0) return null;

    switch (goal) {
      case 'strength':
        return allDone ? lastWeight + 2.5 : lastWeight;
      case 'gain_mass':
        return allDone ? lastWeight + 1.0 : lastWeight;
      case 'lose_weight':
      case 'tone':
      default:
        return lastWeight;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  БЛОКИ — создание/сброс ДО старта
  // ═══════════════════════════════════════════════════════════

  /// ⚠️ Кардио НЕ попадает в блоки — оно отдельно, после.
  void _createBlocks() {
    _pendingBlocks.clear();
    _collapsedCircles.clear();

    int blockNum = 1;
    int countInBlock = 0;

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isCoolDown) continue;

      // ⚠️ Кардио — вне блоков
      final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
      final isCardio = ex != null && _isCardio(ex);
      if (isCardio) continue;

      if (countInBlock >= 3) {
        blockNum++;
        countInBlock = 0;
      }
      countInBlock++;

      _pendingBlocks[i] = blockNum;
    }

    setState(() {
      _blocksReady = true;
      _hasBlocks = true;
    });

    _showMessage('Сформировано блоков: $blockNum');
  }

  void _resetBlocks() {
    setState(() {
      _pendingBlocks.clear();
      _blocksReady = false;
      _hasBlocks = false;
      _collapsedCircles.clear();
    });
    _showMessage('Блоки сброшены');
  }

  // ═══════════════════════════════════════════════════════════
  //  БЛОКИ — включение/выключение (после старта, в БД)
  // ═══════════════════════════════════════════════════════════

  /// ⚠️ Кардио получает `blockNumber = null` — оно вне блоков.
  Future<void> _toggleBlocks() async {
    if (_workoutDayId == null) return;

    if (_hasBlocks) {
      await DatabaseHelper.instance.clearBlocksForWorkoutDay(
        _workoutDayId!,
      );
      if (!mounted) return;
      setState(() {
        _hasBlocks = false;
        _collapsedCircles.clear();
      });
      _showMessage('Блоки убраны');
    } else {
      int blockNum = 1;
      int countInBlock = 0;

      for (final item in _items) {
        if (item.id == null) continue;
        if (item.isCoolDown) continue;

        // ⚠️ Кардио — вне блоков
        final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
        final isCardio = ex != null && _isCardio(ex);
        if (isCardio) {
          await DatabaseHelper.instance.updateWorkoutExerciseBlock(
            id: item.id!,
            blockNumber: null,
          );
          continue;
        }

        if (countInBlock >= 3) {
          blockNum++;
          countInBlock = 0;
        }
        countInBlock++;

        await DatabaseHelper.instance.updateWorkoutExerciseBlock(
          id: item.id!,
          blockNumber: blockNum,
        );
      }

      if (!mounted) return;
      setState(() => _hasBlocks = true);
      _showMessage('Сформировано блоков: $blockNum');
    }
  }

// ═══ ЧАСТЬ 1 — КОНЕЦ ═══
  // ═══════════════════════════════════════════════════════════
  //  СТАРТ ТРЕНИРОВКИ
  // ═══════════════════════════════════════════════════════════

  Future<void> _startWorkout() async {
    if (_workoutDayId != null) return;

    final day = WorkoutDay(
      profileId: widget.profileId,
      templateId: widget.template?.id,
      name: widget.template?.name ?? 'Тренировка',
      type: widget.template?.type ?? 'strength',
      date: DateTime.now(),
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    final id = await DatabaseHelper.instance.createWorkoutDay(day);
    _workoutDayId = id;

    for (int idx = 0; idx < _items.length; idx++) {
      final item = _items[idx];
      final blockNumber = _blocksReady ? _pendingBlocks[idx] : null;

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
        blockNumber: blockNumber,
      );

      final weId = await DatabaseHelper.instance.addWorkoutExercise(we);

      if (item.id != null) _weIds[item.id!] = weId;

      if (item.itemType == 'exercise' && !item.isCoolDown) {
        final sets = <SetData>[];
        final ids = <int>[];

        final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
        final isCardio = ex != null && _isCardio(ex);

        final defaultReps = isCardio ? 5 : _parseReps(item.reps);
        final setsCount = isCardio ? 1 : item.sets;

        final effectiveId = item.replacedByItemId ?? item.itemId;
        final goal = _profile?.goal ?? 'tone';
        final recommendedWeight = isCardio
            ? null
            : await _computeRecommendedWeight(
                exerciseId: effectiveId,
                targetRepsStr: item.reps,
                goal: goal,
              );

        for (int i = 0; i < setsCount; i++) {
          final setId = await DatabaseHelper.instance.addWorkoutSet(
            WorkoutSet(
              workoutExerciseId: weId,
              order: i + 1,
              weight: recommendedWeight,
              reps: defaultReps,
              completed: false,
            ),
          );
          ids.add(setId);
          sets.add(SetData(
            weight: recommendedWeight,
            reps: defaultReps,
            completed: false,
          ));
        }

        if (item.id != null) {
          _setsData[item.id!] = sets;
          _setIds[item.id!] = ids;
        }
      } else if (item.isCoolDown) {
        final setId = await DatabaseHelper.instance.addWorkoutSet(
          WorkoutSet(
            workoutExerciseId: weId,
            order: 1,
            completed: false,
          ),
        );

        if (item.id != null) {
          _setsData[item.id!] = [SetData(completed: false)];
          _setIds[item.id!] = [setId];
        }
      }
    }

    if (!mounted) return;
    setState(() => _started = true);

    FairyReactionService().trigger(
      'workout_started',
      mood: FairyMood.wink,
    );

    _showMessage('Тренировка началась! 💪');
  }

  // ═══════════════════════════════════════════════════════════
  //  ЗАВЕРШЕНИЕ — пересчёт статуса по семам
  // ═══════════════════════════════════════════════════════════

  Future<void> _finishWorkout() async {
    if (_workoutDayId == null) return;

    int completedSets = 0;
    int totalSets = 0;
    for (final sets in _setsData.values) {
      for (final s in sets) {
        totalSets++;
        if (s.completed) completedSets++;
      }
    }

    if (completedSets == 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ничего не отмечено'),
          content: const Text(
              'Вы не отметили ни одного подхода. Завершить всё равно?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Завершить'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final day =
        await DatabaseHelper.instance.getWorkoutDayById(_workoutDayId!);
    if (day == null) return;

    final minutes = DateTime.now()
        .difference(day.startedAt ?? DateTime.now())
        .inMinutes;

    // ⚠️ Статус:
    //    все подходы отмечены → 'completed'
    //    иначе → 'in_progress' (можно вернуться и доделать)
    final isFullyDone = totalSets > 0 && completedSets == totalSets;
    final newStatus = isFullyDone ? 'completed' : 'in_progress';

    final updated = day.copyWith(
      status: newStatus,
      completedAt: isFullyDone ? DateTime.now() : null,
      durationMinutes: minutes > 0 ? minutes : 1,
    );

    await DatabaseHelper.instance.updateWorkoutDay(updated);

    if (!mounted) return;

    // ⚠️ Фея: только на полное завершение
    if (isFullyDone) {
      FairyReactionService().trigger(
        'workout_completed',
        mood: FairyMood.party,
      );
      await Future.delayed(const Duration(milliseconds: 900));
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ═══════════════════════════════════════════════════════════
  //  СОХРАНИТЬ КАК ШАБЛОН
  // ═══════════════════════════════════════════════════════════

  Future<void> _saveAsTemplate() async {
    if (_day == null || _day!.id == null) return;

    if (_items.isEmpty) {
      _showMessage('Нечего сохранять — нет упражнений');
      return;
    }

    final nameController = TextEditingController(
      text: _day!.name,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.bookmark_add_rounded),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Сохранить как шаблон',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Создаст шаблон с этими упражнениями. Позже '
              'сможете начать по нему новую тренировку.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название шаблона',
                prefixIcon: Icon(Icons.fitness_center_rounded),
                hintText: 'Например: Моя силовая A',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final templateName = nameController.text.trim().isEmpty
        ? _day!.name
        : nameController.text.trim();

    try {
      await DatabaseHelper.instance.createTemplateFromWorkoutDay(
        profileId: widget.profileId,
        workoutDayId: _day!.id!,
        templateName: templateName,
        type: _day!.type,
        estimatedMinutes: _day!.durationMinutes ?? 45,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Шаблон «$templateName» сохранён'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Ошибка: $e');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  МЕНЮ УПРАЖНЕНИЯ
  // ═══════════════════════════════════════════════════════════

  Future<void> _openExerciseMenu(
      TemplateItem item, Exercise exercise) async {
    if (_isViewMode) return;

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
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Theme.of(ctx)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.1),
            ),
          ),
          leading: Icon(icon, color: color),
          title: Text(title),
          onTap: onTap,
        ),
      ),
    );
  }

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
              child: Material(
                color: Colors.transparent,
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
              ),
            );
          }),
        ],
      ),
    );
  }

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

    final defaultReps = _parseReps(newReps);

    setState(() {
      final idx = _items.indexOf(item);
      if (idx >= 0) {
        _items[idx] = item.copyWith(
          sets: newSets,
          reps: newReps,
          restSeconds: newRest,
        );
      }
      if (item.id != null) {
        _setsData[item.id!] =
            List.generate(newSets, (_) => SetData(reps: defaultReps));
      }
    });

    _showMessage('Параметры обновлены');
  }

  // ═══════════════════════════════════════════════════════════
  //  ДОБАВЛЕНИЕ ПОДХОДА
  // ═══════════════════════════════════════════════════════════

  Future<void> _addSetToExercise(TemplateItem item) async {
    if (item.id == null) return;

    if (!_started) {
      _showMessage('Сначала начните тренировку');
      return;
    }
    if (_isViewMode) return;

    final sets = _setsData[item.id!];
    final ids = _setIds[item.id!];
    final weId = _weIds[item.id!];

    if (sets == null || ids == null || weId == null) return;

    final newOrder = sets.length + 1;
    final defaultReps = _parseReps(item.reps);

    final newSetId = await DatabaseHelper.instance.addWorkoutSet(
      WorkoutSet(
        workoutExerciseId: weId,
        order: newOrder,
        reps: defaultReps,
        completed: false,
      ),
    );

    if (!mounted) return;
    setState(() {
      sets.add(SetData(reps: defaultReps, completed: false));
      ids.add(newSetId);
    });

    _showMessage('Подход $newOrder добавлен');
  }

  // ═══════════════════════════════════════════════════════════
  //  УДАЛЕНИЕ ПОДХОДА
  // ═══════════════════════════════════════════════════════════

  Future<void> _deleteSetFromExercise(TemplateItem item, int index) async {
    if (item.id == null) return;
    if (_isViewMode) return;

    final sets = _setsData[item.id!];
    final ids = _setIds[item.id!];

    if (sets == null || ids == null) return;
    if (index < 0 || index >= sets.length) return;
    if (sets.length <= 1) {
      _showMessage('Нельзя удалить последний подход');
      return;
    }

    final setId = ids[index];

    if (setId > 0) {
      await DatabaseHelper.instance.deleteWorkoutSet(setId);
    }

    if (!mounted) return;
    setState(() {
      sets.removeAt(index);
      ids.removeAt(index);
    });

    _showMessage('Подход удалён');
  }

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
      _setIds.remove(item.id);
      _weIds.remove(item.id);
    });

    _showMessage('Упражнение удалено');
  }

  Future<void> _startStretchTimer(TemplateItem item, Stretch st) async {
    if (_isViewMode) return;
    if (!_started) {
      _showMessage('Сначала начните тренировку');
      return;
    }
    if (item.id == null) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StretchTimerDialog(
        name: st.name,
        totalSeconds: st.durationSeconds,
        bothSides: st.bothSides,
      ),
    );

    if (result != true) return;
    if (!mounted) return;

    final ids = _setIds[item.id!];
    final weId = _weIds[item.id!];
    if (ids != null && weId != null && ids.isNotEmpty) {
      await DatabaseHelper.instance.updateWorkoutSet(
        WorkoutSet(
          id: ids.first,
          workoutExerciseId: weId,
          order: 1,
          completed: true,
        ),
      );
    }

    setState(() {
      _setsData[item.id!] = [SetData(completed: true)];
    });

    _showMessage('Заминка выполнена ✓');
  }

// ═══ ЧАСТЬ 2 — КОНЕЦ ═══
  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_started)
            IconButton(
              tooltip: _hasBlocks
                  ? 'Убрать блоки'
                  : 'Сформировать блоки по 3',
              onPressed: _isViewMode ? null : _toggleBlocks,
              icon: Icon(
                _hasBlocks
                    ? Icons.grid_off_rounded
                    : Icons.grid_view_rounded,
                color: _hasBlocks
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),

          if (_isInProgressMode)
            TextButton.icon(
              onPressed: _finishWorkout,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Завершить'),
            ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(context),
          const FairyBubble(screenKey: 'workout_detail'),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (_isViewMode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  _buildCompletedBanner(context),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveAsTemplate,
                      icon: const Icon(Icons.bookmark_add_rounded),
                      label: const Text('Сохранить как шаблон'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

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

        if (_isNewMode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _blocksReady ? null : _createBlocks,
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: Text(
                        _blocksReady ? 'Блоки созданы' : 'Создать блоки',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _blocksReady ? _resetBlocks : null,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Сбросить',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (_isNewMode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
              ),
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

        // ═══ Список упражнений ═══
        if (_hasBlocks)
          ..._buildCircuitsSlivers(context)
        else
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

  // ═══════════════════════════════════════════════════════════
  //  ПЕРЕГРУППИРОВКА ПО КРУГАМ (блоки включены)
  //
  //  ⚠️ Кардио (без blockNumber) идёт в `unassigned` —
  //     показывается отдельной секцией «Кардио» ПОСЛЕ блоков,
  //     перед заминкой.
  // ═══════════════════════════════════════════════════════════

  List<Widget> _buildCircuitsSlivers(BuildContext context) {
    final slivers = <Widget>[];

    final Map<int, List<TemplateItem>> blocks = {};
    final List<TemplateItem> unassigned = []; // ⚠️ кардио и прочее

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isCoolDown) continue;

      final blockNum = _pendingBlocks[i];

      // ⚠️ Если blockNumber не задан → показываем после блоков
      if (blockNum == null) {
        unassigned.add(item);
        continue;
      }

      blocks.putIfAbsent(blockNum, () => []);
      blocks[blockNum]!.add(item);
    }

    final coolDowns = _items.where((i) => i.isCoolDown).toList();

    final sortedBlocks = blocks.keys.toList()..sort();

    for (final blockNum in sortedBlocks) {
      final blockItems = blocks[blockNum]!;

      // ⚠️ Количество кругов = макс. подходов среди упражнений блока
      int maxCircles = 1;
      for (final item in blockItems) {
        final sets = _setsData[item.id!] ?? [];
        if (sets.length > maxCircles) maxCircles = sets.length;
      }

      for (int circle = 0; circle < maxCircles; circle++) {
        final circleNum = circle + 1;
        final isComplete =
            _isCircleComplete(blockItems, circle) && _started;
        final completed =
            _completedInCircle(blockItems, circle);
        final total = blockItems.length;
        final isCollapsed = _isCircleCollapsed(blockNum, circleNum);

        // ⚠️ Авто-сворачивание при завершении
        if (isComplete && !isCollapsed) {
          _collapsedCircles.add(_circleKey(blockNum, circleNum));
        }

        // ⚠️ Заголовок
        slivers.add(
          SliverToBoxAdapter(
            child: _buildCircleHeader(
              blockNum: blockNum,
              circleNum: circleNum,
              completed: completed,
              total: total,
              isComplete: isComplete,
              isCollapsed: isCollapsed,
              onToggle: () => _toggleCircle(blockNum, circleNum),
            ),
          ),
        );

        // ⚠️ Упражнения (только если не свёрнуто)
        if (!isCollapsed) {
          slivers.add(
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = blockItems[i];
                    return _buildExerciseCard(
                      context,
                      item,
                      circleIndex: circle,
                    );
                  },
                  childCount: blockItems.length,
                ),
              ),
            ),
          );
        }
      }
    }

    // ⚠️ Кардио и прочее вне блоков — после блоков, перед заминкой
    if (unassigned.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE17055).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Кардио',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFFE17055),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildItemCard(context, unassigned[i]),
              childCount: unassigned.length,
            ),
          ),
        ),
      );
    }

    // ⚠️ Заминка — отдельно
    if (coolDowns.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Заминка',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF00B894),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildStretchCard(context, coolDowns[i]),
              childCount: coolDowns.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  /// ⚠️ Заголовок «БЛОК N — КРУГ M · X/Y» с кнопкой ▼/▲.
  Widget _buildCircleHeader({
    required int blockNum,
    required int circleNum,
    required int completed,
    required int total,
    required bool isComplete,
    required bool isCollapsed,
    required VoidCallback onToggle,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isComplete
                ? const LinearGradient(
                    colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle_rounded
                    : Icons.fitness_center,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'БЛОК $blockNum — КРУГ $circleNum · $completed/$total',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),

              Icon(
                isCollapsed
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  БАННЕР «ЗАВЕРШЕНА»
  // ═══════════════════════════════════════════════════════════

  Widget _buildCompletedBanner(BuildContext context) {
    final day = _day;

    final months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];

    final dateStr = day != null
        ? '${day.date.day} ${months[day.date.month - 1]} ${day.date.year}'
        : '';

    final minutes = day?.durationMinutes ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B894).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Тренировка завершена ✓',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · $minutes мин',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ИНФО-КАРТОЧКА
  // ═══════════════════════════════════════════════════════════

  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final mainCount = _items.where((i) => !i.isCoolDown).length;

    int completedSets = 0;
    int totalSets = 0;
    for (final sets in _setsData.values) {
      for (final s in sets) {
        totalSets++;
        if (s.completed) completedSets++;
      }
    }

    final minutesText = _isViewMode
        ? '${_day?.durationMinutes ?? 0}'
        : '${widget.template?.estimatedMinutes ?? 0}';

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
          _infoItem(
              context, Icons.fitness_center, '$mainCount', 'упражнений'),
          _infoDivider(),
          _infoItem(context, Icons.check_circle_rounded,
              '$completedSets/$totalSets', 'подходов'),
          _infoDivider(),
          _infoItem(context, Icons.timer, minutesText, 'минут'),
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

// ═══ ЧАСТЬ 3 — КОНЕЦ ═══
  // ═══════════════════════════════════════════════════════════
  //  КАРТОЧКИ УПРАЖНЕНИЙ
  // ═══════════════════════════════════════════════════════════

  Widget _buildItemCard(BuildContext context, TemplateItem item) {
    if (item.itemType == 'exercise') {
      return _buildExerciseCard(context, item);
    } else {
      return _buildStretchCard(context, item);
    }
  }

  /// ⚠️ Карточка упражнения.
  /// `circleIndex` — если задан, показываем ТОЛЬКО один подход.
  Widget _buildExerciseCard(
    BuildContext context,
    TemplateItem item, {
    int? circleIndex,
  }) {
    final theme = Theme.of(context);
    final effectiveId = item.replacedByItemId ?? item.itemId;
    final ex = _exerciseMap[effectiveId];
    if (ex == null) return const SizedBox.shrink();

    final isCardio = _isCardio(ex);
    final defaultReps = _parseReps(item.reps);

    _setsData.putIfAbsent(item.id!, () {
      return List.generate(
        item.sets,
        (_) => SetData(reps: defaultReps),
      );
    });

    final sets = _setsData[item.id!]!;

    // ⚠️ Определяем, какие подходы показывать
    final List<int> setIndexesToShow;
    if (circleIndex != null) {
      if (circleIndex < sets.length) {
        setIndexesToShow = [circleIndex];
      } else {
        setIndexesToShow = [];
      }
    } else {
      setIndexesToShow = List.generate(sets.length, (i) => i);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _isViewMode || circleIndex != null
                  ? null
                  : () => _openExerciseMenu(item, ex),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCardio
                            ? const [Color(0xFFE17055), Color(0xFFFAB1A0)]
                            : const [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCardio
                          ? Icons.directions_run_rounded
                          : Icons.fitness_center,
                      color: Colors.white,
                      size: 22,
                    ),
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
                          circleIndex != null
                              ? 'Подход ${circleIndex + 1} из ${sets.length}'
                              : isCardio
                                  ? 'Кардио · 5-10 мин'
                                  : '${item.sets} подходов × ${item.reps}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isViewMode && circleIndex == null)
                    Icon(
                      Icons.more_vert_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                ],
              ),
            ),
            if (ex.description.isNotEmpty && circleIndex == null) ...[
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
            for (final i in setIndexesToShow)
              SetRow(
                key: ValueKey('${item.id}_$i'),
                setNumber: i + 1,
                completed: sets[i].completed,
                initialWeight: sets[i].weight,
                initialReps: sets[i].reps ?? defaultReps,
                readOnly: _isViewMode,
                isCardio: isCardio,
                onChanged: (data) async {
                  if (item.id == null || _isViewMode) return;
                  setState(() => sets[i] = data);

                  final ids = _setIds[item.id!];
                  final weId = _weIds[item.id!];
                  if (ids != null && weId != null && i < ids.length) {
                    await DatabaseHelper.instance.updateWorkoutSet(
                      WorkoutSet(
                        id: ids[i],
                        workoutExerciseId: weId,
                        order: i + 1,
                        weight: data.weight,
                        reps: data.reps,
                        completed: data.completed,
                      ),
                    );
                  }

                  // ⚠️ Авто-сворачивание круга
                  if (circleIndex != null && item.id != null) {
                    _tryAutoCollapse(item, circleIndex);
                  }
                },
                onComplete: () {
                  if (_started && !_isViewMode && !item.isCoolDown) {
                    setState(
                        () => _activeRestSeconds = item.restSeconds);
                  }

                  // ⚠️ Авто-сворачивание круга
                  if (circleIndex != null && item.id != null) {
                    _tryAutoCollapse(item, circleIndex);
                  }
                },
                onDelete: circleIndex == null
                    ? () => _deleteSetFromExercise(item, i)
                    : null,
              ),

            // ⚠️ Кнопка «+ Добавить подход» (только в обычном режиме)
            if (!_isViewMode && _started && circleIndex == null && !isCardio)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addSetToExercise(item),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Добавить подход'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ⚠️ Попытка авто-свернуть круг, если всё выполнено.
  void _tryAutoCollapse(TemplateItem item, int circleIndex) {
    if (!_hasBlocks) return;

    final idx = _items.indexOf(item);
    if (idx < 0) return;

    final blockNum = _pendingBlocks[idx] ?? 1;

    // ⚠️ Собираем items этого блока
    final blockItems = <TemplateItem>[];
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].isCoolDown) continue;
      if ((_pendingBlocks[i] ?? 1) != blockNum) continue;
      blockItems.add(_items[i]);
    }

    // ⚠️ Проверяем, всё ли выполнено
    if (_isCircleComplete(blockItems, circleIndex) && _started) {
      final key = _circleKey(blockNum, circleIndex + 1);
      if (!_collapsedCircles.contains(key)) {
        setState(() => _collapsedCircles.add(key));
      }
    }
  }

  Widget _buildStretchCard(BuildContext context, TemplateItem item) {
    final theme = Theme.of(context);
    final st = _stretchMap[item.itemId];
    if (st == null) return const SizedBox.shrink();

    final sets = _setsData[item.id!] ?? [SetData(completed: false)];
    final isDone = sets.isNotEmpty && sets.first.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: (_started && !_isViewMode)
            ? () => _startStretchTimer(item, st)
            : null,
        borderRadius: BorderRadius.circular(12),
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
                child: Icon(
                  isDone
                      ? Icons.check_rounded
                      : Icons.self_improvement,
                  color: Colors.white,
                  size: 22,
                ),
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
              if (isDone)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00B894),
                    size: 20,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ДИАЛОГ ТАЙМЕРА ДЛЯ ЗАМИНКИ
// ═══════════════════════════════════════════════════════════

class _StretchTimerDialog extends StatefulWidget {
  final String name;
  final int totalSeconds;
  final bool bothSides;

  const _StretchTimerDialog({
    required this.name,
    required this.totalSeconds,
    required this.bothSides,
  });

  @override
  State<_StretchTimerDialog> createState() => _StretchTimerDialogState();
}

class _StretchTimerDialogState extends State<_StretchTimerDialog> {
  late int _remaining;
  Timer? _timer;
  bool _finished = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_paused) return;

      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        setState(() => _finished = true);
        t.cancel();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.totalSeconds > 0
        ? _remaining / widget.totalSeconds
        : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.name,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(
                        _finished
                            ? const Color(0xFF00B894)
                            : _paused
                                ? const Color(0xFFFDCB6E)
                                : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    _finished ? '✓' : '$_remaining',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _finished
                          ? const Color(0xFF00B894)
                          : _paused
                              ? const Color(0xFFFDCB6E)
                              : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_paused && !_finished)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⏸ Пауза',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFDCB6E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (widget.bothSides && !_finished)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Выполните для обеих сторон',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (!_finished)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _togglePause,
                  icon: Icon(
                    _paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 22,
                  ),
                  label: Text(_paused ? 'Продолжить' : 'Пауза'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _paused
                        ? theme.colorScheme.primary
                        : const Color(0xFFFDCB6E),
                    side: BorderSide(
                      color: _paused
                          ? theme.colorScheme.primary.withOpacity(0.5)
                          : const Color(0xFFFDCB6E).withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (!_finished) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _finished
                          ? const Color(0xFF00B894)
                          : theme.colorScheme.primary,
                    ),
                    child: Text(_finished ? 'Готово ✓' : 'Завершить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// ═══ ЧАСТЬ 4 — КОНЕЦ ═══
// ═══ ФАЙЛ workout_detail_screen.dart ЗАВЕРШЁН ═══