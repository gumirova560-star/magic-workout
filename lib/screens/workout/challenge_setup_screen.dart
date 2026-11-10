import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../models/workout_day.dart';
import '../../services/database_helper.dart';
import '../../data/base_exercises.dart';
import '../exercise/exercise_picker_screen.dart';
import 'challenge_300_screen.dart';

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
  final int _maxSelection = 3;

  final Map<String, List<Exercise>> _groupedExercises = {};
  final List<Exercise> _customSelected = [];

  @override
  void initState() {
    super.initState();
    _prepareExercises();
  }

  void _prepareExercises() {
    final focusZones = widget.profile?.focusAreas ?? [];

    final Map<String, List<String>> targetExercises = {
      'Ягодицы и Ноги': ['Приседания', 'Выпады', 'Ягодичный мост', 'Махи ногой', 'Подъемы на носки'],
      'Пресс и Кор': ['Скручивания', 'Планка', 'Велосипед', 'Подъем ног', 'Боковая планка'],
      'Верх тела': ['Отжимания', 'Супермен', 'Лодочка', 'Обратные отжимания'],
    };

    targetExercises.forEach((groupName, names) {
      final foundExercises = <Exercise>[];

      for (final name in names) {
        final matches = widget.allExercises.where((e) {
          final exName = e.name.toLowerCase();
          final targetName = name.toLowerCase();
          return exName.contains(targetName);
        }).toList();

        if (matches.isNotEmpty) {
          matches.sort((a, b) => a.name.length.compareTo(b.name.length));
          final bestMatch = matches.first;
          if (!foundExercises.any((e) => e.id == bestMatch.id)) {
            foundExercises.add(bestMatch);
          }
        }
      }

      foundExercises.sort((a, b) {
        final aFocus = a.muscleGroups.any((m) => focusZones.contains(m));
        final bFocus = b.muscleGroups.any((m) => focusZones.contains(m));
        if (aFocus && !bFocus) return -1;
        if (!aFocus && bFocus) return 1;
        return 0;
      });

      if (foundExercises.length < 4) {
        List<String> targetZones = [];
        if (groupName == 'Ягодицы и Ноги') targetZones = ['glutes', 'legs'];
        if (groupName == 'Пресс и Кор') targetZones = ['abs', 'core'];
        if (groupName == 'Верх тела') targetZones = ['chest', 'back', 'shoulders', 'arms'];

        final extras = widget.allExercises.where((e) {
          if (!e.muscleGroups.any((m) => targetZones.contains(m))) return false;
          if (foundExercises.any((fe) => fe.id == e.id)) return false;
          if (e.muscleGroups.contains('cardio')) return false;
          if (e.name.toLowerCase().contains('гантел') || e.name.toLowerCase().contains('штанг')) return false;
          return true;
        }).toList()..shuffle();

        for (int i = 0; i < (4 - foundExercises.length) && i < extras.length; i++) {
          foundExercises.add(extras[i]);
        }
      }

      if (foundExercises.isNotEmpty) {
        _groupedExercises[groupName] = foundExercises;
      }
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _customSelected.removeWhere((e) => e.id == id);
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

  Future<void> _openCatalog() async {
    final result = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePickerScreen(
          allExercises: widget.allExercises,
          initialSelectedIds: _selectedIds.toList(),
          maxSelection: _maxSelection,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedIds.clear();
        _selectedIds.addAll(result);

        _customSelected.clear();
        for (final id in result) {
          final ex = widget.allExercises.firstWhere((e) => e.id == id);
          bool isInBase = _groupedExercises.values.any((list) => list.any((e) => e.id == id));
          if (!isInBase) {
            _customSelected.add(ex);
          }
        }
      });
    }
  }

  Future<void> _startChallenge() async {
    if (_selectedIds.length < _maxSelection) return;

    // 1. Удаляем старые упражнения
    final existing = await DatabaseHelper.instance.getWorkoutExercises(widget.day.id!);
    for (final e in existing) {
      if (e.id != null) await DatabaseHelper.instance.deleteWorkoutExercise(e.id!);
    }

    // 2. Добавляем новые базы
    final List<WorkoutExercise> newItems = [];
    final Map<int, Exercise> exMap = {};

    for (final id in _selectedIds) {
      final ex = widget.allExercises.firstWhere((e) => e.id == id);
      final isTimed = ex.name.toLowerCase().contains('планка');
      final repsStr = isTimed ? '100 сек' : '100 повторов';

      final we = WorkoutExercise(
        workoutDayId: widget.day.id!,
        itemType: 'exercise',
        itemId: id,
        order: newItems.length + 1,
        sets: 1,
        reps: repsStr,
        blockNumber: 0,
      );

      final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
      newItems.add(we.copyWith(id: newId));
      exMap[id] = ex;
    }

    // 3. Генерируем 6 изоляций
    if (widget.profile != null) {
      await _generateIsolations(widget.day.id!, widget.profile!, 6, _selectedIds);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => Challenge300Screen(
          day: widget.day,
          profileId: widget.profile?.id ?? 1,
          items: newItems,
          exerciseMap: exMap,
        ),
      ),
    );
  }

  Future<void> _generateIsolations(int workoutDayId, UserProfile profile, int count, Set<int> selectedBaseIds) async {
    final allExercises = await DatabaseHelper.instance.getExercises();
    final allZones = ['chest', 'back', 'arms', 'shoulders', 'glutes', 'legs', 'abs'];
    final blockedZones = profile.limitations.map((e) => e.toLowerCase()).toList();
    final focusZones = profile.focusAreas.map((e) => e.toLowerCase()).toList();

    int added = 0;
    int order = 200;
    final Set<int> usedIds = {...selectedBaseIds};
    final Set<String> usedFamilies = {};

    // 👇 Добавляем семейства выбранных баз в игнор, чтобы не брать их же в изоляциях
    for (final id in selectedBaseIds) {
      final ex = allExercises.firstWhere((e) => e.id == id);
      usedFamilies.add(getExerciseFamily(ex.name));
    }

    bool isSafe(Exercise e) {
      final primaryZone = getExerciseZone(e).toLowerCase();
      if (blockedZones.contains(primaryZone)) return false;

      for (final c in e.contraindications) {
        for (final b in blockedZones) {
          if (c.toLowerCase().contains(b) || b.contains(c.toLowerCase())) return false;
        }
      }
      return true;
    }

    Future<void> tryAdd(Exercise ex) async {
      if (added >= count) return;
      if (ex.id == null) return;
      if (usedIds.contains(ex.id)) return;
      if (ex.muscleGroups.contains('cardio')) return;
      if (usedFamilies.contains(getExerciseFamily(ex.name))) return;
      if (!isSafe(ex)) return;

      usedIds.add(ex.id!);
      usedFamilies.add(getExerciseFamily(ex.name));

      final we = WorkoutExercise(
        workoutDayId: workoutDayId, itemType: 'exercise', itemId: ex.id!,
        order: order++, sets: 3, reps: '15', blockNumber: 1,
      );
      final newId = await DatabaseHelper.instance.addWorkoutExercise(we);
      for (int s = 1; s <= 3; s++) {
        await DatabaseHelper.instance.addWorkoutSet(WorkoutSet(workoutExerciseId: newId, order: s, completed: false));
      }
      added++;
    }

    // ШАГ 1: Изоляции из забытых зон
    final forgottenZones = allZones.where((z) =>
    !blockedZones.contains(z) && !focusZones.contains(z)
    ).toList();

    for (final zone in forgottenZones) {
      if (added >= count) break;
      final zoneExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
        return e.muscleGroups.contains(zone);
      }).toList()..shuffle();

      for (final ex in zoneExs) {
        if (added >= count) break;
        await tryAdd(ex);
      }
    }

    // ШАГ 2: Базы из забытых зон
    if (added < count) {
      for (final zone in forgottenZones) {
        if (added >= count) break;
        final zoneExs = allExercises.where((e) {
          if (e.id == null) return false;
          if (!isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
          return e.muscleGroups.contains(zone);
        }).toList()..shuffle();

        for (final ex in zoneExs) {
          if (added >= count) break;
          await tryAdd(ex);
        }
      }
    }

    // ШАГ 3: Изоляции из фокусных зон (и любых других, если фокус пуст)
    if (added < count) {
      final extraZones = focusZones.isNotEmpty
          ? focusZones
          : allZones.where((z) => !blockedZones.contains(z)).toList();

      for (final zone in extraZones) {
        if (added >= count) break;
        if (blockedZones.contains(zone)) continue;

        final zoneExs = allExercises.where((e) {
          if (e.id == null) return false;
          if (isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
          return e.muscleGroups.contains(zone);
        }).toList()..shuffle();

        for (final ex in zoneExs) {
          if (added >= count) break;
          await tryAdd(ex);
        }
      }
    }

    // ШАГ 4: Базы из фокусных зон
    if (added < count) {
      final extraZones = focusZones.isNotEmpty
          ? focusZones
          : allZones.where((z) => !blockedZones.contains(z)).toList();

      for (final zone in extraZones) {
        if (added >= count) break;
        if (blockedZones.contains(zone)) continue;

        final zoneExs = allExercises.where((e) {
          if (e.id == null) return false;
          if (!isBaseExercise(e) || e.muscleGroups.contains('cardio')) return false;
          return e.muscleGroups.contains(zone);
        }).toList()..shuffle();

        for (final ex in zoneExs) {
          if (added >= count) break;
          await tryAdd(ex);
        }
      }
    }

    // ШАГ 5: Любые безопасные упражнения (последний резерв)
    if (added < count) {
      final fallbackExs = allExercises.where((e) {
        if (e.id == null) return false;
        if (e.muscleGroups.contains('cardio')) return false;
        return isSafe(e);
      }).toList()..shuffle();

      for (final ex in fallbackExs) {
        if (added >= count) break;
        await tryAdd(ex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройка челленджа')),
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
              children: [
                OutlinedButton.icon(
                  onPressed: _openCatalog,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Выбрать из полного каталога'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_customSelected.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text('Выбрано из каталога', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  ),
                  ..._customSelected.map((ex) {
                    return CheckboxListTile(
                      title: Text(ex.name),
                      value: _selectedIds.contains(ex.id),
                      onChanged: (_) => _toggleSelection(ex.id!),
                      activeColor: const Color(0xFFFFB800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  }),
                  const Divider(),
                ],
                ..._groupedExercises.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(entry.key, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
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
              ],
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
                    _selectedIds.length == _maxSelection ? 'Погнали!' : 'Выбрано ${_selectedIds.length} из $_maxSelection',
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
}