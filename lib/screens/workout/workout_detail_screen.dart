import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/fairy_mood.dart';
import '../../data/base_exercises.dart';
import '../../models/exercise.dart';
import '../../models/stretch.dart';
import '../../models/workout_day.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import '../../services/achievement_service.dart';
import 'replace_exercise_screen.dart';
import 'warmup_screen.dart';
import 'workout_complete_screen.dart';
import 'widgets/set_row.dart';
import 'widgets/exercise_card.dart';
import 'widgets/circle_header.dart';
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

final Map<int, Map<String, dynamic>> _lastRecords = {};

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
if (_isCardioName(lower)) return true;
final coreGroups = ['abs', 'core', 'obliques'];
if (ex.muscleGroups.any((m) => coreGroups.contains(m))) return false;
return ex.muscleGroups.contains('cardio');
}

bool _isTimed(String name) {
final lower = name.toLowerCase();
return lower.contains('планка') || lower.contains('plank') || _isCardioName(lower);
}

bool _isCardioName(String lowerName) {
if (lowerName.contains('бег') || lowerName.contains('дорожк') || lowerName.contains('скакалк') ||
lowerName.contains('эллипс') || lowerName.contains('велотренаж') || lowerName.contains('велоэргометр') ||
lowerName.contains('гребл') || lowerName.contains('степпер') || lowerName.contains('кардио')) return true;
if (lowerName.contains('скалолаз')) return true;
if (lowerName.contains('канат') && (lowerName.contains('махи') || lowerName.contains('волны') || lowerName.contains('бэтл'))) return true;
return false;
}

Future<int?> _getPrevTarget(int itemId, int week, int? cycle) async {
if (week <= 1) return null;
final prevDays = await DatabaseHelper.instance.getWorkoutDaysByWeek(
profileId: widget.profileId, weekNumber: week - 1, cycleNumber: cycle
);
for (final pd in prevDays) {
final exs = await DatabaseHelper.instance.getWorkoutExercises(pd.id!);
for (final ex in exs) {
if (ex.itemId == itemId || ex.replacedByItemId == itemId) {
return _parseReps(ex.reps);
}
}
}
return null;
}

Future<List<WorkoutSet>> _getSmartPrevSets(int exerciseId, int currentWeek, int? cycle) async {
if (currentWeek == 4) {
final dayNumMatch = RegExp(r'День (\d+)').firstMatch(_day?.name ?? '');
final currentDayNum = dayNumMatch?.group(1);

final w3Days = await DatabaseHelper.instance.getWorkoutDaysByWeek(
profileId: widget.profileId, weekNumber: 3, cycleNumber: cycle
);

WorkoutDay? correspondingDay3;
for (final d in w3Days) {
if (currentDayNum != null && d.name.contains('День $currentDayNum')) {
correspondingDay3 = d;
break;
}
}

if (correspondingDay3 != null && correspondingDay3.type == 'challenge') {
final w2Days = await DatabaseHelper.instance.getWorkoutDaysByWeek(
profileId: widget.profileId, weekNumber: 2, cycleNumber: cycle
);
for (final d in w2Days) {
if (currentDayNum != null && d.name.contains('День $currentDayNum')) {
final exs = await DatabaseHelper.instance.getWorkoutExercises(d.id!);
for (final ex in exs) {
if (ex.itemId == exerciseId || ex.replacedByItemId == exerciseId) {
final sets = await DatabaseHelper.instance.getWorkoutSets(ex.id!);
if (sets.isNotEmpty) return sets;
}
}
}
}
}
}

return await DatabaseHelper.instance.getLastWorkoutExerciseSets(
profileId: widget.profileId, exerciseId: exerciseId, daysLimit: 365
);
}

Future<void> _loadExistingDay(WorkoutDay day) async {
if (day.type == 'challenge') {
_workoutDayId = day.id;
_completed = false;
_started = true;

final allWorkoutExs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
_items = allWorkoutExs.where((we) => we.blockNumber == 1).toList();

final exMap = <int, Exercise>{};
final stMap = <int, Stretch>{};

for (final we in _items) {
if (we.itemType == 'exercise') {
final ex = await DatabaseHelper.instance.getExerciseById(we.replacedByItemId ?? we.itemId);
if (ex != null) exMap[ex.id!] = ex;
} else {
final st = await DatabaseHelper.instance.getStretchById(we.itemId);
if (st != null) stMap[we.itemId] = st;
}
}

final setsData = <int, List<SetData>>{};
final setIds = <int, List<int>>{};

for (final item in _items) {
if (item.id == null) continue;
final sets = await DatabaseHelper.instance.getWorkoutSets(item.id!);
final list = <SetData>[];
final ids = <int>[];

for (final s in sets) {
list.add(SetData(weight: s.weight, reps: s.reps, completed: s.completed));
ids.add(s.id!);
}

setsData[item.id!] = list;
setIds[item.id!] = ids;
}

_exerciseMap = exMap;
_stretchMap = stMap;
_setsData.addAll(setsData);
_setIds.addAll(setIds);

return;
}

// ОБЫЧНАЯ ТРЕНИРОВКА
_workoutDayId = day.id;
_completed = day.status == 'completed';
_started = day.status == 'completed' || day.status == 'in_progress';
final workoutExs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);

// 👇 БЕЗОПАСНОЕ УДАЛЕНИЕ ДУБЛИКАТОВ (ГРУППИРУЕМ ПО НАЗВАНИЮ)
final Map<String, List<WorkoutExercise>> groupedExs = {};
for (final we in workoutExs) {
String key = '${we.itemType}_${we.itemId}';
if (we.itemType == 'exercise') {
final ex = await DatabaseHelper.instance.getExerciseById(we.replacedByItemId ?? we.itemId);
if (ex != null) {
final cleanName = ex.name.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
key = 'exercise_$cleanName';
}
} else {
final st = await DatabaseHelper.instance.getStretchById(we.itemId);
if (st != null) {
final cleanName = st.name.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
key = 'stretch_$cleanName';
}
}
groupedExs.putIfAbsent(key, () => []).add(we);
}

final List<WorkoutExercise> uniqueExs = [];
for (final entry in groupedExs.entries) {
final list = entry.value;
if (list.length == 1) {
uniqueExs.add(list.first);
} else {
WorkoutExercise? keeper;
for (final we in list) {
final sets = await DatabaseHelper.instance.getWorkoutSets(we.id!);
final hasCompleted = sets.any((s) => s.completed || s.weight != null);
if (hasCompleted) {
keeper = we;
break;
}
}
keeper ??= list.first;

uniqueExs.add(keeper);

for (final we in list) {
if (we.id != keeper.id) {
await DatabaseHelper.instance.deleteWorkoutExercise(we.id!);
}
}
}
}
uniqueExs.sort((a, b) => a.order.compareTo(b.order));
// 👆 КОНЕЦ ИСПРАВЛЕНИЯ

_hasBlocks = uniqueExs.any((we) => we.blockNumber != null && !we.isWarmup);
_pendingBlocks.clear();
for (int i = 0; i < uniqueExs.length; i++) {
final bn = uniqueExs[i].blockNumber;
if (bn != null && !uniqueExs[i].isWarmup) _pendingBlocks[i] = bn;
}
_items = uniqueExs;

