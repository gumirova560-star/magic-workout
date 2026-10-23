import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border; // 👈 Скрываем Border
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../../models/user_profile.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  UserProfile? _activeProfile;
  List<WorkoutDay> _allHistory = [];

  Map<String, Map<int, List<WorkoutDay>>> _groupedHistory = {};

  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
    FairyReactionService().addWorkoutListener(_onWorkoutCompleted);
  }

  void _onWorkoutCompleted() { if (mounted) _loadData(); }

  @override
  void dispose() {
    FairyReactionService().removeWorkoutListener(_onWorkoutCompleted);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    var profiles = await DatabaseHelper.instance.getProfiles();
    if (profiles.isEmpty) {
      if (!mounted) return;
      setState(() { _activeProfile = null; _allHistory = []; _loading = false; });
      return;
    }

    final active = profiles.first;
    final history = await DatabaseHelper.instance.getWorkoutDays(profileId: active.id!, limit: 500);

    final relevantHistory = history.where((w) => w.status == 'completed' || w.status == 'in_progress').toList();
    relevantHistory.sort((a, b) => a.date.compareTo(b.date));

    if (!mounted) return;
    setState(() {
      _activeProfile = active;
      _allHistory = relevantHistory;
      _applyFilter(_filter);
      _loading = false;
    });
  }

  int _extractNum(String s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0;

  void _applyFilter(String filter) {
    setState(() {
      _filter = filter;
      List<WorkoutDay> filtered;
      if (filter == 'all') filtered = _allHistory;
      else if (filter == 'completed') filtered = _allHistory.where((w) => w.status == 'completed').toList();
      else filtered = _allHistory.where((w) => w.status == 'in_progress').toList();

      final Map<String, Map<int, List<WorkoutDay>>> grouped = {};

      for (final day in filtered) {
        final cycle = day.cycleNumber ?? 1;
        final week = day.weekNumber ?? 1;
        final cycleKey = 'Цикл $cycle';

        grouped.putIfAbsent(cycleKey, () => {});
        grouped[cycleKey]!.putIfAbsent(week, () => []);
        grouped[cycleKey]![week]!.add(day);
      }

      final sortedGrouped = <String, Map<int, List<WorkoutDay>>>{};
      final cycleKeys = grouped.keys.toList()..sort((a, b) => _extractNum(b).compareTo(_extractNum(a)));

      for (final ck in cycleKeys) {
        final weeks = grouped[ck]!;
        final sortedWeeks = <int, List<WorkoutDay>>{};
        final weekKeys = weeks.keys.toList()..sort((a, b) => b.compareTo(a));

        for (final wk in weekKeys) {
          sortedWeeks[wk] = weeks[wk]!.reversed.toList();
        }
        sortedGrouped[ck] = sortedWeeks;
      }

      _groupedHistory = sortedGrouped;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_activeProfile == null) return _buildNoProfileState(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded), onPressed: _allHistory.isEmpty ? null : _exportToExcel),
          IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _allHistory.isEmpty ? null : _clearHistory),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'Все', Icons.all_inclusive_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('completed', 'Завершены', Icons.check_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('in_progress', 'В процессе', Icons.hourglass_bottom_rounded),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _groupedHistory.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _groupedHistory.keys.length,
                      itemBuilder: (context, index) {
                        final cycleKey = _groupedHistory.keys.elementAt(index);
                        final weeks = _groupedHistory[cycleKey]!;
                        return _buildCycleGroup(context, cycleKey, weeks);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleGroup(BuildContext context, String cycleKey, Map<int, List<WorkoutDay>> weeks) {
    final totalDays = weeks.values.expand((e) => e).length;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: const Color(0xFF6C5CE7).withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.fitness_center, color: Colors.white, size: 20),
            ),
            title: Text(
              cycleKey.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: 1.2),
            ),
            subtitle: Text(
              '$totalDays тренировок',
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            initiallyExpanded: false,
            shape: const Border(),
            collapsedShape: const Border(),
            children: weeks.entries.map((wEntry) {
              final weekNum = wEntry.key;
              final days = wEntry.value;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ExpansionTile(
                  title: Text('Неделя $weekNum', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF6C5CE7))),
                  subtitle: Text('${days.length} тренировок', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                  initiallyExpanded: false,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: const Color(0xFF6C5CE7),
                  collapsedIconColor: const Color(0xFF6C5CE7),
                  children: days.map((d) => _buildHistoryCard(context, d)).toList(),
                ),
              );
            }).toList(),
            childrenPadding: const EdgeInsets.only(bottom: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isActive = _filter == value;
    final theme = Theme.of(context);
    return FilterChip(
      selected: isActive,
      onSelected: (_) => _applyFilter(value),
      avatar: Icon(icon, size: 16, color: isActive ? Colors.white : theme.colorScheme.onSurface),
      label: Text(label),
      labelStyle: TextStyle(color: isActive ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isActive ? Colors.transparent : theme.colorScheme.onSurface.withOpacity(0.2))),
      showCheckmark: false,
    );
  }

  Widget _buildHistoryCard(BuildContext context, WorkoutDay workout) {
    final theme = Theme.of(context);
    final isCompleted = workout.status == 'completed';
    final color = isCompleted ? const Color(0xFF00B894) : const Color(0xFFE17055);
    final icon = isCompleted ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded;
    final statusText = isCompleted ? 'Завершена' : 'В процессе';

    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryDetailScreen(workout: workout))),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(workout.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${workout.date.day}.${workout.date.month}.${workout.date.year} · $statusText',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.4)),
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все завершённые и текущие тренировки будут удалены. Плановые дни останутся.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Очистить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    // 👇 ПОЛНАЯ ОЧИСТКА ВСЕХ ДНЕЙ (включая скрытые плановые)
    if (_activeProfile?.id != null) {
      await DatabaseHelper.instance.deleteAllWorkoutDaysForProfile(_activeProfile!.id!);
    }

    if (!mounted) return;
    _loadData();
  }

  Future<void> _exportToExcel() async {
    if (_activeProfile == null || _allHistory.isEmpty) return;
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['История тренировок'];
      sheetObject.appendRow([TextCellValue('Дата'), TextCellValue('Название'), TextCellValue('Тип'), TextCellValue('Минуты'), TextCellValue('Статус')]);
      for (var day in _allHistory) {
        sheetObject.appendRow([
          TextCellValue('${day.date.day}.${day.date.month}.${day.date.year}'), TextCellValue(day.name),
          TextCellValue(day.type == 'yoga' ? 'Йога' : 'Силовая'), IntCellValue(day.durationMinutes ?? 0),
          TextCellValue(day.status == 'completed' ? 'Завершена' : 'В процессе'),
        ]);
      }
      final bytes = excel.save();
      if (bytes != null) {
        final file = XFile.fromData(Uint8List.fromList(bytes), name: 'History_${_activeProfile!.name}.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        if (!mounted) return;
        await Share.shareXFiles([file], text: 'Моя история тренировок (${_activeProfile!.name})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 80, color: theme.colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text('Пока нет тренировок', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Завершите первую тренировку,\nчтобы она появилась здесь.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ),
    );
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
              Text('Создайте профиль во вкладке «Профиль»', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ],
          ),
        ),
      ),
    );
  }
}