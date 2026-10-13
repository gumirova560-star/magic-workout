import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';
import '../../widgets/history_card.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<UserProfile> _profiles = [];
  UserProfile? _activeProfile;
  List<WorkoutDay> _history = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final profiles = await DatabaseHelper.instance.getProfiles();

    UserProfile? active;
    List<WorkoutDay> history = [];

    if (profiles.isNotEmpty) {
      active = profiles.first;
      history = await DatabaseHelper.instance.getWorkoutDays(
        profileId: active.id!,
      );
    }

    setState(() {
      _profiles = profiles;
      _activeProfile = active;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _switchProfile(UserProfile profile) async {
    setState(() => _loading = true);
    final history = await DatabaseHelper.instance.getWorkoutDays(
      profileId: profile.id!,
    );
    setState(() {
      _activeProfile = profile;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _openDetail(WorkoutDay workout) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryDetailScreen(workout: workout),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteWorkout(WorkoutDay workout) async {
    await DatabaseHelper.instance.deleteWorkoutDay(workout.id!);
    _loadData();
  }

  Future<void> _clearAllHistory() async {
    if (_activeProfile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: Text(
            'Все ${_history.length} тренировок профиля «${_activeProfile!.name}» будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final w in _history) {
      await DatabaseHelper.instance.deleteWorkoutDay(w.id!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('История очищена')),
    );
    _loadData();
  }

  List<WorkoutDay> get _filteredHistory {
    if (_filter == 'all') return _history;
    return _history.where((w) => w.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Очистить всё',
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _activeProfile == null
              ? _buildNoProfileState(context)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: Column(
                    children: [
                      if (_profiles.length > 1)
                        _buildProfileSwitcher(context),
                      _buildFilters(context),
                      Expanded(
                        child: _filteredHistory.isEmpty
                            ? _buildEmptyState(context)
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredHistory.length,
                                itemBuilder: (_, i) {
                                  final w = _filteredHistory[i];
                                  return HistoryCard(
                                    workout: w,
                                    onTap: () => _openDetail(w),
                                    onDelete: () => _deleteWorkout(w),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileSwitcher(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _profiles.length,
        itemBuilder: (_, i) {
          final p = _profiles[i];
          final isActive = p.id == _activeProfile!.id;

          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () => _switchProfile(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: isActive
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('all', 'Все', Icons.list_rounded),
          const SizedBox(width: 8),
          _filterChip('completed', 'Завершены', Icons.check_rounded),
          const SizedBox(width: 8),
          _filterChip('in_progress', 'В процессе', Icons.timer_rounded),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final isActive = _filter == value;
    return FilterChip(
      selected: isActive,
      onSelected: (_) => setState(() => _filter = value),
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'История пуста',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Здесь появятся завершённые тренировки',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoProfileState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_rounded,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text('Нет профилей', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Создайте профиль во вкладке «Профили»',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}