final exMap = <int, Exercise>{};
final stMap = <int, Stretch>{};
for (final we in _items) {
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

for (final item in _items) {
if (item.id == null) continue;
final sets = await DatabaseHelper.instance.getWorkoutSets(item.id!);

var list = <SetData>[];
var ids = <int>[];

bool needsPulling = true;
if (sets.isNotEmpty) {
for (final s in sets) {
if (s.completed || s.weight != null) needsPulling = false;
list.add(SetData(weight: s.weight, reps: s.reps, completed: s.completed));
ids.add(s.id!);
}
}

// 👇 ИСПРАВЛЕНИЕ: ЗАГРУЖАЕМ ИСТОРИЮ ДЛЯ ПЛАШКИ "ПРОШЛЫЙ РЕКОРД" ВСЕГДА
if (!item.isWarmup && !item.isCoolDown && item.itemType == 'exercise') {
final lastSets = await _getSmartPrevSets(item.replacedByItemId ?? item.itemId, day.weekNumber ?? 1, day.cycleNumber);
if (lastSets.isNotEmpty) {
final completed = lastSets.where((s) => s.completed).toList();
if (completed.isNotEmpty) {
double? maxW = completed.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
int? maxR = completed.map((s) => s.reps ?? 0).reduce((a, b) => a > b ? a : b);
if (maxW == 0) maxW = null;
if (maxR == 0) maxR = null;
if (maxW != null || maxR != null) {
_lastRecords[item.id!] = {'weight': maxW, 'reps': maxR};
}
}
}
}

if (needsPulling && !item.isWarmup && !item.isCoolDown && day.weekNumber != null && day.weekNumber! > 1) {
final ex = exMap[item.replacedByItemId ?? item.itemId];
final isCardio = ex != null && _isCardio(ex);
final isTimed = ex != null && _isTimed(ex.name);

if (!isCardio && !isTimed) {
double? baseWeight;
int? prevReps;
bool wasInPrevWeek = false;
final exName = ex?.name ?? '';

if (exName.isNotEmpty && _lastRecords.containsKey(item.id!)) {
wasInPrevWeek = true;
baseWeight = _lastRecords[item.id!]!['weight'] as double?;
prevReps = _lastRecords[item.id!]!['reps'] as int?;
}

double? targetWeight = baseWeight;
final step = (_profile?.level == 'beginner') ? 1.5 : 2.5;

final prevTarget = await _getPrevTarget(item.itemId, day.weekNumber!, day.cycleNumber);
final planMin = _parseReps(item.reps) ?? 10;
final planMax = _parseMaxReps(item.reps) ?? planMin;
final effectivePrevTarget = prevTarget ?? planMin;

int? targetReps = planMax;
final isBaseEx = ex != null && isBaseExercise(ex);

if (isBaseEx) {
if (baseWeight != null && baseWeight > 0) {
if (day.weekNumber == 3 && wasInPrevWeek) {
targetWeight = baseWeight + step;
} else {
targetWeight = baseWeight;
}
}

if (wasInPrevWeek && prevReps != null) {
bool isSuccessful = prevReps >= (effectivePrevTarget - 2);

if (day.weekNumber == 3) {
targetReps = prevReps;
} else if (day.weekNumber == 4) {
targetReps = 15;
} else if (isSuccessful) {
targetReps = planMax;
} else {
targetReps = effectivePrevTarget;
}
} else {
targetReps = planMax;
}
} else {
targetWeight = baseWeight;
if (wasInPrevWeek && prevReps != null) {
if (day.weekNumber == 3) {
targetReps = prevReps;
} else if (day.weekNumber == 4) {
targetReps = 15;
} else if (prevReps >= (effectivePrevTarget - 2)) {
targetReps = (prevReps > planMax) ? prevReps : planMax;
} else {
targetReps = effectivePrevTarget;
}
} else {
targetReps = planMax;
}
}

if (targetWeight != null) _targetWeights[item.id!] = targetWeight;

for (int i = 0; i < list.length; i++) {
list[i] = SetData(weight: targetWeight, reps: targetReps, completed: false);
if (ids[i] > 0) {
await DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(
id: ids[i], workoutExerciseId: item.id!, order: i + 1, weight: targetWeight, reps: targetReps, completed: false
));
}
}
}

if (isTimed && !isCardio) {
int? prevSeconds;
bool wasTimedInPrevWeek = false;
final exName = ex?.name ?? '';
if (exName.isNotEmpty) {
final lastSets = await _getSmartPrevSets(item.replacedByItemId ?? item.itemId, day.weekNumber!, day.cycleNumber);
if (lastSets.isNotEmpty) {
wasTimedInPrevWeek = true;
final completed = lastSets.where((s) => s.completed).toList();
if (completed.isNotEmpty) {
prevSeconds = completed.map((s) => s.reps ?? 0).reduce((a, b) => a > b ? a : b);
if (prevSeconds == 0) prevSeconds = null;
}
}
}
if (wasTimedInPrevWeek && prevSeconds != null) _lastRecords[item.id!] = {'weight': null, 'reps': prevSeconds};
int? targetSeconds = _parseReps(item.reps);
final bool isBaseEx = ex != null && isBaseExercise(ex);
if (isBaseEx && prevSeconds != null) {
bool isSuccessful = prevSeconds >= (targetSeconds ?? 0);
if (day.weekNumber == 1 && prevSeconds >= 100) targetSeconds = prevSeconds;
else if (day.weekNumber == 2) targetSeconds = isSuccessful ? (prevSeconds + 20) : (targetSeconds ?? 80);
else if (day.weekNumber == 3) targetSeconds = isSuccessful ? (prevSeconds + 20) : (targetSeconds ?? 100);
else if (day.weekNumber == 4) targetSeconds = isSuccessful ? prevSeconds : (targetSeconds ?? 100);
}
for (int i = 0; i < list.length; i++) {
list[i] = SetData(weight: null, reps: targetSeconds, completed: false);
if (ids[i] > 0) {
await DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(
id: ids[i], workoutExerciseId: item.id!, order: i + 1, weight: null, reps: targetSeconds, completed: false
));
}
}
}
}

// 👇 ПРИНУДИТЕЛЬНАЯ РАЗГРУЗКА НА 4-Й НЕДЕЛЕ
if (day.weekNumber == 4 && !item.isWarmup && !item.isCoolDown) {
final planMin = _parseReps(item.reps) ?? 15;
for (int i = 0; i < list.length; i++) {
if (!list[i].completed) {
list[i] = SetData(weight: list[i].weight, reps: planMin, completed: false);
if (ids[i] > 0) {
await DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(
id: ids[i], workoutExerciseId: item.id!, order: i + 1, weight: list[i].weight, reps: planMin, completed: false
));
}
}
}
}

