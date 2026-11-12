import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/database_helper.dart';
import '../../data/base_exercises.dart';
import '../exercise/exercise_detail_screen.dart';

class ReplaceExerciseScreen extends StatefulWidget {
  final Exercise original;
  final String? reasonCode;

  const ReplaceExerciseScreen({
    super.key,
    required this.original,
    this.reasonCode,
  });

  @override
  State<ReplaceExerciseScreen> createState() => _ReplaceExerciseScreenState();
}

class _ReplaceExerciseScreenState extends State<ReplaceExerciseScreen> {
  List<Exercise> _recommended = [];
  List<Exercise> _allExercises = [];
  bool _loading = true;
  String _search = '';
  String _selectedEquipment = 'all';
  bool _showAllMuscles = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final all = await DatabaseHelper.instance.getExercises();
    final others = all.where((e) => e.id != widget.original.id).toList();

    setState(() {
      _allExercises = others;
      _loading = false;
    });
    _updateRecommendations();
  }

  void _updateRecommendations() {
    setState(() {
      _recommended = _pickRecommended(_allExercises);
    });
  }

  bool _matchesEquipment(Exercise e) {
    if (_selectedEquipment == 'all') return true;
    if (_selectedEquipment == 'gym_machines') {
      return e.equipment.contains('machine') || e.equipment.contains('cable');
    }
    return e.equipment.contains(_selectedEquipment);
  }

  bool _matchesMuscleGroupAndType(Exercise e) {
    if (_showAllMuscles) return true;
    if (widget.original.muscleGroups.isEmpty) return true;

    final muscleMatch = e.muscleGroups.any(widget.original.muscleGroups.contains);
    final originalIsBase = isBaseExercise(widget.original);
    final candidateIsBase = isBaseExercise(e);
    final typeMatch = originalIsBase == candidateIsBase;

    return muscleMatch && typeMatch;
  }

  List<Exercise> _pickRecommended(List<Exercise> all) {
    final original = widget.original;
    final originalFamily = getExerciseFamily(original.name);
    final originalIsBase = isBaseExercise(original);

    var familyCandidates = all.where((e) => getExerciseFamily(e.name) == originalFamily).toList();

    if (_selectedEquipment != 'all') {
      familyCandidates = familyCandidates.where(_matchesEquipment).toList();
    }

    if (familyCandidates.isNotEmpty) {
      return familyCandidates.take(4).toList();
    }

    var muscleCandidates = all.where((e) {
      final muscleMatch = e.muscleGroups.any(original.muscleGroups.contains);
      final typeMatch = isBaseExercise(e) == originalIsBase;
      return muscleMatch && typeMatch;
    }).toList();

    if (_selectedEquipment != 'all') {
      muscleCandidates = muscleCandidates.where(_matchesEquipment).toList();
    }

    muscleCandidates.sort((a, b) {
      final aEq = a.equipment.any(original.equipment.contains) ? 0 : 1;
      final bEq = b.equipment.any(original.equipment.contains) ? 0 : 1;
      return aEq.compareTo(bEq);
    });

    return muscleCandidates.take(4).toList();
  }

  List<Exercise> get _filteredAll {
    var result = _allExercises;
    result = result.where(_matchesMuscleGroupAndType).toList();

    if (_selectedEquipment != 'all') {
      result = result.where(_matchesEquipment).toList();
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((e) => e.name.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  String _groupLabel(String code) {
    const map = {
      'glutes': 'ягодицы', 'abs': 'пресс', 'obliques': 'косые', 'arms': 'руки',
      'biceps': 'бицепс', 'triceps': 'трицепс', 'shoulders': 'плечи', 'legs': 'ноги',
      'quads': 'бёдра', 'hamstrings': 'задняя поверхность', 'calves': 'голень',
      'back': 'спина', 'lats': 'широчайшие', 'traps': 'трапеции', 'lower_back': 'поясница',
      'chest': 'грудь', 'core': 'кор', 'cardio': 'кардио', 'rotator_cuff': 'манжета',
    };
    return map[code] ?? code;
  }

  Future<void> _pickExercise(Exercise exercise) async {
    final typeResult = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Как заменить?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Заменить на «${exercise.name}»', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.today_rounded),
              title: const Text('Только сегодня'),
              subtitle: const Text('В этой тренировке'),
              onTap: () => Navigator.pop(ctx, 'today'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.save_rounded),
              title: const Text('Навсегда'),
              subtitle: const Text('Изменить и шаблон'),
              onTap: () => Navigator.pop(ctx, 'forever'),
            ),
          ],
        ),
      ),
    );

    if (typeResult == null) return;
    if (!mounted) return;

    Navigator.pop(context, {
      'newExercise': exercise,
      'permanent': typeResult == 'forever',
      'reason': widget.reasonCode ?? 'other',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Заменить упражнение')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOriginalCard(context),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск по названию...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
              )
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 12),

          // 👇 ФИЛЬТРЫ ТЕПЕРЬ ПЕРЕНОСЯТСЯ НА СЛЕДУЮЩУЮ СТРОКУ (Wrap) 👇
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEquipmentChip('all', 'Все'),
              _buildEquipmentChip('bodyweight', 'Своё тело'),
              _buildEquipmentChip('dumbbells', 'Гантели'),
              _buildEquipmentChip('barbell', 'Штанга'),
              _buildEquipmentChip('gym_machines', 'Тренажеры'),
              _buildEquipmentChip('resistance_band', 'Резинки'),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Искать во всех группах мышц',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ),
                Switch(
                  value: _showAllMuscles,
                  onChanged: (v) {
                    setState(() => _showAllMuscles = v);
                  },
                ),
              ],
            ),
          ),

          if (_recommended.isNotEmpty && _search.isEmpty) ...[
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Рекомендуем (Аналоги)', style: theme.textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            ..._recommended.map((e) => _buildExerciseCard(context, e, isRecommended: true)),
            const SizedBox(height: 24),
          ],

          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                    _showAllMuscles ? 'Все упражнения' : 'Подходящие упражнения',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.w600)
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),

          if (_filteredAll.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Аналогов не найдено', style: TextStyle(color: Colors.grey))),
            )
          else
            ..._filteredAll.map((e) => _buildExerciseCard(context, e)),
        ],
      ),
    );
  }

  Widget _buildEquipmentChip(String code, String label) {
    final isSelected = _selectedEquipment == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) {
        if (v) {
          setState(() => _selectedEquipment = code);
          _updateRecommendations();
        }
      },
    );
  }

  Widget _buildOriginalCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Меняем:', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                Text(widget.original.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, Exercise exercise, {bool isRecommended = false}) {
    final theme = Theme.of(context);
    final groups = exercise.muscleGroups.map(_groupLabel).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _pickExercise(exercise),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isRecommended ? const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]) : null,
                  color: isRecommended ? null : theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isRecommended ? Icons.auto_awesome_rounded : Icons.fitness_center, color: isRecommended ? Colors.white : theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: theme.textTheme.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(groups, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (isRecommended) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text('Аналог', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                      ),
                    ],
                  ],
                ),
              ),

              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: exercise)),
                  );
                },
                tooltip: 'Детали упражнения',
              ),

              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}