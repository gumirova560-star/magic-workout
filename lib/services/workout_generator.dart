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
for (final lim in limitations) blocked.add(_norm(lim));
return blocked;
}

// 👇 ФИЛЬТР: Исключаем реабилитацию стоп, вакуум и танцы для зала/смешанного
static bool _isExcludedForGym(String exerciseName) {
final lower = exerciseName.toLowerCase();
const excludedWords = [
'полотенц',
'мячик',
'пальц',
'внешней стороне стопы',
'вакуум',
'танц',
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
if (we.itemType == 'exercise' && !we.isCoolDown) {
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

final allExercises = await DatabaseHelper.instance.getExercises();
final allStretches = await DatabaseHelper.instance.getStretches();

final monthBases = <List<Exercise>>[];
final usedBaseIds = <int>{...oldBaseIds};
final Set<String> usedFamiliesInMonth = {}; // 👈 Защита от дублей в разных днях

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
);

if (bases.length < 3 && dayPlans[i].isNotEmpty) {
final blocked = _buildBlockedZones(profile.limitations);
final extraCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (bases.any((b) => b.id == e.id)) return false;
if (usedBaseIds.contains(e.id)) return false;
if (e.contraindications.any((c) => blocked.contains(_norm(c)))) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList()..shuffle(_random);

for (final extra in extraCandidates) {
if (bases.length >= 3) break;
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
maxCount: _getExerciseCount(profile.sessionMinutes, profile.level) + 4,
recentDayIds: recentIsolationIds,
repeatWindowSize: profile.daysPerWeek * 2,
);

final dayExercises = [...baseExercises, ...isolationExercises];

final dayCardios = <Exercise>[];
if (cardioMode == 'every_day' || dayGroups.isEmpty) {
final uniqueCardio = allExercises.where((e) {
if (e.id == null || usedCardioThisWeek.contains(e.id)) return false;
if (!_isCardio(e)) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList()..shuffle(_random);

final fallbackCardio = allExercises.where((e) {
if (e.id == null) return false;
if (!_isCardio(e)) return false;
if (!_matchesEquipment(e, profile.equipment)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList()..shuffle(_random);

final cardioCandidates = [...uniqueCardio, ...fallbackCardio];
final bool isCardioOnlyDay = dayGroups.isEmpty || (dayGroups.length == 1 && dayGroups.first == 'cardio');
final int cardioCount = isCardioOnlyDay
? (profile.sessionMinutes / 10).round().clamp(2, 6)
: ((profile.goal == 'lose_weight') ? 3 : 1);

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

final uniqueExercises = <Exercise>[];
final Set<String> addedNames = {};
final Set<String> addedBaseTypes = {};

final finalExercisesList = [...dayExercises, ...dayCardios];
for (final ex in finalExercisesList) {
if (isBaseExercise(ex)) {
final normName = _normalizeName(ex.name);
if (normName.contains('мост') || normName.contains('хип траст') || normName.contains('hip thrust')) {
if (addedBaseTypes.contains('bridge')) continue;
addedBaseTypes.add('bridge');
}
if (!addedNames.contains(normName)) { uniqueExercises.add(ex); addedNames.add(normName); }
} else {
if (!uniqueExercises.any((u) => u.id == ex.id)) {
uniqueExercises.add(ex);
}
}
}

final dayDate = DateTime.now().add(Duration(days: (week - 1) * 7 + dayIndex));

final bool isCardioOnlyDay = dayGroups.isEmpty || (dayGroups.length == 1 && dayGroups.first == 'cardio');
final dayName = isCardioOnlyDay
? 'День ${dayIndex + 1}: Кардио-день 🏃‍♀️'
: 'День ${dayIndex + 1}: ${dayGroups.where((g) => g != 'cardio').map(_groupLabel).join(' + ')}';

final day = WorkoutDay(
profileId: profile.id!, name: 'Неделя $week: $dayName', type: 'strength',
weekNumber: week, cycleNumber: newCycle, status: 'planned',
durationMinutes: profile.sessionMinutes, date: dayDate,
);

final dayId = await DatabaseHelper.instance.createWorkoutDay(day);
final baseSets = _getSets(profile.level);
final finalSets = (baseSets + setsAdjustment).clamp(2, 5);
final progression = _getProgressionParams(week, profile.goal, profile.level, finalSets, _getRest(profile.goal), _getReps(profile.goal));

// 👇 ЖЕСТКО 3 ПОДХОДА ДЛЯ КРУГОВОЙ ТРЕНИРОВКИ
int setsCount = 3;

uniqueExercises.sort((a, b) => _getExerciseWeight(a).compareTo(_getExerciseWeight(b)));

final Map<int, int> blockByExerciseId = {};
for (int i = 0; i < baseExercises.length; i++) {
final bId = baseExercises[i].id;
if (bId != null) blockByExerciseId[bId] = i + 1;
}
for (int i = 0; i < isolationExercises.length; i++) {
final isoId = isolationExercises[i].id;
if (isoId != null) blockByExerciseId[isoId] = (i ~/ 2) + 1;
}

int order = 1;
for (final ex in uniqueExercises) {
final lowerName = ex.name.toLowerCase();
final isJumpRope = lowerName.contains('скакалк') || (lowerName.contains('прыжк') && !lowerName.contains('тумбу'));
final isHighIntensityCardio = _isHighIntensityCardio(lowerName);
final isShadowBoxing = lowerName.contains('бой с тенью');
final isBoxJump = lowerName.contains('тумбу');
final isCardio = ex.muscleGroups.contains('cardio');

int localSetsCount; String repsStr;
if (isJumpRope) { localSetsCount = 3; repsStr = '2 мин'; }
else if (isShadowBoxing) { localSetsCount = 3; repsStr = '3 мин'; }
else if (isBoxJump) { localSetsCount = 3; repsStr = '12 повт'; }
else if (isHighIntensityCardio) { localSetsCount = 3; repsStr = '30 сек'; }
else if (isCardio) { localSetsCount = 1; repsStr = '${progression.cardioMinutes} мин'; }
else if (_isTimedExercise(ex.name)) {
localSetsCount = setsCount;
int secs = isBaseExercise(ex) ? progression.timedSeconds : 60;
repsStr = '$secs сек';
}
else {
localSetsCount = setsCount;
if (isBaseExercise(ex)) {
repsStr = progression.reps;
} else {
if (profile.goal == 'strength' || profile.goal == 'gain_mass') {
repsStr = '10';
} else {
repsStr = '15';
}
}
}

final workoutExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
workoutDayId: dayId, itemType: 'exercise', itemId: ex.id!,
order: order++, sets: localSetsCount, reps: repsStr, restSeconds: progression.rest,
blockNumber: blockByExerciseId[ex.id!],
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

final coolDown = _pickCoolDown(allStretches, dayGroups, 5);
for (final stretch in coolDown) {
final stretchExId = await DatabaseHelper.instance.addWorkoutExercise(WorkoutExercise(
workoutDayId: dayId, itemType: 'stretch', itemId: stretch.id!,
order: order++, durationSeconds: stretch.durationSeconds, isCoolDown: true,
));
await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: stretchExId, order: 1, completed: false));
}
createdDays.add(day.copyWith(id: dayId));

final dayIsolationIds = isolationExercises.map((e) => e.id).whereType<int>().toSet();
recentIsolationIds.insert(0, dayIsolationIds);
if (recentIsolationIds.length > profile.daysPerWeek * 2) {
recentIsolationIds.removeRange(profile.daysPerWeek * 2, recentIsolationIds.length);
}
}
}
return createdDays;
}
// ═══ КОНЕЦ ЧАСТИ 1 из 3 — workout_generator.dart ═══
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

final freshCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (usedBaseIds.contains(e.id)) return false;
if (e.contraindications.any((c) => blocked.contains(_norm(c)))) return false;
if (!_matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level)) return false;
if (getExerciseZone(e) != zone) return false;
if (usedFamilies.contains(getExerciseFamily(e.name))) return false;
if (usedFamiliesInMonth.contains(getExerciseFamily(e.name))) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList();

if (freshCandidates.isNotEmpty) {
freshCandidates.shuffle(_random);
final pick = freshCandidates.first;
result.add(pick);
zonesCovered.add(zone);
usedFamilies.add(getExerciseFamily(pick.name));
if (['glutes', 'legs'].contains(zone)) lowerBodyBases++;
} else {
final fallbackCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (!oldBaseIds.contains(e.id)) return false;
if (e.contraindications.any((c) => blocked.contains(_norm(c)))) return false;
if (!_matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level)) return false;
if (getExerciseZone(e) != zone) return false;
if (usedFamilies.contains(getExerciseFamily(e.name))) return false;
if (usedFamiliesInMonth.contains(getExerciseFamily(e.name))) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList();

if (fallbackCandidates.isNotEmpty) {
fallbackCandidates.shuffle(_random);
final pick = fallbackCandidates.first;
result.add(pick);
zonesCovered.add(zone);
usedFamilies.add(getExerciseFamily(pick.name));
if (['glutes', 'legs'].contains(zone)) lowerBodyBases++;
}
}
}
return result;
}

static List<String> _isolationZonesForBase(String baseZone) {
switch (baseZone) {
case 'glutes': return ['abs', 'glutes'];
case 'legs':   return ['abs', 'legs'];
case 'abs':    return ['glutes', 'legs'];
case 'chest':  return ['back', 'chest'];
case 'back':   return ['chest', 'back'];
case 'shoulders': return ['arms', 'shoulders'];
case 'arms':   return ['shoulders', 'arms'];
default:       return [baseZone, baseZone];
}
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
if (e.contraindications.any((c) => blocked.contains(_norm(c)))) return false;
if (!_matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level)) return false;
if (getExerciseZone(e) != zone) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
final fam = getExerciseFamily(e.name);
if (usedFamilies.contains(fam)) return false;
return true;
}).toList();

