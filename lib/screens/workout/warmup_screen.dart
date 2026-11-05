import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../data/fairy_mood.dart';
import '../../models/stretch.dart';
import '../../models/workout_day.dart';
import 'widgets/set_row.dart';

class WarmupScreen extends StatefulWidget {
  final List<WorkoutExercise> warmups;
  final Map<int, Stretch> stretchMap;
  final Map<int, List<SetData>> setsData;
  final Map<int, List<int>> setIds;
  final bool started;

  const WarmupScreen({
    super.key,
    required this.warmups,
    required this.stretchMap,
    required this.setsData,
    required this.setIds,
    required this.started,
  });

  @override
  State<WarmupScreen> createState() => _WarmupScreenState();
}

class _WarmupScreenState extends State<WarmupScreen> {
  static const int _totalSeconds = 180; // 3 минуты
  static const double _volume = 0.3;

  int _remaining = _totalSeconds;
  bool _running = false;
  bool _paused = false;
  bool _finished = false;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _audioPlayer.setVolume(_volume);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    setState(() { _running = true; _paused = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _paused) return;
      if (_remaining > 1) {
        setState(() => _remaining--);
      } else {
        setState(() { _remaining = 0; _finished = true; _running = false; });
        t.cancel();
        _playSound();
        // небольшая пауза, чтобы звук успел начаться, и возврат
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _close(markDone: true);
        });
      }
    });
  }

  void _togglePause() {
    if (!_running) return;
    setState(() => _paused = !_paused);
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/warmup_done.mp3'));
    } catch (_) {
      // звук не критичен — если не проигрался, просто молчим
    }
  }

  void _skip() => _close(markDone: true);

  void _close({required bool markDone}) {
    Navigator.pop(context, markDone ? _buildUpdatedSets() : null);
  }

  /// Возвращает обновлённую копию setsData с отмеченными разминками.
  Map<int, List<SetData>> _buildUpdatedSets() {
    final updated = <int, List<SetData>>{};
    for (final w in widget.warmups) {
      if (w.id == null) continue;
      final existing = widget.setsData[w.id!];
      if (existing == null || existing.isEmpty) {
        updated[w.id!] = [SetData(completed: true)];
      } else {
        updated[w.id!] = [
          SetData(weight: existing.first.weight, reps: existing.first.reps, completed: true),
          ...existing.skip(1),
        ];
      }
    }
    return updated;
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _totalSeconds > 0 ? _remaining / _totalSeconds : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Разминка')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFairyMessage(context),
          const SizedBox(height: 24),
          _buildCircle(context, progress, theme),
          const SizedBox(height: 20),
          _buildControls(context, theme),
          const SizedBox(height: 28),
          Text('Что делать (в любом порядке):', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          ...widget.warmups.asMap().entries.map((e) {
            final st = widget.stretchMap[e.value.itemId];
            if (st == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${e.key + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFFFB800))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          '${st.durationLabel}${st.bothSides ? " × 2 стороны" : ""}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _skip,
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('Пропустить разминку'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFairyMessage(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFFB800).withOpacity(0.15),
          const Color(0xFFFDCB6E).withOpacity(0.15),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            FairyMood.wink.asset,
            width: 64, height: 64, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department_rounded, size: 48, color: Color(0xFFFFB800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Разминка — важная часть тренировки! 🔥', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Она разогревает суставы и мышцы, снижает риск травм и помогает работать эффективнее. Не пропускай — даже 3 минуты дают большую разницу.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircle(BuildContext context, double progress, ThemeData theme) {
    final color = _finished
        ? const Color(0xFF00B894)
        : _paused
        ? const Color(0xFFFDCB6E)
        : const Color(0xFFFFB800);
    final timeText = _finished ? '✓' : _fmt(_remaining);

    return Center(
      child: SizedBox(
        width: 200, height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200, height: 200,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 12,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeText,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: _finished ? 48 : 42,
                  ),
                ),
                if (_paused && !_finished)
                  Text('⏸ Пауза', style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, ThemeData theme) {
    if (_finished) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _close(markDone: true),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Вернуться к тренировке'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B894),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }
    if (!_running) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Старт'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB800),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _togglePause,
            icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(_paused ? 'Продолжить' : 'Пауза'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
// ═══ ФАЙЛ warmup_screen.dart ЗАВЕРШЁН ═══