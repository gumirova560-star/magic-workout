import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';
import 'challenge_screen.dart';

class ChallengeSetupScreen extends StatefulWidget {
  final WorkoutDay day;
  final UserProfile? profile;
  final List<Exercise> allExercises;

  const ChallengeSetupScreen({
    super.key,
    required this.day,
    required this.profile,
    required this.allExercises,
  });

  @override
  State<ChallengeSetupScreen> createState() => _ChallengeSetupScreenState();
}

class _ChallengeSetupScreenState extends State<ChallengeSetupScreen> {
  final Set<int> _selectedIds = {};
  final int _maxSelection = 4; // 👈 Теперь выбираем 4 упражнения

  // Жестко заданные списки для челленджа (по названиям)
  final Map<String, List<String>> _challengePool = {
    'glutes': ['Ягодичный мост', 'Махи ногой назад', 'Отведение ноги в сторону'],
    'legs': ['Приседания', 'Выпады', 'Подъемы на носки'],
    'abs': ['Скручивания', 'Планка', 'Велосипед'],
    'back': ['Супермен', 'Тяга к поясу (если есть резинка)', 'Лодочка'],
    'chest': ['Отжимания от пола', 'Отжимания с колен', 'Жим гантелей лежа'],
    'arms': ['Сгибания на бицепс', 'Разгибания на трицепс', 'Обратные отжимания'],
  };

  // Итоговый список сгруппированных упражнений
  final Map<String, List<Exercise>> _groupedExercises = {};

  @override
  void initState() {
    super.initState();
    _prepareExercises();
  }

  void _prepareExercises() {
    final focusZones = widget.profile?.focusAreas ?? [];

    // Проходимся по нашему жесткому списку зон
    _challengePool.forEach((zone, names) {
      final zoneExercises = <Exercise>[];

      for (final name in names) {
        // Ищем упражнение в базе по названию (частичное совпадение)
        final found = widget.allExercises.where((e) =>
            e.name.toLowerCase().contains(name.toLowerCase())
        ).toList();

        if (found.isNotEmpty) {
          // Берем первое совпадение, чтобы не дублировать
          zoneExercises.add(found.first);
        }
      }

      if (zoneExercises.isNotEmpty) {
        // Сортируем так, чтобы упражнения из фокусных зон были в начале
        zoneExercises.sort((a, b) {
          final aFocus = a.muscleGroups.any((m) => focusZones.contains(m));
          final bFocus = b.muscleGroups.any((m) => focusZones.contains(m));
          if (aFocus && !bFocus) return -1;
          if (!aFocus && bFocus) return 1;
          return 0;
        });

        _groupedExercises[_getZoneLabel(zone)] = zoneExercises;
      }
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length < _maxSelection) {
          _selectedIds.add(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Можно выбрать максимум $_maxSelection упражнения')),
          );
        }
      }
    });
  }

  Future<void> _startChallenge() async {
    if (_selectedIds.length < _maxSelection) return;

    // 1. Удаляем старые упражнения
    final existing = await DatabaseHelper.instance.getWorkoutExercises(widget.day.id!);
    for (final e in existing) {
      if (e.id != null) await DatabaseHelper.instance.deleteWorkoutExercise(e.id!);
    }

    // 2. Добавляем новые
    final List<WorkoutExercise> newItems = [];
    final Map<int, Exercise> exMap = {};

    for (final id in _selectedIds) {
      final ex = widget.allExercises.firstWhere((e) => e.id == id);

      // Если это планка — ставим 100 сек, иначе 100 повторений
      final isTimed = ex.name.toLowerCase().contains('планка') || ex.name.toLowerCase().contains('вакуум');
      final repsStr = isTimed ? '100 сек' : '100 повторов';

      final we = WorkoutExercise(
        workoutDayId: widget.day.id!,
        itemType: 'exercise',
        itemId: id,
        order: newItems.length + 1,
        sets: 1,
        reps: repsStr,
      );

      final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
      newItems.add(we.copyWith(id: newId));
      exMap[id] = ex;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeScreen(
          day: widget.day,
          profileId: widget.profile?.id ?? 1,
          items: newItems,
          exerciseMap: exMap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка челленджа'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withOpacity(0.1),
              border: const Border(bottom: BorderSide(color: Color(0xFFFFB800), width: 2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB800), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Выбери $_maxSelection любимых упражнения. Тебе нужно будет сделать каждое по 100 раз (или 100 секунд).',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _groupedExercises.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        entry.key,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ),
                    ...entry.value.map((ex) {
                      final isSelected = _selectedIds.contains(ex.id);
                      return CheckboxListTile(
                        title: Text(ex.name),
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(ex.id!),
                        activeColor: const Color(0xFFFFB800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedIds.length == _maxSelection ? _startChallenge : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _selectedIds.length == _maxSelection
                        ? 'Погнали!'
                        : 'Выбрано ${_selectedIds.length} из $_maxSelection',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getZoneLabel(String zone) {
    switch (zone) {
      case 'glutes': return 'Ягодицы';
      case 'legs': return 'Ноги';
      case 'abs': return 'Пресс';
      case 'back': return 'Спина';
      case 'chest': return 'Грудь';
      case 'arms': return 'Руки';
      default: return 'Другое';
    }
  }
}