final fresh = candidates.where((e) => repeatLevel(e.id) == null).toList()..shuffle(_random);
final old = candidates.where((e) => repeatLevel(e.id) != null).toList()..shuffle(_random);
final ordered = [...fresh, ...old];
if (ordered.isEmpty) return null;
final pick = ordered.first;
usedIds.add(pick.id!);
usedFamilies.add(getExerciseFamily(pick.name));
return pick;
}

Exercise? pickFromAnyZone(List<String> zones) {
for (final z in zones) {
final e = pickFromZone(z);
if (e != null) return e;
}
return null;
}

for (final base in bases) {
if (result.length >= maxCount) break;
final baseZone = getExerciseZone(base);
final zones = _isolationZonesForBase(baseZone);

Exercise? first = pickFromZone(zones[0]);
Exercise? second = pickFromZone(zones[1]);

if (baseZone == 'abs') {
if (first == null) first = pickFromAnyZone(['glutes', 'legs']);
if (second == null) second = pickFromAnyZone(['glutes', 'legs']);
} else {
if (first == null) first = pickFromAnyZone(['glutes', 'legs', 'abs', 'shoulders', 'arms', 'chest', 'back']);
if (second == null) second = pickFromAnyZone(['glutes', 'legs', 'abs', 'shoulders', 'arms', 'chest', 'back']);
}

if (first != null) result.add(first);
if (second != null) result.add(second);
}

