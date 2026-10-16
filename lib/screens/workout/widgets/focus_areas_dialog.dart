import 'package:flutter/material.dart';

/// ⚠️ Диалог выбора фокусных зон при генерации плана.
class FocusAreasDialog extends StatefulWidget {
  final Set<String> initial;
  final int maxCount;

  const FocusAreasDialog({
    super.key,
    this.initial = const {},
    this.maxCount = 3,
  });

  @override
  State<FocusAreasDialog> createState() => _FocusAreasDialogState();
}

class _FocusAreasDialogState extends State<FocusAreasDialog> {
  late Set<String> _selected;

  static const List<(String, String)> _zones = [
    ('glutes', 'Ягодицы'),
    ('abs', 'Пресс'),
    ('arms', 'Руки'),
    ('legs', 'Ноги'),
    ('back', 'Спина'),
    ('chest', 'Грудь'),
    ('shoulders', 'Плечи'),
    ('calves', 'Голень'),
    ('cardio', 'Кардио'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(
      widget.initial.take(widget.maxCount),
    );
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else if (_selected.length < widget.maxCount) {
        _selected.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm = _selected.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text('Фокусные зоны'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Можно выбрать до ${widget.maxCount} зон. '
            'Выбрано: ${_selected.length}/${widget.maxCount}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _zones.map((z) {
              final (value, label) = z;
              final isSelected = _selected.contains(value);
              final atLimit = !isSelected &&
                  _selected.length >= widget.maxCount;

              return FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: atLimit ? null : (_) => _toggle(value),
              );
            }).toList(),
          ),
          if (!canConfirm) ...[
            const SizedBox(height: 12),
            Text(
              'Выберите хотя бы одну зону',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: canConfirm
              ? () => Navigator.pop(context, _selected)
              : null,
          child: const Text('Создать план'),
        ),
      ],
    );
  }
}