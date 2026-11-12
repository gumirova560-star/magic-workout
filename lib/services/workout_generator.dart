import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../models/stretch.dart';
import '../models/user_profile.dart';
import '../models/workout_day.dart';
import '../data/base_exercises.dart';
import 'database_helper.dart';
import 'week_analyzer.dart';

class WorkoutGenerator {
static final Random _random = Random();

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
final blocked = <String>{};
for (final lim in limitations) blocked.add(_norm(lim).toLowerCase());
return blocked;
}

static bool _isBlocked(Exercise e, Set<String> blockedZones) {
if (blockedZones.isEmpty) return false;
for (final contra in e.contraindications) {
final c = contra.toLowerCase().trim();
for (final block in blockedZones) {
final b = block.toLowerCase().trim();
if (c.contains(b) || b.contains(c)) return true;
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

final maxCycle = await DatabaseHelper.instance.getMaxCycleNumber(profile.id!);
final newCycle = maxCycle + 1;

final prefs = await SharedPreferences.getInstance();
final allowBaseChange = prefs.getBool('allow_base_change_${profile.id}_$maxCycle') ?? false;
final bool shouldChangeBase = allowBaseChange;

final Map<int, List<Exercise>> baseToKeepByDay = {};
final Set<int> oldBaseIds = {};

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
final ex = await DatabaseHelper.instance.getExerciseById(we.replacedByItemId ?? we.itemId);
if (ex != null && isBaseExercise(ex) && !dayBases.any((e) => e.id == ex.id)) {
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

await DatabaseHelper.instance.deleteMonthPlan(profile.id!);

int setsAdjustment = 0;
if (smart) {
try {
final missed = await WeekAnalyzer.missedLastWeek(profile.id!);
if (missed >= 2) setsAdjustment = -1;
} catch (_) {}
}

final focusGroups = _getFocusGroups(profile);
final cardioMode = _computeCardioMode(focusGroups, profile.goal);
final dayPlans = _createDayTemplates(focusGroups, profile.daysPerWeek, profile.limitations);

final rawExercises = await DatabaseHelper.instance.getExercises();
final Map<String, Exercise> uniqueExercisesMap = {};
for (final ex in rawExercises) {
final cleanName = ex.name.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
uniqueExercisesMap.putIfAbsent(cleanName, () => ex);
}
final allExercises = uniqueExercisesMap.values.toList();

final allStretches = await DatabaseHelper.instance.getStretches();

final monthBases = <List<Exercise>>[];
final usedBaseIds = <int>{...oldBaseIds};
final Set<String> usedFamiliesInMonth = {};

final int targetStrength = _getExerciseCount(profile.sessionMinutes, profile.level);
int maxBases = (targetStrength / 3).ceil();
if (profile.level == 'beginner') {
maxBases = 2;
}

for (int i = 0; i < dayPlans.length; i++) {
var bases = _pickBasesForDay(
allExercises: allExercises,
baseToKeep: baseToKeepByDay[i] ?? [],
muscleGroups: dayPlans[i],
equipment: profile.equipment,
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
if (!_matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') && _isExcludedForGym(e.name)) return false;

if (!e.muscleGroups.any((m) => dayPlans[i].contains(m))) return false;

return true;
}).toList()..shuffle(_random);

for (final extra in extraCandidates) {
if (bases.length >= maxBases) break;
bases.add(extra);
if (extra.id != null) usedBaseIds.add(extra.id!);
}
}

for (final ex in bases) if (ex.id != null) usedBaseIds.add(ex.id!);
for (final ex in bases) usedFamiliesInMonth.add(getExerciseFamily(ex.name));

monthBases.add(bases);
}

final createdDays = <WorkoutDay>[];
final List<Set<int>> recentIsolationIds = [];
final Set<int> usedCardioThisWeek = {};
final Set<int> usedBonusIds = {};
String? lastBonusZone;
// ═══ КОНЕЦ ЧАСТИ 1 ═══
for (int week = 1; week <= 4; week++) {
if (usedCardioThisWeek.length > 6) {
usedCardioThisWeek.clear();
}

for (int dayIndex = 0; dayIndex < dayPlans.length; dayIndex++) {
final dayGroups = dayPlans[dayIndex];
final baseExercises = monthBases[dayIndex];

final isolationExercises = _pickIsolationForDay(
allExercises: allExercises,
muscleGroups: dayGroups,
bases: baseExercises,
equipment: profile.equipment,
level: profile.level,
limitations: profile.limitations,
maxCount: targetStrength + 4,
recentDayIds: recentIsolationIds,
repeatWindowSize: profile.daysPerWeek * 4,
);

final dayExercises = [...baseExercises, ...isolationExercises];

final dayCardios = <Exercise>[];
if (cardioMode == 'every_day' && dayGroups.isNotEmpty) {
final blocked = _buildBlockedZones(profile.limitations);

final uniqueCardio = allExercises.where((e) {
if (e.id == null || usedCardioThisWeek.contains(e.id)) return false;
if (!_isCardio(e)) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
if (_isBlocked(e, blocked)) return false;
return true;
}).toList()..shuffle(_random);

final fallbackCardio = allExercises.where((e) {
if (e.id == null) return false;
if (!_isCardio(e)) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
if (_isBlocked(e, blocked)) return false;
return true;
}).toList()..shuffle(_random);

final cardioCandidates = [...uniqueCardio, ...fallbackCardio];
final bool isCardioOnlyDay = dayGroups.isEmpty || (dayGroups.length == 1 && dayGroups.first == 'cardio');

final bool isLoseWeight = profile.goal == 'lose_weight' || profile.goal.contains('weight') || profile.goal.contains('lose');
final int baseCardioCount = isLoseWeight ? 3 : 1;

final int cardioCount = isCardioOnlyDay
? (profile.sessionMinutes / 10).round().clamp(2, 6)
: (profile.level == 'beginner' ? (isLoseWeight ? 2 : 1) : baseCardioCount);

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

if (strengthList.length > targetStrength) {
strengthList.removeRange(targetStrength, strengthList.length);
}
if (strengthList.length < targetStrength) {
final remaining = targetStrength - strengthList.length;
final Set<int> recentIds = {};
for (int r = 0; r < recentIsolationIds.length && r < 2; r++) {
recentIds.addAll(recentIsolationIds[r]);
}
final extras = allExercises.where((e) {
if (strengthList.any((u) => u.id == e.id)) return false;
if (recentIds.contains(e.id)) return false;
if (_isCardio(e)) return false;
if (dayGroups.isNotEmpty && !e.muscleGroups.any((m) => dayGroups.contains(m))) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
return true;
}).toList()..shuffle(_random);

for (int i = 0; i < remaining && i < extras.length; i++) {
strengthList.add(extras[i]);
}
}

final bool isCardioOnlyDay = dayGroups.isEmpty || (dayGroups.length == 1 && dayGroups.first == 'cardio');
final bool isLoseWeightTarget = profile.goal == 'lose_weight' || profile.goal.contains('weight') || profile.goal.contains('lose');

int targetCardio;
if (isCardioOnlyDay) {
targetCardio = 5;
} else if (cardioMode == 'off') {
targetCardio = 0;
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
if (!_isCardio(e)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
return true;
}).toList()..shuffle(_random);
for (int i = 0; i < targetCardio - cardioList.length && i < extras.length; i++) {
cardioList.add(extras[i]);
}
}

uniqueExercises.clear();
uniqueExercises.addAll(strengthList);
uniqueExercises.addAll(cardioList);

final dayDate = DateTime.now().add(Duration(days: (week - 1) * 7 + dayIndex));

bool isChallengeDay = (week == 3 && dayIndex == 1);
final dayType = isChallengeDay ? 'challenge' : 'strength';
final dayName = isChallengeDay
? 'Неделя $week: День Челленджа'
: 'Неделя $week: День ${dayIndex + 1}: ${dayGroups.where((g) => g != 'cardio').map(_groupLabel).join(' + ')}';

final day = WorkoutDay(
profileId: profile.id!, name: dayName, type: dayType,
weekNumber: week, cycleNumber: newCycle, status: 'planned',
durationMinutes: isChallengeDay ? 45 : profile.sessionMinutes, date: dayDate,
);

final dayId = await DatabaseHelper.instance.createWorkoutDay(day);

if (isChallengeDay) {
lastBonusZone = null;
createdDays.add(day.copyWith(id: dayId));
continue;
}

final baseSets = _getSets(profile.level);
final finalSets = (baseSets + setsAdjustment).clamp(2, 5);
final progression = _getProgressionParams(week, profile.goal, profile.level, finalSets, _getRest(profile.goal), _getReps(profile.goal));

int setsCount = progression.sets;

uniqueExercises.sort((a, b) => _getExerciseWeight(a).compareTo(_getExerciseWeight(b)));

final bool hasCardioMachine = profile.equipment == 'gym' || profile.equipment == 'mixed' || profile.equipment == 'both';
if (hasCardioMachine) {
final warmupCardio = allExercises.where((e) =>
(e.name.contains('дорожк') || e.name.contains('велотренаж') || e.name.contains('эллипс')) &&
_matchesEquipment(e, profile.equipment)
).toList();
if (warmupCardio.isNotEmpty) {
final ex = (warmupCardio..shuffle(_random)).first;
final warmupExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
workoutDayId: dayId, itemType: 'exercise', itemId: ex.id!,
order: 0, durationSeconds: 300, isWarmup: true, sets: 1, reps: '5 мин',
));
await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: warmupExId, order: 1, completed: false));
}
}

int order = 1;
final warmup = _pickWarmup(allStretches, dayGroups, 8);
for (final stretch in warmup) {
final warmupExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
workoutDayId: dayId, itemType: 'stretch', itemId: stretch.id!,
order: order++, durationSeconds: stretch.durationSeconds, isWarmup: true,
));
await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: warmupExId, order: 1, completed: false));
}

