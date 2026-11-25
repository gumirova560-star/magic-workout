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

/// Фиксированный сид — для тестов. В проде вызывать не нужно.
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
    // 👇 v21.1: ограничения → зоны через карту (knees → legs, glutes).
    // Сырые коды ограничений оставляем в наборе — по ним матчатся
    // противопоказания ('knees', 'колени').
    final blocked = zonesBlockedByLimitations(limitations).toSet();
    for (final lim in limitations) {
        blocked.add(_norm(lim).toLowerCase());
    }
    return blocked;
}


static bool _isBlocked(Exercise e, Set<String> blockedZones) {
    if (blockedZones.isEmpty) return false;
    // 👇 v21.2: фолбэк в таблицу стал настоящим — таблица ключуется
    // кодами ограничений (knees/back/...), а не именами упражнений.
    // blockedZones содержит и сырые коды ограничений — по ним
    // exerciseBlockedByLimitations найдёт упражнение в таблице.
    if (exerciseBlockedByLimitations(e, blockedZones.toList())) return true;
    // Зональный блок (v21.1) — без изменений.
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
// 👈 ФИКС 1: проверка id ДО обращения к БД — иначе sqflite получает
// null в whereArgs и кидает не тот тип исключения.
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

// 👇 N+1 FIX 1: упражнения грузим ОДИН раз и ищем по map.
// Раньше getExerciseById дергался на каждое упражнение каждого дня
// прошлой недели — десятки лишних запросов за генерацию.
final rawExercises = await DatabaseHelper.instance.getExercises();
final Map<int, Exercise> exerciseById = {
for (final ex in rawExercises)
if (ex.id != null) ex.id!: ex,
};

final prefs = await SharedPreferences.getInstance();
final allowBaseChange =
prefs.getBool('allow_base_change_${profile.id}_$maxCycle') ?? false;
final bool shouldChangeBase = allowBaseChange;

// 👈 ФИКС 2: раскладку дат считаем ДО удаления незавершённых дней.
// _hasWorkoutToday читает базу — если бы удалили до неё, «сегодняшняя»
// выполненная тренировка потерялась бы и план снова встал на сегодня.
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

// Считаем пропуски ДО удаления незавершённых дней —
// анализатор смотрит в историю, а не в пустую базу.
int setsAdjustment = 0;
if (smart) {
try {
final missed = await WeekAnalyzer.missedLastWeek(profile.id!);
if (missed >= 2) setsAdjustment = -1;
} catch (_) {}
}

// 👈 ФИКС 3: снимаем историю весов/повторов ДО удаления незавершённых дней.
// (Исторически тут стоял deleteMonthPlan, стиравший всё — отсюда порядок.)
//
// COALESCE: замена хранится так, что в workout_exercises остаётся
// СТАРЫЙ itemId, а фактический id — в replacedByItemId. Группировка
// по we.itemId теряла историю заменённых упражнений (вес поднимали
// новым упражнением — а агрегировался старый id). Группируем по
// фактическому упражнению.
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

// 👇 ФИКС 7: снапшот истории в prefs. Храним личный рекорд
// веса в prefs — он переживает любые чистки базы, переустановку
// планов и пропущенные циклы.
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

// Вес с учётом prefs-фолбэка: если в текущей базе истории нет
// (упражнение пропустило цикл), берём сохранённый рекорд.
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
// 👇 N+1 FIX 1: lookup по map вместо запроса в цикле
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

// 👇 ФИКС 8: удаляем только НЕзавершённые дни (planned / in_progress).
// Прежний deleteMonthPlan стирал и completed — вместе с ними исчезала
// история, стрик и достижения. Завершённые дни — это достижения,
// они не трогаются никогда. Связанные упражнения и сеты чистит
// каскад (foreign_keys = ON).
await DatabaseHelper.instance.deleteUnfinishedWorkoutDays(profile.id!);

final focusGroups = _getFocusGroups(profile);
final cardioMode = _computeCardioMode(focusGroups, profile.goal);
final dayPlans =
_createDayTemplates(focusGroups, profile.daysPerWeek, profile.limitations);
// 👇 N+1 FIX 1: загрузку rawExercises перенесли наверх —
// здесь больше не грузим повторно, просто строим дедуп.
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
if (!matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
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
final createdDays = <WorkoutDay>[];

final List<Set<int>> recentIsolationIds = [];
// память семейств изоляции по последним дням (защита между днями)
final List<Set<String>> recentIsolationFamilies = [];
final Set<int> usedCardioThisWeek = {};
final Set<int> usedBonusIds = {};
String? lastBonusZone;

// окно памяти изоляции — 2 недели
final int isolationWindowDays = profile.daysPerWeek * 2;

for (int week = 1; week <= 4; week++) {
if (usedCardioThisWeek.length > 6) {
usedCardioThisWeek.clear();
}

for (int dayIndex = 0; dayIndex < dayPlans.length; dayIndex++) {
final dayGroups = dayPlans[dayIndex];
final baseExercises = monthBases[dayIndex];

// Разминку-кардио выбираем заранее, чтобы не дублировать с основным кардио
final bool hasCardioMachine = profile.equipment == 'gym' ||
profile.equipment == 'mixed' ||
profile.equipment == 'both';
Exercise? warmupCardioEx;
if (hasCardioMachine) {
final warmupCardioList = allExercises
.where((e) =>
(e.name.contains('дорожк') ||
e.name.contains('велотренаж') ||
e.name.contains('эллипс')) &&
matchesEquipment(e, profile.equipment))
.toList()
..shuffle(_random);
if (warmupCardioList.isNotEmpty) warmupCardioEx = warmupCardioList.first;
}

final isolationExercises = _pickIsolationForDay(
allExercises: allExercises,
muscleGroups: dayGroups,
bases: baseExercises,
equipment: profile.equipment,
level: profile.level,
limitations: profile.limitations,
maxCount: targetStrength + 4,
recentDayIds: recentIsolationIds,
repeatWindowSize: isolationWindowDays,
recentDayFamilies: recentIsolationFamilies,
);

final dayExercises = [...baseExercises, ...isolationExercises];
    // 👇 правка 6: blocked поднимаем на уровень дня — он нужен
    // кардио-фолбэку, добору силовых и бонусу за забытую зону
    final blocked = _buildBlockedZones(profile.limitations);

final dayCardios = <Exercise>[];
if (cardioMode == 'every_day' && dayGroups.isNotEmpty) {

final uniqueCardio = allExercises.where((e) {
if (e.id == null || usedCardioThisWeek.contains(e.id)) return false;
if (warmupCardioEx != null && e.id == warmupCardioEx.id) return false;
if (!_isCardio(e)) return false;
if (!matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (_isBlocked(e, blocked)) return false;
return true;
}).toList()..shuffle(_random);

final fallbackCardio = allExercises.where((e) {
if (e.id == null) return false;
if (warmupCardioEx != null && e.id == warmupCardioEx.id) return false;
if (!_isCardio(e)) return false;
if (!matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (_isBlocked(e, blocked)) return false;
return true;
}).toList()..shuffle(_random);

final cardioCandidates = [...uniqueCardio, ...fallbackCardio];
final bool isCardioOnlyDay =
dayGroups.isEmpty || (dayGroups.length == 1 && dayGroups.first == 'cardio');

final bool isLoseWeight = profile.goal == 'lose_weight' ||
profile.goal.contains('weight') ||
profile.goal.contains('lose');
final int baseCardioCount = isLoseWeight ? 3 : 1;

final int cardioCount = isCardioOnlyDay
? (profile.sessionMinutes / 10).round().clamp(2, 6)
: (profile.level == 'beginner'
? (isLoseWeight ? 2 : 1)
: baseCardioCount);

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
// не допускать дубль семейства в дне
final dayFamilies = <String>{
for (final e in strengthList) familyOf(e),
};
final extras = allExercises.where((e) {
if (strengthList.any((u) => u.id == e.id)) return false;
if (recentIds.contains(e.id)) return false;
if (_isCardio(e)) return false;
if (_isBlocked(e, blocked)) return false;   // 👈 правка 6: добавить
if (dayGroups.isNotEmpty &&
!e.muscleGroups.any((m) => dayGroups.contains(m))) return false;
if (dayFamilies.contains(familyOf(e))) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (!matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
return true;
}).toList()..shuffle(_random);

for (int i = 0; i < remaining && i < extras.length; i++) {
strengthList.add(extras[i]);
dayFamilies.add(familyOf(extras[i]));
}
}

final bool isCardioOnlyDay =
dayGroups.isEmpty || (dayGroups.length == 1 && dayGroups.first == 'cardio');
final bool isLoseWeightTarget = profile.goal == 'lose_weight' ||
profile.goal.contains('weight') ||
profile.goal.contains('lose');

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
if (warmupCardioEx != null && e.id == warmupCardioEx.id) return false;
if (!_isCardio(e)) return false;
if (_isBlocked(e, blocked)) return false;   // 👈 правка 6: добавить
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (!matchesEquipment(e, profile.equipment)) return false;
return true;
}).toList()..shuffle(_random);
for (int i = 0; i < targetCardio - cardioList.length && i < extras.length; i++) {
cardioList.add(extras[i]);
}
}

// ═══ СОРТИРОВКА И ИНТЕРВАЛЬНАЯ ВСТАВКА КАРДИО ═══
strengthList.sort((a, b) => _getExerciseWeight(a).compareTo(_getExerciseWeight(b)));
cardioList.sort((a, b) => _getExerciseWeight(a).compareTo(_getExerciseWeight(b)));

final List<Exercise?> finalOrder = [];
if (isLoseWeightTarget && strengthList.isNotEmpty) {
// ДЛЯ ПОХУДЕНИЯ: 3 силовых → кардио → ... → бонус → последнее кардио
final int numBlocks = (strengthList.length / 3).ceil();
final Exercise? lastCardio = cardioList.isNotEmpty ? cardioList.last : null;
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
finalOrder.add(null); // слот для бонуса
if (lastCardio != null) finalOrder.add(lastCardio);
} else {
// ОБЫЧНЫЙ РЕЖИМ: все силовые → бонус → всё кардио
finalOrder.addAll(strengthList);
finalOrder.add(null); // слот для бонуса
finalOrder.addAll(cardioList);
}

uniqueExercises.clear();
for (final e in finalOrder) {
if (e != null) uniqueExercises.add(e);
}

// ═══ Дата дня — по выбранным дням (или fallback-паттерну) ═══
// 👈 Слоты посчитаны выше, ДО удаления незавершённых дней (ФИКС 2).
final dayDate = today.add(Duration(
days: (week - 1) * 7 + weekdaySlots[dayIndex % weekdaySlots.length]));
bool isChallengeDay = (week == 3 && dayIndex == 1);
final dayType = isChallengeDay ? 'challenge' : 'strength';
final dayName = isChallengeDay
? 'Неделя $week: День Челленджа'
: 'Неделя $week: День ${dayIndex + 1}: ${dayGroups
.where((g) => g != 'cardio')
.map(_groupLabel)
.join(' + ')}';

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
final progression = _getProgressionParams(
week, profile.goal, profile.level, finalSets, _getRest(profile.goal), _getReps(profile.goal));

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
WorkoutSet(workoutExerciseId: warmupExId, order: 1, completed: false),
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
WorkoutSet(workoutExerciseId: warmupExId, order: 1, completed: false),
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
// 👇 Миграция v20: читаем тип из данных (exType), а не
// перечитываем muscleGroups — тот же источник, что и у
// деления дня на strengthList/cardioList выше.
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

final workoutExId = await DatabaseHelper.instance.addWorkoutExercise(
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
// 👈 ФИКС 4: вес из истории применяется для ВСЕХ недель (а не
// только первой). Перевыполнил 50 вместо 40 — новый план
// стартует с 50. Недовыполнил — вес не повышается.
//
// 👇 РЕЖИМ ВЕСА: 0 — нет поля, 1 — опционально, 2 — обязательно.
// Вес подкладываем только для обязательных (2) и НЕ timed:
// для timed _parseReps от «60 сек» вернула бы 60 «повторов»
// и раздул бы историю повторов.
final int wMode = weightModeOf(ex);
final bool timed = _isTimedExercise(ex.name);
final double? baseWeight = (!timed && wMode == 2) ? weightFor(ex.id) : null;
int? plannedReps;
if (!timed) {
plannedReps = _parseReps(repsStr);
// запоминаем и повторы: если пользователь делает больше
// запланированного, новый план не сбрасывает их обратно
final int? lastReps = lastRepsByExercise[ex.id];
if (plannedReps != null && lastReps != null && lastReps > plannedReps) {
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
} else if (isJumpRope || isHighIntensityCardio || isShadowBoxing || isBoxJump) {
// Скакалка, берпи, джеки, скалолаз, канаты, бой с тенью,
// прыжки на тумбу — сеты без веса и без «повторов из минут»
for (int s = 1; s <= localSetsCount; s++) {
await DatabaseHelper.instance.addWorkoutSet(
WorkoutSet(workoutExerciseId: workoutExId, order: s, weight: null, reps: null, completed: false),
);
}
}
}
// ═══ БОНУС НА «ЗАБЫТУЮ ЗОНУ» ═══
    final allZones = ['chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'];
    // 👇 v21: ограничения → зоны через карту. Раньше 'knees' сравнивался
    // с кодами зон напрямую и не срабатывал никогда — человек с больными
    // коленями получал бонус на ноги.
    final blockedZones = zonesBlockedByLimitations(profile.limitations);

    final forgottenZones = allZones
        .where((z) => !dayGroups.contains(z) && !blockedZones.contains(z))
        .toList();


if (forgottenZones.isNotEmpty) {
var availableZones = forgottenZones.where((z) => z != lastBonusZone).toList();
if (availableZones.isEmpty) availableZones = forgottenZones;

final zonesToTry = List.from(availableZones)..shuffle(_random);

// бонус не дублирует семейства, уже попавшие в день
final dayFamiliesForBonus = <String>{
for (final e in combinedList) familyOf(e),
};

for (final randomZone in zonesToTry) {
var bonusCandidates = allExercises.where((e) {
if (e.id == null || isBaseExercise(e) || _isCardio(e)) return false;
if (!matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
if (usedBonusIds.contains(e.id)) return false;
// 👇 ФИКС 10: бонус уважает исключения для зала
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (dayFamiliesForBonus.contains(familyOf(e))) return false;
if (_isBlocked(e, blocked)) return false;   // 👈 правка 6: добавить
return e.muscleGroups.contains(randomZone);
}).toList();

if (bonusCandidates.isEmpty) {
usedBonusIds.clear();
bonusCandidates = allExercises.where((e) {
if (e.id == null || isBaseExercise(e) || _isCardio(e)) return false;
if (!matchesEquipment(e, profile.equipment)) return false;
if (!_isDifficultyAllowed(e, profile.level, profile.equipment)) return false;
// 👇 ФИКС 10: и в fallback тоже
if ((profile.equipment == 'gym' || profile.equipment == 'mixed') &&
_isExcludedForGym(e.name)) return false;
if (dayFamiliesForBonus.contains(familyOf(e))) return false;
if (_isBlocked(e, blocked)) return false;   // 👈 правка 6: добавить
return e.muscleGroups.contains(randomZone);
}).toList();
}

if (bonusCandidates.isNotEmpty) {
final bonusEx = (bonusCandidates..shuffle(_random)).first;
usedBonusIds.add(bonusEx.id!);
lastBonusZone = randomZone;

// Timed-упражнения (планка, стульчик и т.п.) получают секунды,
// а не «10 повторов» — иначе прогрессия времени ломается
String bonusReps;
if (_isTimedExercise(bonusEx.name)) {
int secs = progression.timedSeconds;
if (bonusEx.name.toLowerCase().contains('боковая планка')) {
secs = (secs * 0.7).round();
}
bonusReps = '$secs сек';
} else if (profile.goal == 'strength' || profile.goal == 'gain_mass') {
bonusReps = '10';
} else if (profile.level == 'beginner') {
bonusReps = progression.reps;
} else {
bonusReps = '15';
}

final bonusWorkoutExId = await DatabaseHelper.instance.addWorkoutExercise(
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

// 👇 Бонус — полноценное упражнение. Если у него есть
// история веса, стартуем с последнего достигнутого веса и
// повторов, а не с нуля (как в основном цикле через ФИКС 4).
// Режим веса и timed-защита — как в основной ветке.
final int bonusMode = weightModeOf(bonusEx);
final bool bonusTimed = _isTimedExercise(bonusEx.name);
final double? bonusBaseWeight =
(!bonusTimed && bonusMode == 2) ? weightFor(bonusEx.id) : null;
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

final coolDown = _pickCoolDown(allStretches, dayGroups, 5);
for (final stretch in coolDown) {
final stretchExId = await DatabaseHelper.instance.addWorkoutExercise(
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
WorkoutSet(workoutExerciseId: stretchExId, order: 1, completed: false),
);
}
createdDays.add(day.copyWith(id: dayId));

// сохраняем id и семейства изоляции дня
final dayIsolationIds = isolationExercises.map((e) => e.id).whereType<int>().toSet();
recentIsolationIds.insert(0, dayIsolationIds);
final dayIsolationFamilies =
isolationExercises.map((e) => familyOf(e)).toSet();
recentIsolationFamilies.insert(0, dayIsolationFamilies);

final memoryLimit = isolationWindowDays;
if (recentIsolationIds.length > memoryLimit) {
recentIsolationIds.removeRange(memoryLimit, recentIsolationIds.length);
}
if (recentIsolationFamilies.length > memoryLimit) {
recentIsolationFamilies.removeRange(memoryLimit, recentIsolationFamilies.length);
}
}
}
return createdDays;
}

// ═══ РАСКЛАДКА ПО ВЫБРАННЫМ ДНЯМ НЕДЕЛИ ═══

/// Была ли сегодня уже завершённая/начатая тренировка у профиля.
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
return days.any((d) => d.status == 'completed' || d.status == 'in_progress');
} catch (_) {
return false;
}
}

/// Смещения дней от сегодняшнего (0..6), по одному на каждый день плана.
///
/// 1. Если в профиле выбраны дни (trainingWeekdays) — смещения из них.
/// 2. Если сегодня — выбранный день, но тренировка сегодня уже была —
///    offset 0 пропускается, план стартует со следующего выбранного дня.
/// 3. Если выбранных дней меньше daysPerWeek — дополняем ближайшими.
/// 4. Если дни не выбраны — fallback на фиксированные паттерны.
static Future<List<int>> _resolveWeekdaySlots(
UserProfile profile,
int todayWeekday, {
bool hasWorkoutToday = false,
}) async {
final selected = profile.trainingWeekdays.toSet().toList()..sort();

// Fallback: дни не выбраны — старое поведение
if (selected.isEmpty) {
return _weekdayOffsets(profile.daysPerWeek, todayWeekday,
hasWorkoutToday: hasWorkoutToday);
}

final offsets = <int>{};
for (final w in selected) {
final off = (w - todayWeekday) % 7;
if (off == 0 && hasWorkoutToday) continue; // старт со следующего дня
offsets.add(off);
}

// Дополняем ближайшими оставшимися днями
for (int off = 1; off < 7 && offsets.length < profile.daysPerWeek; off++) {
offsets.add(off);
}
// 👈 ФИКС 5: если единственный выбранный день — сегодня и он уже
// выполнен, ставим завтра, а не снова сегодня.
if (offsets.isEmpty) offsets.add(1);

final sorted = offsets.toList()..sort();
return sorted.take(profile.daysPerWeek).toList();
}

/// Fallback-раскладка по фиксированным паттернам (когда дни не выбраны).
/// Первый день — всегда сегодня (или завтра, если сегодня уже тренировался).
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

// 👈 ФИКС 6: fallback тоже уважает «сегодня уже тренировался» —
// слот 0 заменяется тем же днём на следующей неделе (+7)
if (hasWorkoutToday && offsets.contains(0)) {
offsets.remove(0);
offsets.add(7);
}

if (offsets.contains(0)) {
return offsets;
}
return [0, ...offsets.take(daysPerWeek - 1)];
}

// ═══ ПОДБОР БАЗ ДНЯ ═══
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
int lowerBodyBases =
baseToKeep.where((e) => ['glutes', 'legs'].contains(getExerciseZone(e))).length;

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
if (!matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if (usedFamilies.contains(familyOf(e))) return false;
if (usedFamiliesInMonth.contains(familyOf(e))) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList();

if (freshCandidates.isNotEmpty) {
final pick = _pickBestCandidate(freshCandidates, level, equipment)!;
result.add(pick);
zonesCovered.add(zone);
usedFamilies.add(familyOf(pick));
if (['glutes', 'legs'].contains(zone)) lowerBodyBases++;
} else {
final fallbackCandidates = allExercises.where((e) {
if (!isBaseExercise(e)) return false;
if (_isBlocked(e, blocked)) return false;
if (!matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if (usedFamilies.contains(familyOf(e))) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
return true;
}).toList();

if (fallbackCandidates.isNotEmpty) {
final pick = _pickBestCandidate(fallbackCandidates, level, equipment)!;
result.add(pick);
zonesCovered.add(zone);
usedFamilies.add(familyOf(pick));
if (['glutes', 'legs'].contains(zone)) lowerBodyBases++;
}
}
}
return result;
}

// ═══ ПОДБОР ИЗОЛЯЦИИ ДНЯ ═══
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
if (!matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if (getExerciseZone(e) != zone) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
final fam = familyOf(e);
if (usedFamilies.contains(fam)) return false;
return true;
}).toList();

// 👇 ЖЁСТКОЕ ОКНО: разрешено только то, что не встречалось
// в последних repeatWindowSize днях. Свежее — приоритет.
// Прежние ветки safeOld/mediumOld/lastTimeOld обходили окно —
// изоляция возвращалась через неделю. Теперь окно = запрет.
final allowed = candidates.where((e) {
  final lvl = repeatLevel(e.id);
  return lvl == null || lvl >= repeatWindowSize;
}).toList();

if (allowed.isNotEmpty) {
  // среди разрешённых сначала fresh — не в окне и не в памяти
  // семейств соседних дней
  final fresh = allowed.where((e) =>
  repeatLevel(e.id) == null &&
      !crossDayFamilies.contains(familyOf(e))).toList();
  final pick = _pickBestCandidate(
      fresh.isNotEmpty ? fresh : allowed, level, equipment)!;
  usedIds.add(pick.id!);
  usedFamilies.add(familyOf(pick));
  return pick;
}

// Каталог по зоне исчерпан в рамках окна — честный фолбэк:
// берём самое «остывшее» (максимальный lvl = дальше всех
// от текущего дня), а не самое свежее, как раньше.
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
if (!matchesEquipment(e, equipment)) return false;
if (!_isDifficultyAllowed(e, level, equipment)) return false;
if ((equipment == 'gym' || equipment == 'mixed') && _isExcludedForGym(e.name)) return false;
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

static Exercise? _pickBestCandidate(List<Exercise> candidates, String level, String equipment) {
if (candidates.isEmpty) return null;

if (level != 'beginner' && equipment != 'bodyweight') {
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

// ═══ ФОКУС И ШАБЛОНЫ ДНЕЙ ═══
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

final bool isLoseWeight =
goal == 'lose_weight' || goal.contains('weight') || goal.contains('lose');
if (isLoseWeight || goal == 'tone') return 'every_day';

return 'off';
}

    static List<List<String>> _createDayTemplates(
        List<String> focus, int days, List<String> limitations) {
        final blocked = _buildBlockedZones(limitations);
        final zoneBlocked = zonesBlockedByLimitations(limitations);
        final hasCardio = focus.contains('cardio');
// 👇 v21.1: фильтруем и по карте зон, и по сырым кодам —
// чтобы 'спина' отсекала 'back' даже до матчинга противопоказаний.
        final pool = focus.where((g) =>
        g != 'cardio' && !blocked.contains(g) && !zoneBlocked.contains(g)).toList();
        final isOnlyCardio = focus.length == 1 && hasCardio;
        if (pool.isEmpty && !isOnlyCardio) {
            pool.addAll(['glutes', 'abs', 'legs'].where((g) => !zoneBlocked.contains(g)));
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
                    // 👇 v21.1: соседние зоны не должны быть заблокированы —
                    // иначе в названии дня появится «Ноги» для человека с коленями
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

// 👇 Миграция v20: кардио-определение переехало в base_exercises.dart —
// сначала читаем exType из базы, эвристика по названию — только фолбэк.
static bool _isCardio(Exercise ex) => isCardioOf(ex);

static bool matchesEquipment(Exercise e, String equipment) {
final lowerName = e.name.toLowerCase();

if (equipment == 'gym' || equipment == 'mixed' || equipment == 'both' || equipment == 'any') {
return true;
}

// 👈 ФИКС 13: домашнее кардио доступно при любом инвентаре —
// «бег на месте» не становится недоступным от отсутствия гантелей.
// Машинное кардио (дорожка, велотренажёр, эллипс) — по-прежнему только зал:
// его правило проверяется ПЕРВЫМ, чтобы «бег на дорожке» не проскочил
// через homeCardio (он содержит и «бег», и «дорожк»).
const machineCardio = ['дорожк', 'велотренаж', 'эллипс', 'гребл', 'степпер'];
final isMachineCardio = machineCardio.any(lowerName.contains);
const homeCardio = ['бег', 'скакалк', 'скалолаз', 'берпи', 'джеки', 'бой с тенью'];
if (!isMachineCardio && homeCardio.any(lowerName.contains)) return true;

final homeForbidden = [
'тренажер', 'тренажёр', 'блок', 'кроссовер', 'смит', 'т-гриф',
'бабочка', 'тумбу', 'тумба', 'платформ', 'паттерн', 'босу', 'полусфер',
'жим ногами', 'гакк',
];
for (final word in homeForbidden) {
if (lowerName.contains(word)) return false;
}

if (equipment == 'bodyweight') {
final iron = ['гантел', 'штанг', 'гирей', 'блин', 'гриф', 'резинк'];
for (final word in iron) {
if (lowerName.contains(word)) return false;
}
return e.equipment.contains('bodyweight');
}

if (equipment == 'dumbbells') {
final heavy = ['штанг', 'гирей', 'блин', 'гриф'];
for (final word in heavy) {
if (lowerName.contains(word)) return false;
}
return e.equipment.contains('bodyweight') ||
e.equipment.contains('dumbbells') ||
e.equipment.contains('resistance_band');
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
      'feet': 'стопы', 'adductors': 'приводящие'
    };
    return map[code] ?? code;
  }

  // ═══ РАЗМИНКА / ЗАМИНКА ═══
  static List<Stretch> _pickCoolDown(List<Stretch> all, List<String> groups, int max) {
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

  static List<Stretch> _pickWarmup(List<Stretch> all, List<String> dayGroups, int max) {
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

  // ═══ ПРОГРЕССИЯ ═══
  static int _getSets(String level) =>
      level == 'beginner' ? 2 : (level == 'advanced' ? 4 : 3);

  static String _getReps(String goal) => goal == 'strength'
      ? '6-8'
      : (goal == 'gain_mass' ? '8-10' : (goal == 'tone' ? '15-18' : '15-20'));

  static int _getRest(String goal) => goal == 'strength'
      ? 120
      : (goal == 'gain_mass' ? 90 : (goal == 'lose_weight' ? 45 : 60));

  static _ProgressionParams _getProgressionParams(
      int week, String goal, String level, int baseSets, int baseRest, String baseReps) {
    int sets = baseSets;
    String reps = baseReps;
    int rest = baseRest;
    int timedSeconds = 60;
    int cardioMinutes = 15;
    if (goal == 'lose_weight') { rest = 45; }

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
        sets: sets, reps: reps, rest: rest,
        timedSeconds: timedSeconds, cardioMinutes: cardioMinutes);
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
