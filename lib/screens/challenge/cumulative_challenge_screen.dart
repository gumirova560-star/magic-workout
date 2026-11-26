import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/daily_challenge.dart';
import '../../data/challenge_data.dart';
import '../../services/challenge_service.dart';
import '../../services/energy_service.dart'; // 👈 ДОБАВЛЕНО ДЛЯ БОНУСА

class CumulativeChallengeScreen extends StatefulWidget {
  final int profileId;
  final DailyChallenge challenge;

  const CumulativeChallengeScreen({super.key, required this.profileId, required this.challenge});

  @override
  State<CumulativeChallengeScreen> createState() => _CumulativeChallengeScreenState();
}

class _CumulativeChallengeScreenState extends State<CumulativeChallengeScreen> {
  static const int _pauseSeconds = 15;

  late int _currentProgress;
  late int _targetValue;
  bool _isCompleted = false;

  Timer? _pauseTimer;
  int _pauseLeft = 0;

  String get _pauseKey => 'challenge_${widget.challenge.id}_lastTapMs';

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.challenge.currentProgress;
    _targetValue = widget.challenge.targetValue;
    _isCompleted = widget.challenge.isCompleted;
    _restorePause();
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    super.dispose();
  }

  Future<void> _restorePause() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_pauseKey);
    if (lastMs == null) return;

    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastMs));
    if (diff.inSeconds >= _pauseSeconds) return;

    final remaining = _pauseSeconds - diff.inSeconds;
    if (!mounted) return;
    setState(() => _pauseLeft = remaining);
    _startPauseTicker();
  }

  void _startPauseTicker() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _pauseLeft--;
        if (_pauseLeft <= 0) {
          _pauseLeft = 0;
          t.cancel();
        }
      });
    });
  }

  Future<void> _addProgress(int amount) async {
    if (_isCompleted) return;
    if (_pauseLeft > 0) return;

    HapticFeedback.lightImpact();

    setState(() {
      _currentProgress += amount;
      if (_currentProgress >= _targetValue) {
        _isCompleted = true;
      }
    });

    await ChallengeService.updateProgress(widget.challenge.id!, _currentProgress);

    if (_isCompleted) {
      await Future.delayed(const Duration(milliseconds: 100));
      await _awardFlower();
    } else {
      await _startPause();
    }
  }

  // 👇 НОВЫЙ МЕТОД: Диалоговое окно ручного ввода
  Future<void> _showManualInputDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Сколько добавить?', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Например: 12',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              Navigator.pop(ctx, val);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await _addProgress(result);
    }
  }

  Future<void> _startPause() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pauseKey, DateTime.now().millisecondsSinceEpoch);

    if (!mounted) return;
    setState(() => _pauseLeft = _pauseSeconds);
    _startPauseTicker();
  }

  // 👇 ИЗМЕНЕНО: Теперь считает перевыполнение и дает бонус
  Future<void> _awardFlower() async {
    final int overshoot = _currentProgress - _targetValue;
    int bonusEnergy = 0;

    if (overshoot > 0) {
      // Даем +1⚡ за каждые 10 повторений сверху, но максимум +10⚡
      bonusEnergy = (overshoot / 10).floor().clamp(0, 10);

      if (bonusEnergy > 0) {
        await EnergyService.addEnergy(
          profileId: widget.profileId,
          delta: bonusEnergy,
          reason: 'challenge_overshoot_bonus', // Уникальная причина
          refId: widget.challenge.id,
        );
      }
    }

    final granted = await ChallengeService.tryAwardReward(
      profileId: widget.profileId,
      challengeId: widget.challenge.id!,
      isLegendary: false,
    );

    if (!mounted) return;
    _showCompletionDialog(granted, bonusEnergy: bonusEnergy, overshoot: overshoot);
  }

  // 👇 ИЗМЕНЕНО: Показывает бонус в диалоговом окне
  void _showCompletionDialog(bool granted, {int bonusEnergy = 0, int overshoot = 0}) {
    String message = 'Ты отлично справился!\n\n🌸 В твоем Саду Феи расцвел новый цветок!\n⚡️ Начислено +15 энергии!';

    if (!granted) {
      message = 'Ты уже получал награду за этот челлендж. Но всё равно молодец!';
    }

    if (overshoot > 0) {
      message += '\n\n🔥 Ого! Ты перевыполнил план на $overshoot повторений!';
      if (bonusEnergy > 0) {
        message += '\n🎁 Бонус за упорство: +$bonusEnergy ⚡!';
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
            overshoot > 0 ? '🏆 РЕКОРД ПОБИТ!' : '🎉 Челлендж выполнен!',
            textAlign: TextAlign.center
        ),
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
    final progressPercent = (_currentProgress / _targetValue).clamp(0.0, 1.0);
    final isPaused = _pauseLeft > 0;

    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('$_currentProgress / $_targetValue ${config.unit}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressPercent,
                minHeight: 20,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                    _isCompleted ? Colors.green : Colors.deepPurple),
              ),
            ),
            const Spacer(),

            if (isPaused) ...[
              Text(
                'Отдых: $_pauseLeft сек',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE17055),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ты только что сделал подход.\nСледующее нажатие — через $_pauseSeconds секунд.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ] else if (!_isCompleted) ...[
              const Text('Добавляй по мере выполнения:',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAddButton(10, enabled: !isPaused),
                  const SizedBox(width: 12),
                  _buildAddButton(15, enabled: !isPaused),
                  const SizedBox(width: 12),
                  _buildAddButton(20, enabled: !isPaused),
                ],
              ),
              const SizedBox(height: 12),
              // 👇 НОВАЯ КНОПКА РУЧНОГО ВВОДА
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isPaused ? null : _showManualInputDialog,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Ввести вручную', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    foregroundColor: Colors.deepPurple,
                    side: BorderSide(
                      color: Colors.deepPurple.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ] else
              const Text('Отдыхай, ты молодец! 🏆',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(int amount, {bool enabled = true}) {
    return Expanded(
      child: ElevatedButton(
        onPressed: enabled ? () => _addProgress(amount) : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor:
          enabled ? Colors.deepPurple.shade50 : Colors.grey.shade200,
          foregroundColor:
          enabled ? Colors.deepPurple : Colors.grey.shade500,
          elevation: 0,
        ),
        child: Text('+$amount',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
// ═══ КОНЕЦ ФАЙЛА CumulativeChallengeScreen ═══