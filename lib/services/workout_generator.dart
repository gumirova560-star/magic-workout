import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../models/stretch.dart';
import '../models/user_profile.dart';
import '../models/workout_day.dart';
import '../data/base_exercises.dart';
import 'database_helper.dart';
import 'week_analyzer.dart';

class WorkoutGenerator {
static Random _random = Random();

static void setSeed(int seed) {
_random = Random(seed);
}

static const Map<String, List<String>> _zoneExpand = {
'legs': ['quads', 'hamstrings', 'legs', 'calves', 'feet'],
'glutes': ['glutes', 'hamstrings'],
'abs': ['abs', 'obliques', 'core'],
'chest': ['chest'],
'back': ['back', 'lats', 'traps', 'lower_back'],
'arms': ['arms', 'biceps', 'triceps', 'forearms'],
'shoulders': ['shoulders', 'traps'],
};

static const Map<String, List<String>> _adjacentZones = {
'glutes': ['legs', 'abs'],
'legs': ['glutes', 'abs'],
'abs': ['glutes', 'legs'],
'chest': ['shoulders', 'arms'],
'back': ['shoulders', 'arms'],
'shoulders': ['chest', 'back'],
'arms': ['chest', 'back'],
};

static String _norm(String s) => s;

static Set<String> _buildBlockedZones(List<String> limitations) {
final blocked = zonesBlockedByLimitations(limitations).toSet();
for (final lim in limitations) {
blocked.add(_norm(lim).toLowerCase());
}
return blocked;
}

static bool _isBlocked(Exercise e, Set<String> blockedZones) {
if (blockedZones.isEmpty) return false;
if (exerciseBlockedByLimitations(e, blockedZones.toList())) return true;
for (final m in e.muscleGroups) {
if (blockedZones.contains(m)) return true;
for (final zone in blockedZones) {
if ((_zoneExpand[zone] ?? const <String>[]).contains(m)) return true;
}
}
return false;
}

static bool _isExcludedForGym(String exerciseName) {
final lower = exerciseName.toLowerCase();
const excludedWords = [
'полотенц', 'мячик', 'пальц', 'внешней стороне стопы', 'вакуум',
'танц', 'бой с тенью',
'джеки', 'джампинг джек'
];
return excludedWords.any((w) => lower.contains(w));
}

static Future<List<WorkoutDay>> generateMonthPlan(
UserProfile profile, {
bool smart = true,
}) async {
if (profile.id == null) throw Exception('Profile ID обязателен');

final db = await DatabaseHelper.instance.database;
final profileRows = await db.query(
'user_profiles',
columns: ['id'],
where: 'id = ?',
whereArgs: [profile.id],
);
if (profileRows.isEmpty) {
throw StateError('Профиль id=${profile.id} не найден в базе');
}

final maxCycle = await DatabaseHelper.instance.getMaxCycleNumber(profile.id!);
final newCycle = maxCycle + 1;

final rawExercises = await DatabaseHelper.instance.getExercises();
final Map<int, Exercise> exerciseById = {
for (final ex in rawExercises)
if (ex.id != null) ex.id!: ex,
};

final prefs = await SharedPreferences.getInstance();
final allowBaseChange =
prefs.getBool('allow_base_change_${profile.id}_$maxCycle') ?? false;
final bool shouldChangeBase = allowBaseChange;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
final bool hasWorkoutToday = await _hasWorkoutToday(profile.id!);
final weekdaySlots = await _resolveWeekdaySlots(
profile,
now.weekday,
hasWorkoutToday: hasWorkoutToday,
);

final Map<int, List<Exercise>> baseToKeepByDay = {};
final Set<int> oldBaseIds = {};

int setsAdjustment = 0;
if (smart) {
try {
final missed = await WeekAnalyzer.missedLastWeek(profile.id!);
if (missed >= 2) setsAdjustment = -1;
} catch (_) {}
}

final Map<int, double> lastWeightByExercise = {};
final Map<int, int> lastRepsByExercise = {};
if (smart) {
try {
final weightRows = await db.rawQuery('''
          SELECT COALESCE(we.replacedByItemId, we.itemId) AS exerciseId,
                 MAX(ws.weight) AS maxWeight,
                 MAX(ws.reps)   AS maxReps
          FROM workout_sets ws
          JOIN workout_exercises we ON we.id = ws.workoutExerciseId
          JOIN workout_days wd      ON wd.id = we.workoutDayId
          WHERE wd.profileId = ?
            AND ws.completed = 1
            AND ws.weight IS NOT NULL
            AND ws.weight > 0
            AND we.itemType = 'exercise'
          GROUP BY COALESCE(we.replacedByItemId, we.itemId)
        ''', [profile.id]);
for (final row in weightRows) {
final exId = row['exerciseId'];
if (exId is! int) continue;
final w = row['maxWeight'];
if (w is num && w > 0) lastWeightByExercise[exId] = w.toDouble();
final r = row['maxReps'];
if (r is num) lastRepsByExercise[exId] = r.toInt();
}

for (final entry in lastWeightByExercise.entries) {
final key = 'last_weight_${profile.id}_${entry.key}';
final stored = prefs.getDouble(key) ?? 0.0;
if (entry.value > stored) await prefs.setDouble(key, entry.value);
}
for (final entry in lastRepsByExercise.entries) {
final key = 'last_reps_${profile.id}_${entry.key}';
final stored = prefs.getInt(key) ?? 0;
if (entry.value > stored) await prefs.setInt(key, entry.value);
}
} catch (_) {}
}

double? weightFor(int? exId) {
if (exId == null) return null;
final fromDb = lastWeightByExercise[exId];
if (fromDb != null && fromDb > 0) return fromDb;
final stored = prefs.getDouble('last_weight_${profile.id}_$exId');
return (stored != null && stored > 0) ? stored : null;
}

if (maxCycle > 0) {
final prevWeeks = await DatabaseHelper.instance.getWorkoutDaysByWeek(
profileId: profile.id!, weekNumber: 4, cycleNumber: maxCycle,
);

if (prevWeeks.isNotEmpty) {
prevWeeks.sort((a, b) => a.date.compareTo(b.date));
for (int dayIdx = 0; dayIdx < prevWeeks.length; dayIdx++) {
final pd = prevWeeks[dayIdx];
final exs = await DatabaseHelper.instance.getWorkoutExercises(pd.id!);
final dayBases = <Exercise>[];

for (final we in exs) {
if (we.itemType == 'exercise' && !we.isCoolDown && !we.isWarmup) {
final ex = exerciseById[we.replacedByItemId ?? we.itemId];
if (ex != null &&
isBaseExercise(ex) &&
!dayBases.any((e) => e.id == ex.id)) {
dayBases.add(ex);
if (ex.id != null) oldBaseIds.add(ex.id!);
}
}
}

if (!shouldChangeBase) {
baseToKeepByDay[dayIdx] = dayBases;
}
}
}
}

await DatabaseHelper.instance.deleteUnfinishedWorkoutDays(profile.id!);

final focusGroups = _getFocusGroups(profile);
// 👇 НОВОЕ: флаг дома — нужен для всех ветвлений ниже
final bool isHome = profile.equipment == 'home';
final cardioMode = _computeCardioMode(focusGroups, profile.goal);
final dayPlans = _createDayTemplates(
focusGroups,
profile.daysPerWeek,
profile.limitations,
equipment: profile.equipment,          // 👈 НОВОЕ
bodyType: profile.bodyType,            // 👈 НОВОЕ
);

final Map<String, Exercise> uniqueExercisesMap = {};
for (final ex in rawExercises) {
final cleanName = ex.name
.toLowerCase()
.replaceAll('ё', 'е')
.replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
uniqueExercisesMap.putIfAbsent(cleanName, () => ex);
}
final allExercises = uniqueExercisesMap.values.toList();

final allStretches = await DatabaseHelper.instance.getStretches();

final monthBases = <List<Exercise>>[];
final usedBaseIds = <int>{...oldBaseIds};
final Set<String> usedFamiliesInMonth = {};

final int targetStrength =
_getExerciseCount(profile.sessionMinutes, profile.level);
int maxBases = (targetStrength / 3).ceil();
if (profile.level == 'beginner') {
maxBases = 2;
}

for (int i = 0; i < dayPlans.length; i++) {
// 👇 ДОМ: паттерны вместо зон, без изоляции и доборов
if (isHome) {
final patterns = dayPlans[i];
if (patterns.length == 1 && patterns.first == 'cardio') {
monthBases.add(<Exercise>[]);
continue;
}
final dayIndexGlobal = (newCycle - 1) * profile.daysPerWeek + i;
final bases = _pickByPattern(
allExercises: allExercises,
patterns: patterns,
equipment: profile.equipment,
homeEquipment: profile.homeEquipment,
level: profile.level,
limitations: profile.limitations,
usedIds: usedBaseIds,
usedFamilies: usedFamiliesInMonth,
focusZones: focusGroups,
dayIndex: dayIndexGlobal,
sessionMinutes: profile.sessionMinutes,
daysPerWeek: profile.daysPerWeek,
);
for (final ex in bases) {
if (ex.id != null) usedBaseIds.add(ex.id!);
usedFamiliesInMonth.add(familyOf(ex));
}
monthBases.add(bases);
continue;
}

// ═══ ЗАЛ: старая логика без изменений ═══
var bases = _pickBasesForDay(
allExercises: allExercises,
baseToKeep: baseToKeepByDay[i] ?? [],
muscleGroups: dayPlans[i],
equipment: profile.equipment,
homeEquipment: profile.homeEquipment,
level: profile.level,
limitations: profile.limitations,
usedBaseIds: usedBaseIds,
oldBaseIds: oldBaseIds,
usedFamiliesInMonth: usedFamiliesInMonth,
maxBases: maxBases,
);

if (bases.length < maxBases && dayPlans[i].isNotEmpty) {
final blocked = _buildBlockedZones(profile.limitations);
final extraCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (bases.any((b) => b.id == e.id)) return false;
if (usedBaseIds.contains(e.id)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, profile.equipment,
homeEquipment: profile.homeEquipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) {
return false;
}
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (!e.muscleGroups.any((m) => dayPlans[i].contains(m))) return false;
return true;
}).toList()..shuffle(_random);

for (final extra in extraCandidates) {
if (bases.length >= maxBases) break;
bases.add(extra);
if (extra.id != null) usedBaseIds.add(extra.id!);
}
}

for (final ex in bases) {
if (ex.id != null) usedBaseIds.add(ex.id!);
}
for (final ex in bases) {
usedFamiliesInMonth.add(familyOf(ex));
}

monthBases.add(bases);
}

