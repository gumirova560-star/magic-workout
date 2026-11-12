import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для вибрации
import '../../models/daily_challenge.dart';
import '../../data/challenge_data.dart';
import '../../services/challenge_service.dart';

class CumulativeChallengeScreen extends StatefulWidget {
  final int profileId;
  final DailyChallenge challenge;

  const CumulativeChallengeScreen({super.key, required this.profileId, required this.challenge});

  @override
  State<CumulativeChallengeScreen> createState() => _CumulativeChallengeScreenState();
}

class _CumulativeChallengeScreenState extends State<CumulativeChallengeScreen> {
  late int _currentProgress;
  late int _targetValue;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.challenge.currentProgress;
    _targetValue = widget.challenge.targetValue;
    _isCompleted = widget.challenge.isCompleted;
  }

  Future<void> _addProgress(int amount) async {
    if (_isCompleted) return;

    HapticFeedback.lightImpact(); // Вибрация при нажатии

    setState(() {
      _currentProgress += amount;
      if (_currentProgress >= _targetValue) {
        _isCompleted = true;
      }
    });

    // Сохраняем в БД
    await ChallengeService.updateProgress(widget.challenge.id!, _currentProgress);

    if (_isCompleted) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    // TODO: Здесь потом вызовем EnergyService.addEnergy(config.energyReward)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🎉 Челлендж выполнен!', textAlign: TextAlign.center),
        content: const Text('Ты заработал Жизненную Энергию! ⚡️\nТак держать!', textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Возвращаемся на главный
            },
            child: const Text('Забрать награду'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
    final progressPercent = (_currentProgress / _targetValue).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(config.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            Text('$_currentProgress / $_targetValue ${config.unit}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressPercent,
                minHeight: 20,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_isCompleted ? Colors.green : Colors.deepPurple),
              ),
            ),
            const Spacer(),
            if (!_isCompleted) ...[
              const Text('Добавляй по мере выполнения:', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAddButton(10),
                  const SizedBox(width: 12),
                  _buildAddButton(15),
                  const SizedBox(width: 12),
                  _buildAddButton(20),
                ],
              ),
            ] else
              const Text('Отдыхай, ты молодец! 🏆', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(int amount) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _addProgress(amount),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.deepPurple.shade50,
          foregroundColor: Colors.deepPurple,
          elevation: 0,
        ),
        child: Text('+$amount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }
}