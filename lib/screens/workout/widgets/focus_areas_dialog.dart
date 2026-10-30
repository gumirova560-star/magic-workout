import 'package:flutter/material.dart';

class FocusAreasDialog extends StatefulWidget {
  final Set<String> initial;
  final int maxCount;
  final bool isWeightLoss;
  final int daysPerWeek;

  const FocusAreasDialog({
    super.key,
    required this.initial,
    this.maxCount = 3,
    this.isWeightLoss = false,
    required this.daysPerWeek,
  });

  @override
  State<FocusAreasDialog> createState() => _FocusAreasDialogState();
}

class _FocusAreasDialogState extends State<FocusAreasDialog> {
  late Set<String> _selected;

  // 👇 8 ФОКУСНЫХ ЗОН (Руки и Плечи разделены)
  final List<Map<String, String>> _allAreas = [
    {'label': 'Ягодицы', 'tag': 'glutes'},
    {'label': 'Ноги (Квадрицепс, Бицепс, Икры)', 'tag': 'legs'},
    {'label': 'Пресс', 'tag': 'abs'},
    {'label': 'Спина', 'tag': 'back'},
    {'label': 'Грудь', 'tag': 'chest'},
    {'label': 'Руки', 'tag': 'arms'},
    {'label': 'Плечи', 'tag': 'shoulders'},
    {'label': 'Кардио-день', 'tag': 'cardio'},
  ];

  @override
  void initState() {
    super.initState();
    // Миграция старых тегов (например, если раньше было quads или hamstrings)
    _selected = widget.initial.map((s) {
      if (_allAreas.any((a) => a['tag'] == s)) return s;
      final byLabel = _allAreas.where((a) => a['label'] == s);
      if (byLabel.isNotEmpty) return byLabel.first['tag']!;

      if (s == 'quads' || s == 'hamstrings' || s == 'legs_main' || s == 'legs_lower') return 'legs';
      if (s == 'Кардио') return 'cardio';

      return s;
    }).toSet();
  }

  void _toggle(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        if (_selected.length >= widget.maxCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Можно выбрать не более ${widget.maxCount} зон'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        _selected.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Фокусные зоны'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выберите до ${widget.maxCount} зон, на которые сделать упор.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allAreas.map((area) {
                    final label = area['label']!;
                    final tag = area['tag']!;
                    final isSelected = _selected.contains(tag);

                    // Запрет для кардио, если дней меньше 3
                    bool isDisabled = false;
                    if (tag == 'cardio' && widget.daysPerWeek <= 2) {
                      isDisabled = true;
                    }

                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label),
                          if (isDisabled) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock, size: 14, color: Colors.grey),
                          ]
                        ],
                      ),
                      selected: isSelected,
                      onSelected: isDisabled
                          ? (val) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Для отдельного кардио-дня нужно минимум 3 дня в неделю'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : (_) => _toggle(tag),
                      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isDisabled
                            ? Colors.grey
                            : (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}