order = 100;
for (final ex in uniqueExercises) {
final lowerName = ex.name.toLowerCase();
final isJumpRope = lowerName.contains('скакалк') || (lowerName.contains('прыжк') && !lowerName.contains('тумбу'));
final isHighIntensityCardio = _isHighIntensityCardio(lowerName);
final isShadowBoxing = lowerName.contains('бой с тенью');
final isBoxJump = lowerName.contains('тумбу');
final isCardio = ex.muscleGroups.contains('cardio');

int localSetsCount; String repsStr;
if (isJumpRope) {
localSetsCount = 3;
repsStr = profile.level == 'beginner' ? '45 сек' : '2 мин';
}
else if (isShadowBoxing) {
localSetsCount = 3;
repsStr = profile.level == 'beginner' ? '1 мин' : '3 мин';
}
else if (isBoxJump) { localSetsCount = 3; repsStr = '12 повт'; }
else if (isHighIntensityCardio) {
localSetsCount = 3;
repsStr = profile.level == 'beginner' ? '20 сек' : '30 сек';
}
else if (isCardio) {
localSetsCount = 1;
int minutes = 10;
if (isCardioOnlyDay) {
minutes = profile.level == 'beginner' ? 10 : 15;
} else {
if (profile.goal == 'lose_weight') minutes = 5;
else if (profile.goal == 'tone') minutes = 10;
else minutes = 10;
}
if (profile.level == 'beginner' && minutes > 10) {
minutes = 10;
}
repsStr = '$minutes мин';
}
else if (_isTimedExercise(ex.name)) {
localSetsCount = setsCount;
int secs = progression.timedSeconds;
if (lowerName.contains('боковая планка')) {
secs = (secs * 0.7).round();
}
repsStr = '$secs сек';
}
else {
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

final workoutExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
workoutDayId: dayId, itemType: 'exercise', itemId: ex.id!,
order: order++, sets: localSetsCount, reps: repsStr, restSeconds: progression.rest,
blockNumber: null,
));