if (!_completed) {
final int targetSets = item.sets > 0 ? item.sets : 3;

if (list.length > targetSets) {
for (int i = targetSets; i < list.length; i++) {
if (ids[i] > 0) await DatabaseHelper.instance.deleteWorkoutSet(ids[i]);
}
list = list.sublist(0, targetSets);
ids = ids.sublist(0, targetSets);
}

while (list.length < targetSets && list.length < 10) {
final newSetId = await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
workoutExerciseId: item.id!, order: list.length + 1, weight: null, reps: _parseReps(item.reps), completed: false
));
list.add(SetData(reps: _parseReps(item.reps), completed: false));
ids.add(newSetId);
}
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
final match = RegExp(r'(\d+)').firstMatch(repsStr);
if (match == null) return null;
return int.tryParse(match.group(1) ?? '');
}

int? _parseMaxReps(String repsStr) {
final matches = RegExp(r'(\d+)').allMatches(repsStr);
if (matches.isEmpty) return null;
final nums = matches.map((m) => int.tryParse(m.group(1) ?? '')).whereType<int>().toList();
if (nums.isEmpty) return null;
return nums.reduce((a, b) => a > b ? a : b);
}
// ═══ КОНЕЦ ЧАСТИ 1 ═══
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
if (_restTimeLeft > 0) setState(() => _restTimeLeft--); else _stopRestTimer();
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

Future<void> _showWeekNotification() async {
final week = _day?.weekNumber;
if (week == null || week == 1 || _started || _completed) return;

final prefs = await SharedPreferences.getInstance();
final key = 'week${week}_notified_${widget.profileId}_${_day?.id}';
if (prefs.getBool(key) == true) return;

final prevDays = await DatabaseHelper.instance.getWorkoutDaysByWeek(
profileId: widget.profileId, weekNumber: week - 1, cycleNumber: _day?.cycleNumber,
);
prevDays.sort((a, b) => a.date.compareTo(b.date));

if (prevDays.isEmpty) { await prefs.setBool(key, true); return; }

final currentWeekDays = await DatabaseHelper.instance.getWorkoutDaysByWeek(
profileId: widget.profileId, weekNumber: week, cycleNumber: _day?.cycleNumber,
);
currentWeekDays.sort((a, b) => a.date.compareTo(b.date));
final currentDayIndex = currentWeekDays.indexWhere((d) => d.id == _day?.id);

WorkoutDay? prevDay;
if (currentDayIndex != -1 && currentDayIndex < prevDays.length) {
prevDay = prevDays[currentDayIndex];
}

if (prevDay == null) {
final match = RegExp(r'День (\d+)').firstMatch(_day?.name ?? '');
final dayNum = match?.group(1);
if (dayNum != null) {
for (final pd in prevDays) {
if (pd.name.contains('День $dayNum')) {
prevDay = pd;
break;
}
}
}
}

if (prevDay == null || (prevDay.status != 'completed' && prevDay.status != 'in_progress')) {
return;
}

List<String> repsNotDone = [];
List<String> weightNotDone = [];
List<String> notDoneExercises = [];

final exs = await DatabaseHelper.instance.getWorkoutExercises(prevDay.id!);
for (final we in exs) {
if (we.itemType != 'exercise' || we.isCoolDown || we.isWarmup) continue;
final exId = we.replacedByItemId ?? we.itemId;

final ex = await DatabaseHelper.instance.getExerciseById(exId);
if (ex == null) continue;

final sets = await DatabaseHelper.instance.getWorkoutSets(we.id!);
final completed = sets.where((s) => s.completed).toList();
final exName = ex.name;

bool allDone = completed.isNotEmpty && completed.length == sets.length;

if (!allDone) {
notDoneExercises.add('«$exName» (${completed.length} из ${sets.length} подходов)');
}

if (!isBaseExercise(ex)) continue;

double avgReps = completed.isNotEmpty ? completed.map((s) => s.reps ?? 0).reduce((a, b) => a + b) / completed.length : 0;
final actualTargetReps = _parseReps(we.reps) ?? 0;
final targetWeight = _targetWeights[we.id!];

if (targetWeight != null && targetWeight > 0) {
final maxWeight = completed.isNotEmpty ? completed.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b) : 0;
if (maxWeight < targetWeight * 0.95) {
weightNotDone.add('«$exName»: ${maxWeight.toStringAsFixed(1)} кг из ${targetWeight.toStringAsFixed(1)} кг');
}
}

if (!allDone || (actualTargetReps > 0 && avgReps < (actualTargetReps - 3))) {
final realReps = avgReps.round();
if (realReps < actualTargetReps) {
repsNotDone.add('«$exName»: $realReps из $actualTargetReps');
} else {
repsNotDone.add('«$exName»: не все подходы выполнены');
}
}
}

String title, message;
Color dialogColor = const Color(0xFF00B894);
final isFemale = _profile?.gender == 'female';
final name = _profile?.name ?? 'друг';
final coped = isFemale ? 'справилась' : 'справился';
final didNot = isFemale ? 'не доделала' : 'не доделал';

if (week == 2) {
title = 'Неделя 2: Работа над ошибками 📈';
if (notDoneExercises.isNotEmpty) {
message = 'Привет, $name! На прошлой неделе ты $didNot:\n${notDoneExercises.take(5).join('\n')}.\n\nДавай на этой неделе доделаем всё по плану! 🔥';
} else if (repsNotDone.isNotEmpty) {
message = 'Привет, $name! На прошлой неделе ты $didNot норму в:\n${repsNotDone.take(5).join('\n')}.\n\nНа этой неделе мы закрепляем эти повторы, чтобы ты могла догнать план. На остальных упражнениях повторы увеличены! 🔥';
} else if (weightNotDone.isNotEmpty) {
message = 'Привет, $name! На прошлой неделе не хватило веса в:\n${weightNotDone.take(5).join('\n')}.\n\nВес оставляем прежним, но добавляем повторения. Работаем над техникой! 💪';
} else {
message = 'Привет, $name! Ты отлично $coped! На этой неделе мы не трогаем вес, но добавляем повторения, чтобы стимулировать мышцы. Всё по плану! 🚀';
}
} else if (week == 3) {
title = 'Неделя 3: Пик силы! 🚀';
dialogColor = const Color(0xFFE17055);
if (notDoneExercises.isNotEmpty) {
message = 'Пиковая неделя, $name! На прошлой неделе остались недоделанными:\n${notDoneExercises.take(5).join('\n')}.\n\nСоберись, это пик нагрузки! 💪';
} else if (weightNotDone.isNotEmpty) {
message = 'Пиковая неделя, $name! Были сложности с весом в:\n${weightNotDone.take(5).join('\n')}.\n\nВес пока оставляем прежним, но на остальных упражнениях мы его добавили. Выкладываемся на максимум! 🏋️‍♂️';
} else if (repsNotDone.isNotEmpty) {
message = 'Пиковая неделя, $name! На прошлой неделе ты $didNot повторы в:\n${repsNotDone.take(5).join('\n')}.\n\nНа этой неделе мы добавляем вес, а повторы на этих упражнениях оставляем базовыми. Работаем! 🔥';
} else {
message = 'Пиковая неделя, $name! Это пик нагрузки. Мы добавляем вес, а повторения остаются на уровне прошлой недели. Выкладываемся на максимум! 🔥';
}
} else {
title = 'Неделя 4: Закрепление 🌿';
dialogColor = const Color(0xFF0984E3);

final isSpecialDay = prevDay.name.toLowerCase().contains('челлендж');

if (isSpecialDay) {
final workedOut = isFemale ? 'проработала' : 'проработал';
message = 'Привет, $name! На прошлой неделе у нас был особый день — ты отлично $workedOut забытые зоны! А сегодня возвращаемся к нашим фокусным группам. Вес закрепляем с прошлой недели, а повторения снижаем для отдыха. ✨';
} else {
message = 'Время восстанавливаться, $name! Вес закрепляем с прошлой недели, а повторения снижаем для отдыха. ✨';
}
}

