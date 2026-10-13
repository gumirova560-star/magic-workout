import 'package:flutter/material.dart';
import '../../models/stretch.dart';
import '../../services/database_helper.dart';

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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openStretch(stretch),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStretch(Stretch stretch) {
    // Создаём «одиночную» сессию для плеера
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(stretch.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stretch.description.isNotEmpty) ...[
              Text(stretch.description,
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
            ],
            Text('Длительность: ${stretch.durationSeconds} сек',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (stretch.bothSides) ...[
              const SizedBox(height: 4),
              const Text('Делать на 2 стороны',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}