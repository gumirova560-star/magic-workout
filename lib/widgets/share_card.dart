import 'package:flutter/material.dart';

enum ShareCardMode { workout, week, cycle, challenge }

class ShareCard extends StatelessWidget {
  final ShareCardMode mode;
  final String userName; // Оставили для совместимости, но больше не используем в тексте
  final String title;
  final int minutes;
  final int exercisesCount;
  final int workoutsCount;
  final int streakWeeks;

  // 👇 НОВЫЕ ПАРАМЕТРЫ ДЛЯ ЧЕЛЛЕНДЖЕЙ
  final String? challengeStat;
  final String? challengeMainStat;
  final String? challengeSubStat;
  final String? challengeTimeStat;

  // 👇 НОВЫЕ ПАРАМЕТРЫ ДЛЯ НЕДЕЛЬ
  final bool isWeekInProgress;
  final int plannedDays;

  const ShareCard({
    super.key,
    required this.mode,
    required this.userName,
    required this.title,
    required this.minutes,
    required this.exercisesCount,
    required this.workoutsCount,
    required this.streakWeeks,
    this.challengeStat,
    this.challengeMainStat,
    this.challengeSubStat,
    this.challengeTimeStat,
    this.isWeekInProgress = false,
    this.plannedDays = 3,
  });

  String get _minutesLabel {
    final n = minutes.abs() % 100;
    if (n >= 11 && n <= 19) return '$minutes минут';
    final i = n % 10;
    if (i == 1) return '$minutes минута';
    if (i >= 2 && i <= 4) return '$minutes минуты';
    return '$minutes минут';
  }

  String get _exercisesLabel {
    final n = exercisesCount.abs() % 100;
    if (n >= 11 && n <= 19) return '$exercisesCount упражнений';
    final i = n % 10;
    if (i == 1) return '$exercisesCount упражнение';
    if (i >= 2 && i <= 4) return '$exercisesCount упражнения';
    return '$exercisesCount упражнений';
  }

  String get _workoutsLabel {
    final n = workoutsCount.abs() % 100;
    if (n >= 11 && n <= 19) return '$workoutsCount тренировок';
    final i = n % 10;
    if (i == 1) return '$workoutsCount тренировка';
    if (i >= 2 && i <= 4) return '$workoutsCount тренировки';
    return '$workoutsCount тренировок';
  }

  String get _streakLabel {
    final n = streakWeeks.abs() % 100;
    if (n >= 11 && n <= 19) return '$streakWeeks недель подряд';
    final i = n % 10;
    if (i == 1) return '$streakWeeks неделя подряд';
    if (i >= 2 && i <= 4) return '$streakWeeks недели подряд';
    return '$streakWeeks недель подряд';
  }

  String get _headline {
    switch (mode) {
      case ShareCardMode.workout: return 'Тренировка завершена!';
      case ShareCardMode.week: return 'Неделя завершена! 🔥';
      case ShareCardMode.cycle: return 'Цикл завершён! 🏆';
      case ShareCardMode.challenge: return 'Челлендж пройден! 🔥';
    }
  }

  String get _subheadline {
    switch (mode) {
      case ShareCardMode.workout: return 'Ещё один шаг к цели';
      case ShareCardMode.week: return 'Отличная работа, продолжай!';
      case ShareCardMode.cycle: return 'Ты прошла весь месяц. Горжусь!';
      case ShareCardMode.challenge: return 'Это было мощно. Настоящий вызов!';
    }
  }

  Color get _accent {
    switch (mode) {
      case ShareCardMode.workout: return const Color(0xFF6C5CE7);
      case ShareCardMode.week: return const Color(0xFF4834D4);
      case ShareCardMode.cycle: return const Color(0xFF8E44AD);
      case ShareCardMode.challenge: return const Color(0xFFFFA000);
    }
  }

  String get _fairyImage {
    switch (mode) {
      case ShareCardMode.workout: return 'assets/fairy/fairy_happy.png';
      case ShareCardMode.week: return 'assets/fairy/fairy_party.png';
      case ShareCardMode.cycle: return 'assets/fairy/fairy_party.png';
      case ShareCardMode.challenge: return 'assets/fairy/fairy_party.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent,
            mode == ShareCardMode.challenge
                ? Color.lerp(_accent, Colors.black, 0.25)!
                : Color.lerp(_accent, Colors.white, 0.2)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            ),
          ),
          Positioned(
            bottom: 100, left: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                          ]
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.auto_awesome_rounded, color: Colors.grey, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Magic Workout',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const Spacer(),

                // 👇 ЗАМЕНИЛИ ПРИВЕТСТВИЕ
                Text(
                    mode == ShareCardMode.challenge ? 'Настоящий вызов!' : 'Вызов принят!',
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)
                ),
                const SizedBox(height: 8),
                Text(_headline, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 8),
                Text(_subheadline, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 24),

                // 👇 УМНАЯ ЛОГИКА ПЛАШЕК
                Row(
                  children: [
                    if (mode == ShareCardMode.challenge) ...[
                      // ЧЕЛЛЕНДЖИ
                      Expanded(child: _buildStatTile(Icons.emoji_events_rounded, challengeMainStat ?? 'Готово')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatTile(Icons.timer_rounded, challengeSubStat ?? '—')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatTile(Icons.local_fire_department_rounded, challengeTimeStat ?? '1-й раз')),
                    ] else ...[
                      // ОБЫЧНЫЕ ТРЕНИРОВКИ
                      Expanded(
                          child: _buildStatTile(
                              mode == ShareCardMode.workout ? Icons.timer_rounded : Icons.fitness_center_rounded,
                              mode == ShareCardMode.workout ? _minutesLabel : _workoutsLabel
                          )
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatTile(Icons.fitness_center_rounded, _exercisesLabel)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatTile(
                          Icons.local_fire_department_rounded,
                          isWeekInProgress ? '$streakWeeks из $plannedDays' : _streakLabel,
                        ),
                      ),
                    ]
                  ],
                ),
                const Spacer(),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Image.asset(
                      _fairyImage,
                      width: 115,
                      height: 115,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome_rounded, size: 80, color: Colors.white54),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('С верой в тебя,', style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic)),
                          const Text('твоя Фея', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
                          const SizedBox(height: 4),
                          Text('magic-workout.app', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}