if (!mounted) return;
Future.delayed(const Duration(milliseconds: 600), () {
if (!mounted) return;
showDialog(
context: context,
barrierDismissible: false,
builder: (ctx) => AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
title: Row(children: [
Image.asset(FairyMood.wink.asset, width: 44, height: 44, fit: BoxFit.contain),
const SizedBox(width: 10),
Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))
]),
content: Text(message, style: const TextStyle(fontSize: 15)),
actions: [
ElevatedButton(
onPressed: () => Navigator.pop(ctx),
style: ElevatedButton.styleFrom(backgroundColor: dialogColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
child: const Text('Вперёд! 🚀', style: TextStyle(fontWeight: FontWeight.bold))
)
],
),
);
});
await prefs.setBool(key, true);
}

Future<void> _preloadHistory() async {
final Set<int> loadedHistory = {};
for (final item in _items) {
if (item.isCoolDown || item.isWarmup || item.itemType != 'exercise') continue;
final exId = item.replacedByItemId ?? item.itemId;
if (loadedHistory.contains(exId)) continue;
final sets = await DatabaseHelper.instance.getLastWorkoutExerciseSets(profileId: widget.profileId, exerciseId: exId);
if (sets.isNotEmpty) loadedHistory.add(exId);
}
if (mounted) setState(() {
_exercisesWithHistory.clear();
_exercisesWithHistory.addAll(loadedHistory);
});
}

String? _getBaseZone(Exercise ex) => getExerciseZone(ex);
String _groupLabel(String code) => getZoneLabel(code);

String _circleKey(int blockNum, int circleNum) => '${blockNum}_$circleNum';
bool _isCircleCollapsed(int blockNum, int circleNum) => _collapsedCircles.contains(_circleKey(blockNum, circleNum));

bool _isCircleComplete(List<WorkoutExercise> blockItems, int circle) {
bool hasSetsForCircle = false;
for (final item in blockItems) {
final sets = _setsData[item.id!];
if (sets == null) return false;
if (circle >= sets.length) return false;
hasSetsForCircle = true;
if (!sets[circle].completed) return false;
}
return hasSetsForCircle;
}

int _completedInCircle(List<WorkoutExercise> blockItems, int circle) {
int count = 0;
for (final item in blockItems) {
final sets = _setsData[item.id!];
if (sets == null || circle >= sets.length) continue;
if (sets[circle].completed) count++;
}
return count;
}

void _toggleCircle(int blockNum, int circleNum) {
final key = _circleKey(blockNum, circleNum);
setState(() {
if (_collapsedCircles.contains(key)) _collapsedCircles.remove(key);
else _collapsedCircles.add(key);
});
}

void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Map<int, int> _computeBlockDistribution() {
final Map<int, int> distribution = {};
if (_day?.type == 'challenge') return distribution;
bool hasStored = false;
for (int i = 0; i < _items.length; i++) {
final item = _items[i];
if (item.isWarmup) continue;
final bn = item.blockNumber;
if (bn != null) {
distribution[i] = bn;
hasStored = true;
}
}
if (hasStored) return distribution;
final List<int> baseIndices = [];
final List<int> isolationIndices = [];
for (int i = 0; i < _items.length; i++) {
final item = _items[i];
if (item.isCoolDown || item.isWarmup) continue;
final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
if (ex == null || _isCardio(ex)) continue;
if (isBaseExercise(ex)) baseIndices.add(i);
else isolationIndices.add(i);
}
int blockNum = 1;
int isoIndex = 0;
for (final baseIdx in baseIndices) {
distribution[baseIdx] = blockNum;
int taken = 0;
while (taken < 2 && isoIndex < isolationIndices.length) {
distribution[isolationIndices[isoIndex]] = blockNum;
isoIndex++;
taken++;
}
blockNum++;
}
while (isoIndex < isolationIndices.length) {
distribution[isolationIndices[isoIndex]] = blockNum;
isoIndex++;
}
return distribution;
}

Future<void> _createBlocks() async {
if (_workoutDayId == null) return;
_pendingBlocks.clear();
_collapsedCircles.clear();
final dist = _computeBlockDistribution();
_pendingBlocks.addAll(dist);
for (final entry in dist.entries) {
final item = _items[entry.key];
if (item.id != null) await DatabaseHelper.instance.updateWorkoutExerciseBlock(id: item.id!, blockNumber: entry.value);
}
if (!mounted) return;
setState(() {
_blocksReady = true;
_hasBlocks = true;
});
final maxBlock = dist.values.isEmpty ? 0 : dist.values.reduce((a, b) => a > b ? a : b);
_showMessage('Сформировано блоков: $maxBlock');
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
for (final item in _items) {
if (item.id == null || item.isCoolDown || item.isWarmup) continue;
final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
if (ex != null && _isCardio(ex)) await DatabaseHelper.instance.updateWorkoutExerciseBlock(id: item.id!, blockNumber: null);
}
final dist = _computeBlockDistribution();
for (final entry in dist.entries) {
final item = _items[entry.key];
if (item.id != null) await DatabaseHelper.instance.updateWorkoutExerciseBlock(id: item.id!, blockNumber: entry.value);
}
if (!mounted) return;
setState(() => _hasBlocks = true);
final maxBlock = dist.values.isEmpty ? 0 : dist.values.reduce((a, b) => a > b ? a : b);
_showMessage('Сформировано блоков: $maxBlock');
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

if (day.type != 'challenge' && day.weekNumber != null && day.weekNumber! > 1) {
final prevWeekDays = await DatabaseHelper.instance.getWorkoutDaysByWeek(profileId: widget.profileId, weekNumber: day.weekNumber! - 1, cycleNumber: day.cycleNumber);
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

int completedSets = 0;
int totalSets = 0;

for (final item in _items) {
if (item.isCoolDown || item.isWarmup || item.id == null) continue;
final sets = _setsData[item.id!];
if (sets == null) continue;
for (final s in sets) {
totalSets++;
if (s.completed) completedSets++;
}
}

if (completedSets < totalSets) {
final confirm = await showDialog<bool>(
context: context,
builder: (ctx) => AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
title: const Text('Тренировка не завершена'),
content: Text('Вы выполнили $completedSets из $totalSets подходов.\n\nСохранить прогресс и вернуться? День останется в плане как «В процессе».'),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx, false),
child: const Text('Продолжить'),
),
ElevatedButton(
onPressed: () => Navigator.pop(ctx, true),
style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE17055)),
child: const Text('Сохранить и выйти'),
),
],
),
);

if (confirm != true) return;

