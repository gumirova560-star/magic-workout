import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ⚠️ Для вибрации

class RestTimer extends StatefulWidget {
  final int seconds;
  final VoidCallback onFinished;
  final VoidCallback? onSkip;

  const RestTimer({
    super.key,
    required this.seconds,
    required this.onFinished,
    this.onSkip,
  });

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (_remaining > 0) {
        setState(() => _remaining--);

        // ⚠️ Вибрация за 3 и 1 секунду до конца
        if (_remaining == 3 || _remaining == 1) {
          HapticFeedback.mediumImpact();
        }
      } else {
        t.cancel();
        HapticFeedback.heavyImpact(); // ⚠️ Вибрация в конце
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.seconds > 0 ? _remaining / widget.seconds : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  color: const Color(0xFF6C5CE7),
                ),
              ),
              Text(
                '$_remaining',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Отдых',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 16),
            ),
          ),
          if (widget.onSkip != null)
            TextButton(
              onPressed: () {
                _timer?.cancel();
                widget.onSkip!();
              },
              child: const Text('Пропустить'),
            ),
        ],
      ),
    );
  }
}