if (!isCardio && !isJumpRope) {
final lastSets = await DatabaseHelper.instance.getLastWorkoutExerciseSets(profileId: profile.id!, exerciseId: ex.id!, daysLimit: 365);
double? baseWeight;
if (lastSets.isNotEmpty) {
baseWeight = lastSets.map((s) => s.weight ?? 0).reduce((a, b) => a > b ? a : b);
if (baseWeight == 0) baseWeight = null;
}
for (int s = 1; s <= localSetsCount; s++) {
double? targetWeight = null;
if (week == 1 && baseWeight != null) targetWeight = baseWeight;
await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
workoutExerciseId: workoutExId, order: s, weight: targetWeight,
reps: _parseReps(repsStr), completed: false,
));
}
} else if (isJumpRope || isHighIntensityCardio || isShadowBoxing) {
for (int s = 1; s <= localSetsCount; s++) {
await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: workoutExId, order: s, weight: null, reps: null, completed: false));
}
}
}

// 👇 2. ДОБАВЛЯЕМ УПРАЖНЕНИЕ НА «ЗАБЫТУЮ ЗОНУ» (Бонус)
final allZones = ['chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'];
final blockedZones = profile.limitations.map((e) => e.toLowerCase()).toList();

final forgottenZones = allZones.where((z) =>
!dayGroups.contains(z) && !blockedZones.contains(z)
).toList();

