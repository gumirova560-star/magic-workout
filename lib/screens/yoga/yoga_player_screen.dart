import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/stretch.dart';
import '../../models/yoga_session.dart';
import '../../services/database_helper.dart';

class YogaPlayerScreen extends StatefulWidget {
  final YogaSession session;

  const YogaPlayerScreen({super.key, required this.session});

  @override
  State<YogaPlayerScreen> createState() => _YogaPlayerScreenState();
}

class _YogaPlayerScreenState extends State<YogaPlayerScreen> {
  List<YogaStep> _steps = [];
  Map<int, Stretch> _stretchMap = {};
  bool _loading = true;

  int _currentIndex = 0;
  int _remaining = 0;
  bool _playing = false;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadSteps();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSteps() async {
    setState(() => _loading = true);
    final steps =
        await DatabaseHelper.instance.getYogaSteps(widget.session.id!);

    final map = <int, Stretch>{};
    for (final step in steps) {
      final st = await DatabaseHelper.instance.getStretchById(step.stretchId);
      if (st != null) map[step.stretchId] = st;
    }

    setState(() {
      _steps = steps;
      _stretchMap = map;
      _loading = false;
      if (steps.isNotEmpty) {
        _remaining = steps.first.durationSeconds;
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _playing = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining > 1) {
        setState(() => _remaining--);
      } else {
        _nextStep();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _playing = false);
  }

  void _nextStep() {
    if (_currentIndex >= _steps.length - 1) {
      _timer?.cancel();
      setState(() {
        _playing = false;
        _finished = true;
      });
      return;
    }

    setState(() {
      _currentIndex++;
      _remaining = _steps[_currentIndex].durationSeconds;
    });
    _startTimer();
  }

  void _prevStep() {
    if (_currentIndex <= 0) return;
    _timer?.cancel();
    setState(() {
      _currentIndex--;
      _remaining = _steps[_currentIndex].durationSeconds;
      _playing = false;
    });
  }

  String _format(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _steps.isEmpty
              ? _buildEmpty(context)
              : _finished
                  ? _buildFinished(context)
                  : _buildPlayer(context, theme),
    );
  }

  Widget _buildPlayer(BuildContext context, ThemeData theme) {
    final step = _steps[_currentIndex];
    final stretch = _stretchMap[step.stretchId];
    final total = step.durationSeconds;
    final progress = total > 0 ? (total - _remaining) / total : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ═══ Прогресс ═══
          Row(
            children: [
              Text(
                '${_currentIndex + 1} / ${_steps.length}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _steps.length,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  color: theme.colorScheme.primary,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),

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
                    color: theme.colorScheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.self_improvement_rounded,
                      size: 40,
                      color: theme.colorScheme.primary.withOpacity(0.6),
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
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ═══ Название позы ═══
          if (stretch != null) ...[
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
            if (step.notes != null && step.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  step.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],

          const Spacer(),

          // ═══ Кнопки ═══
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Назад
              _controlButton(
                context,
                icon: Icons.skip_previous_rounded,
                onTap: _currentIndex > 0 ? _prevStep : null,
              ),

              // Play/Pause
              GestureDetector(
                onTap: _playing ? _pauseTimer : _startTimer,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withOpacity(0.3),
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

              // Вперёд
              _controlButton(
                context,
                icon: Icons.skip_next_rounded,
                onTap: _nextStep,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ═══ Пропустить ═══
          TextButton.icon(
            onPressed: () {
              _timer?.cancel();
              setState(() {
                _playing = false;
                _finished = true;
              });
            },
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Завершить'),
          ),
        ],
      ),
    );
  }

  Widget _controlButton(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 36),
      color: onTap != null
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurface.withOpacity(0.2),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.self_improvement_rounded,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Сессия пуста',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'В этой практике ещё нет упражнений',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
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