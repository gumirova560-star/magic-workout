import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/daily_challenge.dart';
import '../../data/challenge_data.dart';
import '../../services/challenge_service.dart';

class HoldChallengeScreen extends StatefulWidget {
  final int profileId;
  final DailyChallenge challenge;

  const HoldChallengeScreen({super.key, required this.profileId, required this.challenge});

  @override
  State<HoldChallengeScreen> createState() => _HoldChallengeScreenState();
}

class _HoldChallengeScreenState extends State<HoldChallengeScreen> {
  late final int _targetSeconds;
  late bool _isCompleted;

  bool _isHolding = false;
  int _lastAttemptSeconds = 0;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _targetSeconds = widget.challenge.targetValue;
    _isCompleted = widget.challenge.isCompleted;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  int get _currentSeconds => _stopwatch.elapsed.inSeconds;
  double get _progress => (_currentSeconds / _targetSeconds).clamp(0.0, 1.0);

  void _onPointerDown(PointerDownEvent _) {
    if (_isCompleted || _isHolding) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isHolding = true;
    });

    _stopwatch.reset();
    _stopwatch.start();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {}); // обновляем UI

      if (_currentSeconds >= _targetSeconds) {
        _completeChallenge();
      }
    });
  }

  void _onPointerUp(PointerUpEvent _) => _handleRelease();

  void _onPointerCancel(PointerCancelEvent _) => _handleRelease();

  void _handleRelease() {
    if (!_isHolding) return;

    _stopwatch.stop();
    _ticker?.cancel();

    final reached = _currentSeconds;
    setState(() {
      _isHolding = false;
      _lastAttemptSeconds = reached;
    });

    _stopwatch.reset();

    if (reached < _targetSeconds && mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Отпустил на $reached сек. Нужно $_targetSeconds секунд подряд. Попробуй снова!',
          ),
          backgroundColor: const Color(0xFFE17055),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _completeChallenge() async {
    if (_isCompleted) return;

    _ticker?.cancel();
    _stopwatch.stop();

    setState(() {
      _isHolding = false;
      _isCompleted = true;
    });

    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));

    // Сохраняем «выполнено» в БД
    await ChallengeService.updateProgress(widget.challenge.id!, _targetSeconds);

    // Начисляем энергию (с защитой от дублей)
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
        title: const Text('🎉 Челлендж выполнен!', textAlign: TextAlign.center),
        content: Text(
          granted
              ? 'Ты продержался $_targetSeconds секунд!\n\n+$reward ⚡️ Жизненной Энергии.'
              : 'Ты уже получал награду за этот челлендж. Но всё равно молодец!',
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              _buildTimerCircle(config),
              const SizedBox(height: 24),
              _buildHint(),
              const Spacer(),
              _buildHoldArea(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerCircle(ChallengeConfig config) {
    final accent = _isCompleted
        ? const Color(0xFF00B894)
        : _isHolding
        ? const Color(0xFFE17055)
        : Colors.deepPurple;

    final secondsToShow = _isCompleted ? _targetSeconds : _currentSeconds;

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: _isCompleted ? 1.0 : _progress,
              strokeWidth: 12,
              backgroundColor: accent.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$secondsToShow',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'из $_targetSeconds сек',
                style: TextStyle(fontSize: 14, color: accent.withOpacity(0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    if (_isCompleted) {
      return const Text(
        'Ты справился! 💪',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      );
    }
    if (_isHolding) {
      return const Text(
        'Держи! Не отпускай до конца 🧘',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE17055),
        ),
        textAlign: TextAlign.center,
      );
    }
    return Column(
      children: [
        const Text(
          'Прижми и удерживай палец в круге\nдо конца таймера',
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

  Widget _buildHoldArea() {
    final accent = _isCompleted
        ? const Color(0xFF00B894)
        : _isHolding
        ? const Color(0xFFE17055)
        : Colors.deepPurple;

    return Listener(
      onPointerDown: _isCompleted ? null : _onPointerDown,
      onPointerUp: _isCompleted ? null : _onPointerUp,
      onPointerCancel: _isCompleted ? null : _onPointerCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: _isHolding
              ? accent.withOpacity(0.9)
              : _isCompleted
              ? accent.withOpacity(0.15)
              : accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accent,
            width: _isHolding ? 3 : 2,
          ),
          boxShadow: _isHolding
              ? [
            BoxShadow(
              color: accent.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              _isCompleted
                  ? Icons.check_circle_rounded
                  : _isHolding
                  ? Icons.touch_app_rounded
                  : Icons.fingerprint_rounded,
              size: 48,
              color: _isHolding ? Colors.white : accent,
            ),
            const SizedBox(height: 12),
            Text(
              _isCompleted
                  ? 'Выполнено'
                  : _isHolding
                  ? 'Не отпускай!'
                  : 'Держи здесь',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _isHolding ? Colors.white : accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}