import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/daily_challenge.dart';
import '../../data/challenge_data.dart';
import '../../services/challenge_service.dart';
import '../../services/database_helper.dart';

class TimerChallengeScreen extends StatefulWidget {
  final int profileId;
  final DailyChallenge challenge;

  const TimerChallengeScreen({super.key, required this.profileId, required this.challenge});

  @override
  State<TimerChallengeScreen> createState() => _TimerChallengeScreenState();
}

class _TimerChallengeScreenState extends State<TimerChallengeScreen> with WidgetsBindingObserver {
  static const int _checkWindowSeconds = 5;
  static const int _upgradeBonusSeconds = 120;   // +2 минуты за шаг
  static const int _upgradeBonusReward = 15;     // доп. энергия за легенду

  late int _targetSeconds;
  late bool _isCompleted;

  late int _accumulatedSeconds;
  int _todayAttempts = 0;

  bool _isRunning = false;
  bool _isFinished = false;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Timer? _nextCheckTimer;

  bool _checkActive = false;
  int _checkCountdown = 0;
  Timer? _checkTimer;

  int _lastAttemptSeconds = 0;
  int _lastAttemptTotal = 0;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _targetSeconds = widget.challenge.targetValue;
    _isCompleted = widget.challenge.isCompleted;
    _accumulatedSeconds = widget.challenge.currentProgress.clamp(0, _targetSeconds);
    _isFinished = _isCompleted || _accumulatedSeconds >= _targetSeconds;
    _loadTodayAttempts();
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
    if (state == AppLifecycleState.paused && _isRunning && !_isFinished) {
      _handleAttemptEnd('Нельзя сворачивать приложение во время планки');
    }
  }

  // Проверяем, находимся ли мы в режиме легенды (цель выше базовой)
  bool get _isUpgradedLevel {
    try {
      final cfg = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
      return _targetSeconds > cfg.baseTarget;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadTodayAttempts() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'daily_challenges',
      columns: ['attemptsCount'],
      where: 'id = ?',
      whereArgs: [widget.challenge.id],
      limit: 1,
    );
    if (rows.isNotEmpty && mounted) {
      setState(() {
        _todayAttempts = (rows.first['attemptsCount'] as int?) ?? 0;
      });
    }
  }

  int get _currentAttemptSeconds => _stopwatch.elapsed.inSeconds;
  int get _totalSeconds => _accumulatedSeconds + _currentAttemptSeconds;
  double get _progress => (_totalSeconds / _targetSeconds).clamp(0.0, 1.0);

  Future<void> _start() async {
    if (_isFinished || _isRunning) return;

    WakelockPlus.enable();
    HapticFeedback.mediumImpact();

    _stopwatch.reset();
    _stopwatch.start();

    setState(() => _isRunning = true);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {});
      if (_totalSeconds >= _targetSeconds && !_isFinished) {
        _handleAttemptEnd(null);
      }
    });

    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    if (!_isRunning || _isFinished) return;
    _nextCheckTimer?.cancel();
    final baseSeconds = _currentAttemptSeconds == 0 ? 15 : 20;
    final extra = _random.nextInt(10);
    _nextCheckTimer = Timer(Duration(seconds: baseSeconds + extra), _triggerCheck);
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
        _handleAttemptEnd('Пропустил проверку');
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

  Future<void> _handleAttemptEnd(String? failReason) async {
    if (!_isRunning) return;

    _ticker?.cancel();
    _nextCheckTimer?.cancel();
    _checkTimer?.cancel();
    _stopwatch.stop();
    WakelockPlus.disable();

    final attemptSecs = _currentAttemptSeconds;
    final newTotal = _accumulatedSeconds + attemptSecs;
    final reachedTarget = newTotal >= _targetSeconds;
    final attemptCounted = attemptSecs > 0;

    if (attemptCounted) _todayAttempts++;

    final newAccumulated = reachedTarget ? _targetSeconds : newTotal;

    setState(() {
      _isRunning = false;
      _checkActive = false;
      _checkCountdown = 0;
      _accumulatedSeconds = newAccumulated;
      _lastAttemptSeconds = attemptSecs;
      _lastAttemptTotal = newAccumulated;
      if (reachedTarget) _isFinished = true;
    });

    _stopwatch.reset();

    if (attemptCounted || reachedTarget) {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'daily_challenges',
        {
          'currentProgress': newAccumulated,
          'isCompleted': reachedTarget ? 1 : 0,
          'attemptsCount': _todayAttempts,
        },
        where: 'id = ?',
        whereArgs: [widget.challenge.id],
      );
    }

    if (!mounted) return;

    if (reachedTarget) {
      await _awardAndShowDialog(attemptSecs: attemptSecs);
      return;
    }

    if (attemptCounted && failReason != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$failReason\n'
                'За попытку: ${_formatTime(attemptSecs)}. '
                'Всего: ${_formatTime(newAccumulated)} / ${_formatTime(_targetSeconds)}',
          ),
          backgroundColor: const Color(0xFFE17055),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _awardAndShowDialog({required int attemptSecs}) async {
    final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
    final isUpgraded = _isUpgradedLevel;
    final madeStepAtOnce = attemptSecs >= _upgradeBonusSeconds;

    // 1. Всю ТЕКУЩУЮ цель сделал за ОДИН подход → предложить новый апгрейд
    if (attemptSecs >= _targetSeconds) {
      await _offerUpgrade(config, isLegend: isUpgraded);
      return;
    }

    // 2. В режиме легенды доделал шаг (+2 мин) за раз → легенда засчитана
    if (isUpgraded && madeStepAtOnce) {
      await _awardLegend(config);
      return;
    }

    // 3. Обычное завершение (или набрал подходами)
    final granted = await ChallengeService.tryAwardReward(
      profileId: widget.profileId,
      challengeId: widget.challenge.id!,
      energyAmount: config.energyReward,
    );
    if (!mounted) return;
    _showCompletionDialog(granted, config.energyReward, isUpgraded: isUpgraded);
  }

  Future<void> _awardLegend(ChallengeConfig config) async {
    final amount = config.energyReward + _upgradeBonusReward;
    final granted = await ChallengeService.tryAwardReward(
      profileId: widget.profileId,
      challengeId: widget.challenge.id!,
      energyAmount: amount,
    );
    if (!mounted) return;
    _showLegendDialog(granted, amount);
  }

  Future<void> _offerUpgrade(ChallengeConfig config, {required bool isLegend}) async {
    final upgraded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          isLegend ? '🏆 ЛЕГЕНДА ПРОДОЛЖАЕТСЯ!' : '🔥 ВАУ! ЛЕГЕНДА!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧘', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              '${_formatTime(_targetSeconds)} за ОДИН подход!',
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
              'Новая цель: ${_formatTime(_targetSeconds + _upgradeBonusSeconds)} навсегда. '
                  'Награда за легенду: ${config.energyReward + _upgradeBonusReward} ⚡️.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Оставить ${_formatTime(_targetSeconds)}'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE17055),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'ПОДНЯТЬ ДО ${_formatTime(_targetSeconds + _upgradeBonusSeconds)} 🔥',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (upgraded == true) {
      final newTarget = _targetSeconds + _upgradeBonusSeconds;
      await _saveTarget(newTarget);
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'daily_challenges',
        {'targetValue': newTarget, 'isCompleted': 0},
        where: 'id = ?',
        whereArgs: [widget.challenge.id],
      );

      if (!mounted) return;
      setState(() {
        _targetSeconds = newTarget;
        _isCompleted = false;
        _isFinished = false;
        _lastAttemptSeconds = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔥 Новая цель: ${_formatTime(newTarget)}. '
                'Сделай ${_formatTime(_upgradeBonusSeconds)} без перерыва!',
          ),
          backgroundColor: const Color(0xFFE17055),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      final reward = isLegend
          ? config.energyReward + _upgradeBonusReward
          : config.energyReward;
      final granted = await ChallengeService.tryAwardReward(
        profileId: widget.profileId,
        challengeId: widget.challenge.id!,
        energyAmount: reward,
      );
      if (!mounted) return;
      if (isLegend) {
        _showLegendDialog(granted, reward);
      } else {
        _showCompletionDialog(granted, reward);
      }
    }
  }

  Future<void> _saveTarget(int newTarget) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'challenge_target_${widget.profileId}_${widget.challenge.taskId}';
    final current = prefs.getInt(key) ?? 0;
    if (newTarget > current) {
      await prefs.setInt(key, newTarget);
    }
  }

  void _showCompletionDialog(bool granted, int reward, {bool isUpgraded = false}) {
    final attemptsLine = _todayAttempts > 0
        ? '\n\nПонадобилось: ${_pluralAttempts(_todayAttempts)}.'
        : '';

    final upgradedHint = isUpgraded
        ? '\n\nЦель повышена до ${_formatTime(_targetSeconds)}, '
        'но шаг ${_formatTime(_upgradeBonusSeconds)} не был сделан за раз — '
        'легенда не засчитана.'
        : '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🎉 Планка на сегодня закрыта!', textAlign: TextAlign.center),
        content: Text(
          granted
              ? 'Ты набрал ${_formatTime(_targetSeconds)} планки за день!$attemptsLine\n\n+$reward ⚡️ Жизненной Энергии.\n\n🌿 Загляни в свой Сад Феи — там расцвел новый цветок! 🌸'
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

  void _showLegendDialog(bool granted, int reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('🏆 ЛЕГЕНДА!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧘', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 12),
            Text(
              '${_formatTime(_targetSeconds)} планки!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _todayAttempts > 0 ? 'Понадобилось: ${_pluralAttempts(_todayAttempts)}.' : '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              granted
                  ? 'Ты поднял планку на новый уровень!\n\n+$reward ⚡️ Жизненной Энергии.\n\n'
                  '🔥 Следующая цель: ${_formatTime(_targetSeconds + _upgradeBonusSeconds)}'
                  : 'Награда уже была получена ранее.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: granted ? const Color(0xFF00B894) : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B894),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Забрать награду', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _pluralAttempts(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    String word;
    if (mod10 == 1 && mod100 != 11) {
      word = 'подход';
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      word = 'подхода';
    } else {
      word = 'подходов';
    }
    return '$n $word';
  }

  @override
  Widget build(BuildContext context) {
    final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);

    return Scaffold(
      appBar: AppBar(
        title: Text(config.title),
        actions: [
          if (_isUpgradedLevel)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE17055), Color(0xFFFDCB6E)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '🏆 ЛЕГЕНДА',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
        : _isUpgradedLevel
        ? const Color(0xFFE17055)
        : Colors.deepPurple;

    final secondsToShow = _isCompleted ? _targetSeconds : _totalSeconds;

    return Column(
      children: [
        SizedBox(
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
        ),
        const SizedBox(height: 12),
        if (_isRunning)
          Text(
            'Текущая попытка: ${_formatTime(_currentAttemptSeconds)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE17055),
            ),
          ),
      ],
    );
  }

  Widget _buildHint() {
    if (_isCompleted) {
      return Text(
        _todayAttempts > 0
            ? 'Цель достигнута за ${_pluralAttempts(_todayAttempts)}! 🏆'
            : 'Цель на день достигнута! 🏆',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
    final attemptsSuffix = _todayAttempts > 0
        ? ' за ${_pluralAttempts(_todayAttempts)}'
        : '';

    if (_isUpgradedLevel) {
      final needMore = _targetSeconds - _accumulatedSeconds;
      return Column(
        children: [
          const Text(
            '🔥 Режим легенды',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE17055),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Сделай ${_formatTime(_upgradeBonusSeconds)} без перерыва за один заход, '
                'или добери до цели подходами.\n'
                'Осталось: ${_formatTime(needMore)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          _accumulatedSeconds > 0
              ? 'Продолжай! Уже набрано ${_formatTime(_accumulatedSeconds)} из ${_formatTime(_targetSeconds)}$attemptsSuffix.'
              : 'Прими упор на локти и носки.\nМожно делать подходами — время суммируется за день.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
        ),
        if (_lastAttemptSeconds > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Последняя попытка: ${_formatTime(_lastAttemptSeconds)} '
                '(всего ${_formatTime(_lastAttemptTotal)})',
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
            Text('Цель достигнута', style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    if (_isRunning) {
      return TextButton.icon(
        onPressed: () => _handleAttemptEnd('Ты остановился'),
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('Стоп (прогресс сохранится)'),
        style: TextButton.styleFrom(foregroundColor: Colors.grey),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(_accumulatedSeconds > 0 ? 'Продолжить планку' : 'Начать планку'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: _isUpgradedLevel ? const Color(0xFFE17055) : Colors.deepPurple,
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