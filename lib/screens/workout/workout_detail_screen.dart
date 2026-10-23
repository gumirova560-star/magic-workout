import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/fairy_mood.dart';
import '../../models/exercise.dart';
import '../../models/stretch.dart';
import '../../models/workout_day.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import '../../services/achievement_service.dart';
import '../../services/progression_service.dart';
import 'replace_exercise_screen.dart';
import 'widgets/set_row.dart';
import '../exercise/exercise_detail_screen.dart';
import '../exercise/stretch_detail_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutDay? workoutDay;
  final int profileId;

  const WorkoutDetailScreen({super.key, this.workoutDay, required this.profileId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  static const List<List<Color>> _blockPalettes = [
    [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
    [Color(0xFFE17055), Color(0xFFFAB1A0)],
    [Color(0xFFE84393), Color(0xFFFD79A8)],
    [Color(0xFF0984E3), Color(0xFF74B9FF)],
    [Color(0xFFFDCB6E), Color(0xFFF9E79F)],
  ];

  List<WorkoutExercise> _items = [];
  Map<int, Exercise> _exerciseMap = {};
  Map<int, Stretch> _stretchMap = {};

  int? _workoutDayId;
  bool _started = false;
  bool _completed = false;
  bool _loading = true;

  bool _hasBlocks = false;
  bool _blocksReady = false;
  final Map<int, int> _pendingBlocks = {};

  final Set<String> _collapsedCircles = {};
  final Set<int> _exercisesWithHistory = {};

  int _globalRestSeconds = 60;

  final Map<int, List<SetData>> _setsData = {};
  final Map<int, List<int>> _setIds = {};
  final Map<int, double?> _targetWeights = {};

  WorkoutDay? _day;
  UserProfile? _profile;

  Timer? _restTimer;
  int _restTimeLeft = 0;
  int _restTotalTime = 0;
  bool _isRestTimerRunning = false;
  bool _isRestTimerPaused = false;

  bool get _isViewMode => _completed;
  bool get _isInProgressMode => _started && !_completed;
  bool get _isNewMode => !_started && !_completed;

  String get _title => _day?.name ?? 'Тренировка';

  @override
  void initState() {
    super.initState();
    _day = widget.workoutDay;
    _loadSavedRestTime();
    _init();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedRestTime() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('global_rest_seconds');
    if (saved != null && mounted) setState(() => _globalRestSeconds = saved);
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    _profile = await DatabaseHelper.instance.getProfileById(widget.profileId);

    if (widget.workoutDay != null) {
      await _loadExistingDay(widget.workoutDay!);
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _preloadHistory();
    _showWeekNotification();
  }

  bool _isCardio(Exercise ex) {
    final lower = ex.name.toLowerCase();

    if (lower.contains('бег') || lower.contains('дорожк') || lower.contains('скакалк') ||
        lower.contains('эллипс') || lower.contains('велотренаж') || lower.contains('велоэргометр') ||
        lower.contains('гребл') || lower.contains('степпер') || lower.contains('кардио') ||
        lower.contains('канат') || lower.contains('скалолаз')) {
      return true;
    }

    final coreGroups = ['abs', 'core', 'obliques'];
    if (ex.muscleGroups.any((m) => coreGroups.contains(m))) return false;

    return ex.muscleGroups.contains('cardio');
  }

  bool _isTimed(String name) {
    final lower = name.toLowerCase();
    return lower.contains('планка') || lower.contains('plank') || _isCardioName(lower) ||
           lower.contains('канат') || lower.contains('скалолаз');
  }

  bool _isCardioName(String lowerName) {
    return lowerName.contains('бег') || lowerName.contains('дорожк') || lowerName.contains('скакалк') ||
        lowerName.contains('эллипс') || lowerName.contains('велотренаж') || lowerName.contains('велоэргометр') ||
        lowerName.contains('гребл') || lowerName.contains('степпер') || lowerName.contains('кардио');
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restTotalTime = _globalRestSeconds;
      _restTimeLeft = _globalRestSeconds;
      _isRestTimerRunning = true;
      _isRestTimerPaused = false;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isRestTimerPaused) return;
      if (_restTimeLeft > 0) setState(() => _restTimeLeft--);
      else _stopRestTimer();
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isRestTimerRunning = false;
      _isRestTimerPaused = false;
    });
  }

  void _togglePauseRestTimer() => setState(() => _isRestTimerPaused = !_isRestTimerPaused);

  Future<({String status, List<String> weightFails, List<String> repsFails})> _analyzePrevWeek(int prevWeekNum) async {
    final prevDays = await DatabaseHelper.instance.getWorkoutDaysByWeek(
      profileId: widget.profileId,
      weekNumber: prevWeekNum,
      cycleNumber: _day?.cycleNumber,
    );

    if (prevDays.isEmpty) return (status: 'empty', weightFails: [], repsFails: []);

    bool weightFailed = false;
    bool repsFailed = false;
    bool allPerfect = true;
    final List<String> weightFails = [];
    final List<String> repsFails = [];

    for (final day in prevDays) {
      if (day.status != 'completed') {
        allPerfect = false;
        continue;
      }
      final exs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
      for (final we in exs) {
        if (we.itemType != 'exercise' || we.isCoolDown) continue;

        final ex = await DatabaseHelper.instance.getExerciseById(we.replacedByItemId ?? we.itemId);
        final exName = ex?.name ?? 'Упражнение';

        final sets = await DatabaseHelper.instance.getWorkoutSets(we.id!);
        final completed = sets.where((s) => s.completed).toList();
        if (completed.isEmpty) {
          repsFailed = true;
          allPerfect = false;
          if (!repsFails.contains(exName)) repsFails.add(exName);
          continue;
        }

        final targetReps = _parseReps(we.reps) ?? 0;
        final avgReps = completed.map((s) => s.reps ?? 0).reduce((a, b) => a + b) / completed.length;
        if (avgReps < (targetReps * 0.8)) {
          repsFailed = true;
          allPerfect = false;
          if (!repsFails.contains(exName)) repsFails.add(exName);
        }

        final maxWeight = completed.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
        if (maxWeight > 0) {
          final avgWeight = completed.map((s) => s.weight ?? 0).reduce((a, b) => a + b) / completed.length;
          if (avgWeight < (maxWeight * 0.95)) {
             weightFailed = true;
             allPerfect = false;
             if (!weightFails.contains(exName)) weightFails.add(exName);
          }
        }
      }
    }

    String status = 'partial';
    if (allPerfect && prevDays.every((d) => d.status == 'completed')) status = 'perfect';
    else if (weightFailed) status = 'weight_failed';
    else if (repsFailed) status = 'reps_failed';

    return (status: status, weightFails: weightFails, repsFails: repsFails);
  }

  Future<void> _showWeekNotification() async {
    final week = _day?.weekNumber;
    if (week == null || week == 1 || _started || _completed) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'week${week}_notified_${widget.profileId}_${_day?.id}';
    if (prefs.getBool(key) == true) return;

    String title, message, fairyAsset;
    Color dialogColor;

    final analysis = await _analyzePrevWeek(week - 1);
    final prevStatus = analysis.status;

    String formatList(List<String> list) {
      if (list.isEmpty) return '';
      if (list.length == 1) return '«${list.first}»';
      if (list.length == 2) return '«${list[0]}» и «${list[1]}»';
      return '«${list[0]}», «${list[1]}» и еще ${list.length - 2} упр.';
    }

    if (week == 2) {
      title = 'Неделя 2: Повышение! 📈';
      dialogColor = const Color(0xFF00B894);
      fairyAsset = FairyMood.wink.asset;

      if (prevStatus == 'weight_failed') {
        final listStr = formatList(analysis.weightFails);
        message = 'Привет! На прошлой неделе было тяжело с весом в: $listStr. Я не буду повышать там вес! Оставляем тот же вес, но добавляем повторения. Сначала закрепим технику! 💪';
      } else if (prevStatus == 'reps_failed') {
        final listStr = formatList(analysis.repsFails);
        message = 'Привет! Вес ты взял отлично, но не доделал повторения в: $listStr. Поэтому там мы не трогаем вес, а просто добавим повторения. Закрепляем результат! 🔥';
      } else {
        message = 'Привет! Ты отлично справился на прошлой неделе! Мы держим те же повторения, но я добавила тебе вес (+2.5 кг). Работай сфокусированно! 💪';
      }
    } else if (week == 3) {
      title = 'Неделя 3: Пик формы! 🚀';
      dialogColor = const Color(0xFFE17055);
      fairyAsset = FairyMood.wink.asset;

      if (prevStatus == 'weight_failed' || prevStatus == 'reps_failed') {
        final fails = prevStatus == 'weight_failed' ? analysis.weightFails : analysis.repsFails;
        final listStr = formatList(fails);
        message = 'Пиковая неделя, но давай без фанатизма! В упражнениях: $listStr на прошлой неделе было тяжело. Там вес мы оставляем прежним. Просто выложись на максимум! 🏋️‍♂️';
      } else {
        message = 'Это самая тяжелая неделя. Ты доказал, что готов! Мы увеличили и вес (еще +2.5 кг), и повторения. Слушай тело и держи технику! 🏋️‍♂️';
      }
    } else if (week == 4) {
      title = 'Неделя 4: Закрепление 🌿';
      dialogColor = const Color(0xFF0984E3);
      fairyAsset = FairyMood.party.asset;
      message = 'Время восстанавливаться! Повторения возвращаются к базовым, а вес снижается до уровня прошлой недели. Это нужно, чтобы в следующем месяце начать с более высокой точки! ✨';
    } else return;

    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Image.asset(fairyAsset, width: 44, height: 44, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Вперёд! 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
    await prefs.setBool(key, true);
  }
// ═══ ЧАСТЬ 1 ЗАКОНЧИЛАСЬ ═══
  Future<void> _preloadHistory() async {
    final Set<int> loadedHistory = {};
    for (final item in _items) {
      if (item.isCoolDown || item.itemType != 'exercise') continue;
      final exId = item.replacedByItemId ?? item.itemId;
      if (loadedHistory.contains(exId)) continue;
      final sets = await DatabaseHelper.instance.getLastWorkoutExerciseSets(profileId: widget.profileId, exerciseId: exId);
      if (sets.isNotEmpty) loadedHistory.add(exId);
    }
    if (mounted) setState(() { _exercisesWithHistory.clear(); _exercisesWithHistory.addAll(loadedHistory); });
  }

  String? _getBaseZone(Exercise ex) {
    final keywords = [
      'присед', 'приседание', 'squat', 'выпад', 'lunge', 'становая', 'deadlift',
      'румынск', 'romanian', 'жим', 'press', 'bench press', 'жим лёжа', 'жим лежа',
      'тяга', 'row', 'подтягив', 'pull-up', 'pullup', 'отжимание', 'push-up', 'pushup',
      'берпи', 'burpee', 'планка', 'plank', 'скручивание', 'crunch', 'зашаг',
    ];
    final lower = ex.name.toLowerCase();
    if (!keywords.any((kw) => lower.contains(kw))) return null;

    if (ex.muscleGroups.contains('glutes') || ex.muscleGroups.contains('legs')) return 'Ягодицы/Ноги';
    if (ex.muscleGroups.contains('chest')) return 'Грудь';
    if (ex.muscleGroups.contains('back') || ex.muscleGroups.contains('lats')) return 'Спина';
    if (ex.muscleGroups.contains('arms') || ex.muscleGroups.contains('biceps') || ex.muscleGroups.contains('triceps')) return 'Руки';
    if (ex.muscleGroups.contains('abs') || ex.muscleGroups.contains('core')) return 'Пресс';
    if (ex.muscleGroups.contains('shoulders')) return 'Плечи';

    return 'База';
  }

  String _groupLabel(String code) {
    const map = {
      'glutes': 'ягодицы', 'abs': 'пресс', 'obliques': 'косые', 'arms': 'руки',
      'biceps': 'бицепс', 'triceps': 'трицепс', 'shoulders': 'плечи', 'legs': 'ноги',
      'quads': 'бёдра', 'hamstrings': 'задняя поверхность', 'calves': 'голень',
      'back': 'спина', 'lats': 'широчайшие', 'traps': 'трапеции', 'lower_back': 'поясница',
      'chest': 'грудь', 'core': 'кор', 'full_body': 'всё тело', 'cardio': 'кардио',
      'feet': 'стопы', 'adductors': 'приводящие', 'forearms': 'предплечья',
      'rotator_cuff': 'ротаторная манжета'
    };
    return map[code] ?? code;
  }

  String _circleKey(int blockNum, int circleNum) => '${blockNum}_$circleNum';
  bool _isCircleCollapsed(int blockNum, int circleNum) => _collapsedCircles.contains(_circleKey(blockNum, circleNum));

  void _toggleCircle(int blockNum, int circleNum) {
    final key = _circleKey(blockNum, circleNum);
    setState(() {
      if (_collapsedCircles.contains(key)) _collapsedCircles.remove(key);
      else _collapsedCircles.add(key);
    });
  }

  bool _isCircleComplete(List<WorkoutExercise> blockItems, int circle) {
    for (final item in blockItems) {
      final sets = _setsData[item.id!];
      if (sets == null) return false;
      if (circle >= sets.length) continue;
      if (!sets[circle].completed) return false;
    }
    return true;
  }

  int _completedInCircle(List<WorkoutExercise> blockItems, int circle) {
    int count = 0;
    for (final item in blockItems) {
      final sets = _setsData[item.id!];
      if (sets == null) continue;
      if (circle >= sets.length) continue;
      if (sets[circle].completed) count++;
    }
    return count;
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _loadExistingDay(WorkoutDay day) async {
    _workoutDayId = day.id;
    _completed = day.status == 'completed';
    _started = day.status == 'completed' || day.status == 'in_progress';

    final workoutExs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
    _hasBlocks = workoutExs.any((we) => we.blockNumber != null);

    _pendingBlocks.clear();
    for (int i = 0; i < workoutExs.length; i++) {
      final bn = workoutExs[i].blockNumber;
      if (bn != null) _pendingBlocks[i] = bn;
    }

    _items = workoutExs;
    final exMap = <int, Exercise>{};
    final stMap = <int, Stretch>{};

    for (final we in workoutExs) {
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

    for (final item in workoutExs) {
      if (item.id == null) continue;
      final sets = await DatabaseHelper.instance.getWorkoutSets(item.id!);

      final list = <SetData>[];
      final ids = <int>[];
      bool needsPulling = true;

      if (sets.isNotEmpty) {
        for (final s in sets) {
          if (s.completed || s.weight != null) needsPulling = false;
          list.add(SetData(weight: s.weight, reps: s.reps, completed: s.completed));
          ids.add(s.id!);
        }
      }

      if (needsPulling && day.weekNumber != null && day.weekNumber! > 1) {
        final ex = exMap[item.replacedByItemId ?? item.itemId];
        final isCardio = ex != null && _isCardio(ex);
        final isTimed = ex != null && _isTimed(ex.name);

        if (!isCardio && !isTimed) {
          double? baseWeight;
          bool isSuccessful = true;

          final lastSets = await DatabaseHelper.instance.getLastWorkoutExerciseSets(
            profileId: widget.profileId,
            exerciseId: item.replacedByItemId ?? item.itemId,
            daysLimit: 30,
          );

          if (lastSets.isNotEmpty) {
            baseWeight = lastSets.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
            if (baseWeight == 0) baseWeight = null;

            final completedSets = lastSets.where((s) => s.completed).toList();
            if (completedSets.length < lastSets.length) {
              isSuccessful = false;
            } else if (baseWeight != null && baseWeight > 0) {
              final avgWeight = completedSets.map((s) => s.weight ?? 0).reduce((a, b) => a + b) / completedSets.length;
              if (avgWeight < (baseWeight * 0.95)) {
                isSuccessful = false;
              }
            }
          }

          if (baseWeight != null && baseWeight > 0) {
            double? targetWeight = baseWeight;

            if (day.weekNumber == 2 || day.weekNumber == 3) {
              if (isSuccessful) {
                if (_profile?.goal == 'tone' && day.weekNumber == 2) {
                  targetWeight = baseWeight;
                } else {
                  final step = (_profile?.level == 'beginner') ? 1.5 : 2.5;
                  targetWeight = baseWeight + step;
                }
              }
            } else if (day.weekNumber == 4) {
              targetWeight = baseWeight;
            }

            _targetWeights[item.id!] = targetWeight;

            for (int i = 0; i < list.length; i++) {
              list[i] = SetData(weight: targetWeight, reps: list[i].reps, completed: false);
              if (ids[i] > 0) {
                await DatabaseHelper.instance.updateWorkoutSet(
                  WorkoutSet(id: ids[i], workoutExerciseId: item.id!, order: i + 1, weight: targetWeight, reps: list[i].reps, completed: false),
                );
              }
            }
          }
        }
      }

      while (list.length < item.sets && list.length < 5) {
        list.add(SetData(reps: _parseReps(item.reps), completed: false));
        ids.add(0);
      }

      setsData[item.id!] = list;
      setIds[item.id!] = ids;
    }

    _exerciseMap = exMap;
    _stretchMap = stMap;
    _setsData.addAll(setsData);
    _setIds.addAll(setIds);
  }

  int? _parseReps(String repsStr) {
    final match = RegExp(r'(\d+)(?:-(\d+))?').firstMatch(repsStr);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  List<int> _getBlockSizes(int total) {
    if (total <= 0) return [];
    if (total <= 4) return [total];

    List<int> sizes = [];
    int remaining = total;

    while (remaining > 0) {
      if (remaining == 4) { sizes.add(4); remaining -= 4; }
      else if (remaining == 5) { sizes.add(3); sizes.add(2); remaining -= 5; }
      else if (remaining == 7) { sizes.add(3); sizes.add(4); remaining -= 7; }
      else { sizes.add(3); remaining -= 3; }
    }
    return sizes;
  }

  void _createBlocks() {
    _pendingBlocks.clear();
    _collapsedCircles.clear();

    List<int> validIndexes = [];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isCoolDown) continue;
      final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
      final isCardio = ex != null && _isCardio(ex);
      if (isCardio) continue;
      validIndexes.add(i);
    }

    final blockSizes = _getBlockSizes(validIndexes.length);
    int blockNum = 1;
    int itemIndex = 0;

    for (final size in blockSizes) {
      for (int k = 0; k < size; k++) {
        if (itemIndex < validIndexes.length) {
          final originalIndex = validIndexes[itemIndex];
          _pendingBlocks[originalIndex] = blockNum;
          itemIndex++;
        }
      }
      blockNum++;
    }

    setState(() {
      _blocksReady = true;
      _hasBlocks = true;
    });
    _showMessage('Сформировано блоков: ${blockSizes.length}');
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

  Future<void> _toggleBlocks() async {
    if (_workoutDayId == null) return;

    if (_hasBlocks) {
      await DatabaseHelper.instance.clearBlocksForWorkoutDay(_workoutDayId!);
      if (!mounted) return;
      setState(() {
        _hasBlocks = false;
        _collapsedCircles.clear();
      });
      _showMessage('Блоки убраны');
    } else {
      List<WorkoutExercise> validItems = [];
      for (final item in _items) {
        if (item.id == null || item.isCoolDown) continue;
        final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
        final isCardio = ex != null && _isCardio(ex);
        if (isCardio) {
          await DatabaseHelper.instance.updateWorkoutExerciseBlock(id: item.id!, blockNumber: null);
        } else {
          validItems.add(item);
        }
      }

      final blockSizes = _getBlockSizes(validItems.length);
      int blockNum = 1;
      int itemIndex = 0;

      for (final size in blockSizes) {
        for (int k = 0; k < size; k++) {
          if (itemIndex < validItems.length) {
            await DatabaseHelper.instance.updateWorkoutExerciseBlock(id: validItems[itemIndex].id!, blockNumber: blockNum);
            itemIndex++;
          }
        }
        blockNum++;
      }

      if (!mounted) return;
      setState(() => _hasBlocks = true);
      _showMessage('Сформировано блоков: ${blockSizes.length}');
    }
  }

  Future<void> _startWorkout() async {
    if (_workoutDayId == null) return;
    final day = await DatabaseHelper.instance.getWorkoutDayById(_workoutDayId!);
    if (day == null) return;

    if (day.status == 'completed') {
      _showMessage('Эта тренировка уже завершена');
      return;
    }

    if (day.weekNumber != null && day.weekNumber! > 1) {
      final prevWeekDays = await DatabaseHelper.instance.getWorkoutDaysByWeek(
        profileId: widget.profileId,
        weekNumber: day.weekNumber! - 1,
        cycleNumber: day.cycleNumber,
      );
      final isPrevDone = prevWeekDays.isNotEmpty && prevWeekDays.every((d) => d.status == 'completed');
      if (!isPrevDone) {
        _showMessage('Сначала завершите предыдущую неделю!');
        return;
      }
    }

    final updated = day.copyWith(status: 'in_progress', startedAt: DateTime.now());
    await DatabaseHelper.instance.updateWorkoutDay(updated);
    if (!mounted) return;

    setState(() {
      _started = true;
      _day = updated;
    });
    FairyReactionService().trigger('workout_started', mood: FairyMood.wink);
    _showMessage('Тренировка началась! 💪');
  }

  Future<void> _finishWorkout() async {
    if (_workoutDayId == null) return;

    String? note;
    final noteController = TextEditingController();
    final noteResult = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заметка к тренировке'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Как прошло?', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Пропустить')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );

    if (noteResult == true) note = noteController.text.trim();

    int completedSets = 0;
    int totalSets = 0;
    bool isOverperformed = false;

    for (final item in _items) {
      if (item.isCoolDown || item.id == null) continue;
      final sets = _setsData[item.id!];
      if (sets == null) continue;

      final targetW = _targetWeights[item.id!];

      for (final s in sets) {
        totalSets++;
        if (s.completed) {
          completedSets++;
          if (targetW != null && targetW > 0 && s.weight != null && s.weight! > targetW) {
            isOverperformed = true;
          }
        }
      }
    }

    if (completedSets == 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ничего не отмечено'),
          content: const Text('Вы не отметили ни одного подхода. Завершить всё равно?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Завершить')),
          ],
        ),
      );
      if (ok != true) return;
    }

    final day = await DatabaseHelper.instance.getWorkoutDayById(_workoutDayId!);
    if (day == null) return;

    final minutes = DateTime.now().difference(day.startedAt ?? DateTime.now()).inMinutes;
    final isFullyDone = totalSets > 0 && completedSets == totalSets;
    final newStatus = isFullyDone ? 'completed' : 'in_progress';

    final updated = day.copyWith(
      status: newStatus,
      completedAt: isFullyDone ? DateTime.now() : null,
      durationMinutes: minutes > 0 ? minutes : 1,
      notes: note,
    );
    await DatabaseHelper.instance.updateWorkoutDay(updated);

    if (!mounted) return;

    if (isFullyDone) {
      if (isOverperformed) {
        FairyReactionService().trigger('workout_overperformed', mood: FairyMood.party);
      } else {
        FairyReactionService().trigger('workout_completed', mood: FairyMood.party);
      }

      final unlocked = await AchievementService.checkAchievements(widget.profileId);
      if (unlocked.isNotEmpty && mounted) {
        for (final a in unlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(a.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Новое достижение: ${a.title}!', style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
              backgroundColor: const Color(0xFF6C5CE7),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      FairyReactionService().trigger('workout_partial', mood: FairyMood.happy);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }
// ═══ ЧАСТЬ 2 ЗАКОНЧИЛАСЬ ═══
  Future<void> _saveAsTemplate() async {
    if (_day == null || _day!.id == null) return;
    if (_items.isEmpty) {
      _showMessage('Нечего сохранять — нет упражнений');
      return;
    }

    final nameController = TextEditingController(text: _day!.name);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bookmark_add_rounded),
            SizedBox(width: 8),
            Expanded(child: Text('Сохранить как шаблон', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Создаст шаблон с этими упражнениями.', style: TextStyle(fontSize: 13)),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );

    if (confirm != true) return;

    final templateName = nameController.text.trim().isEmpty ? _day!.name : nameController.text.trim();
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
        SnackBar(content: Text('✅ Шаблон «$templateName» сохранён'), duration: const Duration(seconds: 3)),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Ошибка: $e');
    }
  }

  Future<void> _openExerciseMenu(WorkoutExercise item, Exercise exercise) async {
    if (_isViewMode) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
          Text(exercise.name, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          _menuTile(ctx, icon: Icons.swap_horiz_rounded, title: 'Заменить упражнение', color: theme.colorScheme.primary, onTap: () => Navigator.pop(ctx, 'replace')),
          _menuTile(ctx, icon: Icons.tune_rounded, title: 'Изменить подходы и повторения', color: const Color(0xFF00B894), onTap: () => Navigator.pop(ctx, 'edit')),
          _menuTile(ctx, icon: Icons.delete_outline_rounded, title: 'Удалить из тренировки', color: theme.colorScheme.error, onTap: () => Navigator.pop(ctx, 'delete')),
        ],
      ),
    );
  }

  Widget _menuTile(BuildContext ctx, {required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.1)),
          ),
          leading: Icon(icon, color: color),
          title: Text(title),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _replaceExercise(WorkoutExercise item, Exercise original) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _buildReasonSheet(ctx),
    );
    if (reason == null) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ReplaceExerciseScreen(original: original, reasonCode: reason)),
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

        if (item.id != null) {
          final defaultReps = _parseReps(_items[idx].reps);
          _setsData[item.id!] = List.generate(_items[idx].sets, (_) => SetData(reps: defaultReps, completed: false));
          _setIds[item.id!] = List.generate(_items[idx].sets, (_) => 0);
        }
      }
    });

    if (_day?.weekNumber != null) {
      await DatabaseHelper.instance.replaceExerciseInMonth(
        profileId: widget.profileId,
        oldItemId: original.id!,
        newItemId: newExercise.id!,
        reason: reasonCode,
        permanent: permanent,
      );
    }
    _showMessage('Заменено на «${newExercise.name}» во всем месяце');
  }

  Widget _buildReasonSheet(BuildContext ctx) {
    final theme = Theme.of(ctx);
    final reasons = [
      ('no_equipment', 'Нет оборудования', Icons.block_rounded, theme.colorScheme.error),
      ('too_hard', 'Слишком тяжело', Icons.trending_down_rounded, const Color(0xFFE17055)),
      ('too_easy', 'Слишком легко', Icons.trending_up_rounded, const Color(0xFF00B894)),
      ('dislike', 'Не нравится', Icons.thumb_down_rounded, const Color(0xFFFDCB6E)),
      ('other', 'Другое (вручную)', Icons.search_rounded, theme.colorScheme.primary),
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
          Text('Почему заменить?', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Приложение подберёт замену с учётом причины',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
                    side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.1)),
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

  Future<void> _editExerciseParams(WorkoutExercise item) async {
    final setsController = TextEditingController(text: '${item.sets}');
    final repsController = TextEditingController(text: item.reps);
    final restController = TextEditingController(text: '${item.restSeconds}');
    final isTimed = _isTimed(_exerciseMap[item.replacedByItemId ?? item.itemId]?.name ?? '');

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
              decoration: const InputDecoration(labelText: 'Подходы', prefixIcon: Icon(Icons.repeat_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: repsController,
              decoration: InputDecoration(
                labelText: isTimed ? 'Время (например, 60 сек)' : 'Повторения (например, 10-12)',
                prefixIcon: const Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: restController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Отдых (сек)', prefixIcon: Icon(Icons.timer_rounded)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );

    if (result != true) return;

    final newSets = int.tryParse(setsController.text) ?? item.sets;
    final newReps = repsController.text.trim().isEmpty ? item.reps : repsController.text.trim();
    final newRest = int.tryParse(restController.text) ?? item.restSeconds;
    final defaultReps = _parseReps(newReps);

    setState(() {
      final idx = _items.indexOf(item);
      if (idx >= 0) _items[idx] = item.copyWith(sets: newSets, reps: newReps, restSeconds: newRest);
      if (item.id != null) {
        _setsData[item.id!] = List.generate(newSets, (_) => SetData(reps: defaultReps));
        _setIds[item.id!] = List.generate(newSets, (_) => 0);
      }
    });

    _showMessage('Параметры обновлены');
  }

  Future<void> _addSetToExercise(WorkoutExercise item) async {
    if (item.id == null || !_started || _isViewMode) return;
    final sets = _setsData[item.id!];
    final ids = _setIds[item.id!];
    if (sets == null || ids == null) return;

    final newOrder = sets.length + 1;
    final defaultReps = _parseReps(item.reps);

    final newSetId = await DatabaseHelper.instance.addWorkoutSet(
      WorkoutSet(workoutExerciseId: item.id!, order: newOrder, reps: defaultReps, completed: false),
    );

    if (!mounted) return;
    setState(() {
      sets.add(SetData(reps: defaultReps, completed: false));
      ids.add(newSetId);
    });
  }

  Future<void> _deleteSetFromExercise(WorkoutExercise item, int index) async {
    if (item.id == null || _isViewMode) return;
    final sets = _setsData[item.id!];
    final ids = _setIds[item.id!];
    if (sets == null || ids == null || index < 0 || index >= sets.length) return;
    if (sets.length <= 1) {
      _showMessage('Нельзя удалить последний подход');
      return;
    }

    final setId = ids[index];
    if (setId > 0) await DatabaseHelper.instance.deleteWorkoutSet(setId);

    if (!mounted) return;
    setState(() {
      sets.removeAt(index);
      ids.removeAt(index);
    });
    _showMessage('Подход удалён');
  }

  Future<void> _deleteExercise(WorkoutExercise item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить упражнение?'),
        content: const Text('Упражнение будет удалено из этой тренировки.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _items.remove(item);
      _setsData.remove(item.id);
      _setIds.remove(item.id);
    });
    _showMessage('Упражнение удалено');
  }

  Future<void> _startStretchTimer(WorkoutExercise item, Stretch st) async {
    if (_isViewMode || !_started || item.id == null) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StretchTimerDialog(name: st.name, totalSeconds: st.durationSeconds, bothSides: st.bothSides),
    );
    if (result != true || !mounted) return;

    final ids = _setIds[item.id!];
    if (ids != null && ids.isNotEmpty) {
      if (ids.first == 0) {
        final newId = await DatabaseHelper.instance.addWorkoutSet(
          WorkoutSet(workoutExerciseId: item.id!, order: 1, completed: true),
        );
        if (mounted) setState(() => ids[0] = newId);
      } else {
        await DatabaseHelper.instance.updateWorkoutSet(
          WorkoutSet(id: ids.first, workoutExerciseId: item.id!, order: 1, completed: true),
        );
      }
    }
    setState(() => _setsData[item.id!] = [SetData(completed: true)]);
    _showMessage('Заминка выполнена ✓');
  }
// ═══ ЧАСТЬ 3.1 ЗАКОНЧИЛАСЬ ═══
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_rounded),
            tooltip: 'Время отдыха',
            onPressed: _started ? _showRestTimePicker : null,
          ),
          if (_started)
            IconButton(
              tooltip: _hasBlocks ? 'Убрать блоки' : 'Сформировать блоки по 3',
              onPressed: _isViewMode ? null : _toggleBlocks,
              icon: Icon(
                _hasBlocks ? Icons.grid_off_rounded : Icons.grid_view_rounded,
                color: _hasBlocks ? Theme.of(context).colorScheme.primary : null,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isRestTimerRunning) _buildTopRestTimer(context),
                Expanded(
                  child: _buildContent(context),
                ),
              ],
            ),
    );
  }

  Widget _buildTopRestTimer(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _restTotalTime > 0 ? _restTimeLeft / _restTotalTime : 0.0;

    final minutes = (_restTimeLeft / 60).floor();
    final seconds = _restTimeLeft % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isRestTimerPaused ? const Color(0xFFFDCB6E) : theme.colorScheme.primary,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _isRestTimerPaused ? Icons.pause_circle_filled_rounded : Icons.timer_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRestTimerPaused ? 'Пауза' : 'Отдых',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_isRestTimerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white),
                onPressed: _togglePauseRestTimer,
              ),
              TextButton(
                onPressed: _stopRestTimer,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Пропустить', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: _buildInfoCard(context))),
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
                      label: Text(_blocksReady ? 'Блоки созданы' : 'Создать блоки', style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _blocksReady ? _resetBlocks : null,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Сбросить', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
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
        if (_hasBlocks)
          ..._buildCircuitsSlivers(context)
        else
          ..._buildUnblockedList(context),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  List<Widget> _buildUnblockedList(BuildContext context) {
    final List<WorkoutExercise> displayItems = [];

    if (_profile?.goal == 'lose_weight') {
      final strength = _items.where((i) {
        if (i.isCoolDown) return false;
        final ex = _exerciseMap[i.replacedByItemId ?? i.itemId];
        return ex != null && !_isCardio(ex);
      }).toList();

      final cardio = _items.where((i) {
        if (i.isCoolDown) return false;
        final ex = _exerciseMap[i.replacedByItemId ?? i.itemId];
        return ex != null && _isCardio(ex);
      }).toList();

      final coolDowns = _items.where((i) => i.isCoolDown).toList();

      int sIdx = 0;
      int cIdx = 0;
      int counter = 0;

      while (sIdx < strength.length || cIdx < cardio.length) {
        if (counter > 0 && counter % 3 == 0 && cIdx < cardio.length) {
          displayItems.add(cardio[cIdx++]);
        } else if (sIdx < strength.length) {
          displayItems.add(strength[sIdx++]);
        } else if (cIdx < cardio.length) {
          displayItems.add(cardio[cIdx++]);
        }
        counter++;
      }
      displayItems.addAll(coolDowns);
    } else {
      displayItems.addAll(_items);
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _buildItemCard(context, displayItems[i], index: i + 1),
            childCount: displayItems.length,
          ),
        ),
      )
    ];
  }

  List<Widget> _buildCircuitsSlivers(BuildContext context) {
    final slivers = <Widget>[];
    final Map<int, List<WorkoutExercise>> blocks = {};
    final List<WorkoutExercise> coolDowns = [];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isCoolDown) {
        coolDowns.add(item);
        continue;
      }
      final blockNum = _pendingBlocks[i];
      if (blockNum != null) {
        blocks.putIfAbsent(blockNum, () => []);
        blocks[blockNum]!.add(item);
      }
    }

    final Set<int> printedBlocks = {};

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isCoolDown) continue;

      final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
      final isCardio = ex != null && _isCardio(ex);

      if (isCardio) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildExerciseCard(context, item),
            ),
          ),
        );
      } else {
        final blockNum = _pendingBlocks[i];
        if (blockNum != null && !printedBlocks.contains(blockNum)) {
          printedBlocks.add(blockNum);
          final blockItems = blocks[blockNum]!;

          for (int circle = 0; circle < 3; circle++) {
            final circleNum = circle + 1;
            final isComplete = _isCircleComplete(blockItems, circle) && _started;
            final completed = _completedInCircle(blockItems, circle);
            final total = blockItems.length;
            final isCollapsed = _isCircleCollapsed(blockNum, circleNum);

            slivers.add(
              SliverToBoxAdapter(
                child: _buildCircleHeader(
                  blockNum: blockNum,
                  circleNum: circleNum,
                  circleIndex: circle,
                  blockItems: blockItems,
                  completed: completed,
                  total: total,
                  isComplete: isComplete,
                  isCollapsed: isCollapsed,
                  onToggle: () => _toggleCircle(blockNum, circleNum),
                ),
              ),
            );

            if (!isCollapsed) {
              slivers.add(
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) => _buildExerciseCard(context, blockItems[idx], circleIndex: circle),
                      childCount: blockItems.length,
                    ),
                  ),
                ),
              );
            }
          }

          if (_started && !_isViewMode) {
            slivers.add(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: OutlinedButton.icon(
                    onPressed: () => _addCircle(blockItems: blockItems, blockNum: blockNum),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text('Добавить круг в Блок $blockNum'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
                      foregroundColor: const Color(0xFF6C5CE7),
                    ),
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    if (coolDowns.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Заминка', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF00B894))),
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
              (context, idx) => _buildStretchCard(context, coolDowns[idx]),
              childCount: coolDowns.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  void _showRestTimePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Время отдыха', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [30, 45, 60, 90, 120].map((sec) {
                return ChoiceChip(
                  label: Text('$sec сек'),
                  selected: _globalRestSeconds == sec,
                  onSelected: (_) async {
                    setState(() => _globalRestSeconds = sec);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('global_rest_seconds', sec);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markCircleCompleted({
    required List<WorkoutExercise> blockItems,
    required int blockNum,
    required int circleIndex,
  }) async {
    if (_isViewMode || !_started) return;

    final updates = <Future>[];
    bool hasChanges = false;

    for (final item in blockItems) {
      if (item.id == null) continue;
      final sets = _setsData[item.id];
      if (sets == null || circleIndex >= sets.length || sets[circleIndex].completed) continue;

      hasChanges = true;
      final updated = SetData(weight: sets[circleIndex].weight, reps: sets[circleIndex].reps, completed: true);
      setState(() => sets[circleIndex] = updated);

      final ids = _setIds[item.id!];
      if (ids != null && circleIndex < ids.length) {
        if (ids[circleIndex] == 0) {
          final newId = await DatabaseHelper.instance.addWorkoutSet(
            WorkoutSet(
              workoutExerciseId: item.id!,
              order: circleIndex + 1,
              weight: updated.weight,
              reps: updated.reps,
              completed: true,
            ),
          );
          if (mounted) setState(() => ids[circleIndex] = newId);
        } else {
          updates.add(DatabaseHelper.instance.updateWorkoutSet(
            WorkoutSet(
              id: ids[circleIndex],
              workoutExerciseId: item.id!,
              order: circleIndex + 1,
              weight: updated.weight,
              reps: updated.reps,
              completed: true,
            ),
          ));
        }
      }
    }

    if (!hasChanges) return;

    final key = _circleKey(blockNum, circleIndex + 1);
    if (!_collapsedCircles.contains(key)) setState(() => _collapsedCircles.add(key));

    if (updates.isNotEmpty) await Future.wait(updates);

    if (blockItems.isNotEmpty && _started && !_isViewMode) {
      _startRestTimer();
    }
  }

  Future<void> _addCircle({required List<WorkoutExercise> blockItems, required int blockNum}) async {
    if (!_started || _isViewMode) return;
    for (final item in blockItems) {
      if (item.id == null || item.isCoolDown) continue;
      final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
      if (ex != null && _isCardio(ex)) continue;
      await _addSetToExercise(item);
    }
  }

  Widget _buildCircleHeader({
    required int blockNum,
    required int circleNum,
    required int circleIndex,
    required List<WorkoutExercise> blockItems,
    required int completed,
    required int total,
    required bool isComplete,
    required bool isCollapsed,
    required VoidCallback onToggle,
  }) {
    final showActions = _started && !_isViewMode;
    final canMarkAll = showActions && !isComplete;
    final gradientColors = isComplete
        ? const [Color(0xFF00B894), Color(0xFF55EFC4)]
        : _blockPalettes[(blockNum - 1) % _blockPalettes.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: gradientColors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Icon(isComplete ? Icons.check_circle_rounded : Icons.fitness_center, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'БЛОК $blockNum — КРУГ $circleNum · $completed/$total',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (canMarkAll)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton.icon(
                    onPressed: () => _markCircleCompleted(blockItems: blockItems, blockNum: blockNum, circleIndex: circleIndex),
                    icon: const Icon(Icons.done_all_rounded, size: 14, color: Colors.white),
                    label: const Text('Весь круг', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: const Size(0, 28),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Icon(
                    isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
// ═══ ЧАСТЬ 3.2 ЗАКОНЧИЛАСЬ ═══