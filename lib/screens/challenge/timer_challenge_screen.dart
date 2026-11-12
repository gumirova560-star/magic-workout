import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/daily_challenge.dart';
import '../../data/challenge_data.dart';
import '../../services/challenge_service.dart';

class TimerChallengeScreen extends StatefulWidget {
  final int profileId;
  final DailyChallenge challenge;

  const TimerChallengeScreen({super.key, required this.profileId, required this.challenge});

  @override
  State<TimerChallengeScreen> createState() => _TimerChallengeScreenState();
}

class _TimerChallengeScreenState extends State<TimerChallengeScreen> with WidgetsBindingObserver {
  static const int _checkWindowSeconds = 5;

  late final int _targetSeconds;
  late bool _isCompleted;

  bool _isRunning = false;
  bool _isFinished = false;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Timer? _nextCheckTimer;

  bool _checkActive = false;
  int _checkCountdown = 0;
  Timer? _checkTimer;

  int _lastAttemptSeconds = 0;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _targetSeconds = widget.challenge.targetValue;
    _isCompleted = widget.challenge.isCompleted;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _nextCheckTimer?.cancel();
    _checkTimer?.cancel();
    _stopwatch.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Если пользователь свернул приложение во время планки — провал
    if (state == AppLifecycleState.paused && _isRunning && !_isFinished) {
      _failAttempt('Нельзя сворачивать приложение во время планки');
    }
  }

  int get _currentSeconds => _stopwatch.elapsed.inSeconds;
  double get _progress => (_currentSeconds / _targetSeconds).clamp(0.0, 1.0);

  Future<void> _start() async {
    if (_isCompleted) return;

    WakelockPlus.enable();
    HapticFeedback.mediumImpact();

    _stopwatch.reset();
    _stopwatch.start();

    setState(() {
      _isRunning = true;
      _isFinished = false;
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {});
      if (_currentSeconds >= _targetSeconds && !_isFinished) {
        _complete();
      }
    });

    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    if (!_isRunning || _isFinished) return;
    _nextCheckTimer?.cancel();

    // Первая проверка через 15-25 сек, потом каждые 20-40 сек
    final baseSeconds = _currentSeconds == 0 ? 15 : 20;
    final extra = _random.nextInt(10);
    final delay = Duration(seconds: baseSeconds + extra);

    _nextCheckTimer = Timer(delay, _triggerCheck);
  }

  void _triggerCheck() {
    if (!_isRunning || _isFinished) return;

    HapticFeedback.heavyImpact();
    setState(() {
      _checkActive = true;
      _checkCountdown = _checkWindowSeconds;
    });

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _checkCountdown--);
      if (_checkCountdown <= 0) {
        _failAttempt('Пропустил проверку. Попробуй снова!');
      }
    });
  }

  void _onCheckConfirmed() {
    if (!_checkActive) return;
    _checkTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() {
      _checkActive = false;
      _checkCountdown = 0;
    });
    _scheduleNextCheck();
  }

  Future<void> _failAttempt(String reason) async {
    if (_isFinished) return;

    _ticker?.cancel();
    _nextCheckTimer?.cancel();
    _checkTimer?.cancel();
    _stopwatch.stop();

    _lastAttemptSeconds = _currentSeconds;
    _stopwatch.reset();

    HapticFeedback.heavyImpact();

    setState(() {
      _isRunning = false;
      _checkActive = false;
      _checkCountdown = 0;
    });

    WakelockPlus.disable();

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason),
        backgroundColor: const Color(0xFFE17055),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _complete() async {
    if (_isFinished) return;

    _ticker?.cancel();
    _nextCheckTimer?.cancel();
    _checkTimer?.cancel();
    _stopwatch.stop();

    final seconds = _currentSeconds;
    setState(() {
      _isRunning = false;
      _isFinished = true;
      _isCompleted = true;
    });

    HapticFeedback.heavyImpact();
    WakelockPlus.disable();

    await ChallengeService.updateProgress(widget.challenge.id!, max(seconds, _targetSeconds));

    final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
    final granted = await ChallengeService.tryAwardReward(
      profileId: widget.profileId,
      challengeId: widget.challenge.id!,
      energyAmount: config.energyReward,
    );

    if (!mounted) return;
    _showCompletionDialog(granted, config.energyReward);
  }

  void _showCompletionDialog(bool granted, int reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🎉 Планка выполнена!', textAlign: TextAlign.center),
        content: Text(
          granted
              ? 'Ты держал планку $_targetSeconds секунд!\n\n+$reward ⚡️ Жизненной Энергии.'
              : 'Ты уже получал награду за этот челлендж.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Забрать награду'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);

    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Spacer(),
                  _buildTimerCircle(),
                  const SizedBox(height: 24),
                  _buildHint(),
                  const Spacer(),
                  _buildActionButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (_checkActive) _buildCheckOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCircle() {
    final accent = _isCompleted
        ? const Color(0xFF00B894)
        : _isRunning
        ? const Color(0xFFE17055)
        : Colors.deepPurple;

    final secondsToShow = _isCompleted ? _targetSeconds : _currentSeconds;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: CircularProgressIndicator(
              value: _isCompleted ? 1.0 : _progress,
              strokeWidth: 14,
              backgroundColor: accent.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(secondsToShow),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'из ${_formatTime(_targetSeconds)}',
                style: TextStyle(fontSize: 14, color: accent.withOpacity(0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(1, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildHint() {
    if (_isCompleted) {
      return const Text(
        'Ты справился! 🏆',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      );
    }
    if (_isRunning) {
      return const Column(
        children: [
          Text(
            'Держи планку!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFE17055)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'В случайный момент приложение провибрирует.\nНажми "Я держу!" за 5 секунд.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
        ],
      );
    }
    return Column(
      children: [
        const Text(
          'Прими упор на локти и носки.\nТело — прямая линия.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.4),
        ),
        if (_lastAttemptSeconds > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Предыдущая попытка: $_lastAttemptSeconds сек',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton() {
    if (_isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        decoration: BoxDecoration(
          color: const Color(0xFF00B894).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00B894)),
            SizedBox(width: 8),
            Text('Выполнено', style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    if (_isRunning) {
      return TextButton.icon(
        onPressed: () => _failAttempt('Ты прервал попытку'),
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('Прервать'),
        style: TextButton.styleFrom(foregroundColor: Colors.grey),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Начать планку'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCheckOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⏱ Проверка!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _checkCountdown.toString(),
                style: const TextStyle(
                  color: Color(0xFFE17055),
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ты ещё держишь?',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _onCheckConfirmed,
                icon: const Icon(Icons.check_rounded, size: 28),
                label: const Text('Я ДЕРЖУ!'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  backgroundColor: const Color(0xFF00B894),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}