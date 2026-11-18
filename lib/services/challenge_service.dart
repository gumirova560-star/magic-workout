import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_challenge.dart';
import '../data/challenge_data.dart';
import 'database_helper.dart';
import 'energy_service.dart';
import 'garden_service.dart';

class ChallengeService {
  static Future<DailyChallenge?> getTodayChallenge(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final maps = await db.query(
      'daily_challenges',
      where: 'profileId = ? AND date = ?',
      whereArgs: [profileId, today],
    );

    if (maps.isNotEmpty) {
      return DailyChallenge.fromMap(maps.first);
    }

    final randomConfig = (List.from(kDailyChallenges)..shuffle()).first;

    final prefs = await SharedPreferences.getInstance();
    final targetKey = 'challenge_target_${profileId}_${randomConfig.id}';
    final savedTarget = prefs.getInt(targetKey);
    final effectiveTarget = (savedTarget != null && savedTarget > randomConfig.baseTarget)
        ? savedTarget
        : randomConfig.baseTarget;

    final newChallenge = DailyChallenge(
      profileId: profileId,
      date: today,
      challengeType: randomConfig.type,
      taskId: randomConfig.id,
      targetValue: effectiveTarget,
    );

    final id = await db.insert('daily_challenges', newChallenge.toMap());
    newChallenge.id = id;
    return newChallenge;
  }

  static Future<void> updateProgress(int challengeId, int newProgress) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('daily_challenges', where: 'id = ?', whereArgs: [challengeId]);
    if (maps.isEmpty) return;

    final challenge = DailyChallenge.fromMap(maps.first);
    final bool isCompleted = newProgress >= challenge.targetValue;

    await db.update(
      'daily_challenges',
      {
        'currentProgress': newProgress,
        'isCompleted': isCompleted ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [challengeId],
    );
  }

  static Future<void> increaseTarget(int challengeId, int extraValue) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('daily_challenges', where: 'id = ?', whereArgs: [challengeId]);
    if (maps.isEmpty) return;

    final challenge = DailyChallenge.fromMap(maps.first);
    final newTarget = challenge.targetValue + extraValue;

    await db.update(
      'daily_challenges',
      {
        'targetValue': newTarget,
        'isCompleted': 0,
      },
      where: 'id = ?',
      whereArgs: [challengeId],
    );
  }

  // 👇 ВЫДАЧА НАГРАДЫ (Энергия + Цветок + Защита от сбоев)
  static Future<bool> tryAwardReward({
    required int profileId,
    required int challengeId,
    bool isLegendary = false,
    int energyReward = 15, // Начисляем 15 энергии
  }) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query(
      'daily_challenges',
      columns: ['rewardGranted', 'isCompleted', 'currentProgress', 'targetValue'],
      where: 'id = ?',
      whereArgs: [challengeId],
      limit: 1,
    );
    if (maps.isEmpty) return false;

    final row = maps.first;
    final alreadyGranted = (row['rewardGranted'] as int? ?? 0) == 1;
    final currentProgress = row['currentProgress'] as int? ?? 0;
    final targetValue = row['targetValue'] as int? ?? 0;

    final actuallyCompleted = currentProgress >= targetValue;

    // Если награда уже выдана или цель не достигнута — выходим
    if (alreadyGranted || !actuallyCompleted) return false;

    try {
      // 1. Начисляем энергию
      if (energyReward > 0) {
        await EnergyService.addEnergy(
          profileId: profileId,
          delta: energyReward,
          reason: 'challenge_reward',
          refId: challengeId,
        );
      }

      // 2. Сажаем цветок (вызывается наш GardenService)
      await GardenService.plantNextFlower(
        profileId: profileId,
        flowerType: isLegendary ? 'legendary' : 'normal',
      );

      // 3. Отмечаем награду как полученную
      await db.update(
        'daily_challenges',
        {'isCompleted': 1, 'rewardGranted': 1},
        where: 'id = ?',
        whereArgs: [challengeId],
      );

      return true;
    } catch (e) {
      print('ОШИБКА ВЫДАЧИ НАГРАДЫ: $e');
      return false;
    }
  }
}