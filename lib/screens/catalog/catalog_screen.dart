import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/database_helper.dart';
import '../exercise/exercise_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  bool _loading = true;
  String _searchQuery = '';
  String _selectedMuscle = 'all';
  String _selectedEquipment = 'all';

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _loading = true);
    final exercises = await DatabaseHelper.instance.getExercises();
    setState(() {
      _allExercises = exercises;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredExercises = _allExercises.where((ex) {
        final matchesSearch = ex.name
            .toLowerCase()
            .contains(_searchQuery.toLowerCase().trim());
        if (!matchesSearch) return false;

        if (_selectedMuscle != 'all' &&
            !ex.muscleGroups.contains(_selectedMuscle)) {
          return false;
        }

        if (_selectedEquipment != 'all' &&
            !ex.equipment.contains(_selectedEquipment)) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог упражнений'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Найти упражнение...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilters();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showMusclePicker(context),
                          icon: const Icon(Icons.fitness_center, size: 18),
                          label: Text(
                            _selectedMuscle == 'all'
                                ? 'Все мышцы'
                                : _muscleLabel(_selectedMuscle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showEquipmentPicker(context),
                          icon: const Icon(Icons.construction_rounded, size: 18),
                          label: Text(
                            _selectedEquipment == 'all'
                                ? 'Оборудование'
                                : _equipmentLabel(_selectedEquipment),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _filteredExercises.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _filteredExercises.length,
                          itemBuilder: (context, i) {
                            final ex = _filteredExercises[i];
                            return _buildExerciseCard(context, ex);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showMusclePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final muscles = ['all', ..._getUniqueMuscles()];
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: muscles.length,
          itemBuilder: (context, i) {
            final m = muscles[i];
            final isSelected = _selectedMuscle == m;
            return ListTile(
              title: Text(m == 'all' ? 'Все мышцы' : _muscleLabel(m)),
              trailing: isSelected ? const Icon(Icons.check_rounded, color: Colors.green) : null,
              onTap: () {
                _selectedMuscle = m;
                _applyFilters();
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  void _showEquipmentPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final equipment = ['all', ..._getUniqueEquipment()];
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: equipment.length,
          itemBuilder: (context, i) {
            final e = equipment[i];
            final isSelected = _selectedEquipment == e;
            return ListTile(
              title: Text(e == 'all' ? 'Всё оборудование' : _equipmentLabel(e)),
              trailing: isSelected ? const Icon(Icons.check_rounded, color: Colors.green) : null,
              onTap: () {
                _selectedEquipment = e;
                _applyFilters();
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  List<String> _getUniqueMuscles() {
    final set = <String>{};
    for (final ex in _allExercises) {
      set.addAll(ex.muscleGroups.where((m) => m != 'cardio'));
    }
    return set.toList()..sort();
  }

  List<String> _getUniqueEquipment() {
    final set = <String>{};
    for (final ex in _allExercises) {
      set.addAll(ex.equipment);
    }
    return set.toList()..sort();
  }

  Widget _buildExerciseCard(BuildContext context, Exercise ex) {
    final theme = Theme.of(context);
    final isCardio = ex.muscleGroups.contains('cardio');
    final color = isCardio ? const Color(0xFFE17055) : const Color(0xFF6C5CE7);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseDetailScreen(exercise: ex),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCardio
                      ? Icons.directions_run_rounded
                      : Icons.fitness_center,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ex.muscleGroups.map(_muscleLabel).join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Ничего не найдено',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _muscleLabel(String code) {
    const map = {
      'glutes': 'Ягодицы',
      'abs': 'Пресс',
      'obliques': 'Косые',
      'arms': 'Руки',
      'biceps': 'Бицепс',
      'triceps': 'Трицепс',
      'shoulders': 'Плечи',
      'legs': 'Ноги',
      'quads': 'Бёдра',
      'hamstrings': 'Задняя поверхность',
      'calves': 'Голень',
      'back': 'Спина',
      'lats': 'Широчайшие',
      'traps': 'Трапеции',
      'lower_back': 'Поясница',
      'chest': 'Грудь',
      'core': 'Кор',
      'forearms': 'Предплечья',
      'cardio': 'Кардио',
      'full_body': 'Всё тело',
    };
    return map[code] ?? code;
  }

  String _equipmentLabel(String code) {
    const map = {
      'barbell': 'Штанга',
      'dumbbells': 'Гантели',
      'bodyweight': 'Своё тело',
      'bench': 'Скамья',
      'machine': 'Тренажёр',
      'cable': 'Блок',
      'resistance_band': 'Резинка',
      'jump_rope': 'Скакалка',
    };
    return map[code] ?? code;
  }
}