// ═══ КОНЕЦ ЧАСТИ 1 ═══
final createdDays = <WorkoutDay>[];

final List<Set<int>> recentIsolationIds = [];
final List<Set<String>> recentIsolationFamilies = [];
final Set<int> usedCardioThisWeek = {};
final Set<int> usedBonusIds = {};
String? lastBonusZone;

final int isolationWindowDays = profile.daysPerWeek * 2;

for (int week = 1; week <= 4; week++) {
if (usedCardioThisWeek.length > 6) {
usedCardioThisWeek.clear();
}

for (int dayIndex = 0; dayIndex < dayPlans.length; dayIndex++) {
final dayGroups = dayPlans[dayIndex];
final baseExercises = monthBases[dayIndex];

final bool hasCardioMachine = profile.equipment == 'gym' ||
profile.equipment == 'mixed' ||
profile.equipment == 'both' ||
(profile.equipment == 'home' &&
profile.homeEquipment.any((eq) =>
['treadmill', 'elliptical', 'bike', 'rower', 'stepper']
.contains(eq)));
Exercise? warmupCardioEx;
if (hasCardioMachine) {
final warmupCardioList = allExercises
.where((e) =>
(e.name.contains('дорожк') ||
e.name.contains('велотренаж') ||
e.name.contains('эллипс')) &&
matchesEquipment(e, profile.equipment,
homeEquipment: profile.homeEquipment))
.toList()
..shuffle(_random);
if (warmupCardioList.isNotEmpty) warmupCardioEx = warmupCardioList.first;
}

// 👇 ДОМ: изоляции нет, паттерны уже дали 5-7 упражнений
final isolationExercises = isHome
? <Exercise>[]
: _pickIsolationForDay(
allExercises: allExercises,
muscleGroups: dayGroups,
bases: baseExercises,
equipment: profile.equipment,
homeEquipment: profile.homeEquipment,
level: profile.level,
limitations: profile.limitations,
maxCount: targetStrength + 4,
recentDayIds: recentIsolationIds,
repeatWindowSize: isolationWindowDays,
recentDayFamilies: recentIsolationFamilies,
);

final dayExercises = [...baseExercises, ...isolationExercises];
final blocked = _buildBlockedZones(profile.limitations);

final dayCardios = <Exercise>[];
if (cardioMode == 'every_day' && dayGroups.isNotEmpty) {
final uniqueCardio = allExercises.where((e) {
if (e.id == null || usedCardioThisWeek.contains(e.id)) return false;
if (warmupCardioEx != null && e.id == warmupCardioEx.id) return false;
if (!_isCardio(e)) return false;
if (!matchesEquipment(e, profile.equipment,
homeEquipment: profile.homeEquipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) {
return false;
}
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (_isBlocked(e, blocked)) return false;
return true;
}).toList()..shuffle(_random);

final fallbackCardio = allExercises.where((e) {
if (e.id == null) return false;
if (warmupCardioEx != null && e.id == warmupCardioEx.id) return false;
if (!_isCardio(e)) return false;
if (!matchesEquipment(e, profile.equipment,
homeEquipment: profile.homeEquipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) {
return false;
}
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (_isBlocked(e, blocked)) return false;
return true;
}).toList()..shuffle(_random);

final cardioCandidates = [...uniqueCardio, ...fallbackCardio];
final bool isCardioOnlyDay = dayGroups.isEmpty ||
(dayGroups.length == 1 && dayGroups.first == 'cardio');

final bool isLoseWeight = profile.goal == 'lose_weight' ||
profile.goal.contains('weight') ||
profile.goal.contains('lose');
final int baseCardioCount = isLoseWeight ? 3 : 1;

// 👇 ДОМ: кардио — финишер, 1 упражнение
final int cardioCount;
if (isCardioOnlyDay) {
cardioCount = (profile.sessionMinutes / 10).round().clamp(2, 6);
} else if (isHome) {
cardioCount = 1;
} else if (profile.level == 'beginner') {
cardioCount = isLoseWeight ? 2 : 1;
} else {
cardioCount = baseCardioCount;
}

final Set<String> addedCardioNames = {};
for (final ex in cardioCandidates) {
if (dayCardios.length >= cardioCount) break;
final normName = _normalizeName(ex.name);
if (addedCardioNames.contains(normName)) continue;
dayCardios.add(ex);
addedCardioNames.add(normName);
if (ex.id != null) usedCardioThisWeek.add(ex.id!);
}
}

final List<Exercise> combinedList = [...dayExercises, ...dayCardios];
final uniqueExercises = <Exercise>[];
final Set<int> seenIds = {};
final Set<String> seenNames = {};

for (final ex in combinedList) {
if (ex.id == null) continue;
if (seenIds.contains(ex.id)) continue;
final normName = _normalizeName(ex.name);
if (seenNames.contains(normName)) continue;
seenIds.add(ex.id!);
seenNames.add(normName);
uniqueExercises.add(ex);
}

final strengthList = uniqueExercises.where((e) => !_isCardio(e)).toList();
final cardioList = uniqueExercises.where((e) => _isCardio(e)).toList();

// 👇 Для дома не обрезаем до targetStrength — там 5 паттернов + 1-2 фокуса,
// их не надо резать. Логику добора/обрезки применяем только для зала.
if (!isHome) {
if (strengthList.length > targetStrength) {
strengthList.removeRange(targetStrength, strengthList.length);
}
if (strengthList.length < targetStrength) {
final remaining = targetStrength - strengthList.length;
final Set<int> recentIds = {};
for (int r = 0; r < recentIsolationIds.length && r < 2; r++) {
recentIds.addAll(recentIsolationIds[r]);
}
final dayFamilies = <String>{
for (final e in strengthList) familyOf(e),
};
final extras = allExercises.where((e) {
if (strengthList.any((u) => u.id == e.id)) return false;
if (recentIds.contains(e.id)) return false;
if (_isCardio(e)) return false;
if (_isBlocked(e, blocked)) return false;
if (dayGroups.isNotEmpty &&
!e.muscleGroups.any((m) => dayGroups.contains(m))) return false;
if (dayFamilies.contains(familyOf(e))) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (!matchesEquipment(e, profile.equipment,
homeEquipment: profile.homeEquipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) {
return false;
}
return true;
}).toList()..shuffle(_random);

for (int i = 0; i < remaining && i < extras.length; i++) {
strengthList.add(extras[i]);
dayFamilies.add(familyOf(extras[i]));
}
}
}

final bool isCardioOnlyDay = dayGroups.isEmpty ||
(dayGroups.length == 1 && dayGroups.first == 'cardio');
final bool isLoseWeightTarget = profile.goal == 'lose_weight' ||
profile.goal.contains('weight') ||
profile.goal.contains('lose');

int targetCardio;
if (isCardioOnlyDay) {
targetCardio = 5;
} else if (cardioMode == 'off') {
targetCardio = 0;
} else if (isHome) {
targetCardio = 1; // 👈 Дом — финишер
} else if (profile.level == 'beginner') {
targetCardio = isLoseWeightTarget ? 2 : 1;
} else {
targetCardio = isLoseWeightTarget ? 3 : 1;
}

if (cardioList.length > targetCardio) {
cardioList.removeRange(targetCardio, cardioList.length);
} else if (cardioList.length < targetCardio) {
final extras = allExercises.where((e) {
if (cardioList.any((u) => u.id == e.id)) return false;
if (warmupCardioEx != null && e.id == warmupCardioEx.id) return false;
if (!_isCardio(e)) return false;
if (_isBlocked(e, blocked)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) {
return false;
}
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (!matchesEquipment(e, profile.equipment,
homeEquipment: profile.homeEquipment)) return false;
return true;
}).toList()..shuffle(_random);
for (int i = 0;
i < targetCardio - cardioList.length && i < extras.length;
i++) {
cardioList.add(extras[i]);
}
}

strengthList.sort((a, b) =>
_getExerciseWeight(a).compareTo(_getExerciseWeight(b)));
cardioList.sort((a, b) =>
_getExerciseWeight(a).compareTo(_getExerciseWeight(b)));

final List<Exercise?> finalOrder = [];
if (!isHome && isLoseWeightTarget && strengthList.isNotEmpty) {
// Зал + похудение: интервальная вставка кардио
final int numBlocks = (strengthList.length / 3).ceil();
final Exercise? lastCardio =
cardioList.isNotEmpty ? cardioList.last : null;
final List<Exercise> cardioBetween = cardioList.length > 1
? cardioList.sublist(0, cardioList.length - 1)
: <Exercise>[];

int sIdx = 0;
int cIdx = 0;
for (int b = 0; b < numBlocks; b++) {
for (int i = 0; i < 3 && sIdx < strengthList.length; i++) {
finalOrder.add(strengthList[sIdx++]);
}
if (b < numBlocks - 1 && cIdx < cardioBetween.length) {
finalOrder.add(cardioBetween[cIdx++]);
}
}
while (cIdx < cardioBetween.length) {
finalOrder.add(cardioBetween[cIdx++]);
}
finalOrder.add(null);
if (lastCardio != null) finalOrder.add(lastCardio);
} else {
// Дом или обычный режим: силовые → финишер в конце
finalOrder.addAll(strengthList);
finalOrder.add(null);
finalOrder.addAll(cardioList);
}

uniqueExercises.clear();
for (final e in finalOrder) {
if (e != null) uniqueExercises.add(e);
}

final dayDate = today.add(Duration(
days: (week - 1) * 7 +
weekdaySlots[dayIndex % weekdaySlots.length]));
bool isChallengeDay = (week == 3 && dayIndex == 1);
final dayType = isChallengeDay ? 'challenge' : 'strength';

// 👇 Названия: дом → «Всё тело A/B/C», зал → «День N: зоны»
String dayName;
if (isChallengeDay) {
dayName = 'Неделя $week: День Челленджа';
} else if (isHome) {
if (isCardioOnlyDay) {
dayName = 'Неделя $week: Кардио-день';
} else {
final letter = ['A', 'B', 'C'][dayIndex % 3];
dayName = 'Неделя $week: Всё тело $letter';
}
} else {
dayName =
'Неделя $week: День ${dayIndex + 1}: ${dayGroups.where((g) => g != 'cardio').map(_groupLabel).join(' + ')}';
}

final day = WorkoutDay(
profileId: profile.id!,
name: dayName,
type: dayType,
weekNumber: week,
cycleNumber: newCycle,
status: 'planned',
durationMinutes: isChallengeDay ? 45 : profile.sessionMinutes,
date: dayDate,
);

final dayId = await DatabaseHelper.instance.createWorkoutDay(day);

if (isChallengeDay) {
lastBonusZone = null;
createdDays.add(day.copyWith(id: dayId));
continue;
}

final baseSets = _getSets(profile.level);
final finalSets = (baseSets + setsAdjustment).clamp(2, 5);
final progression = _getProgressionParams(week, profile.goal,
profile.level, finalSets, _getRest(profile.goal),
_getReps(profile.goal));

int setsCount = progression.sets;

if (warmupCardioEx != null) {
final warmupExId = await DatabaseHelper.instance.addWorkoutExercise(
WorkoutExercise(
workoutDayId: dayId,
itemType: 'exercise',
itemId: warmupCardioEx.id!,
order: 0,
durationSeconds: 300,
isWarmup: true,
sets: 1,
reps: '5 мин',
),
);
await DatabaseHelper.instance.addWorkoutSet(
WorkoutSet(
workoutExerciseId: warmupExId,
order: 1,
completed: false),
);
}

int order = 1;
final warmup = _pickWarmup(allStretches, dayGroups, 8);
for (final stretch in warmup) {
final warmupExId = await DatabaseHelper.instance.addWorkoutExercise(
WorkoutExercise(
workoutDayId: dayId,
itemType: 'stretch',
itemId: stretch.id!,
order: order++,
durationSeconds: stretch.durationSeconds,
isWarmup: true,
),
);
await DatabaseHelper.instance.addWorkoutSet(
WorkoutSet(
workoutExerciseId: warmupExId,
order: 1,
completed: false),
);
}

order = 100;
for (final ex in finalOrder) {
if (ex == null) {
if (order < 151) order = 151;
continue;
}
if (order == 150) order = 151;

final lowerName = ex.name.toLowerCase();
final isJumpRope = lowerName.contains('скакалк') ||
(lowerName.contains('прыжк') && !lowerName.contains('тумбу'));
final isHighIntensityCardio = _isHighIntensityCardio(lowerName);
final isShadowBoxing = lowerName.contains('бой с тенью');
final isBoxJump = lowerName.contains('тумбу');
final isCardio = isCardioOf(ex);

int localSetsCount;
String repsStr;
if (isJumpRope) {
localSetsCount = 3;
repsStr = profile.level == 'beginner' ? '45 сек' : '2 мин';
} else if (isShadowBoxing) {
localSetsCount = 3;
repsStr = profile.level == 'beginner' ? '1 мин' : '3 мин';
} else if (isBoxJump) {
localSetsCount = 3;
repsStr = '12 повт';
} else if (isHighIntensityCardio) {
localSetsCount = 3;
repsStr = profile.level == 'beginner' ? '20 сек' : '30 сек';
} else if (isCardio) {
localSetsCount = 1;
int minutes = 10;
if (isCardioOnlyDay) {
minutes = profile.level == 'beginner' ? 10 : 15;
} else {
if (profile.goal == 'lose_weight') {
minutes = 5;
} else if (profile.goal == 'tone') {
minutes = 10;
} else {
minutes = 10;
}
}
if (profile.level == 'beginner' && minutes > 10) {
minutes = 10;
}
repsStr = '$minutes мин';
} else if (_isTimedExercise(ex.name)) {
localSetsCount = setsCount;
int secs = progression.timedSeconds;
if (lowerName.contains('боковая планка')) {
secs = (secs * 0.7).round();
}
repsStr = '$secs сек';
} else {
localSetsCount = setsCount;
if (isBaseExercise(ex)) {
repsStr = progression.reps;
} else {
if (profile.goal == 'strength' || profile.goal == 'gain_mass') {
repsStr = '10';
} else if (profile.level == 'beginner') {
repsStr = progression.reps;
} else {
repsStr = '15';
}
}
}

final workoutExId =
await DatabaseHelper.instance.addWorkoutExercise(
WorkoutExercise(
workoutDayId: dayId,
itemType: 'exercise',
itemId: ex.id!,
order: order++,
sets: localSetsCount,
reps: repsStr,
restSeconds: progression.rest,
blockNumber: null,
),
);

if (!isCardio && !isJumpRope) {
final int wMode = weightModeOf(ex);
final bool timed = _isTimedExercise(ex.name);
final double? baseWeight =
(!timed && wMode == 2) ? weightFor(ex.id) : null;
int? plannedReps;
if (!timed) {
plannedReps = _parseReps(repsStr);
final int? lastReps = lastRepsByExercise[ex.id];
if (plannedReps != null &&
lastReps != null &&
lastReps > plannedReps) {
plannedReps = lastReps;
}
}

for (int s = 1; s <= localSetsCount; s++) {
await DatabaseHelper.instance.addWorkoutSet(
WorkoutSet(
workoutExerciseId: workoutExId,
order: s,
weight: baseWeight,
reps: plannedReps,
completed: false,
),
);
}
} else if (isJumpRope ||
isHighIntensityCardio ||
isShadowBoxing ||
isBoxJump) {
for (int s = 1; s <= localSetsCount; s++) {
await DatabaseHelper.instance.addWorkoutSet(
WorkoutSet(
workoutExerciseId: workoutExId,
order: s,
weight: null,
reps: null,
completed: false),
);
}
}
}

// ═══ БОНУС НА «ЗАБЫТУЮ ЗОНУ» — только для зала ═══
if (!isHome) {
final allZones = [
'chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'
];
final blockedZones = zonesBlockedByLimitations(profile.limitations);

final forgottenZones = allZones
.where((z) =>
!dayGroups.contains(z) && !blockedZones.contains(z))
.toList();

if (forgottenZones.isNotEmpty) {
var availableZones =
forgottenZones.where((z) => z != lastBonusZone).toList();
if (availableZones.isEmpty) availableZones = forgottenZones;

final zonesToTry = List.from(availableZones)..shuffle(_random);

final dayFamiliesForBonus = <String>{
for (final e in combinedList) familyOf(e),
};

for (final randomZone in zonesToTry) {
var bonusCandidates = allExercises.where((e) {
if (e.id == null || isBaseExercise(e) || _isCardio(e)) {
return false;
}
if (!matchesEquipment(e, profile.equipment,
homeEquipment: profile.homeEquipment)) return false;
if (!_isDifficultyAllowed(
e, profile.level, profile.equipment)) {
return false;
}
if (usedBonusIds.contains(e.id)) return false;
if ((profile.equipment == 'gym' ||
profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (dayFamiliesForBonus.contains(familyOf(e))) return false;
if (_isBlocked(e, blocked)) return false;
return e.muscleGroups.contains(randomZone);
}).toList();

if (bonusCandidates.isEmpty) {
usedBonusIds.clear();
bonusCandidates = allExercises.where((e) {
if (e.id == null || isBaseExercise(e) || _isCardio(e)) {
return false;
}
if (!matchesEquipment(e, profile.equipment,
homeEquipment: profile.homeEquipment)) return false;
if (!_isDifficultyAllowed(
e, profile.level, profile.equipment)) {
return false;
}
if ((profile.equipment == 'gym' ||
profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (dayFamiliesForBonus.contains(familyOf(e))) return false;
if (_isBlocked(e, blocked)) return false;
return e.muscleGroups.contains(randomZone);
}).toList();
}

if (bonusCandidates.isNotEmpty) {
final bonusEx = (bonusCandidates..shuffle(_random)).first;
usedBonusIds.add(bonusEx.id!);
lastBonusZone = randomZone;

String bonusReps;
if (_isTimedExercise(bonusEx.name)) {
int secs = progression.timedSeconds;
if (bonusEx.name.toLowerCase().contains('боковая планка')) {
secs = (secs * 0.7).round();
}
bonusReps = '$secs сек';
} else if (profile.goal == 'strength' ||
profile.goal == 'gain_mass') {
bonusReps = '10';
} else if (profile.level == 'beginner') {
bonusReps = progression.reps;
} else {
bonusReps = '15';
}

final bonusWorkoutExId =
await DatabaseHelper.instance.addWorkoutExercise(
WorkoutExercise(
workoutDayId: dayId,
itemType: 'exercise',
itemId: bonusEx.id!,
order: 150,
sets: setsCount,
reps: bonusReps,
restSeconds: progression.rest,
blockNumber: null,
),
);

final int bonusMode = weightModeOf(bonusEx);
final bool bonusTimed = _isTimedExercise(bonusEx.name);
final double? bonusBaseWeight =
(!bonusTimed && bonusMode == 2)
? weightFor(bonusEx.id)
: null;
int? bonusPlannedReps;
if (!bonusTimed) {
bonusPlannedReps = _parseReps(bonusReps);
final int? bonusLastReps = lastRepsByExercise[bonusEx.id];
if (bonusPlannedReps != null &&
bonusLastReps != null &&
bonusLastReps > bonusPlannedReps) {
bonusPlannedReps = bonusLastReps;
}
}

for (int s = 1; s <= setsCount; s++) {
await DatabaseHelper.instance.addWorkoutSet(
WorkoutSet(
workoutExerciseId: bonusWorkoutExId,
order: s,
weight: bonusBaseWeight,
reps: bonusPlannedReps,
completed: false,
),
);
}
break;
}
}
}
}

final coolDown = _pickCoolDown(allStretches, dayGroups, 5);
for (final stretch in coolDown) {
final stretchExId =
await DatabaseHelper.instance.addWorkoutExercise(
WorkoutExercise(
workoutDayId: dayId,
itemType: 'stretch',
itemId: stretch.id!,
order: 1000 + order++,
durationSeconds: stretch.durationSeconds,
isCoolDown: true,
),
);
await DatabaseHelper.instance.addWorkoutSet(
WorkoutSet(
workoutExerciseId: stretchExId,
order: 1,
completed: false),
);
}
createdDays.add(day.copyWith(id: dayId));

final dayIsolationIds =
isolationExercises.map((e) => e.id).whereType<int>().toSet();
recentIsolationIds.insert(0, dayIsolationIds);
final dayIsolationFamilies =
isolationExercises.map((e) => familyOf(e)).toSet();
recentIsolationFamilies.insert(0, dayIsolationFamilies);

final memoryLimit = isolationWindowDays;
if (recentIsolationIds.length > memoryLimit) {
recentIsolationIds.removeRange(memoryLimit, recentIsolationIds.length);
}
if (recentIsolationFamilies.length > memoryLimit) {
recentIsolationFamilies.removeRange(
memoryLimit, recentIsolationFamilies.length);
}
}
}
return createdDays;
}

// ═══ КОНЕЦ ЧАСТИ 2 ═══
// ═══ РАСКЛАДКА ПО ВЫБРАННЫМ ДНЯМ НЕДЕЛИ ═══

static Future<bool> _hasWorkoutToday(int profileId) async {
try {
final now = DateTime.now();
final start = DateTime(now.year, now.month, now.day);
final end = start.add(const Duration(days: 1));
final days = await DatabaseHelper.instance.getWorkoutDaysBetween(
profileId: profileId,
from: start,
to: end,
);
return days.any((d) =>
d.status == 'completed' || d.status == 'in_progress');
} catch (_) {
return false;
}
}

static Future<List<int>> _resolveWeekdaySlots(
UserProfile profile,
int todayWeekday, {
bool hasWorkoutToday = false,
}) async {
final selected = profile.trainingWeekdays.toSet().toList()..sort();

if (selected.isEmpty) {
return _weekdayOffsets(profile.daysPerWeek, todayWeekday,
hasWorkoutToday: hasWorkoutToday);
}

final offsets = <int>{};
for (final w in selected) {
final off = (w - todayWeekday) % 7;
if (off == 0 && hasWorkoutToday) continue;
offsets.add(off);
}

for (int off = 1; off < 7 && offsets.length < profile.daysPerWeek; off++) {
offsets.add(off);
}
if (offsets.isEmpty) offsets.add(1);

final sorted = offsets.toList()..sort();
return sorted.take(profile.daysPerWeek).toList();
}

static List<int> _weekdayOffsets(int daysPerWeek, int todayWeekday,
{bool hasWorkoutToday = false}) {
const patterns = {
1: [1],
2: [1, 4],
3: [1, 3, 5],
4: [1, 2, 4, 6],
5: [1, 2, 3, 5, 6],
6: [1, 2, 3, 4, 5, 6],
7: [1, 2, 3, 4, 5, 6, 7],
};
final pattern = patterns[daysPerWeek.clamp(1, 7)]!;

final offsets = pattern
.map((w) => (w - todayWeekday) % 7)
.toSet()
.toList()
..sort();

if (hasWorkoutToday && offsets.contains(0)) {
offsets.remove(0);
offsets.add(7);
}

if (offsets.contains(0)) {
return offsets;
}
return [0, ...offsets.take(daysPerWeek - 1)];
}

// ═══ ПАТТЕРНЫ ДЛЯ ДОМА ═══

/// Паттерн движения упражнения. Отвечает на «как двигаемся?»,
/// а не «какие мышцы качаем?». Нужен для home-режима.
static String _patternOf(Exercise e)
{
if (isCardioOf(e)) return 'cardio';
final n = e.name.toLowerCase();

// Hinge — ПЕРВЫМ, потому что «румынская тяга» содержит «тяга»
if (n.contains('румынск') ||
n.contains('становая') ||
n.contains('мостик') ||
n.contains('хип траст') ||
n.contains('hip thrust') ||
n.contains('подъем таза') ||
n.contains('подъём таза') ||
n.contains('махи гирей') ||
n.contains('махи гирями')) {
return 'hinge';
}

// Pull
if (n.contains('тяга') ||
n.contains('подтягивани') ||
n.contains('шраги')) {
return 'pull';
}

// Push
if (n.contains('отжимани') ||
n.contains('жим') ||
n.contains('разводк') ||
n.contains('брусь') ||
n.contains('французский') ||
n.contains('пуловер')) {
return 'push';
}

// Lunge — до squat, «болгарский» не содержит «присед»
if (n.contains('выпад') || n.contains('болгарск')) return 'lunge';

// Squat
if (n.contains('присед') || n.contains('сед')) return 'squat';

// Core
if (n.contains('планк') ||
n.contains('скручиван') ||
n.contains('лодочк') ||
n.contains('уголок') ||
n.contains('стульчик') ||
n.contains('велосипед') ||
n.contains('подъем ног') ||
n.contains('подъём ног')) {
return 'core';
}

// Фолбэк по muscleGroups
if (e.muscleGroups.any(
(m) => ['chest', 'shoulders', 'triceps'].contains(m))) {
return 'push';
}
if (e.muscleGroups.any(
(m) => ['back', 'lats', 'biceps', 'traps'].contains(m))) {
return 'pull';
}
if (e.muscleGroups.any((m) => ['quads'].contains(m))) return 'squat';
if (e.muscleGroups.any((m) => ['hamstrings', 'glutes'].contains(m))) {
return 'hinge';
}
if (e.muscleGroups.any(
(m) => ['abs', 'obliques', 'core'].contains(m))) {
return 'core';
}

return 'core';
}
// 👇 ВОТ СЮДА вставить:
        /// Публичный доступ к паттерну упражнения (для экранов и карточек).
        static String patternOf(Exercise e) => _patternOf(e);
/// Шаблоны дней для дома. Три варианта full-body A/B/C.
static List<List<String>> _createHomePatternTemplates(
List<String> focus, int days, List<String> limitations,
{String? bodyType}) {
final hasCardio = focus.contains('cardio');
final withCardioDay = hasCardio && days >= 3;
final strengthDays = withCardioDay ? days - 1 : days;

// Порядок паттернов по типу фигуры (акцент в начале)
List<String> order;
switch (bodyType) {
case 'pear':
order = ['hinge', 'push', 'squat', 'pull', 'core'];
break;
case 'apple':
order = ['core', 'pull', 'hinge', 'push', 'squat'];
break;
case 'hourglass':
order = ['hinge', 'core', 'squat', 'push', 'pull'];
break;
case 'rectangle':
order = ['hinge', 'push', 'squat', 'pull', 'core'];
break;
case 'inverted_triangle':
order = ['hinge', 'squat', 'lunge', 'pull', 'push'];
break;
default:
order = ['push', 'pull', 'squat', 'hinge', 'core'];
}

final variants = [
order,
[...order.skip(2), ...order.take(2)],
[...order.skip(4), ...order.take(4)],
];

final plans = <List<String>>[];
for (int d = 0; d < strengthDays; d++) {
plans.add(variants[d % variants.length]);
}
if (withCardioDay) plans.add(['cardio']);
return plans;
}

static List<List<String>> _createDayTemplates(
List<String> focus, int days, List<String> limitations,
{String equipment = 'gym', String? bodyType}) {
// 👇 Дом: другая логика — по паттернам, не по зонам
if (equipment == 'home') {
return _createHomePatternTemplates(
focus, days, limitations, bodyType: bodyType);
}

// ═══ ЗАЛ: старая логика без изменений ═══
final blocked = _buildBlockedZones(limitations);
final zoneBlocked = zonesBlockedByLimitations(limitations);
final hasCardio = focus.contains('cardio');
final pool = focus
.where((g) =>
g != 'cardio' && !blocked.contains(g) && !zoneBlocked.contains(g))
.toList();
final isOnlyCardio = focus.length == 1 && hasCardio;
if (pool.isEmpty && !isOnlyCardio) {
pool.addAll(['glutes', 'abs', 'legs']
.where((g) => !zoneBlocked.contains(g)));
}

final plans = List.generate(days, (_) => <String>[]);
if (isOnlyCardio) return plans;

int cardioDaysCount = 0;
if (hasCardio) cardioDaysCount = (days >= 3) ? 1 : 0;

final strengthDays = days - cardioDaysCount;

final List<String> everyDayZones = List.from(pool);
if (everyDayZones.length < 3) {
for (final g in List.from(everyDayZones)) {
for (final adj in (_adjacentZones[g] ?? [])) {
if (!everyDayZones.contains(adj) &&
!blocked.contains(adj) &&
!zoneBlocked.contains(adj) &&
everyDayZones.length < 3) {
everyDayZones.add(adj);
}
}
}
}

for (int d = 0; d < strengthDays; d++) {
final shifted = [
...everyDayZones.skip(d % everyDayZones.length),
...everyDayZones.take(d % everyDayZones.length)
];
plans[d] = shifted;
}
return plans;
}

// ═══ ПОДБОР ПО ПАТТЕРНАМ ДЛЯ ДОМА ═══

/// Подбор упражнений по паттернам (для дома).
/// 5 основных паттернов + 1–2 дополнительных на фокус-зоны.
static List<Exercise> _pickByPattern({
required List<Exercise> allExercises,
required List<String> patterns,
required String equipment,
required List<String> homeEquipment,
required String level,
required List<String> limitations,
required Set<int> usedIds,
required Set<String> usedFamilies,
required List<String> focusZones,
required int dayIndex,
required int sessionMinutes,
required int daysPerWeek,
}) {
final blocked = _buildBlockedZones(limitations);
final result = <Exercise>[];

// 1. Основные паттерны (5 упражнений)
for (final pattern in patterns) {
if (pattern == 'cardio') continue;

var candidates = allExercises.where((e) {
if (e.id == null) return false;
if (!isBaseExercise(e)) return false;
if (usedIds.contains(e.id)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, equipment, homeEquipment: homeEquipment)) {
return false;
}
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (_patternOf(e) != pattern) return false;
return true;
}).toList();

if (candidates.isEmpty) {
candidates = allExercises.where((e) {
if (e.id == null) return false;
if (usedIds.contains(e.id)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, equipment, homeEquipment: homeEquipment)) {
return false;
}
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (_patternOf(e) != pattern) return false;
return true;
}).toList();
}

if (candidates.isEmpty) continue;

final fresh = candidates
.where((e) => !usedFamilies.contains(familyOf(e)))
.toList();
final pool = fresh.isNotEmpty ? fresh : candidates;

final pick = _pickBestCandidate(pool, level, equipment,
homeEquipment: homeEquipment)!;
result.add(pick);
usedIds.add(pick.id!);
usedFamilies.add(familyOf(pick));
}

// 2. Дополнительные на фокус-зоны (1 или 2)
final zonesForExtra = focusZones.where((z) => z != 'cardio').toList();
if (zonesForExtra.isEmpty) return result;

int extraCount;
if (sessionMinutes >= 60) {
extraCount = 2;
} else if (daysPerWeek <= 2 && zonesForExtra.length >= 2) {
extraCount = 2;
} else {
extraCount = 1;
}
extraCount = extraCount.clamp(1, zonesForExtra.length);

for (int k = 0; k < extraCount; k++) {
final zoneIdx = (dayIndex + k) % zonesForExtra.length;
final focusZone = zonesForExtra[zoneIdx];
final zoneMembers = _zoneExpand[focusZone] ?? [focusZone];

final extraCandidates = allExercises.where((e) {
if (e.id == null || usedIds.contains(e.id)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, equipment, homeEquipment: homeEquipment)) {
return false;
}
if (!_isDifficultyAllowed(e, level, equipment)) return false;
final hitsZone = e.muscleGroups
.any((m) => m == focusZone || zoneMembers.contains(m));
if (!hitsZone) return false;
if (usedFamilies.contains(familyOf(e))) return false;
return true;
}).toList();

if (extraCandidates.isEmpty) continue;

final pick = _pickBestCandidate(extraCandidates, level, equipment,
homeEquipment: homeEquipment)!;
result.add(pick);
usedIds.add(pick.id!);
usedFamilies.add(familyOf(pick));
}

return result;
}

// ═══ ПОДБОР БАЗ ДНЯ (ЗАЛ) ═══
static List<Exercise> _pickBasesForDay({
required List<Exercise> allExercises,
required List<Exercise> baseToKeep,
required List<String> muscleGroups,
required String equipment,
required List<String> homeEquipment,
required String level,
required List<String> limitations,
required Set<int> usedBaseIds,
required Set<int> oldBaseIds,
required Set<String> usedFamiliesInMonth,
required int maxBases,
}) {
final blocked = _buildBlockedZones(limitations);
final result = <Exercise>[];
final Set<String> zonesCovered = {};
final Set<String> usedFamilies = {};
int lowerBodyBases = baseToKeep
.where((e) => ['glutes', 'legs'].contains(getExerciseZone(e)))
.length;

for (final ex in baseToKeep) {
if (!isBaseExercise(ex)) continue;
result.add(ex);
zonesCovered.add(getExerciseZone(ex));
usedFamilies.add(familyOf(ex));
}

for (final zone in muscleGroups) {
if (zone == 'cardio' || zonesCovered.contains(zone)) continue;
if ((zone == 'glutes' || zone == 'legs') && lowerBodyBases >= 2) continue;

if (result.length >= maxBases) break;

final freshCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (usedBaseIds.contains(e.id)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, equipment, homeEquipment: homeEquipment)) {
return false;
}
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if (usedFamilies.contains(familyOf(e))) return false;
if (usedFamiliesInMonth.contains(familyOf(e))) return false;
if ((equipment == 'gym' || equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
return true;
}).toList();

if (freshCandidates.isNotEmpty) {
final pick = _pickBestCandidate(freshCandidates, level, equipment,
homeEquipment: homeEquipment)!;
result.add(pick);
zonesCovered.add(zone);
usedFamilies.add(familyOf(pick));
if (['glutes', 'legs'].contains(zone)) lowerBodyBases++;
} else {
final fallbackCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, equipment, homeEquipment: homeEquipment)) {
return false;
}
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if (usedFamilies.contains(familyOf(e))) return false;
if ((equipment == 'gym' || equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
return true;
}).toList();

if (fallbackCandidates.isNotEmpty) {
final pick = _pickBestCandidate(fallbackCandidates, level, equipment,
homeEquipment: homeEquipment)!;
result.add(pick);
zonesCovered.add(zone);
usedFamilies.add(familyOf(pick));
if (['glutes', 'legs'].contains(zone)) lowerBodyBases++;
}
}
}
return result;
}