final updates = <Future>[];
for (final item in _items) {
if (item.isCoolDown || item.isWarmup || item.id == null) continue;
final sets = _setsData[item.id!];
if (sets == null) continue;
for (int i = 0; i < sets.length; i++) {
final ids = _setIds[item.id!];
if (ids != null && i < ids.length && ids[i] > 0) {
updates.add(DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(
id: ids[i], workoutExerciseId: item.id!, order: i + 1,
weight: sets[i].weight, reps: sets[i].reps, completed: sets[i].completed,
)));
}
}
}
if (updates.isNotEmpty) await Future.wait(updates);

final day = await DatabaseHelper.instance.getWorkoutDayById(_workoutDayId!);
if (day == null) return;
final updated = day.copyWith(status: 'in_progress', startedAt: day.startedAt ?? DateTime.now());
await DatabaseHelper.instance.updateWorkoutDay(updated);
if (mounted) Navigator.pop(context, true);
return;
}

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
ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить'))
],
),
);
if (noteResult == true) note = noteController.text.trim();

final updates = <Future>[];
for (final item in _items) {
if (item.isCoolDown || item.isWarmup || item.id == null) continue;
final sets = _setsData[item.id!];
if (sets == null) continue;
for (int i = 0; i < sets.length; i++) {
final ids = _setIds[item.id!];
if (ids != null && i < ids.length) {
updates.add(DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(id: ids[i], workoutExerciseId: item.id!, order: i + 1, weight: sets[i].weight, reps: sets[i].reps, completed: true)));
}
}
}
if (updates.isNotEmpty) await Future.wait(updates);

bool isOverperformed = false;
for (final item in _items) {
if (item.isCoolDown || item.isWarmup || item.id == null) continue;
final sets = _setsData[item.id!];
if (sets == null) continue;
final targetW = _targetWeights[item.id!];
for (final s in sets) {
if (s.completed && targetW != null && targetW > 0 && s.weight != null && s.weight! > targetW) isOverperformed = true;
}
}

final day = await DatabaseHelper.instance.getWorkoutDayById(_workoutDayId!);
if (day == null) return;
final minutes = DateTime.now().difference(day.startedAt ?? DateTime.now()).inMinutes;

final updated = day.copyWith(status: 'completed', completedAt: DateTime.now(), durationMinutes: minutes > 0 ? minutes : 1, notes: note);
await DatabaseHelper.instance.updateWorkoutDay(updated);
if (!mounted) return;

if (isOverperformed) FairyReactionService().trigger('workout_overperformed', mood: FairyMood.party);
else FairyReactionService().trigger('workout_completed', mood: FairyMood.party);

final unlocked = await AchievementService.checkAchievements(widget.profileId);
if (unlocked.isNotEmpty && mounted) {
for (final a in unlocked) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
content: Row(children: [
Text(a.icon, style: const TextStyle(fontSize: 24)),
const SizedBox(width: 12),
Expanded(child: Text('Новое достижение: ${a.title}!', style: const TextStyle(fontWeight: FontWeight.w600)))
]),
backgroundColor: const Color(0xFF6C5CE7),
duration: const Duration(seconds: 3),
));
}
}

bool isWeekComplete = false;
bool isCycleComplete = false;

if (updated.weekNumber != null) {
final weekDays = await DatabaseHelper.instance.getWorkoutDaysByWeek(profileId: widget.profileId, weekNumber: updated.weekNumber!, cycleNumber: updated.cycleNumber);
final plannedDays = _profile?.daysPerWeek ?? 3;
final completedCount = weekDays.where((d) => d.status == 'completed').length;
final hasSkipped = weekDays.any((d) => d.status != 'completed');
isWeekComplete = completedCount >= plannedDays && !hasSkipped;

if (isWeekComplete && updated.cycleNumber != null) {
bool allWeeksDone = true;
for (int w = 1; w <= 4; w++) {
final wDays = await DatabaseHelper.instance.getWorkoutDaysByWeek(profileId: widget.profileId, weekNumber: w, cycleNumber: updated.cycleNumber);
final wCompleted = wDays.where((d) => d.status == 'completed').length;
final wHasSkipped = wDays.any((d) => d.status != 'completed');
if (wCompleted < plannedDays || wHasSkipped) {
allWeeksDone = false;
break;
}
}
isCycleComplete = allWeeksDone;
}
}

await Future.delayed(const Duration(milliseconds: 300));
if (!mounted) return;

await Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) => WorkoutCompleteScreen(
completedDay: updated,
exercisesCount: _items.where((i) => !i.isCoolDown && !i.isWarmup).length,
isWeekComplete: isWeekComplete,
isCycleComplete: isCycleComplete,
userName: _profile?.name ?? 'друг',
),
),
);

