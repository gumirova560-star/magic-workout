import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/fairy_mood.dart';
import '../../models/user_profile.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';
import '../../services/workout_generator.dart' hide DatabaseHelper; // 👈 Скрываем, чтобы не было конфликта
import '../../services/week_analyzer.dart';
import '../../services/fairy_reaction_service.dart';
import '../../services/fairy_stats_service.dart';
import '../../services/achievement_service.dart';
import '../yoga/yoga_screen.dart';
// import '../trainer/trainer_screen.dart'; // ⚠️ ВРЕМЕННО ЗАКОММЕНТИРОВАНО (файла не существует)
import 'workout_detail_screen.dart';
import 'my_templates_screen.dart';
import 'widgets/focus_areas_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
    FairyReactionService().addProfileListener(_onProfileChanged);
    FairyReactionService().addWorkoutListener(_onWorkoutCompleted);
  }

  void _onProfileChanged() { if (mounted) _loadData(); }
  void _onWorkoutCompleted() { if (mounted) _loadData(); }

  @override
  void dispose() {
    FairyReactionService().removeProfileListener(_onProfileChanged);
    FairyReactionService().removeWorkoutListener(_onWorkoutCompleted);
    super.dispose();
  }

  String _computeProfileHash(UserProfile p) {
    return [p.gender, p.age, p.height, p.weight, p.level, p.goal, p.equipment, p.daysPerWeek, p.sessionMinutes, p.focusAreas.join(','), p.limitations.join(',')].join('|');
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
        final d = DateTime(w.date.year, w.date.month, w.date.day);
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

      final shouldHold = await _shouldSuggestPlanUpdate(active);
      if (shouldHold) FairyReactionService().holdScreenPhrases();
      await FairyReactionService().setActiveProfile(active.id, active.name, gender: active.gender);

      if (shouldHold) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showProfileChangedBannerNow(active);
          else FairyReactionService().releaseScreenPhrases();
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

  Future<void> _showProfileChangedBannerNow(UserProfile profile) async {
    if (!mounted) { FairyReactionService().releaseScreenPhrases(); return; }
    await FairyReactionService().setActiveProfile(profile.id, profile.name, gender: profile.gender);
    if (!mounted) { FairyReactionService().releaseScreenPhrases(); return; }
    await FairyReactionService().trigger('profile_changed_ask', mood: FairyMood.think);
    await Future.delayed(const Duration(seconds: 4));
    await _saveProfileHashAsDismissed(profile);
    FairyReactionService().releaseScreenPhrases();
  }

  Future<void> _generatePlan({bool isUpdate = false}) async {
    if (_activeProfile == null) { _showMessage('Сначала создайте профиль'); return; }

    final selected = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FocusAreasDialog(
        initial: _activeProfile!.focusAreas.toSet(),
        maxCount: 3,
        isWeightLoss: _activeProfile!.goal == 'lose_weight',
      ),
    );
    if (selected == null || selected.isEmpty) return;

    final updatedProfile = _activeProfile!.copyWith(focusAreas: selected.toList());
    await DatabaseHelper.instance.updateProfile(updatedProfile);
    if (!mounted) return;
    setState(() => _activeProfile = updatedProfile);
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
      FairyReactionService().trigger(isUpdate ? 'plan_updated' : 'plan_generated', mood: FairyMood.party);
    } catch (e) {
      setState(() => _generating = false);
      _showMessage('Ошибка: $e');
    }
  }

  Future<void> _openDay(WorkoutDay day) async {
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

  Future<void> _openMyTemplates() async {
    if (_activeProfile == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => MyTemplatesScreen(profileId: _activeProfile!.id!)));
    if (mounted) _loadData();
  }

  Future<void> _openLastCompleted() async {
    if (_activeProfile == null) return;
    final history = await DatabaseHelper.instance.getWorkoutDays(profileId: _activeProfile!.id!, limit: 1);
    final completed = history.where((w) => w.status == 'completed').toList();
    if (completed.isEmpty) { _showMessage('Пока нет завершённых тренировок'); return; }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workoutDay: completed.first, profileId: _activeProfile!.id!)));
    if (mounted) _loadData();
  }

  Future<void> _continueInProgress() async {
    if (_activeProfile == null) return;
    final history = await DatabaseHelper.instance.getWorkoutDays(profileId: _activeProfile!.id!, limit: 20);
    final inProgress = history.where((w) => w.status == 'in_progress').toList();
    if (inProgress.isEmpty) { _showMessage('Нет незавершённых тренировок'); return; }
    inProgress.sort((a, b) => b.date.compareTo(a.date));
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workoutDay: inProgress.first, profileId: _activeProfile!.id!)));
    if (mounted) _loadData();
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
          // ⚠️ КНОПКА ТРЕНЕРСКОЙ ВРЕМЕННО ЗАКОММЕНТИРОВАНА
          /*
          IconButton(
            tooltip: 'Шпаргалка от Феи',
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFDCB6E)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrainerScreen()),
              );
            },
          ),
          */
          IconButton(tooltip: 'Продолжить тренировку', onPressed: _continueInProgress, icon: const Icon(Icons.play_circle_outline_rounded)),
          IconButton(tooltip: 'Последняя завершённая', onPressed: _openLastCompleted, icon: const Icon(Icons.history_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGreeting(context),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildSectionTitle(context, 'Мой план')),
                if (_monthDays.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'Действия',
                    onSelected: (value) {
                      if (value == 'templates') _openMyTemplates();
                      if (value == 'update') _confirmRegenerate();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'templates', child: Row(children: [Icon(Icons.bookmark_rounded, size: 20), SizedBox(width: 8), Text('Из шаблона')])),
                      const PopupMenuItem(value: 'update', child: Row(children: [Icon(Icons.refresh_rounded, size: 20), SizedBox(width: 8), Text('Обновить план')])),
                    ],
                  ),
              ],
            ),
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
              backgroundColor: isUnlocked ? theme.colorScheme.surface : theme.colorScheme.surface.withOpacity(0.5),
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

    if (isCompleted) { gradientColors = [const Color(0xFF00B894), const Color(0xFF55EFC4)]; icon = Icons.check_rounded; accentColor = const Color(0xFF00B894); }
    else if (isInProgress) { gradientColors = [const Color(0xFFE17055), const Color(0xFFFDCB6E)]; icon = Icons.hourglass_bottom_rounded; accentColor = const Color(0xFFE17055); }
    else { gradientColors = [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)]; icon = isUnlocked ? Icons.fitness_center : Icons.lock_rounded; accentColor = const Color(0xFF6C5CE7); }

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.6,
      child: Card(
        child: InkWell(
          onTap: () => _openDay(day),
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
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text('✓ Сделано', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor))),
                          ],
                          if (!isCompleted && isInProgress) ...[
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text('⏳ В процессе', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor))),
                          ],
                          if (!isCompleted && !isInProgress && !isUnlocked) ...[
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: const Text('🔒 Закрыто', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${day.type == 'strength' ? 'Силовая' : 'Йога'} · ${day.durationMinutes ?? 45} мин', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                    ],
                  ),
                ),
                Icon(isCompleted ? Icons.check_circle_rounded : isUnlocked ? Icons.chevron_right_rounded : Icons.lock_rounded, color: isCompleted ? accentColor : isUnlocked ? theme.colorScheme.onSurface.withOpacity(0.4) : Colors.grey),
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
            Text(dateStr, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            if (_streak > 0) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFDCB6E), Color(0xFFE17055)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: const Color(0xFFFDCB6E).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('🔥', style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text('$_streak ${_streakWord(_streak)} подряд', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))]),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'недели';
    return 'недель';
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
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Сделано: ${summary.completedCount} · Пропущено: ${summary.missedCount}${summary.totalMinutes > 0 ? " · ${summary.totalMinutes} мин" : ""}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                  ],
                ),
              ),
            ],
          ),
          if (recommendation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Icon(Icons.tips_and_updates_rounded, size: 16, color: color), const SizedBox(width: 8), Expanded(child: Text(recommendation, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.85), fontWeight: FontWeight.w600)))]),
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
        Expanded(child: _actionCard(context, icon: hasPlan ? Icons.check_circle_rounded : Icons.auto_awesome_rounded, label: hasPlan ? 'План создан' : 'Создать план', gradient: hasPlan ? const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55EFC4)]) : const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]), onTap: hasPlan ? null : (_generating ? null : _generatePlan), isLoading: _generating)),
        const SizedBox(width: 12),
        Expanded(child: _actionCard(context, icon: Icons.self_improvement_rounded, label: 'Йога', gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55EFC4)]), onTap: _openYoga)),
      ],
    );
  }

  Widget _actionCard(BuildContext context, {required IconData icon, required String label, required LinearGradient gradient, VoidCallback? onTap, bool isLoading = false}) {
    final isDisabled = onTap == null && !isLoading;
    return Opacity(
      opacity: isDisabled ? 0.9 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: gradient.colors.first.withOpacity(isDisabled ? 0.15 : 0.3), blurRadius: isDisabled ? 8 : 16, offset: const Offset(0, 8))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isLoading ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : Icon(icon, color: Colors.white, size: 28),
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
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55EFC4)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFF00B894).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('План завершён! 💪', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)), SizedBox(height: 2), Text('Создать новый на следующий месяц?', style: TextStyle(color: Colors.white70, fontSize: 11))])),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _generating ? null : _generatePlan,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF00B894), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B894))) : const Text('Создать', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlan(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 2)),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 48, color: theme.colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text('Плана пока нет', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Нажмите «Создать план» — приложение подберёт тренировки на месяц под ваш профиль', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _generating ? null : _generatePlan, icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded), label: Text(_generating ? 'Создаём...' : 'Создать план'))),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _statCard(context, icon: Icons.calendar_today_rounded, value: '$_currentWeekWorkouts', label: 'тренировок', color: const Color(0xFF6C5CE7))),
        const SizedBox(width: 12),
        Expanded(child: _statCard(context, icon: Icons.timer_rounded, value: '$_currentWeekMinutes', label: 'минут', color: const Color(0xFF00B894))),
      ],
    );
  }

  Widget _statCard(BuildContext context, {required IconData icon, required String value, required String label, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
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
              Icon(Icons.person_add_rounded, size: 80, color: theme.colorScheme.primary.withOpacity(0.5)),
              const SizedBox(height: 24),
              Text('Нет профиля', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('Создайте профиль в Настройках, чтобы начать тренировки', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ],
          ),
        ),
      ),
    );
  }
}