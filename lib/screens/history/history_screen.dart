import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../../models/user_profile.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import 'history_detail_screen.dart'; // ⚠️ Импорт нового экрана

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  UserProfile? _activeProfile;
  List<WorkoutDay> _allHistory = [];
  List<WorkoutDay> _filteredHistory = [];
  bool _loading = true;

  String _filter = 'all'; // 'all' | 'completed' | 'in_progress'

  @override
  void initState() {
    super.initState();
    _loadData();
    FairyReactionService().addWorkoutListener(_onWorkoutCompleted);
  }

  void _onWorkoutCompleted() {
    if (!mounted) return;
    _loadData();
  }

  @override
  void dispose() {
    FairyReactionService().removeWorkoutListener(_onWorkoutCompleted);
    super.dispose();
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

    if (profiles.isEmpty) {
      if (!mounted) return;
      setState(() {
        _activeProfile = null;
        _allHistory = [];
        _filteredHistory = [];
        _loading = false;
      });
      return;
    }

    final active = profiles.first;
    final history = await DatabaseHelper.instance.getWorkoutDays(
      profileId: active.id!,
      limit: 100,
    );

    if (!mounted) return;
    setState(() {
      _activeProfile = active;
      _allHistory = history;
      _applyFilter(_filter); // Применяем текущий фильтр
      _loading = false;
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _filter = filter;
      if (filter == 'all') {
        _filteredHistory = _allHistory;
      } else if (filter == 'completed') {
        _filteredHistory = _allHistory.where((w) => w.status == 'completed').toList();
      } else if (filter == 'in_progress') {
        _filteredHistory = _allHistory.where((w) => w.status == 'in_progress').toList();
      }
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все завершённые и текущие тренировки будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final w in _allHistory) {
      if (w.id != null) {
        await DatabaseHelper.instance.deleteWorkoutDay(w.id!);
      }
    }

    if (!mounted) return;
    _loadData();
  }

  Future<void> _exportToExcel() async {
    if (_activeProfile == null || _allHistory.isEmpty) return;

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['История тренировок'];

      sheetObject.appendRow([
        TextCellValue('Дата'),
        TextCellValue('Название тренировки'),
        TextCellValue('Тип'),
        TextCellValue('Длительность (мин)'),
        TextCellValue('Статус'),
      ]);

      for (var day in _allHistory) {
        sheetObject.appendRow([
          TextCellValue('${day.date.day}.${day.date.month}.${day.date.year}'),
          TextCellValue(day.name),
          TextCellValue(day.type == 'yoga' ? 'Йога' : 'Силовая'),
          IntCellValue(day.durationMinutes ?? 0),
          TextCellValue(day.status == 'completed' ? 'Завершена' : 'В процессе'),
        ]);
      }

      final bytes = excel.save();
      if (bytes != null) {
        final file = XFile.fromData(
          Uint8List.fromList(bytes),
          name: 'History_${_activeProfile!.name}.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        if (!mounted) return;
        await Share.shareXFiles(
          [file],
          text: 'Моя история тренировок (${_activeProfile!.name})',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeProfile == null) {
      return _buildNoProfileState(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Экспорт в Excel',
            onPressed: _allHistory.isEmpty ? null : _exportToExcel,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Очистить историю',
            onPressed: _allHistory.isEmpty ? null : _clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // ═══ ФИЛЬТРЫ ═══
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

          // ═══ СПИСОК ═══
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _filteredHistory.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, i) {
                        final workout = _filteredHistory[i];
                        return _buildHistoryCard(context, workout);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isActive = _filter == value;
    final theme = Theme.of(context);

    return FilterChip(
      selected: isActive,
      onSelected: (_) => _applyFilter(value),
      avatar: Icon(
        icon,
        size: 16,
        color: isActive ? Colors.white : theme.colorScheme.onSurface,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: isActive ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? Colors.transparent : theme.colorScheme.onSurface.withOpacity(0.2),
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildHistoryCard(BuildContext context, WorkoutDay workout) {
    final theme = Theme.of(context);
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final dateStr = '${workout.date.day} ${months[workout.date.month - 1]} ${workout.date.year}';

    final isCompleted = workout.status == 'completed';
    final color = isCompleted ? const Color(0xFF00B894) : const Color(0xFFE17055);
    final icon = isCompleted ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded;
    final statusText = isCompleted ? 'Завершена' : 'В процессе';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // ⚠️ Переход на красивый экран истории
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryDetailScreen(workout: workout),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          statusText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
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
              Icons.history_rounded,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Пока нет тренировок',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Завершите первую тренировку,\nчтобы она появилась здесь.',
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
    return Scaffold(
      body: Center(
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
              const SizedBox(height: 24),
              Text('Нет профиля', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Создайте профиль во вкладке «Профиль»',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ═══ ФАЙЛ history_screen.dart ЗАВЕРШЁН ═══