if (mounted) Navigator.pop(context, true);
}
// ═══ КОНЕЦ ЧАСТИ 2 ═══
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
        title: const Row(children: [Icon(Icons.bookmark_add_rounded), SizedBox(width: 8), Expanded(child: Text('Сохранить как шаблон', style: TextStyle(fontSize: 18)))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Создаст шаблон с этими упражнениями. Разминка в шаблон не попадёт.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Название шаблона', prefixIcon: Icon(Icons.fitness_center_rounded), hintText: 'Например: Моя силовая A')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить'))
        ],
      ),
    );
    if (confirm != true) return;
    final templateName = nameController.text.trim().isEmpty ? _day!.name : nameController.text.trim();
    try {
      await DatabaseHelper.instance.createTemplateFromWorkoutDay(profileId: widget.profileId, workoutDayId: _day!.id!, templateName: templateName, type: _day!.type, estimatedMinutes: _day!.durationMinutes ?? 45);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Шаблон «$templateName» сохранён'), duration: const Duration(seconds: 3)));
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
      case 'replace': await _replaceExercise(item, exercise); break;
      case 'edit': await _editExerciseParams(item); break;
      case 'delete': await _deleteExercise(item); break;
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
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.1))),
          leading: Icon(icon, color: color),
          title: Text(title),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _replaceExercise(WorkoutExercise item, Exercise original) async {
    final reason = await showModalBottomSheet<String>(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => _buildReasonSheet(ctx));
    if (reason == null) return;
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => ReplaceExerciseScreen(original: original, reasonCode: reason)));
    if (result == null) return;

    final newExercise = result['newExercise'] as Exercise;
    final permanent = result['permanent'] as bool;
    final reasonCode = result['reason'] as String;

    final isAlreadyInWorkout = _items.any((i) =>
    i.id != item.id &&
        (i.replacedByItemId ?? i.itemId) == newExercise.id
    );

    if (isAlreadyInWorkout) {
      _showMessage('Упражнение «${newExercise.name}» уже есть в этой тренировке!');
      return;
    }

    setState(() {
      _exerciseMap[newExercise.id!] = newExercise;
      final idx = _items.indexOf(item);
      if (idx >= 0) {
        _items[idx] = item.copyWith(itemId: newExercise.id!, replacedByItemId: newExercise.id, replacementReason: reasonCode, replacementPermanent: permanent);
        if (item.id != null) {
          final defaultReps = _parseReps(_items[idx].reps);
          _setsData[item.id!] = List.generate(_items[idx].sets, (_) => SetData(reps: defaultReps, completed: false));
          _setIds[item.id!] = List.generate(_items[idx].sets, (_) => 0);
        }
      }
    });
    if (_day?.weekNumber != null) await DatabaseHelper.instance.replaceExerciseInMonth(profileId: widget.profileId, oldItemId: original.id!, newItemId: newExercise.id!, reason: reasonCode, permanent: permanent);
    _showMessage('Заменено на «${newExercise.name}» во всем месяце');
  }

  Widget _buildReasonSheet(BuildContext ctx) {
    final theme = Theme.of(ctx);
    final reasons = [
      ('no_equipment', 'Нет оборудования', Icons.block_rounded, theme.colorScheme.error),
      ('too_hard', 'Слишком тяжело', Icons.trending_down_rounded, const Color(0xFFE17055)),
      ('too_easy', 'Слишком легко', Icons.trending_up_rounded, const Color(0xFF00B894)),
      ('dislike', 'Не нравится', Icons.thumb_down_rounded, const Color(0xFFFDCB6E)),
      ('other', 'Другое (вручную)', Icons.search_rounded, theme.colorScheme.primary)
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Почему заменить?', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Приложение подберёт замену с учётом причины', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ...reasons.map((r) {
            final (code, label, icon, color) = r;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.1))),
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
            TextField(controller: setsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Подходы', prefixIcon: Icon(Icons.repeat_rounded))),
            const SizedBox(height: 12),
            TextField(controller: repsController, decoration: InputDecoration(labelText: isTimed ? 'Время (например, 60 сек)' : 'Повторения (например, 10-12)', prefixIcon: const Icon(Icons.numbers_rounded))),
            const SizedBox(height: 12),
            TextField(controller: restController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Отдых (сек)', prefixIcon: Icon(Icons.timer_rounded))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить'))
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
    final newSetId = await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: item.id!, order: newOrder, reps: defaultReps, completed: false));
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red)))
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
        final newId = await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: item.id!, order: 1, completed: true));
        if (mounted) setState(() => ids[0] = newId);
      } else {
        await DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(id: ids.first, workoutExerciseId: item.id!, order: 1, completed: true));
      }
    }
    setState(() => _setsData[item.id!] = [SetData(completed: true)]);
    _showMessage('Заминка выполнена ✓');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(icon: const Icon(Icons.timer_rounded), tooltip: 'Время отдыха', onPressed: _started ? _showRestTimePicker : null),
          if (_started) IconButton(tooltip: _hasBlocks ? 'Убрать блоки' : 'Сформировать блоки', onPressed: _isViewMode || _day?.type == 'challenge' ? null : _toggleBlocks, icon: Icon(_hasBlocks ? Icons.grid_off_rounded : Icons.grid_view_rounded, color: _hasBlocks ? Theme.of(context).colorScheme.primary : null)),
          if (_isInProgressMode) TextButton.icon(onPressed: _finishWorkout, icon: const Icon(Icons.check_rounded), label: const Text('Завершить')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
        if (_isRestTimerRunning) _buildTopRestTimer(context),
        Expanded(child: _buildContent(context))
      ]),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(children: [
          Icon(_isRestTimerPaused ? Icons.pause_circle_filled_rounded : Icons.timer_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isRestTimerPaused ? 'Пауза' : 'Отдых', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))
          ]),
          const Spacer(),
          IconButton(icon: Icon(_isRestTimerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white), onPressed: _togglePauseRestTimer),
          TextButton(onPressed: _stopRestTimer, style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Пропустить', style: TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.white.withOpacity(0.3), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))),
      ]),
    );
  }

  Widget _buildContent(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (_isViewMode) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Column(children: [
          _buildCompletedBanner(context),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _saveAsTemplate, icon: const Icon(Icons.bookmark_add_rounded), label: const Text('Сохранить как шаблон'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))
        ]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: _buildInfoCard(context))),
        if (_isNewMode) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _blocksReady ? null : () => _createBlocks(), icon: const Icon(Icons.grid_view_rounded, size: 18), label: Text(_blocksReady ? 'Блоки созданы' : 'Создать блоки', style: const TextStyle(fontSize: 13)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _blocksReady ? _resetBlocks : null, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Сбросить', style: TextStyle(fontSize: 13)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))
        ]))),
        if (_isNewMode) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 12, left: 16, right: 16), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _startWorkout, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Начать тренировку'))))),
        if (_hasBlocks) ..._buildCircuitsSlivers(context) else ..._buildUnblockedList(context),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  List<Widget> _buildUnblockedList(BuildContext context) {
    final List<WorkoutExercise> displayItems = [];
    final warmups = _items.where((i) => i.isWarmup).toList();
    final coolDowns = _items.where((i) => i.isCoolDown).toList();
    final strength = _items.where((i) {
      if (i.isCoolDown || i.isWarmup) return false;
      final ex = _exerciseMap[i.replacedByItemId ?? i.itemId];
      return ex != null && !_isCardio(ex);
    }).toList();
    final cardio = _items.where((i) {
      if (i.isCoolDown || i.isWarmup) return false;
      final ex = _exerciseMap[i.replacedByItemId ?? i.itemId];
      return ex != null && _isCardio(ex);
    }).toList();

    if (_profile?.goal == 'lose_weight') {
      int sIdx = 0;
      int cIdx = 0;
      int strengthCounter = 0;
      while (sIdx < strength.length || cIdx < cardio.length) {
        if (sIdx < strength.length) {
          displayItems.add(strength[sIdx++]);
          strengthCounter++;
          if (strengthCounter == 3 && cIdx < cardio.length) {
            displayItems.add(cardio[cIdx++]);
            strengthCounter = 0;
          }
        } else if (cIdx < cardio.length) {
          displayItems.add(cardio[cIdx++]);
        }
      }
    } else {
      displayItems.addAll(strength);
      displayItems.addAll(cardio);
    }

    return [
      if (warmups.isNotEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: _buildWarmupCard(context, warmups))),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, i) => _buildItemCard(context, displayItems[i], index: i + 1),
            childCount: displayItems.length,
          ),
        ),
      ),
      if (coolDowns.isNotEmpty) ...[
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF00B894).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Text('Заминка', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF00B894))))]))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, idx) => _buildStretchCard(context, coolDowns[idx]), childCount: coolDowns.length))),
      ],
    ];
  }

  Widget _buildWarmupCard(BuildContext context, List<WorkoutExercise> warmups) {
    final theme = Theme.of(context);
    final done = warmups.where((w) => _setsData[w.id!]?.first.completed == true).length;
    final total = warmups.length;
    final allDone = done == total && total > 0;
    final accent = const Color(0xFFFFB800);

    return Card(
      margin: EdgeInsets.zero,
      color: accent.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: accent.withOpacity(0.3))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openWarmupScreen(warmups),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: [accent, accent.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)), child: Icon(allDone ? Icons.check_rounded : Icons.local_fire_department_rounded, color: Colors.white, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Разминка', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text('Махи и вращения · 3 мин', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('$done/$total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: accent))),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCircuitsSlivers(BuildContext context) {
    final slivers = <Widget>[];
    final Map<int, List<WorkoutExercise>> blocks = {};
    final List<WorkoutExercise> warmups = [];
    final List<WorkoutExercise> coolDowns = [];
    final List<WorkoutExercise> cardios = [];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isWarmup) { warmups.add(item); continue; }
      if (item.isCoolDown) { coolDowns.add(item); continue; }
      final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
      final isCardio = ex != null && _isCardio(ex);
      if (isCardio) {
        cardios.add(item);
      } else {
        final blockNum = _pendingBlocks[i] ?? 99;
        blocks.putIfAbsent(blockNum, () => []);
        blocks[blockNum]!.add(item);
      }
    }

    if (warmups.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: _buildWarmupCard(context, warmups))));
    }

    final bool isWeightLoss = _profile?.goal == 'lose_weight';
    final bool shouldInterleave = isWeightLoss && cardios.isNotEmpty;
    final sortedBlockNums = blocks.keys.toList()..sort();
    int cardioIndex = 0;

    void addBlockToSlivers(int blockNum) {
      final blockItems = blocks[blockNum]!;
      for (int circle = 0; circle < 3; circle++) {
        final circleNum = circle + 1;
        final isComplete = _isCircleComplete(blockItems, circle) && _started;
        final completed = _completedInCircle(blockItems, circle);
        final total = blockItems.length;
        final isCollapsed = _isCircleCollapsed(blockNum, circleNum);
        slivers.add(SliverToBoxAdapter(child: CircleHeader(blockNum: blockNum, circleNum: circleNum, circleIndex: circle, blockItems: blockItems, completed: completed, total: total, isComplete: isComplete, isCollapsed: isCollapsed, onToggle: () => _toggleCircle(blockNum, circleNum), started: _started, isViewMode: _isViewMode, onMarkCircleCompleted: (b, c) => _markCircleCompleted(blockItems: blockItems, blockNum: b, circleIndex: c))));
        if (!isCollapsed) {
          slivers.add(SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, idx) => _buildExerciseCardWidget(context, blockItems[idx], _exerciseMap[blockItems[idx].replacedByItemId ?? blockItems[idx].itemId]!, circleIndex: circle), childCount: blockItems.length))));
        }
      }
      if (_started && !_isViewMode) {
        slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), child: OutlinedButton.icon(onPressed: () => _addCircle(blockItems: blockItems, blockNum: blockNum), icon: const Icon(Icons.add_circle_outline_rounded), label: Text('Добавить круг в Блок $blockNum'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: Color(0xFF6C5CE7), width: 2), foregroundColor: const Color(0xFF6C5CE7))))));
      }
    }

    void addCardioToSlivers(WorkoutExercise item) {
      final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
      if (ex != null) {
        slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _buildExerciseCardWidget(context, item, ex))));
      }
    }

    if (shouldInterleave) {
      for (int i = 0; i < sortedBlockNums.length; i++) {
        addBlockToSlivers(sortedBlockNums[i]);
        if (cardioIndex < cardios.length) {
          slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE17055).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Text('Кардио / Добивка', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFE17055))))]))));
          addCardioToSlivers(cardios[cardioIndex++]);
        }
      }
      if (cardioIndex < cardios.length) {
        slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE17055).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Text('Кардио / Добивка', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFE17055))))]))));
        while (cardioIndex < cardios.length) {
          addCardioToSlivers(cardios[cardioIndex++]);
        }
      }
    } else {
      for (final blockNum in sortedBlockNums) {
        addBlockToSlivers(blockNum);
      }
      if (cardios.isNotEmpty) {
        slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE17055).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Text('Кардио / Добивка', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFE17055))))]))));
        for (final item in cardios) {
          addCardioToSlivers(item);
        }
      }
    }

    if (coolDowns.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF00B894).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Text('Заминка', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF00B894))))]))));
      slivers.add(SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, idx) => _buildStretchCard(context, coolDowns[idx]), childCount: coolDowns.length))));
    }

    return slivers;
  }

  Widget _buildExerciseCardWidget(BuildContext context, WorkoutExercise item, Exercise ex, {int? circleIndex, int? index}) {
    final sets = _setsData[item.id!] ?? [];
    return ExerciseCard(
      item: item,
      ex: ex,
      circleIndex: circleIndex,
      index: index,
      isViewMode: _isViewMode,
      started: _started,
      sets: sets,
      lastWeight: _lastRecords[item.id]?['weight'] as double?,
      lastReps: _lastRecords[item.id]?['reps'] as int?,
      onSetChanged: (index, data) async {
        if (item.id == null || _isViewMode) return;

        setState(() {
          final setsList = _setsData[item.id!];
          if (setsList != null && index >= 0 && index < setsList.length) setsList[index] = data;
        });

        final ids = _setIds[item.id!];
        if (ids != null && index < ids.length) {
          if (ids[index] == 0) {
            final newId = await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
              workoutExerciseId: item.id!, order: index + 1,
              weight: data.weight, reps: data.reps, completed: data.completed,
            ));
            if (mounted) setState(() => ids[index] = newId);
          } else {
            await DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(
              id: ids[index], workoutExerciseId: item.id!, order: index + 1,
              weight: data.weight, reps: data.reps, completed: data.completed,
            ));
          }
        }
      },
      onSetComplete: () => _startRestTimer(),
      onAddSet: () => _addSetToExercise(item),
      onDeleteSet: (i) => _deleteSetFromExercise(item, i),
      onOpenMenu: () => _openExerciseMenu(item, ex),
      onTryAutoCollapse: (idx) => _tryAutoCollapse(item, idx),
      getBaseZone: _getBaseZone,
      isBase: isBaseExercise,
      groupLabel: _groupLabel,
      isCardio: _isCardio,
      isTimed: _isTimed,
      parseReps: _parseReps,
    );
  }

  Widget _buildItemCard(BuildContext context, WorkoutExercise item, {int? index}) {
    if (item.itemType == 'exercise') {
      final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
      if (ex == null) return const SizedBox.shrink();
      return _buildExerciseCardWidget(context, item, ex, index: index);
    } else {
      return _buildStretchCard(context, item);
    }
  }

  Widget _buildStretchCard(BuildContext context, WorkoutExercise item) {
    final theme = Theme.of(context);
    final st = _stretchMap[item.itemId];
    if (st == null) return const SizedBox.shrink();
    final sets = _setsData[item.id!] ?? [SetData(completed: false)];
    final isDone = sets.isNotEmpty && sets.first.completed;
    const accent = Color(0xFF00B894);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: (_started && !_isViewMode) ? () => _startStretchTimer(item, st) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [accent, Color(0xFF55EFC4)]), borderRadius: BorderRadius.circular(12)), child: Icon(isDone ? Icons.check_rounded : Icons.self_improvement, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(st.name, style: theme.textTheme.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StretchDetailScreen(stretch: st))), borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.info_outline_rounded, size: 20, color: theme.colorScheme.primary)))
              ]),
              const SizedBox(height: 2),
              Text('${st.durationLabel}${st.bothSides ? " × 2 стороны" : ""}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ])),
            if (isDone)
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.check_circle_rounded, color: accent, size: 20))
            else
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('Заминка', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }

  Widget _buildCompletedBanner(BuildContext context) {
    final day = _day;
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final dateStr = day != null ? '${day.date.day} ${months[day.date.month - 1]} ${day.date.year}' : '';
    final minutes = day?.durationMinutes ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55EFC4)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF00B894).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Тренировка завершена ✓', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('$dateStr · $minutes мин', style: const TextStyle(color: Colors.white70, fontSize: 12))
        ]))
      ]),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final mainCount = _items.where((i) => !i.isCoolDown && !i.isWarmup).length;
    final idToItem = <int, WorkoutExercise>{};
    for (final it in _items) {
      if (it.id != null) idToItem[it.id!] = it;
    }
    int completedSets = 0;
    int totalSets = 0;
    for (final entry in _setsData.entries) {
      final item = idToItem[entry.key];
      if (item == null || item.isWarmup || item.isCoolDown) continue;
      for (final s in entry.value) {
        totalSets++;
        if (s.completed) completedSets++;
      }
    }
    final minutesText = _isViewMode ? '${_day?.durationMinutes ?? 0}' : '${_profile?.sessionMinutes ?? 45}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.7)]), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        _infoItem(context, Icons.fitness_center, '$mainCount', 'упражнений'),
        _infoDivider(),
        _infoItem(context, Icons.check_circle_rounded, '$completedSets/$totalSets', 'подходов'),
        _infoDivider(),
        _infoItem(context, Icons.timer, minutesText, 'минут')
      ]),
    );
  }

  Widget _infoItem(BuildContext context, IconData icon, String value, String label) => Expanded(child: Column(children: [
    Icon(icon, color: Colors.white, size: 22),
    const SizedBox(height: 6),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))
  ]));
  Widget _infoDivider() => Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2));

  void _showRestTimePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Время отдыха', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [30, 45, 60, 90, 120].map((sec) => ChoiceChip(label: Text('$sec сек'), selected: _globalRestSeconds == sec, onSelected: (_) async {
            setState(() => _globalRestSeconds = sec);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('global_rest_seconds', sec);
            Navigator.pop(ctx);
          })).toList())
        ]),
      ),
    );
  }

  Future<void> _markCircleCompleted({required List<WorkoutExercise> blockItems, required int blockNum, required int circleIndex}) async {
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
          final newId = await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: item.id!, order: circleIndex + 1, weight: updated.weight, reps: updated.reps, completed: true));
          if (mounted) setState(() => ids[circleIndex] = newId);
        } else {
          updates.add(DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(id: ids[circleIndex], workoutExerciseId: item.id!, order: circleIndex + 1, weight: updated.weight, reps: updated.reps, completed: true)));
        }
      }
    }
    if (!hasChanges) return;
    final key = _circleKey(blockNum, circleIndex + 1);
    if (!_collapsedCircles.contains(key)) setState(() => _collapsedCircles.add(key));
    if (updates.isNotEmpty) await Future.wait(updates);
    if (blockItems.isNotEmpty && _started && !_isViewMode) _startRestTimer();
  }

  Future<void> _addCircle({required List<WorkoutExercise> blockItems, required int blockNum}) async {
    if (!_started || _isViewMode) return;
    for (final item in blockItems) {
      if (item.id == null || item.isCoolDown || item.isWarmup) continue;
      final ex = _exerciseMap[item.replacedByItemId ?? item.itemId];
      if (ex != null && _isCardio(ex)) continue;
      await _addSetToExercise(item);
    }
  }

  void _tryAutoCollapse(WorkoutExercise item, int circleIndex) {
    if (!_hasBlocks) return;
    final idx = _items.indexOf(item);
    if (idx < 0) return;
    final blockNum = _pendingBlocks[idx] ?? 1;
    final blockItems = <WorkoutExercise>[];
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].isCoolDown || _items[i].isWarmup) continue;
      if ((_pendingBlocks[i] ?? 1) != blockNum) continue;
      blockItems.add(_items[i]);
    }
    if (_isCircleComplete(blockItems, circleIndex) && _started) {
      final key = _circleKey(blockNum, circleIndex + 1);
      if (!_collapsedCircles.contains(key)) setState(() => _collapsedCircles.add(key));
    }
  }

  Future<void> _openWarmupScreen(List<WorkoutExercise> warmups) async {
    if (warmups.isEmpty) return;
    final result = await Navigator.push<Map<int, List<SetData>>>(
      context,
      MaterialPageRoute(builder: (_) => WarmupScreen(warmups: warmups, stretchMap: _stretchMap, setsData: _setsData, setIds: _setIds, started: _started)),
    );
    if (result == null || result.isEmpty || !mounted) return;
    final updates = <Future>[];
    for (final entry in result.entries) {
      final itemId = entry.key;
      final newSets = entry.value;
      if (newSets.isEmpty) continue;
      final ids = _setIds[itemId];
      final first = newSets.first;
      if (ids != null && ids.isNotEmpty && ids.first > 0) {
        updates.add(DatabaseHelper.instance.updateWorkoutSet(WorkoutSet(id: ids.first, workoutExerciseId: itemId, order: 1, weight: first.weight, reps: first.reps, completed: first.completed)));
      } else {
        updates.add(DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: itemId, order: 1, weight: first.weight, reps: first.reps, completed: first.completed)));
      }
    }
    setState(() {
      for (final entry in result.entries) {
        _setsData[entry.key] = entry.value;
      }
    });
    if (updates.isNotEmpty) await Future.wait(updates);
  }
}