if (forgottenZones.isNotEmpty) {
var availableZones = forgottenZones.where((z) => z != lastBonusZone).toList();
if (availableZones.isEmpty) availableZones = forgottenZones;

final zonesToTry = List.from(availableZones)..shuffle(_random);

for (final randomZone in zonesToTry) {
var bonusCandidates = allExercises.where((e) {
if (e.id == null || isBaseExercise(e) || _isCardio(e)) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
if (usedBonusIds.contains(e.id)) return false;
return e.muscleGroups.contains(randomZone);
}).toList();

if (bonusCandidates.isEmpty) {
usedBonusIds.clear();
bonusCandidates = allExercises.where((e) {
if (e.id == null || isBaseExercise(e) || _isCardio(e)) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
return e.muscleGroups.contains(randomZone);
}).toList();
}

if (bonusCandidates.isNotEmpty) {
final bonusEx = (bonusCandidates..shuffle(_random)).first;
usedBonusIds.add(bonusEx.id!);
lastBonusZone = randomZone;

String bonusReps;
if (profile.goal == 'strength' || profile.goal == 'gain_mass') {
bonusReps = '10';
} else if (profile.level == 'beginner') {
bonusReps = progression.reps;
} else {
bonusReps = '15';
}

final bonusWorkoutExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
workoutDayId: dayId, itemType: 'exercise', itemId: bonusEx.id!,
order: 150, sets: setsCount, reps: bonusReps, blockNumber: null,
));

for (int s = 1; s <= setsCount; s++) {
await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(
workoutExerciseId: bonusWorkoutExId, order: s, weight: null, reps: _parseReps(bonusReps), completed: false,
));
}
break;
}
}
}

final coolDown = _pickCoolDown(allStretches, dayGroups, 5);
for (final stretch in coolDown) {
final stretchExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
workoutDayId: dayId, itemType: 'stretch', itemId: stretch.id!,
order: 1000 + order++, durationSeconds: stretch.durationSeconds, isCoolDown: true,
));
await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: stretchExId, order: 1, completed: false));
}
createdDays.add(day.copyWith(id: dayId));

