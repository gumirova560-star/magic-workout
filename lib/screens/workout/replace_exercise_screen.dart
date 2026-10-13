import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/database_helper.dart';

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
    final recommended = _pickRecommended(others);

    setState(() {
      _recommended = recommended;
      _allExercises = others;
      _loading = false;
    });
  }

  List<Exercise> _pickRecommended(List<Exercise> all) {
    final reason = widget.reasonCode;
    final original = widget.original;

    var candidates = all
        .where((e) => e.muscleGroups.any(original.muscleGroups.contains))
        .toList();

    if (candidates.isEmpty) candidates = all;

    switch (reason) {
      case 'no_equipment':
        final bw = candidates
            .where((e) => e.equipment.contains('bodyweight'))
            .toList();
        if (bw.isNotEmpty) candidates = bw;
        break;
      case 'too_hard':
        final easy = candidates
            .where((e) => e.difficulty == 'beginner')
            .toList();
        if (easy.isNotEmpty) candidates = easy;
        break;
      case 'too_easy':
        final hard = candidates
            .where((e) => e.difficulty == 'advanced')
            .toList();
        if (hard.isNotEmpty) candidates = hard;
        break;
      default:
        break;
    }

    candidates.sort((a, b) {
      final aEq = a.equipment.any(original.equipment.contains) ? 0 : 1;
      final bEq = b.equipment.any(original.equipment.contains) ? 0 : 1;
      if (aEq != bEq) return aEq.compareTo(bEq);
      final aDiff = a.difficulty == original.difficulty ? 0 : 1;
      final bDiff = b.difficulty == original.difficulty ? 0 : 1;
      return aDiff.compareTo(bDiff);
    });

    return candidates.take(4).toList();
  }

  List<Exercise> get _filteredAll {
    if (_search.isEmpty) return _allExercises;
    final q = _search.toLowerCase();
    return _allExercises
        .where((e) => e.name.toLowerCase().contains(q))
        .toList();
  }

  String _groupLabel(String code) {
    const map = {
      'glutes': 'ягодицы',
      'abs': 'пресс',
      'obliques': 'косые',
      'arms': 'руки',
      'biceps': 'бицепс',
      'triceps': 'трицепс',
      'shoulders': 'плечи',
      'legs': 'ноги',
      'quads': 'бёдра',
      'hamstrings': 'задняя поверхность',
      'calves': 'голень',
      'back': 'спина',
      'lats': 'широчайшие',
      'traps': 'трапеции',
      'lower_back': 'поясница',
      'chest': 'грудь',
      'core': 'кор',
      'cardio': 'кардио',
      'rotator_cuff': 'манжета',
    };
    return map[code] ?? code;
  }

  String _reasonLabel(String? code) {
    switch (code) {
      case 'no_equipment':
        return 'Нет оборудования';
      case 'too_hard':
        return 'Слишком тяжело';
      case 'too_easy':
        return 'Слишком легко';
      case 'dislike':
        return 'Не нравится';
      case 'other':
        return 'Другое';
      default:
        return 'Замена';
    }
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
            Text(
              'Заменить на «${exercise.name}»',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
      appBar: AppBar(
        title: const Text('Заменить упражнение'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOriginalCard(context),
                const SizedBox(height: 16),
                if (_recommended.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Рекомендуем',
                          style: theme.textTheme.headlineMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Подобрано с учётом: ${_reasonLabel(widget.reasonCode)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._recommended.map(
                      (e) => _buildExerciseCard(context, e, isRecommended: true)),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Все упражнения',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
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
                ..._filteredAll.map((e) => _buildExerciseCard(context, e)),
              ],
            ),
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
                Text(
                  'Меняем:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  widget.original.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.reasonCode != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Причина: ${_reasonLabel(widget.reasonCode)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
    BuildContext context,
    Exercise exercise, {
    bool isRecommended = false,
  }) {
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
                  gradient: isRecommended
                      ? const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        )
                      : null,
                  color: isRecommended
                      ? null
                      : theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRecommended
                      ? Icons.auto_awesome_rounded
                      : Icons.fitness_center,
                  color: isRecommended
                      ? Colors.white
                      : theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.headlineMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      groups,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isRecommended) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Рекомендация',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
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
}