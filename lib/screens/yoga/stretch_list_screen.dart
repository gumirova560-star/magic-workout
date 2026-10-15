import 'package:flutter/material.dart';
import '../../models/stretch.dart';
import '../../services/database_helper.dart';
import 'stretch_practice_screen.dart';

class StretchListScreen extends StatefulWidget {
  const StretchListScreen({super.key});

  @override
  State<StretchListScreen> createState() => _StretchListScreenState();
}

class _StretchListScreenState extends State<StretchListScreen> {
  List<Stretch> _all = [];
  List<Stretch> _filtered = [];
  bool _loading = true;
  String _filter = 'all';
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await DatabaseHelper.instance.getStretches();
    setState(() {
      _all = all;
      _filtered = all;
      _loading = false;
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _filter = filter;
      if (filter == 'all') {
        _filtered = _all;
      } else {
        _filtered = _all.where((s) => s.category == filter).toList();
      }
    });
  }

  void _toggleSelect(Stretch stretch) {
    final id = stretch.id;
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _startSingle(Stretch stretch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StretchPracticeScreen(stretches: [stretch]),
      ),
    );
  }

  void _startSeries() {
    final selected = _all.where((s) {
      final id = s.id;
      return id != null && _selectedIds.contains(id);
    }).toList();
    if (selected.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StretchPracticeScreen(stretches: selected),
      ),
    );
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
      'adductors': 'внутренняя поверхность',
      'neck': 'шея',
      'forearms': 'предплечья',
      'full_body': 'всё тело',
      'breathing': 'дыхание',
    };
    return map[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Свободная практика'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ═══ Фильтры ═══
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _filterChip('all', 'Все'),
                      const SizedBox(width: 8),
                      _filterChip('classic', 'Растяжка'),
                      const SizedBox(width: 8),
                      _filterChip('yoga', 'Йога'),
                    ],
                  ),
                ),

                // ═══ Список ═══
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) =>
                        _buildStretchCard(context, _filtered[i]),
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedIds.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _startSeries,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Начать (${_selectedIds.length})'),
              backgroundColor: const Color(0xFF00B894),
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isActive = _filter == value;
    return FilterChip(
      selected: isActive,
      onSelected: (_) => _applyFilter(value),
      label: Text(label),
    );
  }

  Widget _buildStretchCard(BuildContext context, Stretch stretch) {
    final theme = Theme.of(context);
    final isYoga = stretch.category == 'yoga';
    final color =
        isYoga ? const Color(0xFF00B894) : const Color(0xFF6C5CE7);
    final id = stretch.id;
    final isSelected = id != null && _selectedIds.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // ═══ Чекбокс — отдельная зона тапа ═══
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelect(stretch),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              activeColor: color,
            ),
          ),

          // ═══ Строка — тап = пуск ═══
          Expanded(
            child: InkWell(
              onTap: () => _startSingle(stretch),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 4),
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
                        isYoga
                            ? Icons.self_improvement_rounded
                            : Icons.accessibility_new_rounded,
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
                            stretch.name,
                            style: theme.textTheme.headlineMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _groupLabel(stretch.muscleGroup),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isYoga ? 'Йога' : 'Растяжка',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stretch.durationSeconds} сек',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}