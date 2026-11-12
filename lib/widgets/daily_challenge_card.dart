import 'package:flutter/material.dart';
import '../models/daily_challenge.dart';
import '../data/challenge_data.dart';
import '../services/challenge_service.dart';
import '../screens/challenge/cumulative_challenge_screen.dart';

class DailyChallengeCard extends StatefulWidget {
  final int profileId;

  const DailyChallengeCard({super.key, required this.profileId});

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  DailyChallenge? _challenge;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    try {
      final challenge = await ChallengeService.getTodayChallenge(widget.profileId);
      if (mounted) {
        setState(() {
          _challenge = challenge;
          _loading = false;
        });
      }
    } catch (e) {
      // Защита от вечной загрузки: Если произошла ошибка (например, нет таблицы в БД), скрываем карточку
      debugPrint('Ошибка загрузки челленджа: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _challenge = null;
        });
      }
    }
  }

  void _openChallenge() {
    if (_challenge == null) return;
    final config = kDailyChallenges.firstWhere((c) => c.id == _challenge!.taskId);

    if (config.type == 'cumulative') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CumulativeChallengeScreen(
            profileId: widget.profileId,
            challenge: _challenge!,
          ),
        ),
      ).then((_) => _loadChallenge());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этот тип челленджа мы скоро добавим! 🚧')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    if (_challenge == null) return const SizedBox.shrink();

    final config = kDailyChallenges.firstWhere((c) => c.id == _challenge!.taskId);
    final isDone = _challenge!.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: _openChallenge,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDone
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // 👇 ЗАМЕНА ЭМОДЗИ НА ИКОНКУ
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Челлендж дня',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (isDone)
                      const Text('Выполнено! ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    else
                      Text('Прогресс: ${_challenge!.currentProgress} из ${_challenge!.targetValue}', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              if (!isDone) const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}