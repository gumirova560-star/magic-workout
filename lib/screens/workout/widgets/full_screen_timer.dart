import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullScreenTimer extends StatefulWidget {
  final int seconds;
  final VoidCallback onFinished;

  const FullScreenTimer({
    super.key,
    required this.seconds,
    required this.onFinished,
  });

  @override
  State<FullScreenTimer> createState() => _FullScreenTimerState();
}

class _FullScreenTimerState extends State<FullScreenTimer> {
  late int _remaining;
  Timer? _timer;
  bool _isPaused = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = widget.seconds;
      _isFinished = false;
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _isPaused) return;

      if (_remaining > 0) {
        setState(() => _remaining--);

        if (_remaining == 3 || _remaining == 1) {
          HapticFeedback.mediumImpact();
        }
      } else {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _isFinished = true);
        widget.onFinished();
      }
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _skip() {
    _timer?.cancel();
    widget.onFinished();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.seconds > 0 ? _remaining / widget.seconds : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), // Темный фон
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              const Text(
                'ОТДЫХ',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // ⚠️ Круглый таймер с кнопкой внутри
              SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        color: _isFinished
                            ? const Color(0xFF00B894)
                            : (_remaining <= 3 ? const Color(0xFFE17055) : const Color(0xFF6C5CE7)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),

                    // ⚠️ ВНУТРЕННЕЕ СОДЕРЖИМОЕ
                    if (_isFinished)
                      // Если время вышло — показываем кнопку "Повторить"
                      IconButton(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.replay_rounded),
                        iconSize: 80,
                        color: const Color(0xFF00B894),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF00B894).withOpacity(0.1),
                          padding: const EdgeInsets.all(20),
                        ),
                      )
                    else
                      // Пока идет время — показываем цифры
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_remaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 80,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'сек',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const Spacer(),

              // ⚠️ НИЖНИЕ КНОПКИ (Пауза и Пропустить)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isFinished ? null : _togglePause,
                      icon: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: _isFinished ? Colors.white24 : Colors.white,
                      ),
                      label: Text(
                        _isPaused ? 'Продолжить' : 'Пауза',
                        style: TextStyle(color: _isFinished ? Colors.white24 : Colors.white, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: _isFinished ? Colors.white10 : Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _skip,
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                      label: const Text(
                        'Пропустить',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE17055),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}