final dayIsolationIds = isolationExercises.map((e) => e.id).whereType<int>().toSet();
recentIsolationIds.insert(0, dayIsolationIds);
final memoryLimit = profile.daysPerWeek * 4;
if (recentIsolationIds.length > memoryLimit) {
recentIsolationIds.removeRange(memoryLimit, recentIsolationIds.length);
}
}
}
return createdDays;
}
// ═══ КОНЕЦ ЧАСТИ 2 ═══
static List<Exercise> _pickBasesForDay({
required List<Exercise> allExercises,
required List<Exercise> baseToKeep,
required List<String> muscleGroups,
required String equipment,
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
int lowerBodyBases = baseToKeep.where((e) => ['glutes', 'legs'].contains(getExerciseZone(e))).length;

for (final ex in baseToKeep) {
if (!isBaseExercise(ex)) continue;
result.add(ex);
zonesCovered.add(getExerciseZone(ex));
usedFamilies.add(getExerciseFamily(ex.name));
}

for (final zone in muscleGroups) {
if (zone == 'cardio' || zonesCovered.contains(zone)) continue;
if ((zone == 'glutes' || zone == 'legs') && lowerBodyBases >= 2) continue;

if (result.length >= maxBases) break;

final freshCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (usedBaseIds.contains(e.id)) return false;
if (_isBlocked(e, blocked)) return false;
if (!_matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if (usedFamilies.contains(getExerciseFamily(e.name))) return false;
if (usedFamiliesInMonth.contains(getExerciseFamily(e.name))) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList();

if (freshCandidates.isNotEmpty) {
final pick = _pickBestCandidate(freshCandidates, level, equipment)!;
result.add(pick);
zonesCovered.add(zone);
usedFamilies.add(getExerciseFamily(pick.name));
if (['glutes', 'legs'].contains(zone)) lowerBodyBases++;
} else {
final fallbackCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (_isBlocked(e, blocked)) return false;
if (!_matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList();

if (fallbackCandidates.isNotEmpty) {
final pick = _pickBestCandidate(fallbackCandidates, level, equipment)!;
result.add(pick);
zonesCovered.add(zone);
usedFamilies.add(getExerciseFamily(pick.name));
if (['glutes', 'legs'].contains(zone)) lowerBodyBases++;
}
}
}
return result;
}

static List<Exercise> _pickIsolationForDay({
required List<Exercise> allExercises,
required List<String> muscleGroups,
required List<Exercise> bases,
required String equipment,
required String level,
required List<String> limitations,
required int maxCount,
required List<Set<int>> recentDayIds,
required int repeatWindowSize,
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

final usedIds = <int>{...bases.map((b) => b.id).whereType<int>()};
final usedFamilies = <String>{...bases.map((b) => getExerciseFamily(b.name))};

Exercise? pickFromZone(String zone) {
final candidates = allExercises.where((e) {
if (e.id == null) return false;
if (usedIds.contains(e.id)) return false;
if (isBaseExercise(e)) return false;
if (_isCardio(e)) return false;
if (_isBlocked(e, blocked)) return false;
if (!_matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
final fam = getExerciseFamily(e.name);
if (usedFamilies.contains(fam)) return false;
return true;
}).toList();

final fresh = candidates.where((e) => repeatLevel(e.id) == null).toList();
if (fresh.isNotEmpty) {
final pick = _pickBestCandidate(fresh, level, equipment)!;
usedIds.add(pick.id!);
usedFamilies.add(getExerciseFamily(pick.name));
return pick;
}

final safeOld = candidates.where((e) {
final level = repeatLevel(e.id);
return level != null && level >= 2;
}).toList();
if (safeOld.isNotEmpty) {
safeOld.sort((a, b) {
final levelA = repeatLevel(a.id) ?? 0;
final levelB = repeatLevel(b.id) ?? 0;
return levelB.compareTo(levelA);
});

if (level != 'beginner' && equipment != 'bodyweight') {
final weighted = safeOld.where((e) => e.equipment.any((eq) => eq != 'bodyweight')).toList();
if (weighted.isNotEmpty) {
final pick = weighted.first;
usedIds.add(pick.id!);
usedFamilies.add(getExerciseFamily(pick.name));
return pick;
}
}

final pick = safeOld.first;
usedIds.add(pick.id!);
usedFamilies.add(getExerciseFamily(pick.name));
return pick;
}

final mediumOld = candidates.where((e) {
final level = repeatLevel(e.id);
return level == 1;
}).toList();
if (mediumOld.isNotEmpty) {
final pick = _pickBestCandidate(mediumOld, level, equipment)!;
usedIds.add(pick.id!);
usedFamilies.add(getExerciseFamily(pick.name));
return pick;
}

final lastTimeOld = candidates.where((e) {
final level = repeatLevel(e.id);
return level == 0;
}).toList();
if (lastTimeOld.isNotEmpty) {
final pick = _pickBestCandidate(lastTimeOld, level, equipment)!;
usedIds.add(pick.id!);
usedFamilies.add(getExerciseFamily(pick.name));
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
if (!_matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
if (!e.muscleGroups.any((m) => muscleGroups.contains(m))) return false;
return true;
}).toList()..shuffle(_random);

if (extras.isEmpty) break;
result.add(extras.first);
usedIds.add(extras.first.id!);
}

return result;
}

static Exercise? _pickBestCandidate(List<Exercise> candidates, String level, String equipment) {
if (candidates.isEmpty) return null;

if (level != 'beginner' && equipment != 'bodyweight') {
final weighted = candidates.where((e) =>
e.equipment.any((eq) => eq != 'bodyweight')
).toList();

if (weighted.isNotEmpty) {
weighted.shuffle(_random);
return weighted.first;
}
}

candidates.shuffle(_random);
return candidates.first;
}
// ═══ КОНЕЦ ЧАСТИ 3 ═══
  static List<String> _getFocusGroups(UserProfile profile) {
    List<String> focus = [];

    if (profile.focusAreas.isNotEmpty) {
      focus = profile.focusAreas.map(_norm).toList();
    } else if (profile.bodyType != null) {
      switch (profile.bodyType) {
        case 'pear': focus = ['glutes', 'legs', 'shoulders']; break;
        case 'inverted_triangle': focus = ['glutes', 'legs', 'abs']; break;
        case 'rectangle': focus = ['glutes', 'shoulders', 'legs']; break;
        case 'apple': focus = ['abs', 'legs']; break;
        case 'hourglass': focus = ['glutes', 'abs', 'legs']; break;
        default: break;
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

    if (profile.level == 'beginner' && focus.length > 2) {
      focus = focus.take(2).toList();
    }

    return focus;
  }

  static String _computeCardioMode(List<String> focus, String goal) {
    if (goal == 'strength' || goal == 'gain_mass') return 'off';
    if (focus.contains('cardio')) return 'every_day';

    final bool isLoseWeight = goal == 'lose_weight' || goal.contains('weight') || goal.contains('lose');
    if (isLoseWeight || goal == 'tone') return 'every_day';

    return 'off';
  }

  static List<List<String>> _createDayTemplates(List<String> focus, int days, List<String> limitations) {
    final blocked = _buildBlockedZones(limitations);
    final hasCardio = focus.contains('cardio');
    final pool = focus.where((g) => g != 'cardio' && !blocked.contains(g)).toList();
    final isOnlyCardio = focus.length == 1 && hasCardio;
    if (pool.isEmpty && !isOnlyCardio) pool.addAll(['glutes', 'abs', 'legs']);

    final plans = List.generate(days, (_) => <String>[]);
    if (isOnlyCardio) return plans;

    int cardioDaysCount = 0;
    if (hasCardio) cardioDaysCount = (days >= 3) ? 1 : 0;

    final strengthDays = days - cardioDaysCount;

    final List<String> everyDayZones = List.from(pool);
    if (everyDayZones.length < 3) {
      for (final g in pool) {
        for (final adj in (_adjacentZones[g] ?? [])) {
          if (!everyDayZones.contains(adj) && everyDayZones.length < 3) everyDayZones.add(adj);
        }
      }
    }

    for (int d = 0; d < strengthDays; d++) {
      final shifted = [...everyDayZones.skip(d % everyDayZones.length), ...everyDayZones.take(d % everyDayZones.length)];
      plans[d] = shifted;
    }
    return plans;
  }

  static bool _isHighIntensityCardio(String lowerName) {
    if (lowerName.contains('берпи') || lowerName.contains('скалолаз') || lowerName.contains('джеки') || lowerName.contains('колен')) return true;
    if (lowerName.contains('канат') && (lowerName.contains('махи') || lowerName.contains('волны') || lowerName.contains('бэтл'))) return true;
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
    if (lower.contains('канат') && (lower.contains('махи') || lower.contains('волны') || lower.contains('бэтл'))) return true;
    return false;
  }

  static bool _isCardio(Exercise ex) {
    final lower = ex.name.toLowerCase();
    if (lower.contains('бег') || lower.contains('дорожк') || lower.contains('скакалк') || lower.contains('эллипс') || lower.contains('велотренаж') || lower.contains('велоэргометр') || lower.contains('гребл') || lower.contains('степпер') || lower.contains('кардио')) return true;
    if (lower.contains('скалолаз')) return true;
    if (lower.contains('канат') && (lower.contains('махи') || lower.contains('волны') || lower.contains('бэтл'))) return true;
    final coreGroups = ['abs', 'core', 'obliques'];
    if (ex.muscleGroups.any((m) => coreGroups.contains(m))) return false;
    return ex.muscleGroups.contains('cardio');
  }

  static bool _matchesEquipment(Exercise e, String equipment) {
    if (equipment == 'gym' || equipment == 'mixed' || equipment == 'both' || equipment == 'any') return true;
    if (equipment == 'bodyweight') {
      final lowerName = e.name.toLowerCase();
      final hasIron = lowerName.contains('гантел') || lowerName.contains('штанг') || lowerName.contains('гирей') || lowerName.contains('блин') || lowerName.contains('тренажер') || lowerName.contains('блок');
      if (hasIron) return false;
      return e.equipment.contains('bodyweight');
    }
    if (equipment == 'dumbbells') return e.equipment.contains('bodyweight') || e.equipment.contains('dumbbells') || e.equipment.contains('resistance_band');
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
        'приседания на одной ноге', 'в висе', 'на тумбу', 'прыжки на тумбу', 'подтягивания', 'берпи'
      ];
      if (hardCoreKeywords.any((word) => lowerName.contains(word))) return false;

      if (equipment != 'bodyweight') {
        const tooEasyKeywords = ['с собственным весом', 'с колен', 'без веса'];
        if (tooEasyKeywords.any((word) => lowerName.contains(word))) return false;
      }

      return e.difficulty != 'advanced';
    }

    return true;
  }

  static String _normalizeName(String name) {
    var s = name.toLowerCase();
    const removals = [
      'на одной ноге', 'на одной руке', 'на двух ногах', 'на двух руках', 'на одну ногу', 'на одну руку', 'одной ногой', 'одной рукой',
      'на 1 ноге', 'на 1 руке', 'с одной ногой', 'с одной рукой', 'с гантелями', 'с гантелью', 'с гантелей', 'с одной гантелью',
      'со штангой', 'с штангой', 'с гирей', 'с эспандером', 'с резинкой', 'с бодибаром', 'с блином', 'с мячом', 'с фитболом', 'в наклоне',
      'с упором', 'на скамье', 'на полу', 'на коленях', 'сидя', 'стоя', 'лёжа', 'лежа', 'вис', 'вися', 'правой', 'левой', 'собственным весом', 'свой вес',
      'в кроссовере', 'в блоке', 'в тренажере', 'в тренажёре', 'на тренажере', 'на тренажёре', 'в кроссовер', 'с блоком', 'с тросом', 'на тросе', 'с рукоятью',
      'на турнике', 'на брусьях', 'с опорой', 'без опоры', 'с весом', 'без веса', 'с грифом'
    ];
    for (final r in removals) s = s.replaceAll(r, '');
    s = s.replaceAll('упражнение', '').replaceAll('подходы', '');
    s = s.replaceAll('мостик', 'мост').replaceAll('хип траст', 'мост').replaceAll('hip thrust', 'мост').replaceAll('подъем таза', 'мост');
    s = s.replaceAll('ягодичный', '').replaceAll('болгарский', 'выпад').replaceAll('боковая планка', 'планка');
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
      'core': 'кор', 'full_body': 'всё тело', 'cardio': 'кардио', 'feet': 'стопы', 'adductors': 'приводящие'
    };
    return map[code] ?? code;
  }

  static List<Stretch> _pickCoolDown(List<Stretch> all, List<String> groups, int max) {
    final rel = all.where((s) =>
    s.category == 'classic' &&
        (groups.contains(s.muscleGroup) || s.muscleGroup == 'full_body' || s.muscleGroup == 'back')
    ).toList();
    rel.shuffle(_random);
    return rel.take(max).toList();
  }

  static List<Stretch> _pickWarmup(List<Stretch> all, List<String> dayGroups, int max) {
    final warmups = all.where((s) => s.category == 'warmup').toList();
    if (warmups.isEmpty) return [];

    const baseNames = [
      'Вращения головой', 'Вращения плечами', 'Махи руками',
      'Наклоны корпуса в стороны', 'Круги тазом', 'Махи ногами', 'Вращения коленями',
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
        case 'glutes':    targetName = 'Мостик ягодичный (разминка)'; break;
        case 'abs':
        case 'core':
        case 'back':      targetName = 'Кошка-корова (разминка)'; break;
        case 'legs':
        case 'quads':
        case 'hamstrings': targetName = 'Приседания без веса (разминка)'; break;
        case 'shoulders':
        case 'chest':
        case 'arms':      targetName = 'Круги руками (разминка)'; break;
        case 'cardio':    targetName = 'Джампинг Джек'; break;
        default:          targetName = null;
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

  static int _getSets(String level) => level == 'beginner' ? 2 : (level == 'advanced' ? 4 : 3);
  static String _getReps(String goal) => goal == 'strength' ? '6-8' : (goal == 'gain_mass' ? '8-10' : (goal == 'tone' ? '15-18' : '15-20'));
  static int _getRest(String goal) => goal == 'strength' ? 120 : (goal == 'gain_mass' ? 90 : (goal == 'lose_weight' ? 45 : 60));

  static _ProgressionParams _getProgressionParams(int week, String goal, String level, int baseSets, int baseRest, String baseReps) {
    int sets = baseSets; String reps = baseReps; int rest = baseRest; int timedSeconds = 60; int cardioMinutes = 15;
    if (goal == 'lose_weight') { rest = 45; }

    if (goal == 'tone') {
      if (week == 1) reps = (level == 'beginner') ? '10-12' : '15';
      else if (week == 2) reps = (level == 'beginner') ? '12-15' : '18';
      else if (week == 3) reps = (level == 'beginner') ? '15' : '18';
      else reps = '15';
    } else {
      if (week == 1) {
        if (goal == 'strength' || goal == 'gain_mass') reps = '10-12';
        else reps = (level == 'beginner') ? '10-12' : '15';
      } else if (week == 2) {
        if (goal == 'strength' || goal == 'gain_mass') reps = '10-12';
        else reps = (level == 'beginner') ? '12-15' : '18';
      } else if (week == 3) {
        if (goal == 'strength' || goal == 'gain_mass') reps = '12-14';
        else reps = (level == 'beginner') ? '15' : '18';
      } else if (week == 4) {
        if (goal == 'strength' || goal == 'gain_mass') reps = '10-12';
        else reps = '15';
      }
    }

    if (level == 'beginner') {
      if (week == 1) timedSeconds = 30;
      else if (week == 2) timedSeconds = 40;
      else if (week == 3) timedSeconds = 50;
      else timedSeconds = 30;
    } else {
      if (week == 1) timedSeconds = 60;
      else if (week == 2) timedSeconds = 80;
      else if (week == 3) timedSeconds = 100;
      else timedSeconds = 60;
    }

    return _ProgressionParams(sets: sets, reps: reps, rest: rest, timedSeconds: timedSeconds, cardioMinutes: cardioMinutes);
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
      case 'advanced': return 1;
      case 'intermediate': return 2;
      case 'beginner': return 3;
      default: return 4;
    }
  }

  static int? _parseReps(String repsStr) {
    final match = RegExp(r'(\d+)').firstMatch(repsStr);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  static int? _parseMaxReps(String repsStr) {
    final matches = RegExp(r'(\d+)').allMatches(repsStr);
    if (matches.isEmpty) return null;
    final nums = matches.map((m) => int.tryParse(m.group(1) ?? '')).whereType<int>().toList();
    if (nums.isEmpty) return null;
    return nums.reduce((a, b) => a > b ? a : b);
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
