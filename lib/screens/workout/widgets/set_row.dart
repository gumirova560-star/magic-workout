import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Строка одного подхода: номер, вес, повторения, галочка.
class SetRow extends StatefulWidget {
  final int setNumber;
  final double? initialWeight;
  final int? initialReps;
  final bool completed;
  final ValueChanged<SetData> onChanged;
  final VoidCallback? onComplete;
  final VoidCallback? onUncomplete;

  const SetRow({
    super.key,
    required this.setNumber,
    this.initialWeight,
    this.initialReps,
    this.completed = false,
    required this.onChanged,
    this.onComplete,
    this.onUncomplete,
  });

  @override
  State<SetRow> createState() => _SetRowState();
}

class SetData {
  final double? weight;
  final int? reps;
  final bool completed;
  SetData({this.weight, this.reps, this.completed = false});
}

class _SetRowState extends State<SetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late bool _completed;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.initialWeight?.toStringAsFixed(1) ?? '',
    );
    _repsController = TextEditingController(
      text: widget.initialReps?.toString() ?? '',
    );
    _completed = widget.completed;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(SetData(
      weight: double.tryParse(_weightController.text),
      reps: int.tryParse(_repsController.text),
      completed: _completed,
    ));
  }

  void _toggleComplete() {
    setState(() => _completed = !_completed);
    if (_completed) {
      widget.onComplete?.call();
    } else {
      widget.onUncomplete?.call();
    }
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _completed
            ? theme.colorScheme.primary.withOpacity(0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _completed
              ? theme.colorScheme.primary.withOpacity(0.4)
              : theme.colorScheme.onSurface.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          // Номер подхода
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _completed
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${widget.setNumber}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _completed
                    ? Colors.white
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Вес
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                hintText: 'кг',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              onChanged: (_) => _notifyChanged(),
            ),
          ),
          const SizedBox(width: 8),

          // Повторения
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'повт.',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              onChanged: (_) => _notifyChanged(),
            ),
          ),
          const SizedBox(width: 8),

          // Галочка
          GestureDetector(
            onTap: _toggleComplete,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _completed
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _completed
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: _completed
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 24)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}