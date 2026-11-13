class ChallengeConfig {
  final String id;
  final String title;
  final String emoji;
  final String type; // 'cumulative', 'hold', 'timer', 'circuit', 'photo'
  final int baseTarget;
  final String unit; // 'повт.', 'сек', 'мин', 'шаги'
  final int energyReward; // 👈 НОВОЕ ПОЛЕ

  const ChallengeConfig({
    required this.id,
    required this.title,
    required this.emoji,
    required this.type,
    required this.baseTarget,
    required this.unit,
    required this.energyReward, // 👈
  });
}

const List<ChallengeConfig> kDailyChallenges = [
  // Накопительные
  ChallengeConfig(id: 'squats_100', title: 'Сделай 100 приседаний', emoji: '🍑', type: 'cumulative', baseTarget: 100, unit: 'повт.', energyReward: 20),
  ChallengeConfig(id: 'pushups_50', title: 'Сделай 50 отжиманий', emoji: '💪', type: 'cumulative', baseTarget: 50, unit: 'повт.', energyReward: 20),
  ChallengeConfig(id: 'crunches_100', title: 'Сделай 100 скручиваний', emoji: '🔥', type: 'cumulative', baseTarget: 100, unit: 'повт.', energyReward: 20),

  // Статика (удержание пальца)
  ChallengeConfig(id: 'chair_30', title: 'Стульчик у стены', emoji: '🪑', type: 'hold', baseTarget: 30, unit: 'сек', energyReward: 15),

  // Статика (с проверками)
  ChallengeConfig(id: 'plank_180', title: 'Планка', emoji: '⏱', type: 'timer', baseTarget: 300, unit: 'сек', energyReward: 25),

  // Кардио/Шаги (фото)
  ChallengeConfig(id: 'steps_5000', title: 'Пройди 5000 шагов', emoji: '🚶‍♀️', type: 'photo', baseTarget: 5000, unit: 'шагов', energyReward: 30),

  // Круг (утренний взрыв)
  ChallengeConfig(id: 'morning_circuit', title: 'Утренний взрыв', emoji: '⚡️', type: 'circuit', baseTarget: 1, unit: 'круг', energyReward: 30),
];