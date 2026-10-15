import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/stretch.dart';

/// Экран практики растяжек — БЕЗ сохранения в историю.
///
/// Работает и для одной растяжки, и для серии.
class StretchPracticeScreen extends StatefulWidget {
  final List<Stretch> stretches;

  const StretchPracticeScreen({
    super.key,
    required this.stretches,
  });

  @override
  State<StretchPracticeScreen> createState() => _StretchPracticeScreenState();
}

class _StretchPracticeScreenState extends State<StretchPracticeScreen> {
  int _currentIndex = 0;
  int _remaining = 0;
  bool _playing = false;
  bool _paused = false;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.stretches.isNotEmpty) {
      _remaining = widget.stretches.first.durationSeconds;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _playing = true;
      _paused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_paused) return;

      if (_remaining > 1) {
        setState(() => _remaining--);
      } else {
        _nextStretch();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _playing = false;
      _paused = true;
    });
  }

  void _resumeTimer() {
    _startTimer();
  }

  void _nextStretch() {
    if (_currentIndex >= widget.stretches.length - 1) {
      _timer?.cancel();
      setState(() {
        _playing = false;
        _finished = true;
      });
      return;
    }

    setState(() {
      _currentIndex++;
      _remaining = widget.stretches[_currentIndex].durationSeconds;
    });
    _startTimer();
  }

  void _prevStretch() {
    if (_currentIndex <= 0) return;
    _timer?.cancel();
    setState(() {
      _currentIndex--;
      _remaining = widget.stretches[_currentIndex].durationSeconds;
      _playing = false;
      _paused = true;
    });
  }

  void _skip() {
    _nextStretch();
  }

  void _finishEarly() {
    _timer?.cancel();
    setState(() {
      _playing = false;
      _finished = true;
    });
  }

  String _format(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stretches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Практика')),
        body: const Center(child: Text('Нет растяжек')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.stretches.length == 1
              ? 'Растяжка'
              : 'Серия · ${widget.stretches.length}',
        ),
      ),
      body: _finished
          ? _buildFinished(context)
          : _buildPlayer(context),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final theme = Theme.of(context);
    final stretch = widget.stretches[_currentIndex];
    final total = stretch.durationSeconds;
    final progress = total > 0 ? (total - _remaining) / total : 0.0;

    final circleColor = _paused
        ? const Color(0xFFFDCB6E)
        : const Color(0xFF00B894);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ═══ Прогресс серии ═══
          if (widget.stretches.length > 1) ...[
            Row(
              children: [
                Text(
                  '${_currentIndex + 1} / ${widget.stretches.length}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / widget.stretches.length,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.15),
                    color: theme.colorScheme.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          const Spacer(),

          // ═══ Круговой таймер ═══
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.15),
                    color: circleColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      stretch.category == 'yoga'
                          ? Icons.self_improvement_rounded
                          : Icons.accessibility_new_rounded,
                      size: 40,
                      color: circleColor.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _format(_remaining),
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: 2,
                      ),
                    ),
                    if (_paused)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '⏸ Пауза',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFFDCB6E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ═══ Название позы ═══
          Text(
            stretch.name,
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${stretch.durationLabel}${stretch.bothSides ? " · 2 стороны" : ""}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),

          if (stretch.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                stretch.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const Spacer(),

          // ═══ Кнопки управления ═══
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _currentIndex > 0 ? _prevStretch : null,
                icon: const Icon(Icons.skip_previous_rounded, size: 36),
                color: _currentIndex > 0
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withOpacity(0.2),
              ),

              // ═══ Play/Pause ═══
              GestureDetector(
                onTap: _playing ? _pauseTimer : _resumeTimer,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _paused
                          ? [const Color(0xFFFDCB6E),
                              const Color(0xFFFFEAA7)]
                          : [const Color(0xFF00B894),
                              const Color(0xFF55EFC4)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_paused
                                ? const Color(0xFFFDCB6E)
                                : const Color(0xFF00B894))
                            .withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    _playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              IconButton(
                onPressed: _skip,
                icon: const Icon(Icons.skip_next_rounded, size: 36),
                color: theme.colorScheme.onSurface,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ═══ Завершить ═══
          TextButton.icon(
            onPressed: _finishEarly,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Завершить'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinished(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B894).withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Практика завершена!',
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Отличная работа 🧘',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.done_rounded),
              label: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }
}