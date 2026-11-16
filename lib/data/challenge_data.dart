class ChallengeConfig {
  final String id;
  final String title;
  final String emoji;
  final String type; // 'cumulative', 'hold', 'timer', 'circuit', 'photo'
  final int baseTarget;
  final String unit; // 'повт.', 'сек', 'мин', 'шаги'
  final int energyReward;

  const ChallengeConfig({
    required this.id,
    required this.title,
    required this.emoji,
    required this.type,
    required this.baseTarget,
    required this.unit,
    required this.energyReward,
  });
}

const List<ChallengeConfig> kDailyChallenges = [
  // ═══ НАКОПИТЕЛЬНЫЕ (Cumulative) ═══
  ChallengeConfig(id: 'squats_100', title: 'Сделай 100 приседаний', emoji: '🍑', type: 'cumulative', baseTarget: 100, unit: 'повт.', energyReward: 20),
  ChallengeConfig(id: 'pushups_50', title: 'Сделай 50 отжиманий', emoji: '💪', type: 'cumulative', baseTarget: 50, unit: 'повт.', energyReward: 20),
  ChallengeConfig(id: 'crunches_100', title: 'Сделай 100 скручиваний', emoji: '🔥', type: 'cumulative', baseTarget: 100, unit: 'повт.', energyReward: 20),

  // 👇 НОВЫЕ ЧЕЛЛЕНДЖИ ВМЕСТО ШАГОВ
  ChallengeConfig(id: 'mountain_climbers_80', title: 'Сделай 80 скалолазов', emoji: '🧗‍♀️', type: 'cumulative', baseTarget: 80, unit: 'повт.', energyReward: 25),
  ChallengeConfig(id: 'side_lunges_60', title: 'Сделай 60 выпадов в сторону', emoji: '🦵', type: 'cumulative', baseTarget: 60, unit: 'повт.', energyReward: 20),

  // ═══ СТАТИКА (Удержание пальца) ═══
  ChallengeConfig(id: 'chair_30', title: 'Стульчик у стены', emoji: '🪑', type: 'hold', baseTarget: 30, unit: 'сек', energyReward: 15),

  // ═══ СТАТИКА (С проверками) ═══
  ChallengeConfig(id: 'plank_180', title: 'Планка', emoji: '⏱', type: 'timer', baseTarget: 300, unit: 'сек', energyReward: 25),

  // ═══ КРУГ (Утренний взрыв) ═══
  ChallengeConfig(id: 'morning_circuit', title: 'Утренний взрыв', emoji: '⚡️', type: 'circuit', baseTarget: 1, unit: 'круг', energyReward: 30),
];