import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/fairy_mood.dart';
import '../../data/base_exercises.dart';
import '../../models/user_profile.dart';
import '../../models/workout_day.dart';
import '../../models/exercise.dart';
import '../../services/database_helper.dart';
import '../../services/workout_generator.dart' hide DatabaseHelper;
import '../../services/week_analyzer.dart';
import '../../services/fairy_reaction_service.dart';
import '../../services/fairy_stats_service.dart';
import '../yoga/yoga_screen.dart';
import '../trainer/trainer_screen.dart';
import 'workout_detail_screen.dart';
import 'challenge_dice_screen.dart';
import '../../widgets/daily_challenge_card.dart';
import '../../widgets/energy_badge.dart';
import '../garden/garden_screen.dart'; // 👈 Импорт Сада
import '../../services/energy_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  UserProfile? _activeProfile;
  List<WorkoutDay> _monthDays = [];
  List<WorkoutDay> _allHistory = [];
  int _selectedWeek = 1;
  WeekSummary? _lastWeek;
  int _streak = 0;
  bool _loading = true;
  bool _generating = false;
  bool _showCompletionBanner = false;
  int _currentWeekWorkouts = 0;
  int _currentWeekMinutes = 0;

  // 👇 Гендер и имя для фраз Феи
  String get _name => _activeProfile?.name ?? 'друг';
  bool get _isMale => _activeProfile?.gender == 'male';
  String get _ready => _isMale ? 'Готов' : 'Готова';
  String get _tired => _isMale ? 'Устал' : 'Устала';

  @override
  void initState() {
    super.initState();
    _loadData();
    _precacheGardenImages(); // 👈 ПРЕДЗАГРУЗКА КАРТИНОК САДА
    FairyReactionService().addProfileListener(_onProfileChanged);
    FairyReactionService().addWorkoutListener(_onWorkoutCompleted);
  }

  // 👇 МЕТОД ДЛЯ ПРЕДЗАГРУЗКИ
  void _precacheGardenImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(const AssetImage('assets/flowers/grass_bg.png'), context);
      precacheImage(const AssetImage('assets/flowers/tree.png'), context);
      precacheImage(const AssetImage('assets/flowers/pond.png'), context);
      precacheImage(const AssetImage('assets/flowers/fountain.png'), context);
      precacheImage(const AssetImage('assets/flowers/pavilion.png'), context);
    });
  }

  void _onProfileChanged() { if (mounted) _loadData(); }
  void _onWorkoutCompleted() { if (mounted) _loadData(); }

  @override
  void dispose() {
    FairyReactionService().removeProfileListener(_onProfileChanged);
    FairyReactionService().removeWorkoutListener(_onWorkoutCompleted);
    super.dispose();
  }

  // ═══ 👈 ИЗМЕНЕНО: trainingWeekdays участвует в хеше профиля ═══
  String _computeProfileHash(UserProfile p) {
    return [
      p.gender, p.age, p.height, p.weight, p.level, p.goal, p.equipment,
      p.daysPerWeek, p.sessionMinutes, p.trainingWeekdays.join(','),
      p.focusAreas.join(','), p.limitations.join(','),
    ].join('|');
  }

  String _profileHashKey(int profileId) => 'workout_plan_profile_hash_$profileId';
  String _dismissedHashKey(int profileId) => 'workout_plan_profile_hash_dismissed_$profileId';

  Future<bool> _shouldSuggestPlanUpdate(UserProfile profile) async {
    if (profile.id == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = _profileHashKey(profile.id!);
    final currentHash = _computeProfileHash(profile);
    final savedHash = prefs.getString(key);
    if (savedHash == null) { await prefs.setString(key, currentHash); return false; }
    if (savedHash == currentHash) return false;
    final dismissedKey = _dismissedHashKey(profile.id!);
    final dismissedHash = prefs.getString(dismissedKey);
    if (dismissedHash == currentHash) return false;
    return true;
  }

  Future<void> _saveProfileHashAsAccepted(UserProfile profile) async {
    if (profile.id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileHashKey(profile.id!), _computeProfileHash(profile));
    await prefs.remove(_dismissedHashKey(profile.id!));
  }

  Future<void> _saveProfileHashAsDismissed(UserProfile profile) async {
    if (profile.id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedHashKey(profile.id!), _computeProfileHash(profile));
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    var profiles = await DatabaseHelper.instance.getProfiles();
    if (profiles.isEmpty) {
      for (int attempt = 0; attempt < 5; attempt++) {
        await Future.delayed(const Duration(milliseconds: 300));
        profiles = await DatabaseHelper.instance.getProfiles();
        if (profiles.isNotEmpty) break;
      }
    }
    await FairyReactionService().loadActiveProfile();

    if (profiles.isNotEmpty) {
      final active = profiles.first;
      // 👇 ЕЖЕДНЕВНЫЙ ВХОД: +5⚡ один раз в календарный день.
      if (active.id != null) {
        await EnergyService.grantDailyLogin(active.id!);
      }

      final allHistory = await DatabaseHelper.instance.getWorkoutDays(profileId: active.id!, limit: 100);

      final activeMonthPlan = allHistory.where((d) => d.status != 'completed').toList();
      activeMonthPlan.sort((a, b) {
        if (a.weekNumber != b.weekNumber) return (a.weekNumber ?? 0).compareTo(b.weekNumber ?? 0);
        return a.date.compareTo(b.date);
      });

      final hasCompletedHistory = allHistory.any((d) => d.status == 'completed');
      _showCompletionBanner = activeMonthPlan.isEmpty && hasCompletedHistory;

      int activeWeek = 1;
      for (int w = 1; w <= 4; w++) {
        final weekDays = activeMonthPlan.where((d) => d.weekNumber == w).toList();
        if (weekDays.isEmpty) continue;
        final allDone = weekDays.every((d) => d.status == 'completed');
        if (!allDone) { activeWeek = w; break; }
        activeWeek = w + 1;
      }
      if (activeWeek > 4) activeWeek = 4;

      final lastWeek = await WeekAnalyzer.analyzeLastWeek(active.id!);
      final streak = await FairyStatsService.getStreak();
      final completed = allHistory.where((w) => w.status == 'completed').toList();

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final monday = todayDate.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(monday.year, monday.month, monday.day);
      final weekEnd = weekStart.add(const Duration(days: 7));

      int curWeekCount = 0;
      int curWeekMinutes = 0;
      for (final w in completed) {
        final actual = w.completedAt ?? w.date;
        final d = DateTime(actual.year, actual.month, actual.day);
        if (!d.isBefore(weekStart) && d.isBefore(weekEnd)) {
          curWeekCount++;
          curWeekMinutes += (w.durationMinutes ?? 0).toInt();
        }
      }

      if (!mounted) return;
      setState(() {
        _activeProfile = active;
        _monthDays = activeMonthPlan;
        _allHistory = allHistory;
        _selectedWeek = activeWeek;
        _lastWeek = lastWeek;
        _streak = streak;
        _currentWeekWorkouts = curWeekCount;
        _currentWeekMinutes = curWeekMinutes;
        _loading = false;
      });

      // 👇 ИЗМЕНЕНО: вместо holdScreenPhrases() и баннера — нативный диалог
      final shouldAsk = await _shouldSuggestPlanUpdate(active);
      await FairyReactionService().setActiveProfile(active.id, active.name, gender: active.gender);

      if (shouldAsk) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showProfileChangedDialog(active);
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _activeProfile = null;
        _monthDays = [];
        _allHistory = [];
        _selectedWeek = 1;
        _lastWeek = null;
        _streak = 0;
        _currentWeekWorkouts = 0;
        _currentWeekMinutes = 0;
        _showCompletionBanner = false;
        _loading = false;
      });
      await FairyReactionService().setActiveProfile(null, null);
    }
  }

  // 👇 ИЗМЕНЕНО: настоящий диалог вместо исчезающего баннера феи
  Future<void> _showProfileChangedDialog(UserProfile profile) async {
    final update = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.tune_rounded, color: Color(0xFF6C5CE7), size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Text('Настройки изменились', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: Text(
          'Ты ${_isMale ? 'изменил' : 'изменила'} профиль — вес, цель или расписание. '
              'Обновить план тренировок под новые настройки?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Позже')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
            child: const Text('Обновить план'),
          ),
        ],
      ),
    );

    if (update == true) {
      await _generatePlan(isUpdate: true);
    } else {
      await _saveProfileHashAsDismissed(profile);
    }
  }

  // ═══ НОВОЕ: считаем РЕАЛЬНО завершённые циклы ═══
  Future<int> _countCompletedCycles(int profileId, int daysPerWeek) async {
    try {
      final days = await DatabaseHelper.instance.getWorkoutDays(
        profileId: profileId,
        limit: 500,
      );
      final Map<int, List<WorkoutDay>> byCycle = {};
      for (final d in days) {
        final c = d.cycleNumber;
        if (c == null) continue;
        byCycle.putIfAbsent(c, () => []).add(d);
      }
      final int fullCycleSize = daysPerWeek * 4;
      int completed = 0;
      byCycle.forEach((cycle, list) {
        if (list.isNotEmpty &&
            list.length >= fullCycleSize &&
            list.every((d) => d.status == 'completed')) {
          completed++;
        }
      });
      return completed;
    } catch (_) {
      return 0;
    }
  }

  // ═══ ИЗМЕНЕНО: для дома — повышение уровня, для зала — ротация баз.
  // Триггеры FairyReactionService убраны: диалоги самодостаточны. ═══
  Future<void> _generatePlan({bool isUpdate = false}) async {
    if (_activeProfile == null) { _showMessage('Сначала создайте профиль'); return; }

    bool levelUpgraded = false;

    final maxCycle = await DatabaseHelper.instance.getMaxCycleNumber(_activeProfile!.id!);
    final completedCycles = await _countCompletedCycles(
      _activeProfile!.id!,
      _activeProfile!.daysPerWeek,
    );
    if (completedCycles >= 2 && completedCycles % 2 == 0) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'base_update_asked_${_activeProfile!.id}_cc$completedCycles';
      final alreadyAsked = prefs.getBool(key) ?? false;

      if (!alreadyAsked) {
        final profile = _activeProfile!;
        final bool isHome = profile.equipment == 'home';
        final String? nextLevel = isHome && profile.level == 'beginner'
            ? 'intermediate'
            : isHome && profile.level == 'intermediate'
            ? 'advanced'
            : null;

        if (nextLevel != null) {
          // 👇 ДОМ: предложение повышения уровня
          final String levelLabel = nextLevel == 'intermediate' ? 'Средний' : 'Опытный';
          final String dialogText = nextLevel == 'intermediate'
              ? 'Ты стабильно занимаешься уже 2 месяца — время усложнить тренировки! '
              'Перейти на уровень «Средний»? Появятся новые упражнения, '
              'больше подходов и выше нагрузка.'
              : 'Ты отлично держишь темп уже 4 месяца! Перейти на уровень '
              '«Опытный»? Тренировки станут заметно сложнее — новые упражнения, '
              'больше подходов и меньше отдыха.';

          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(children: [
                Image.asset(FairyMood.party.asset, width: 44, height: 44, fit: BoxFit.contain),
                const SizedBox(width: 10),
                const Expanded(child: Text('Пора расти! 🎉', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ]),
              content: Text(dialogText),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Пока на этом уровне')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE17055)),
                  child: Text('Повысить до «$levelLabel»'),
                ),
              ],
            ),
          );

          await prefs.setBool(key, true);

          if (confirmed == true) {
            final updated = UserProfile(
              id: profile.id,
              name: profile.name,
              gender: profile.gender,
              age: profile.age,
              height: profile.height,
              weight: profile.weight,
              level: nextLevel,
              goal: profile.goal,
              focusAreas: profile.focusAreas,
              limitations: profile.limitations,
              equipment: profile.equipment,
              homeEquipment: profile.homeEquipment,
              daysPerWeek: profile.daysPerWeek,
              trainingWeekdays: profile.trainingWeekdays,
              sessionMinutes: profile.sessionMinutes,
              timeRangeLabel: profile.timeRangeLabel,
              createdAt: profile.createdAt,
              avatarPath: profile.avatarPath,
              beforePhotoPath: profile.beforePhotoPath,
              beforeSidePath: profile.beforeSidePath,
              beforeBackPath: profile.beforeBackPath,
              bodyType: profile.bodyType,
            );
            await DatabaseHelper.instance.updateProfile(updated);
            await prefs.setBool('allow_base_change_${profile.id}_$maxCycle', true);
            if (mounted) setState(() => _activeProfile = updated);
            levelUpgraded = true;
          }
        } else {
          // 👇 ЗАЛ (и продвинутый дом) — прежний диалог ротации баз
          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(children: [
                Image.asset(FairyMood.think.asset, width: 44, height: 44, fit: BoxFit.contain),
                const SizedBox(width: 10),
                const Expanded(child: Text('Пора обновить базы! 🧚‍♀️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ]),
              content: const Text('Ты занимаешься уже 2 месяца. Мышцы привыкают к одним и тем же упражнениям. Давай обновим базы, чтобы прогресс не остановился!'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Оставить старые')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE17055)), child: const Text('Обновить базы')),
              ],
            ),
          );

          await prefs.setBool(key, true);
          await prefs.setBool('allow_base_change_${_activeProfile!.id}_$maxCycle', confirmed == true);
        }
      }
    }

    setState(() { _generating = true; _showCompletionBanner = false; });

    try {
      await FairyReactionService().setActiveProfile(_activeProfile!.id, _activeProfile!.name, gender: _activeProfile!.gender);
      final freshProfile = await DatabaseHelper.instance.getProfileById(_activeProfile!.id!);
      if (freshProfile == null) { setState(() => _generating = false); _showMessage('Профиль не найден'); return; }
      setState(() => _activeProfile = freshProfile);

      final newDays = await WorkoutGenerator.generateMonthPlan(freshProfile, smart: true);
      final lastWeek = await WeekAnalyzer.analyzeLastWeek(freshProfile.id!);
      final streak = await FairyStatsService.getStreak();

      if (!mounted) return;
      setState(() {
        _monthDays = newDays.where((d) => d.status != 'completed').toList();
        _selectedWeek = 1;
        _lastWeek = lastWeek;
        _streak = streak;
        _generating = false;
        _showCompletionBanner = false;
      });

      await _saveProfileHashAsAccepted(freshProfile);
      // 👇 ИЗМЕНЕНО: вместо триггера феи — SnackBar
      if (isUpdate) {
        _showMessage(levelUpgraded
            ? 'Уровень повышен — план пересобран под новую сложность!'
            : 'План обновлён! Базы заменены на новые.');
      }
    } catch (e) {
      setState(() => _generating = false);
      _showMessage('Ошибка: $e');
    }
  }
  // ═══ КОНЕЦ ЧАСТИ 1 ═══

  Future<void> _openDay(WorkoutDay day) async {
    final isUnlocked = _isWeekUnlocked(day.weekNumber ?? 1);
    if (!isUnlocked) {
      _showMessage('Сначала завершите предыдущую неделю!');
      return;
    }

    if (day.type == 'challenge') {
      final wantsChallenge = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB800), size: 32),
              SizedBox(width: 12),
              Expanded(child: Text('День Челленджа!')),
            ],
          ),
          content: const Text('Сегодня вместо обычной тренировки мы устроим челлендж! Испытай себя и узнай, что тебя ждет. Погнали?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Обычная тренировка')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: Colors.white),
              child: const Text('Погнали!'),
            ),
          ],
        ),
      );

      if (wantsChallenge == true) {
        final workoutExs = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
        final exMap = <int, Exercise>{};
        for (final we in workoutExs) {
          if (we.itemType == 'exercise') {
            final ex = await DatabaseHelper.instance.getExerciseById(we.replacedByItemId ?? we.itemId);
            if (ex != null) exMap[ex.id!] = ex;
          }
        }

        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChallengeWheelScreen(
              day: day,
              profileId: _activeProfile!.id!,
              items: workoutExs,
              exerciseMap: exMap,
            ),
          ),
        );
        _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Окей! Сегодня будет особенный день: проработаем забытые зоны для гармоничного развития 💪'),
              duration: Duration(seconds: 3),
              backgroundColor: Color(0xFF6C5CE7),
            ),
          );
        }

        final updated = day.copyWith(type: 'strength');
        await DatabaseHelper.instance.updateWorkoutDay(updated);

        // 👇 ИЗМЕНЕНО: «забытые зоны» — только для зала
        if (_activeProfile != null && _activeProfile!.equipment != 'home') {
          await _generateForgottenZonesWorkout(updated, _activeProfile!);
        }

        if (!mounted) return;

        // 👇 ИЗМЕНЕНО: вопрос о самочувствии убран — он теперь в кнопке
        // «Начать тренировку» (workout_detail_screen.dart)
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutDetailScreen(
              workoutDay: updated,
              profileId: _activeProfile!.id!,
            ),
          ),
        );
        if (result == true) {
          await _loadData();
          await _checkAndUnlockNextWeek();
        }
      }
      return;
    }

    // 👇 ИЗМЕНЕНО: вопрос о самочувствии убран — он теперь в кнопке
    // «Начать тренировку» (workout_detail_screen.dart)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(workoutDay: day, profileId: _activeProfile!.id!),
      ),
    );
    if (result == true) {
      await _loadData();
      await _checkAndUnlockNextWeek();
    }
  }

  // 👇 УЧИТЫВАЕТ ИНВЕНТАРЬ И УРОВЕНЬ
  Future<void> _generateForgottenZonesWorkout(WorkoutDay day, UserProfile profile) async {
    final existing = await DatabaseHelper.instance.getWorkoutExercises(day.id!);
    for (final e in existing) {
      if (e.id != null) await DatabaseHelper.instance.deleteWorkoutExercise(e.id!);
    }

    final allExercises = await DatabaseHelper.instance.getExercises();
    // 👇 v21: ограничения → зоны через карту из base_exercises.dart
    final blockedZones = zonesBlockedByLimitations(profile.limitations);

    bool isExerciseAllowed(Exercise e) {
      if (exerciseBlockedByLimitations(e, profile.limitations)) return false;
      if (!WorkoutGenerator.matchesEquipment(e, profile.equipment)) return false;
      if (profile.level == 'beginner') {
        final lowerName = e.name.toLowerCase();
        if (lowerName.contains('штанг') || lowerName.contains('на одной ноге') || lowerName.contains('в висе')) return false;
        if (e.difficulty == 'advanced') return false;
      }
      return true;
    }

    final bases = allExercises.where((e) {
      if (!isBaseExercise(e)) return false;
      final zone = getExerciseZone(e);
      if (blockedZones.contains(zone)) return false;
      if (!isExerciseAllowed(e)) return false;
      return true;
    }).toList()..shuffle();

    final selectedBases = bases.take(3).toList();

    int order = 1;
    for (final ex in selectedBases) {
      final we = WorkoutExercise(
        workoutDayId: day.id!,
        itemType: 'exercise',
        itemId: ex.id!,
        order: order++,
        sets: 3,
        reps: '10-12',
      );
      final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
      for (int s = 1; s <= 3; s++) {
        await DatabaseHelper.instance.addWorkoutSet(
          WorkoutSet(workoutExerciseId: newId, order: s, completed: false),
        );
      }
    }

    final allZones = ['chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'];
    final focusZones = profile.focusAreas.map((e) => e.toLowerCase()).toList();

    final forgottenZones = allZones.where((z) =>
    !blockedZones.contains(z) && !focusZones.contains(z)
    ).toList();

    int added = 0;
    final Set<int> usedIds = selectedBases.map((e) => e.id!).toSet();

    for (final zone in forgottenZones) {
      if (added >= 6) break;
      final zoneExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (usedIds.contains(e.id)) return false;
        if (isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
        if (!isExerciseAllowed(e)) return false;
        return e.muscleGroups.contains(zone);
      }).toList()..shuffle();

      for (final ex in zoneExs.take(2)) {
        if (added >= 6) break;
        usedIds.add(ex.id!);

        final we = WorkoutExercise(
          workoutDayId: day.id!,
          itemType: 'exercise',
          itemId: ex.id!,
          order: order++,
          sets: 3,
          reps: '15',
        );
        final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
        for (int s = 1; s <= 3; s++) {
          await DatabaseHelper.instance.addWorkoutSet(
            WorkoutSet(workoutExerciseId: newId, order: s, completed: false),
          );
        }
        added++;
      }
    }
  }

  bool _isWeekUnlocked(int weekNumber) {
    if (weekNumber == 1) return true;
    final prevWeekDays = _allHistory.where((d) => d.weekNumber == weekNumber - 1).toList();
    if (prevWeekDays.isEmpty) return false;
    return prevWeekDays.every((d) => d.status == 'completed');
  }

  Future<void> _checkAndUnlockNextWeek() async {
    if (_activeProfile == null) return;
    final currentWeekDays = _allHistory.where((d) => d.weekNumber == _selectedWeek).toList();
    if (currentWeekDays.isEmpty) return;
    final allDone = currentWeekDays.every((d) => d.status == 'completed');
    if (allDone && _selectedWeek < 4) {
      await DatabaseHelper.instance.unlockNextWeek(_activeProfile!.id!, _selectedWeek + 1);
      await _loadData();
    }
  }

  Future<void> _openYoga() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const YogaScreen()));
  }

  Future<void> _confirmRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Обновить план?'),
        content: const Text('Текущий план будет удалён и создан заново. Продолжить?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Обновить')),
        ],
      ),
    );
    if (confirmed == true) _generatePlan(isUpdate: true);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_activeProfile == null) return _buildNoProfileState(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировки'),
        actions: [
          // 👇 БЕЙДЖ ЭНЕРГИИ
          EnergyBadge(profileId: _activeProfile!.id!),

          // 👇 КНОПКА САДА
          IconButton(
            tooltip: 'Сад Феи',
            icon: Image.asset(
              'assets/flowers/garden_icon.png',
              width: 32,
              height: 32,
              cacheWidth: 80,
              fit: BoxFit.contain,
            ),
            onPressed: () async {
              await precacheImage(const AssetImage('assets/flowers/grass_bg.png'), context);
              if (!mounted) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GardenScreen(profileId: _activeProfile!.id!),
                ),
              ).then((_) => _loadData());
            },
          ),

          IconButton(
            tooltip: 'Шпаргалка от Феи',
            icon: Image.asset(
              FairyMood.wink.asset,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TrainerScreen(profile: _activeProfile)),
              );
            },
          ),

          // 👇 «Обновить план» в шапке — только если план существует
          if (_monthDays.isNotEmpty)
            IconButton(
              tooltip: 'Обновить план',
              onPressed: _confirmRegenerate,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGreeting(context),
            const SizedBox(height: 20),

            DailyChallengeCard(profileId: _activeProfile!.id!),
            const SizedBox(height: 20),

            if (_monthDays.isNotEmpty) ...[
              _buildWeekChips(context),
              const SizedBox(height: 20),
            ],
            if (_showCompletionBanner) ...[
              _buildCompletionBanner(context),
              const SizedBox(height: 20),
            ],
            _buildSectionTitle(context, 'Быстрый старт'),
            const SizedBox(height: 12),
            _buildQuickActions(context),

            const SizedBox(height: 24),
            if (_lastWeek != null && !_lastWeek!.isEmpty) ...[
              _buildLastWeekCard(context),
              const SizedBox(height: 24),
            ],
            _buildSectionTitle(context, 'Мой план'),
            const SizedBox(height: 12),
            _buildPlanContent(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Прогресс за неделю'),
            const SizedBox(height: 12),
            _buildStats(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  // ═══ КОНЕЦ ЧАСТИ 2 ═══

  Widget _buildWeekChips(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(4, (index) {
          final week = index + 1;
          final isSelected = _selectedWeek == week;
          final isUnlocked = _isWeekUnlocked(week);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUnlocked) ...[const Icon(Icons.lock_rounded, size: 14), const SizedBox(width: 4)],
                  Text('Неделя $week'),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) { if (selected) setState(() => _selectedWeek = week); },
              selectedColor: theme.colorScheme.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 13),
              backgroundColor: isUnlocked ? theme.colorScheme.surface : theme.colorScheme.surface.withValues(alpha: 0.5),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPlanContent(BuildContext context) {
    if (_monthDays.isEmpty) return _buildEmptyPlan(context);
    final weekDays = _monthDays.where((d) => d.weekNumber == _selectedWeek).toList();
    if (weekDays.isEmpty) return const Center(child: Text('Нет дней для этой недели'));
    return Column(children: weekDays.map((d) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _dayCard(context, d))).toList());
  }

  Widget _dayCard(BuildContext context, WorkoutDay day) {
    final theme = Theme.of(context);
    final isCompleted = day.status == 'completed';
    final isInProgress = day.status == 'in_progress';
    final isUnlocked = _isWeekUnlocked(day.weekNumber ?? 1);
    final List<Color> gradientColors;
    final IconData icon;
    final Color accentColor;

    if (isCompleted) {
      gradientColors = [const Color(0xFF00B894), const Color(0xFF55EFC4)];
      icon = Icons.check_rounded;
      accentColor = const Color(0xFF00B894);
    } else if (isInProgress) {
      gradientColors = [const Color(0xFFE17055), const Color(0xFFFDCB6E)];
      icon = Icons.hourglass_bottom_rounded;
      accentColor = const Color(0xFFE17055);
    } else {
      gradientColors = [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)];
      icon = isUnlocked ? (day.type == 'challenge' ? Icons.local_fire_department_rounded : Icons.fitness_center) : Icons.lock_rounded;
      accentColor = const Color(0xFF6C5CE7);
    }

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.6,
      child: Card(
        child: InkWell(
          onTap: isUnlocked ? () => _openDay(day) : () => _showMessage('Сначала завершите предыдущую неделю!'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 26)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(day.name, style: theme.textTheme.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text('✓ Сделано', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor))),
                          ],
                          if (!isCompleted && isInProgress) ...[
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text('⏳ В процессе', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor))),
                          ],
                          if (!isCompleted && !isInProgress && !isUnlocked) ...[
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: const Text('🔒 Закрыто', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${day.type == 'challenge' ? 'Челлендж' : day.type == 'strength' ? 'Силовая' : 'Йога'} · ${day.durationMinutes ?? 45} мин', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            _fmtDate(day),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 👇 Перенос — только для запланированных разблокированных дней текущей недели
                if (day.status == 'planned' && isUnlocked && _isWithinCurrentWeek(day.date)) ...[
                  IconButton(
                    tooltip: 'Перенести',
                    icon: Icon(Icons.event_repeat_rounded,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    onPressed: () => _showRescheduleSheet(day),
                  ),
                ] else ...[
                  Icon(isCompleted ? Icons.check_circle_rounded : isUnlocked ? Icons.chevron_right_rounded : Icons.lock_rounded, color: isCompleted ? accentColor : isUnlocked ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : Colors.grey),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final dateStr = '${now.day} ${months[now.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Привет, ${_activeProfile!.name}!', style: theme.textTheme.displaySmall),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(dateStr, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            if (_streak > 0) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFDCB6E), Color(0xFFE17055)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Color(0xFFFDCB6E).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('🔥', style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text('$_streak ${_streakWord(_streak)} подряд', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))]),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Icon(Icons.fitness_center, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 6), Text('${_monthDays.length}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary))]),
            ),
          ],
        ),
      ],
    );
  }

  String _streakWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'неделя';
    if (mod10 >= 2 && mod100 < 10 || mod100 >= 20) return 'недели';
    return 'недель';
  }

  // ═══ ДАТЫ И ПЕРЕНОС ═══

  String _fmtDate(WorkoutDay day) {
    if (day.status == 'completed' && day.completedAt != null) {
      return 'Выполнено: ${_fmtPlain(day.completedAt!)}';
    }
    return _fmtPlain(day.date);
  }

  String _fmtPlain(DateTime d) {
    const weekDays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${weekDays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  bool _isWithinCurrentWeek(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return !d.isBefore(monday) && !d.isAfter(sunday);
  }

  Future<void> _rescheduleDay(WorkoutDay day, DateTime newDate) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(newDate.year, newDate.month, newDate.day);

    if (day.status != 'planned') {
      _showMessage('Перенести можно только запланированную тренировку');
      return;
    }
    if (!_isWithinCurrentWeek(day.date)) {
      _showMessage('Переносить можно только дни текущей недели');
      return;
    }
    if (!_isWithinCurrentWeek(target)) {
      _showMessage('Перенести можно только на день текущей недели');
      return;
    }

    final occupied = _monthDays.any((d) =>
    d.id != day.id &&
        d.status == 'planned' &&
        d.date.year == target.year &&
        d.date.month == target.month &&
        d.date.day == target.day);
    if (occupied) {
      _showMessage('На этот день уже запланирована тренировка');
      return;
    }

    await DatabaseHelper.instance.updateWorkoutDay(day.copyWith(date: target));
    await _loadData();
  }

  void _showRescheduleSheet(WorkoutDay day) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const weekDays = ['Понедельник', 'Вторник', 'Среда', 'Четверг',
      'Пятница', 'Суббота', 'Воскресенье'];
    const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Куда перенести?', style: theme.textTheme.headlineMedium),
            ),
            ...List.generate(7, (i) {
              final d = monday.add(Duration(days: i));
              final isPast = d.isBefore(today);
              final isSame = d.year == day.date.year &&
                  d.month == day.date.month && d.day == day.date.day;
              final occupied = _monthDays.any((w) =>
              w.id != day.id &&
                  w.status == 'planned' &&
                  w.date.year == d.year &&
                  w.date.month == d.month &&
                  w.date.day == d.day);
              final enabled = !isPast && !isSame && !occupied;

              return ListTile(
                enabled: enabled,
                leading: Icon(
                  isSame ? Icons.check_circle_rounded : Icons.event_rounded,
                  color: enabled ? theme.colorScheme.primary : Colors.grey,
                ),
                title: Text('${weekDays[i]}, ${d.day} ${months[d.month - 1]}'),
                trailing: isPast
                    ? const Text('прошло', style: TextStyle(color: Colors.grey, fontSize: 12))
                    : occupied
                    ? const Text('занято', style: TextStyle(color: Colors.grey, fontSize: 12))
                    : null,
                onTap: enabled
                    ? () {
                  Navigator.pop(ctx);
                  _rescheduleDay(day, d);
                }
                    : null,
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLastWeekCard(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _lastWeek!;
    Color color; IconData icon; String title;

    if (summary.isFullWeek) { color = const Color(0xFF00B894); icon = Icons.emoji_events_rounded; title = 'Отличная неделя!'; }
    else if (summary.isLazyWeek) { color = const Color(0xFFE17055); icon = Icons.warning_amber_rounded; title = 'Мало тренировок'; }
    else { color = const Color(0xFF6C5CE7); icon = Icons.insights_rounded; title = 'Прошлая неделя'; }
    final recommendation = summary.recommendation;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Сделано: ${summary.completedCount} · Пропущено: ${summary.missedCount}${summary.totalMinutes > 0 ? " · ${summary.totalMinutes} min" : ""}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
          if (recommendation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Icon(Icons.tips_and_updates_rounded, size: 16, color: color), const SizedBox(width: 8), Expanded(child: Text(recommendation, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontWeight: FontWeight.w600)))]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final hasPlan = _monthDays.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            context,
            icon: hasPlan ? Icons.check_circle_rounded : Icons.auto_awesome_rounded,
            label: hasPlan ? 'План создан' : 'Создать план',
            gradient: hasPlan
                ? const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55EFC4)])
                : const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]),
            onTap: hasPlan ? null : (_generating ? null : _generatePlan),
            isLoading: _generating,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            context,
            icon: Icons.self_improvement_rounded,
            label: 'Йога',
            gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55EFC4)]),
            onTap: _openYoga,
          ),
        ),
      ],
    );
  }

  Widget _actionCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required LinearGradient gradient,
        VoidCallback? onTap,
        bool isLoading = false,
      }) {
    final isDisabled = onTap == null && !isLoading;
    return Opacity(
      opacity: isDisabled ? 0.9 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: isDisabled ? 0.15 : 0.3),
                blurRadius: isDisabled ? 8 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isLoading
                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55EFC4)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00B894).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('План завершён! 💪', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Создать новый на следующий месяц?', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _generating ? null : _generatePlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00B894),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _generating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B894)))
                : const Text('Создать', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlan(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('Плана пока нет', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Нажмите «Создать план» — приложение подберёт тренировки на месяц под ваш профиль',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generatePlan,
              icon: _generating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_generating ? 'Создаём...' : 'Создать план'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            icon: Icons.calendar_today_rounded,
            value: '$_currentWeekWorkouts',
            label: 'тренировок',
            color: const Color(0xFF6C5CE7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            context,
            icon: Icons.timer_rounded,
            value: '$_currentWeekMinutes',
            label: 'минут',
            color: const Color(0xFF00B894),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
      BuildContext context, {
        required IconData icon,
        required String value,
        required String label,
        required Color color,
      }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.headlineMedium);
  }

  Widget _buildNoProfileState(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_rounded, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 24),
              Text('Нет профиля', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Создайте профиль в Настройках, чтобы начать тренировки',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ═══ КОНЕЦ ФАЙЛА workout_screen.dart ═══