return result;
}

static List<String> _getFocusGroups(UserProfile profile) {
if (profile.focusAreas.isNotEmpty) return profile.focusAreas.map(_norm).toList();

if (profile.bodyType != null) {
switch (profile.bodyType) {
case 'pear': return ['glutes', 'legs', 'shoulders'];
case 'inverted_triangle': return ['glutes', 'legs', 'abs'];
case 'rectangle': return ['glutes', 'shoulders', 'legs'];
case 'apple': return ['abs', 'cardio', 'legs'];
case 'hourglass': return ['glutes', 'abs', 'legs'];
default: break;
}
}

if (profile.goal == 'lose_weight') {
final list = profile.focusAreas.map(_norm).toList();
if (!list.contains('cardio')) list.add('cardio');
return list;
}
if (profile.gender == 'female') return ['glutes', 'abs', 'legs'];
return ['chest', 'back', 'arms', 'legs'];
}

static String _computeCardioMode(List<String> focus, String goal) {
if (focus.contains('cardio')) return 'every_day';
if (goal == 'lose_weight' || goal == 'tone') return 'every_day';
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
// ═══ КОНЕЦ ЧАСТИ 2 из 3 — workout_generator.dart ═══
  static bool _isHighIntensityCardio(String lowerName) {
    if (lowerName.contains('берпи') || lowerName.contains('скалолаз') || lowerName.contains('джеки') || lowerName.contains('колен')) return true;
    if (lowerName.contains('канат') && (lowerName.contains('махи') || lowerName.contains('волны') || lowerName.contains('бэтл'))) return true;
    return false;
  }

  static bool _isTimedExercise(String name) {
    final lower = name.toLowerCase();
    const keywords = ['планка', 'plank', 'бег', 'дорожк', 'скакалк', 'ходьб', 'велотренаж', 'эллипс', 'гребл', 'кардио'];
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
    if (equipment == 'bodyweight') return e.equipment.contains('bodyweight');
    if (equipment == 'dumbbells') return e.equipment.contains('bodyweight') || e.equipment.contains('dumbbells') || e.equipment.contains('resistance_band');
    return true;
  }

  static bool _isDifficultyAllowed(Exercise e, String level) {
    if (level == 'beginner') return e.difficulty == 'beginner' || e.difficulty == 'intermediate';
    if (level == 'intermediate') return e.difficulty != 'advanced';
    return true;
  }

  static String _normalizeName(String name) {
    var s = name.toLowerCase();
    const removals = [
      'на одной ноге', 'на одной руке', 'на двух ногах', 'на двух руках', 'на одну ногу', 'на одну руку', 'одной ногой', 'одной рукой',
      'на 1 ноге', 'на 1 руке', 'с одной ногой', 'с одной рукой', 'с гантелями', 'с гантелью', 'с гантелей', 'с одной гантелью',
      'со штангой', 'с штангой', 'с гирей', 'с эспандером', 'с резинкой', 'с бодибаром', 'с блином', 'с мячом', 'с фитболом', 'в наклоне',
      'с упором', 'на скамье', 'на полу', 'на коленях', 'сидя', 'стоя', 'лёжа', 'лежа', 'вис', 'вися', 'правой', 'левой', 'собственным весом', 'свой вес',
      'в кроссовере', 'в блоке', 'в тренажере', 'в тренажёре', 'на тренажере', 'на тренажёре', 'в кроссовер', 'с блоком', 'с тросом', 'на тросе', 'с рукоятью'
    ];
    for (final r in removals) s = s.replaceAll(r, '');
    s = s.replaceAll('упражнение', '').replaceAll('подходы', '');
    s = s.replaceAll('мостик', 'мост').replaceAll('хип траст', 'мост').replaceAll('hip thrust', 'мост').replaceAll('подъем таза', 'мост');
    s = s.replaceAll('ягодичный', '').replaceAll('болгарский', 'выпад').replaceAll('боковая планка', 'планка');
    s = s.replaceAll(RegExp(r'[,\-—–()\[\]:;]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
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
    final rel = all.where((s) => groups.contains(s.muscleGroup) || s.muscleGroup == 'full_body' || s.muscleGroup == 'back').toList();
    rel.shuffle(_random);
    return rel.take(max).toList();
  }

  static int _getSets(String level) => level == 'beginner' ? 2 : (level == 'advanced' ? 4 : 3);
  static String _getReps(String goal) => goal == 'strength' ? '6-8' : (goal == 'gain_mass' ? '8-10' : (goal == 'tone' ? '15-18' : '15-20'));
  static int _getRest(String goal) => goal == 'strength' ? 120 : (goal == 'gain_mass' ? 90 : (goal == 'lose_weight' ? 45 : 60));

  static _ProgressionParams _getProgressionParams(int week, String goal, String level, int baseSets, int baseRest, String baseReps) {
    int sets = baseSets; String reps = baseReps; int rest = baseRest; int timedSeconds = 60; int cardioMinutes = 15;
    if (goal == 'lose_weight') { cardioMinutes = 15 + (week * 5); rest = 45; }
    if (goal == 'tone') { reps = week == 1 ? '15-18' : (week == 2 ? '18' : (week == 3 ? '20' : '15')); }
    else {
      if (week == 1) { if (goal == 'strength' || goal == 'gain_mass') reps = '10-12'; }
      else if (week == 2) { if (goal == 'strength' || goal == 'gain_mass') reps = '10-12'; else reps = '18'; }
      else if (week == 3) { if (goal == 'strength' || goal == 'gain_mass') reps = '12-14'; else reps = '20'; }
      else if (week == 4) { if (goal == 'strength' || goal == 'gain_mass') reps = '10-12'; else reps = '15'; }
    }

    if (week == 1) timedSeconds = 60;
    else if (week == 2) timedSeconds = 80;
    else if (week == 3) timedSeconds = 100;
    else timedSeconds = 100;

    return _ProgressionParams(sets: sets, reps: reps, rest: rest, timedSeconds: timedSeconds, cardioMinutes: cardioMinutes);
  }

  static int _getExerciseCount(int sessionMinutes, String level) {
    int count = (sessionMinutes / 7.5).round();
    if (level == 'beginner') count = (count * 0.8).round();
    else if (level == 'advanced') count = (count * 1.2).round();
    return ((count / 3).ceil() * 3).clamp(3, 15);
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
    required this.rest,
    required this.reps,
    required this.timedSeconds,
    required this.cardioMinutes,
  });
}
// ═══ КОНЕЦ ЧАСТИ 3 из 3 — ФАЙЛ workout_generator.dart ЗАВЕРШЁН ═══