// ═══ ПОДБОР ИЗОЛЯЦИИ ДНЯ (ЗАЛ) ═══
static List<Exercise> _pickIsolationForDay({
required List<Exercise> allExercises,
required List<String> muscleGroups,
required List<Exercise> bases,
required String equipment,
required List<String> homeEquipment,
required String level,
required List<String> limitations,
required int maxCount,
required List<Set<int>> recentDayIds,
required int repeatWindowSize,
required List<Set<String>> recentDayFamilies,
}) {
final blocked = _buildBlockedZones(limitations);
final result = <Exercise>[];

int? repeatLevel(int? id) {
if (id == null) return null;
for (int i = 0; i < recentDayIds.length && i < repeatWindowSize; i++) {
if (recentDayIds[i].contains(id)) return i;
}
return null;
}

final crossDayFamilies = <String>{};
for (int i = 0; i < recentDayFamilies.length && i < repeatWindowSize; i++) {
crossDayFamilies.addAll(recentDayFamilies[i]);
}

final usedIds = <int>{...bases.map((b) => b.id).whereType<int>()};
final usedFamilies = <String>{...bases.map((b) => familyOf(b))};

Exercise? pickFromZone(String zone) {
final candidates = allExercises.where((e) {
if (e.id == null) return false;
if (usedIds.contains(e.id)) return false;
if (isBaseExercise(e)) return false;
if (_isCardio(e)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, equipment, homeEquipment: homeEquipment)) {
return false;
}
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if ((equipment == 'gym' || equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
final fam = familyOf(e);
if (usedFamilies.contains(fam)) return false;
return true;
}).toList();

final allowed = candidates.where((e) {
final lvl = repeatLevel(e.id);
return lvl == null || lvl >= repeatWindowSize;
}).toList();

if (allowed.isNotEmpty) {
final fresh = allowed
.where((e) =>
repeatLevel(e.id) == null &&
!crossDayFamilies.contains(familyOf(e)))
.toList();
final pick = _pickBestCandidate(
fresh.isNotEmpty ? fresh : allowed, level, equipment,
homeEquipment: homeEquipment)!;
usedIds.add(pick.id!);
usedFamilies.add(familyOf(pick));
return pick;
}

if (candidates.isNotEmpty) {
candidates.sort((a, b) =>
(repeatLevel(b.id) ?? 0).compareTo(repeatLevel(a.id) ?? 0));
final pick = candidates.first;
usedIds.add(pick.id!);
usedFamilies.add(familyOf(pick));
return pick;
}

return null;
}

for (final base in bases) {
if (result.length >= maxCount) break;
final baseZone = getExerciseZone(base);

List<String> zones;
switch (baseZone) {
case 'glutes':    zones = ['glutes', 'abs']; break;
case 'legs':      zones = ['legs', 'glutes']; break;
case 'abs':       zones = ['abs', _random.nextBool() ? 'glutes' : 'legs']; break;
case 'chest':     zones = ['chest', 'back']; break;
case 'back':      zones = ['back', 'chest']; break;
case 'shoulders': zones = ['shoulders', 'back']; break;
case 'arms':      zones = ['arms', 'chest']; break;
default:          zones = [baseZone, baseZone];
}

Exercise? first = pickFromZone(zones[0]);
Exercise? second = pickFromZone(zones[1]);

if (first != null) result.add(first);
if (second != null) result.add(second);
}

while (result.length < maxCount) {
final extras = allExercises.where((e) {
if (e.id == null || usedIds.contains(e.id)) return false;
if (isBaseExercise(e) || _isCardio(e)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, equipment, homeEquipment: homeEquipment)) {
return false;
}
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if ((equipment == 'gym' || equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (!e.muscleGroups.any((m) => muscleGroups.contains(m))) return false;
if (usedFamilies.contains(familyOf(e))) return false;
if (crossDayFamilies.contains(familyOf(e))) return false;
return true;
}).toList()..shuffle(_random);

if (extras.isEmpty) break;
result.add(extras.first);
usedIds.add(extras.first.id!);
usedFamilies.add(familyOf(extras.first));
}

return result;
}

static Exercise? _pickBestCandidate(
List<Exercise> candidates,
String level,
String equipment, {
List<String> homeEquipment = const [],
}) {
if (candidates.isEmpty) return null;

final bool hasRealEquipment = equipment != 'bodyweight' &&
(equipment != 'home' || homeEquipment.isNotEmpty);

if (level != 'beginner' && hasRealEquipment) {
final weighted = candidates
.where((e) => e.equipment.any((eq) => eq != 'bodyweight'))
.toList();

if (weighted.isNotEmpty) {
weighted.shuffle(_random);
return weighted.first;
}
}

candidates.shuffle(_random);
return candidates.first;
}

// ═══ ФОКУС ═══
static List<String> _getFocusGroups(UserProfile profile) {
List<String> focus = [];

if (profile.focusAreas.isNotEmpty) {
focus = profile.focusAreas.map(_norm).toList();
} else if (profile.bodyType != null) {
switch (profile.bodyType) {
case 'pear':
focus = ['glutes', 'legs', 'shoulders'];
break;
case 'inverted_triangle':
focus = ['glutes', 'legs', 'abs'];
break;
case 'rectangle':
focus = ['glutes', 'shoulders', 'legs'];
break;
case 'apple':
focus = ['abs', 'legs'];
break;
case 'hourglass':
focus = ['glutes', 'abs', 'legs'];
break;
default:
break;
}
}

if (focus.isEmpty) {
if (profile.goal == 'lose_weight') {
focus = ['glutes', 'abs', 'legs'];
if (!focus.contains('cardio')) focus.add('cardio');
} else if (profile.gender == 'female') {
focus = ['glutes', 'abs', 'legs'];
} else {
focus = ['chest', 'back', 'arms', 'legs'];
}
}

// 👇 Обрезка: дом → 2, зал → 2/3 по уровню
final int maxFocus;
if (profile.equipment == 'home') {
maxFocus = 2;
} else {
maxFocus = profile.level == 'beginner' ? 2 : 3;
}
if (focus.length > maxFocus) {
focus = focus.take(maxFocus).toList();
}

return focus;
}

// ═══ КОНЕЦ ЧАСТИ 3 ═══
        static String _computeCardioMode(List<String> focus, String goal) {
                if (goal == 'strength' || goal == 'gain_mass') return 'off';
                if (focus.contains('cardio')) return 'every_day';

                final bool isLoseWeight =
                    goal == 'lose_weight' || goal.contains('weight') || goal.contains('lose');
                if (isLoseWeight || goal == 'tone') return 'every_day';

                return 'off';
        }

        // ═══ ВСПОМОГАТЕЛЬНЫЕ ПРОВЕРКИ ═══
        static bool _isHighIntensityCardio(String lowerName) {
                if (lowerName.contains('берпи') ||
                    lowerName.contains('скалолаз') ||
                    lowerName.contains('джеки') ||
                    lowerName.contains('колен')) return true;
                if (lowerName.contains('канат') &&
                    (lowerName.contains('махи') ||
                        lowerName.contains('волны') ||
                        lowerName.contains('бэтл'))) return true;
                return false;
        }

        static bool _isTimedExercise(String name) {
                final lower = name.toLowerCase();
                const keywords = [
                        'планка', 'plank', 'бег', 'дорожк', 'скакалк',
                        'велотренаж', 'эллипс', 'гребл', 'кардио',
                        'стульчик', 'уголок', 'лодочка'
                ];
                if (keywords.any((kw) => lower.contains(kw))) return true;
                if (lower.contains('скалолаз')) return true;
                if (lower.contains('канат') &&
                    (lower.contains('махи') ||
                        lower.contains('волны') ||
                        lower.contains('бэтл'))) return true;
                return false;
        }

        static bool _isCardio(Exercise ex) => isCardioOf(ex);

        /// Проверяет, подходит ли упражнение под оборудование профиля.
        ///
        /// Обратная совместимость (для тестов и мигрированных профилей):
        /// - 'gym' / 'mixed' / 'both' / 'any' → всё доступно
        /// - 'bodyweight' → только своё тело
        /// - 'dumbbells' → тело + гантели + резинка (legacy до миграции)
        ///
        /// Новая логика:
        /// - 'home' + homeEquipment → строго: ВСЕ требования упражнения
        ///   должны быть в {bodyweight} ∪ homeEquipment.
        static bool matchesEquipment(
            Exercise e,
            String equipment, {
                    List<String> homeEquipment = const [],
            }) {
                final lowerName = e.name.toLowerCase();

                // Зал (и legacy-значения) — доступно всё
                if (equipment == 'gym' ||
                    equipment == 'mixed' ||
                    equipment == 'both' ||
                    equipment == 'any') {
                        return true;
                }

                // Legacy: чистое тело (для тестов и до-миграционных профилей)
                if (equipment == 'bodyweight') {
                        final iron = ['гантел', 'штанг', 'гирей', 'блин', 'гриф', 'резинк'];
                        for (final word in iron) {
                                if (lowerName.contains(word)) return false;
                        }
                        return e.equipment.contains('bodyweight');
                }

                // Legacy: дом с гантелями
                if (equipment == 'dumbbells') {
                        final heavy = ['штанг', 'гирей', 'блин', 'гриф'];
                        for (final word in heavy) {
                                if (lowerName.contains(word)) return false;
                        }
                        return e.equipment.contains('bodyweight') ||
                            e.equipment.contains('dumbbells') ||
                            e.equipment.contains('resistance_band');
                }

                if (equipment == 'home') {
                        // 👇 Машинное кардио: не «только зал», а «есть дома».
                        const machineCardioMap = <String, String>{
                                'дорожк': 'treadmill',
                                'велотренаж': 'bike',
                                'эллипс': 'elliptical',
                                'гребл': 'rower',
                                'степпер': 'stepper',
                        };
                        for (final entry in machineCardioMap.entries) {
                                if (lowerName.contains(entry.key)) {
                                        return homeEquipment.contains(entry.value);
                                }
                        }

                        // Тренажёры и зальное железо — по-прежнему только зал
                        const gymOnly = [
                                'тренажер', 'тренажёр', 'блок', 'кроссовер', 'смит', 'т-гриф',
                                'бабочка', 'тумбу', 'тумба', 'платформ', 'паттерн', 'босу', 'полусфер',
                                'жим ногами', 'гакк',
                        ];
                        for (final word in gymOnly) {
                                if (lowerName.contains(word)) return false;
                        }

                        // Строгая проверка: КАЖДОЕ требование упражнения удовлетворено
                        final allowed = <String>{'bodyweight', ...homeEquipment};
                        if (e.equipment.isEmpty) return true;
                        return e.equipment.every(allowed.contains);
                }

                return true;
        }

        static bool _isDifficultyAllowed(Exercise e, String level, String equipment) {
                final lowerName = e.name.toLowerCase();

                if (level == 'beginner') {
                        const forbiddenKeywords = [
                                'на одной ноге', 'на одной руке',
                                'штанг',
                                'в висе', 'подтягивания',
                                'на брусьях', 'к подбородку',
                                'гиперэкстензия с весом', 'складной нож',
                                'французский жим', 'жим штанги лёжа',
                                'болгарский', 'наклоны',
                                'хип-траст', 'хип траст',
                                'берпи', 'скакалк', 'тумбу',
                                'высоким подниманием колен', 'канат', 'гребл'
                        ];

                        if (forbiddenKeywords.any((word) => lowerName.contains(word))) {
                                return false;
                        }

                        return e.difficulty == 'beginner' || e.difficulty == 'intermediate';
                }

                if (level == 'intermediate') {
                        const hardCoreKeywords = [
                                'приседания на одной ноге', 'в висе', 'на тумбу', 'прыжки на тумбу',
                                'подтягивания', 'берпи'
                        ];
                        if (hardCoreKeywords.any((word) => lowerName.contains(word))) return false;

                        // Дом без инвентаря (и legacy bodyweight) — не отсекаем «легкие»
                        if (equipment != 'bodyweight' && equipment != 'home') {
                                const tooEasyKeywords = ['с собственным весом', 'с колен', 'без веса'];
                                if (tooEasyKeywords.any((word) => lowerName.contains(word))) {
                                        return false;
                                }
                        }

                        return e.difficulty != 'advanced';
                }

                return true;
        }

        static String _normalizeName(String name) {
                var s = name.toLowerCase();
                const removals = [
                        'на одной ноге', 'на одной руке', 'на двух ногах', 'на двух руках',
                        'на одну ногу', 'на одну руку', 'одной ногой', 'одной рукой',
                        'на 1 ноге', 'на 1 руке', 'с одной ногой', 'с одной рукой',
                        'с гантелями', 'с гантелью', 'с гантелей', 'с одной гантелью',
                        'со штангой', 'с штангой', 'с гирей', 'с эспандером', 'с резинкой',
                        'с бодибаром', 'с блином', 'с мячом', 'с фитболом', 'в наклоне',
                        'с упором', 'на скамье', 'на полу', 'на коленях', 'сидя', 'стоя',
                        'лёжа', 'лежа', 'вис', 'вися', 'правой', 'левой',
                        'собственным весом', 'свой вес',
                        'в кроссовере', 'в блоке', 'в тренажере', 'в тренажёре',
                        'на тренажере', 'на тренажёре', 'в кроссовер', 'с блоком',
                        'с тросом', 'на тросе', 'с рукоятью',
                        'на турнике', 'на брусьях', 'с опорой', 'без опоры', 'с весом',
                        'без веса', 'с грифом'
                ];
                for (final r in removals) {
                        s = s.replaceAll(r, '');
                }
                s = s.replaceAll('упражнение', '').replaceAll('подходы', '');
                s = s.replaceAll('мостик', 'мост')
                    .replaceAll('хип траст', 'мост')
                    .replaceAll('hip thrust', 'мост')
                    .replaceAll('подъем таза', 'мост');
                s = s.replaceAll('ягодичный', '')
                    .replaceAll('болгарский', 'выпад')
                    .replaceAll('боковая планка', 'планка');
                s = s.replaceAll('ё', 'е');
                s = s.replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
                return s.trim();
        }

        static String _groupLabel(String code) {
                const map = {
                        'glutes': 'ягодицы', 'legs': 'ноги', 'abs': 'пресс', 'chest': 'грудь',
                        'back': 'спина', 'arms': 'руки', 'shoulders': 'плечи',
                        'quads': 'квадрицепс', 'hamstrings': 'бицепс бедра', 'calves': 'голень',
                        'biceps': 'бицепс', 'triceps': 'трицепс', 'forearms': 'предплечья',
                        'lats': 'широчайшие', 'traps': 'трапеции', 'lower_back': 'поясница',
                        'core': 'кор', 'full_body': 'всё тело', 'cardio': 'кардио',
                        'feet': 'стопы', 'adductors': 'приводящие',
                        // 👇 Паттерны (для логов и на будущее)
                        'push': 'жим', 'pull': 'тяга', 'squat': 'присед',
                        'hinge': 'мостик/тяга', 'lunge': 'выпад',
                };
                return map[code] ?? code;
        }

        // ═══ РАЗМИНКА / ЗАМИНКА ═══
        static List<Stretch> _pickCoolDown(
            List<Stretch> all, List<String> groups, int max) {
                final rel = all
                    .where((s) =>
                s.category == 'classic' &&
                    (groups.contains(s.muscleGroup) ||
                        s.muscleGroup == 'full_body' ||
                        s.muscleGroup == 'back'))
                    .toList();
                rel.shuffle(_random);
                return rel.take(max).toList();
        }

        static List<Stretch> _pickWarmup(
            List<Stretch> all, List<String> dayGroups, int max) {
                final warmups = all.where((s) => s.category == 'warmup').toList();
                if (warmups.isEmpty) return [];

                const baseNames = [
                        'Вращения головой', 'Вращения плечами', 'Махи руками',
                        'Наклоны корпуса в стороны', 'Круги тазом', 'Махи ногами',
                        'Вращения коленями',
                ];

                final result = <Stretch>[];
                for (final name in baseNames) {
                        final match = warmups.where((s) => s.name == name).toList();
                        if (match.isNotEmpty) result.add(match.first);
                }

                String? targetName;
                if (dayGroups.isEmpty) {
                        targetName = 'Джампинг Джек';
                } else {
                        final first = dayGroups.first;
                        switch (first) {
                                case 'glutes':
                                case 'hinge':
                                        targetName = 'Мостик ягодичный (разминка)';
                                        break;
                                case 'abs':
                                case 'core':
                                case 'back':
                                case 'pull':
                                        targetName = 'Кошка-корова (разминка)';
                                        break;
                                case 'legs':
                                case 'quads':
                                case 'hamstrings':
                                case 'squat':
                                case 'lunge':
                                        targetName = 'Приседания без веса (разминка)';
                                        break;
                                case 'shoulders':
                                case 'chest':
                                case 'arms':
                                case 'push':
                                        targetName = 'Круги руками (разминка)';
                                        break;
                                case 'cardio':
                                        targetName = 'Джампинг Джек';
                                        break;
                                default:
                                        targetName = null;
                        }
                }

                if (targetName != null) {
                        final match = warmups.where((s) => s.name == targetName).toList();
                        if (match.isNotEmpty && !result.any((s) => s.name == targetName)) {
                                result.add(match.first);
                        }
                }

                return result.take(max).toList();
        }

        // ═══ ПРОГРЕССИЯ ═══
        static int _getSets(String level) =>
            level == 'beginner' ? 2 : (level == 'advanced' ? 4 : 3);

        static String _getReps(String goal) => goal == 'strength'
            ? '6-8'
            : (goal == 'gain_mass' ? '8-10' : (goal == 'tone' ? '15-18' : '15-20'));

        static int _getRest(String goal) => goal == 'strength'
            ? 120
            : (goal == 'gain_mass' ? 90 : (goal == 'lose_weight' ? 45 : 60));

        static _ProgressionParams _getProgressionParams(int week, String goal,
            String level, int baseSets, int baseRest, String baseReps) {
                int sets = baseSets;
                String reps = baseReps;
                int rest = baseRest;
                int timedSeconds = 60;
                int cardioMinutes = 15;
                if (goal == 'lose_weight') {
                        rest = 45;
                }

                if (goal == 'tone') {
                        if (week == 1) {
                                reps = (level == 'beginner') ? '10-12' : '15';
                        } else if (week == 2) {
                                reps = (level == 'beginner') ? '12-15' : '18';
                        } else if (week == 3) {
                                reps = (level == 'beginner') ? '15' : '18';
                        } else {
                                reps = '15';
                        }
                } else {
                        if (week == 1) {
                                reps = (goal == 'strength' || goal == 'gain_mass')
                                    ? '10-12'
                                    : (level == 'beginner' ? '10-12' : '15');
                        } else if (week == 2) {
                                reps = (goal == 'strength' || goal == 'gain_mass')
                                    ? '10-12'
                                    : (level == 'beginner' ? '12-15' : '18');
                        } else if (week == 3) {
                                reps = (goal == 'strength' || goal == 'gain_mass')
                                    ? '12-14'
                                    : (level == 'beginner' ? '15' : '18');
                        } else if (week == 4) {
                                reps = (goal == 'strength' || goal == 'gain_mass')
                                    ? '10-12'
                                    : '15';
                        }
                }

                if (level == 'beginner') {
                        if (week == 1) {
                                timedSeconds = 30;
                        } else if (week == 2) {
                                timedSeconds = 40;
                        } else if (week == 3) {
                                timedSeconds = 50;
                        } else {
                                timedSeconds = 30;
                        }
                } else {
                        if (week == 1) {
                                timedSeconds = 60;
                        } else if (week == 2) {
                                timedSeconds = 80;
                        } else if (week == 3) {
                                timedSeconds = 100;
                        } else {
                                timedSeconds = 60;
                        }
                }

                return _ProgressionParams(
                    sets: sets,
                    reps: reps,
                    rest: rest,
                    timedSeconds: timedSeconds,
                    cardioMinutes: cardioMinutes);
        }

        static int _getExerciseCount(int sessionMinutes, String level) {
                int count = (sessionMinutes / 7.5).round();
                if (level == 'beginner') {
                        count = (count * 0.8).round();
                        if (count > 9) count = 9;
                }
                if (count > 12) count = 12;
                return ((count / 3).ceil() * 3).clamp(3, 18);
        }

        static int _getExerciseWeight(Exercise ex) {
                if (!isBaseExercise(ex)) return 10;
                switch (ex.difficulty) {
                        case 'advanced':
                                return 1;
                        case 'intermediate':
                                return 2;
                        case 'beginner':
                                return 3;
                        default:
                                return 4;
                }
        }

        static int? _parseReps(String repsStr) {
                final match = RegExp(r'(\d+)').firstMatch(repsStr);
                if (match == null) return null;
                return int.tryParse(match.group(1) ?? '');
        }
}

class _ProgressionParams {
        final int sets;
        final int rest;
        final String reps;
        final int timedSeconds;
        final int cardioMinutes;

        _ProgressionParams({
                required this.sets,
                required this.reps,
                required this.rest,
                required this.timedSeconds,
                required this.cardioMinutes,
        });
}
// ═══ КОНЕЦ ФАЙЛА workout_generator.dart ═══