import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetData {
  final double? weight;
  final int? reps;
  final bool completed;
  SetData({this.weight, this.reps, this.completed = false});
}

class SetRow extends StatefulWidget {
  final int setNumber;
  final double? initialWeight;
  final int? initialReps;
  final bool completed;
  final ValueChanged<SetData> onChanged;
  final VoidCallback? onComplete;
  final VoidCallback? onUncomplete;
  final bool readOnly;
  final VoidCallback? onDelete;
  final bool isCardio;
  final bool isTimed;
  final String? targetReps;

  const SetRow({
    super.key,
    required this.setNumber,
    this.initialWeight,
    this.initialReps,
    this.completed = false,
    required this.onChanged,
    this.onComplete,
    this.onUncomplete,
    this.readOnly = false,
    this.onDelete,
    this.isCardio = false,
    this.isTimed = false,
    this.targetReps,
  });

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late FocusNode _weightFocus;
  late FocusNode _repsFocus;
  late bool _completed;

  String _formatWeight(double? weight) {
    if (weight == null) return '';
    if (weight % 1 == 0) return weight.toInt().toString();
    return weight.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: _formatWeight(widget.initialWeight));
    _repsController = TextEditingController(text: widget.initialReps?.toString() ?? '');
    _weightFocus = FocusNode();
    _repsFocus = FocusNode();
    _completed = widget.completed;

    // Очищаем "0" при клике на поле веса
    _weightFocus.addListener(() {
      if (_weightFocus.hasFocus && _weightController.text == '0') {
        _weightController.clear();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWeight != widget.initialWeight && !_weightFocus.hasFocus) {
      _weightController.text = _formatWeight(widget.initialWeight);
    }
    if (oldWidget.initialReps != widget.initialReps && !_repsFocus.hasFocus) {
      _repsController.text = widget.initialReps?.toString() ?? '';
    }
    if (oldWidget.completed != widget.completed) {
      _completed = widget.completed;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    if (widget.readOnly) return;
    widget.onChanged(SetData(
      weight: double.tryParse(_weightController.text.replaceAll(',', '.')),
      reps: int.tryParse(_repsController.text),
      completed: _completed,
    ));
  }

  void _toggleComplete() {
    if (widget.readOnly) return;
    setState(() => _completed = !_completed);
    if (_completed) {
      widget.onComplete?.call();
    } else {
      widget.onUncomplete?.call();
    }
    _notifyChanged();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить подход ${widget.setNumber}?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ro = widget.readOnly;
    final canDelete = !ro && widget.onDelete != null;

    // 👇 УМНОЕ ОПРЕДЕЛЕНИЕ ЕДИНИЦ ИЗМЕРЕНИЯ (МИН/СЕК/ПОВТ)
    final targetStr = widget.targetReps?.toLowerCase() ?? '';
    final isTargetMinutes = targetStr.contains('мин');
    final isTargetSeconds = targetStr.contains('сек');
    final isTargetReps = targetStr.contains('повт');

    // Скрываем поле ввода веса для кардио и упражнений на время (сек/мин)
    final isTimeBased = widget.isCardio || widget.isTimed || isTargetMinutes || isTargetSeconds;

    // Настраиваем подсказки (hint) для поля ввода
    String repsHint = isTargetMinutes ? 'мин' : isTargetSeconds ? 'сек' : isTargetReps ? 'повт.' : widget.isCardio ? 'мин' : widget.isTimed ? 'сек' : 'повт.';
    String repsSuffix = isTargetMinutes ? 'мин' : isTargetSeconds ? 'сек' : isTargetReps ? 'повт.' : widget.isCardio ? 'мин' : widget.isTimed ? 'сек' : 'повт.';

    return GestureDetector(
      onLongPress: canDelete ? _confirmDelete : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _completed ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.surface,
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
                  color: _completed ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Поле Веса (скрыто для кардио и упражнений на время)
            if (!isTimeBased) ...[
              Expanded(
                child: ro
                    ? _readOnlyBox(theme, text: widget.initialWeight != null ? '${_formatWeight(widget.initialWeight)} кг' : '— кг')
                    : TextField(
                        controller: _weightController,
                        focusNode: _weightFocus,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'кг',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        onChanged: (_) => _notifyChanged(),
                      ),
              ),
              const SizedBox(width: 8),
            ],

            // Поле Повторений / Времени
            Expanded(
              child: ro
                  ? _readOnlyBox(theme, text: widget.initialReps != null ? '${widget.initialReps} $repsSuffix' : '— $repsHint')
                  : TextField(
                      controller: _repsController,
                      focusNode: _repsFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: repsHint,
                        suffixText: repsSuffix,
                        suffixStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      onChanged: (_) => _notifyChanged(),
                    ),
            ),
            const SizedBox(width: 8),

            // Кнопка завершения подхода
            GestureDetector(
              onTap: ro ? null : _toggleComplete,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _completed ? theme.colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _completed
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: _completed
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyBox(ThemeData theme, {required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
// ═══ ФАЙЛ set_row.dart ЗАВЕРШЁН ═══