class _StretchTimerDialog extends StatefulWidget {
  final String name;
  final int totalSeconds;
  final bool bothSides;
  const _StretchTimerDialog({required this.name, required this.totalSeconds, required this.bothSides});

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
      if (!mounted || _paused) return;
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.totalSeconds > 0 ? _remaining / widget.totalSeconds : 0.0;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.name, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          SizedBox(width: 140, height: 140, child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 140, height: 140, child: CircularProgressIndicator(value: progress, strokeWidth: 8, backgroundColor: theme.colorScheme.primary.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(_finished ? const Color(0xFF00B894) : _paused ? const Color(0xFFFDCB6E) : theme.colorScheme.primary))),
            Text(_finished ? '✓' : '$_remaining', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: _finished ? const Color(0xFF00B894) : _paused ? const Color(0xFFFDCB6E) : theme.colorScheme.primary)),
          ])),
          const SizedBox(height: 8),
          if (_paused && !_finished) Padding(padding: const EdgeInsets.only(top: 8), child: Text('⏸ Пауза', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFFDCB6E), fontWeight: FontWeight.w700))),
          if (widget.bothSides && !_finished) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Выполните для обеих сторон', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)))),
          const SizedBox(height: 20),
          if (!_finished) SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => setState(() => _paused = !_paused), icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 22), label: Text(_paused ? 'Продолжить' : 'Пауза'), style: OutlinedButton.styleFrom(foregroundColor: _paused ? theme.colorScheme.primary : const Color(0xFFFDCB6E), side: BorderSide(color: _paused ? theme.colorScheme.primary.withOpacity(0.5) : const Color(0xFFFDCB6E).withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 12)))),
          if (!_finished) const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: _finished ? const Color(0xFF00B894) : theme.colorScheme.primary), child: Text(_finished ? 'Готово ✓' : 'Завершить'))),
          ]),
        ]),
      ),
    );
  }
}
// ═══ КОНЕЦ ФАЙЛА workout_detail_screen.dart ═══