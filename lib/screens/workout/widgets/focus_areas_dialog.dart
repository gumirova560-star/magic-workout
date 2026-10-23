import 'package:flutter/material.dart';

/// ⚠️ Диалог выбора фокусных зон при генерации плана.
class FocusAreasDialog extends StatefulWidget {
  final Set<String> initial;
  final int maxCount;
  final bool isWeightLoss; // 👈 ДОБАВЛЕНО: знаем, какая цель

  const FocusAreasDialog({
    super.key,
    this.initial = const {},
    this.maxCount = 3,
    this.isWeightLoss = false, // 👈 По умолчанию false
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
    _selected = Set<String>.from(widget.initial);

    // 👇 Если цель похудеть, принудительно добавляем кардио
    if (widget.isWeightLoss) {
      _selected.add('cardio');
    }

    // Ограничиваем количество (если кардио добавилось, оно входит в лимит)
    if (_selected.length > widget.maxCount) {
      _selected = _selected.take(widget.maxCount).toSet();
      if (widget.isWeightLoss) _selected.add('cardio'); // чтобы не удалить кардио при обрезке
    }
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        // 👇 Запрещаем убирать кардио, если цель - похудение
        if (value == 'cardio' && widget.isWeightLoss) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Для цели «Похудение» кардио необходимо!'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
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
              final atLimit = !isSelected && _selected.length >= widget.maxCount;

              // Блокируем нажатие, если достигнут лимит (и это не кардио)
              final isDisabled = atLimit;

              return FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: isDisabled ? null : (_) => _toggle(value),
                // Визуально показываем, что кардио заблокировано для снятия (опционально)
                avatar: (value == 'cardio' && widget.isWeightLoss)
                    ? const Icon(Icons.lock_rounded, size: 14)
                    : null,
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
          onPressed: canConfirm ? () => Navigator.pop(context, _selected) : null,
          child: const Text('Создать план'),
        ),
      ],
    );
  }
}