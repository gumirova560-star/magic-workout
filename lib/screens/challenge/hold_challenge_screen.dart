import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/daily_challenge.dart';
import '../../data/challenge_data.dart';
import '../../services/challenge_service.dart';
import '../../services/database_helper.dart';

class HoldChallengeScreen extends StatefulWidget {
  final int profileId;
  final DailyChallenge challenge;

  const HoldChallengeScreen({super.key, required this.profileId, required this.challenge});

  @override
  State<HoldChallengeScreen> createState() => _HoldChallengeScreenState();
}

class _HoldChallengeScreenState extends State<HoldChallengeScreen> {
  static const int _upgradeBonusSeconds = 30;

  late int _targetSeconds;
  late bool _isCompleted;

  bool _isLegendPhase = false;
  bool _isHolding = false;
  int _lastAttemptSeconds = 0;
  int _legendStartSeconds = 0; // С какого времени начался легендарный заход

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _targetSeconds = widget.challenge.targetValue;
    _isCompleted = widget.challenge.isCompleted;

    final cfg = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
    if (_targetSeconds > cfg.baseTarget) {
      _isLegendPhase = true;
      _legendStartSeconds = cfg.baseTarget;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  bool get _isUpgradedLevel {
    try {
      final cfg = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
      return _targetSeconds > cfg.baseTarget;
    } catch (_) {
      return false;
    }
  }

  int get _currentAttemptSeconds => _stopwatch.elapsed.inSeconds;

  // В легенде показываем 30..60, в базе 0..30
  int get _displaySeconds => _isLegendPhase ? (_legendStartSeconds + _currentAttemptSeconds) : _currentAttemptSeconds;
  double get _progress => (_displaySeconds / _targetSeconds).clamp(0.0, 1.0);

  void _onPointerDown(PointerDownEvent _) {
    if (_isCompleted || _isHolding) return;
    HapticFeedback.mediumImpact();
    setState(() => _isHolding = true);
    _stopwatch.reset();
    _stopwatch.start();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {});
      if (_displaySeconds >= _targetSeconds) _completeChallenge();
    });
  }

  void _onPointerUp(PointerUpEvent _) => _handleRelease();
  void _onPointerCancel(PointerCancelEvent _) => _handleRelease();

  void _handleRelease() {
    if (!_isHolding) return;
    _stopwatch.stop();
    _ticker?.cancel();

    final reached = _displaySeconds;
    setState(() {
      _isHolding = false;
      _lastAttemptSeconds = _currentAttemptSeconds;
    });
    _stopwatch.reset();

    if (reached < _targetSeconds && mounted) {
      HapticFeedback.heavyImpact();

      if (_isLegendPhase) {
        // Отпустил в легенде - даем новый цветок
        _awardNormalAndFinish();
      } else {
        // Базовая фаза - просто сброс
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Отпустил на $reached сек. Нужно $_targetSeconds секунд подряд. Попробуй снова!'),
            backgroundColor: const Color(0xFFE17055),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _completeChallenge() async {
    if (_isCompleted) return;
    _ticker?.cancel();
    _stopwatch.stop();
    HapticFeedback.heavyImpact();

    setState(() {
      _isHolding = false;
      _isCompleted = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (_isLegendPhase) {
      _awardLegend();
    } else {
      await _offerUpgrade();
    }
  }

  Future<void> _offerUpgrade() async {
    final newTarget = _targetSeconds + _upgradeBonusSeconds;

    final upgrade = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🔥 ВАУ! ЛЕГЕНДА!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ты продержался $_targetSeconds секунд!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Поднять планку ещё выше? 🔥',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Новая цель: $newTarget секунд.\nЕсли выдержишь — 🌟 ЗОЛОТОЙ ЦВЕТОК!\nЕсли отпустишь — просто новый.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Оставить как есть'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE17055),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ПОДНЯТЬ ПЛАНКУ 🔥', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (upgrade == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('challenge_target_${widget.profileId}_${widget.challenge.taskId}', newTarget);

      final db = await DatabaseHelper.instance.database;
      await db.update(
        'daily_challenges',
        {'targetValue': newTarget, 'isCompleted': 0},
        where: 'id = ?',
        whereArgs: [widget.challenge.id],
      );

      if (!mounted) return;
      setState(() {
        _isLegendPhase = true;
        _legendStartSeconds = _targetSeconds; // Например, 30
        _targetSeconds = newTarget; // 60
        _isCompleted = false;
        _lastAttemptSeconds = 0;
      });
    } else {
      await ChallengeService.updateProgress(widget.challenge.id!, _targetSeconds);
      final granted = await ChallengeService.tryAwardReward(
        profileId: widget.profileId,
        challengeId: widget.challenge.id!,
        isLegendary: false,
      );

      if (!mounted) return;
      _showCompletionDialog(granted, isGold: false);
    }
  }

  Future<void> _awardNormalAndFinish() async {
    await ChallengeService.updateProgress(widget.challenge.id!, _targetSeconds);
    final granted = await ChallengeService.tryAwardReward(
      profileId: widget.profileId,
      challengeId: widget.challenge.id!,
      isLegendary: false,
    );

    if (!mounted) return;
    setState(() => _isCompleted = true);
    _showCompletionDialog(granted, isGold: false, wasLegendAttempt: true);
  }

  Future<void> _awardLegend() async {
    await ChallengeService.updateProgress(widget.challenge.id!, _targetSeconds);
    final granted = await ChallengeService.tryAwardReward(
      profileId: widget.profileId,
      challengeId: widget.challenge.id!,
      isLegendary: true,
    );

    if (!mounted) return;
    _showCompletionDialog(granted, isGold: true);
  }

  void _showCompletionDialog(bool granted, {required bool isGold, bool wasLegendAttempt = false}) {
    String message;
    if (granted) {
      if (isGold) {
        message = 'Ты продержался $_targetSeconds секунд без перерыва!\n\n🌟 В твоем Саду Феи расцвел ЗОЛОТОЙ цветок!\n⚡️ Начислено +15 энергии!';
      } else if (wasLegendAttempt) {
        message = 'Ты не достоял до $_targetSeconds секунд в легенде, но базовую цель выполнил!\n\n🌸 В твоем Саду Феи расцвел новый цветок.\n⚡️ Начислено +15 энергии!';
      } else {
        message = 'Ты продержался $_targetSeconds секунд!\n\n🌸 В твоем Саду Феи расцвел новый цветок!\n⚡️ Начислено +15 энергии!';
      }
    } else {
      message = 'Ты уже получал награду за этот челлендж. Но всё равно молодец!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isGold ? '🏆 РЕКОРД ПОБИТ!' : '🎉 Челлендж выполнен!', textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
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
        : _isLegendPhase
        ? const Color(0xFFE17055)
        : Colors.deepPurple;
    final secondsToShow = _isCompleted ? _targetSeconds : _displaySeconds;

    return SizedBox(
      width: 220, height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220, height: 220,
            child: CircularProgressIndicator(
              value: _isCompleted ? 1.0 : _progress, strokeWidth: 12,
              backgroundColor: accent.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$secondsToShow', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: accent, height: 1)),
              const SizedBox(height: 4),
              Text('из $_targetSeconds сек', style: TextStyle(fontSize: 14, color: accent.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    if (_isCompleted) return const Text('Ты справился! 💪', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center);

    if (_isHolding) {
      if (_isLegendPhase) {
        final needMore = _targetSeconds - _displaySeconds;
        return Text(
          'Держи! Осталось $needMore сек до золота 🌟',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFE17055)),
          textAlign: TextAlign.center,
        );
      }
      return const Text('Держи! Не отпускай до конца 🧘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFE17055)), textAlign: TextAlign.center);
    }

    if (_isLegendPhase) {
      return Column(
        children: [
          const Text('🔥 Режим легенды', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFE17055))),
          const SizedBox(height: 8),
          Text(
            'Достой $_targetSeconds секунд без перерыва.\nЕсли отпустишь — получишь новый цветок.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
          ),
        ],
      );
    }

    return Column(
      children: [
        const Text('Прижми и удерживай палец в круге\nдо конца таймера', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.4)),
        if (_lastAttemptSeconds > 0) ...[
          const SizedBox(height: 8),
          Text('Предыдущая попытка: $_lastAttemptSeconds сек', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ],
    );
  }

  Widget _buildHoldArea() {
    final accent = _isCompleted
        ? const Color(0xFF00B894)
        : _isHolding
        ? const Color(0xFFE17055)
        : _isLegendPhase
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
          color: _isHolding ? accent.withValues(alpha: 0.9) : _isCompleted ? accent.withValues(alpha: 0.15) : accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent, width: _isHolding ? 3 : 2),
          boxShadow: _isHolding ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))] : null,
        ),
        child: Column(
          children: [
            Icon(_isCompleted ? Icons.check_circle_rounded : _isHolding ? Icons.touch_app_rounded : Icons.fingerprint_rounded, size: 48, color: _isHolding ? Colors.white : accent),
            const SizedBox(height: 12),
            Text(_isCompleted ? 'Выполнено' : _isHolding ? 'Не отпускай!' : _isLegendPhase ? 'Держи до золота' : 'Держи здесь', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _isHolding ? Colors.white : accent)),
          ],
        ),
      ),
    );
  }
}