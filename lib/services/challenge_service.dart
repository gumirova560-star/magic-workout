import '../models/daily_challenge.dart';
import '../data/challenge_data.dart';
import 'database_helper.dart';
import 'energy_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 ДОБАВЛЕН ИМПОРТ

class ChallengeService {
  // Получить задание на сегодня (или создать новое, если его нет)
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

    // 👇 ЧИТАЕМ СОХРАНЁННУЮ ЦЕЛЬ ИЗ SHARED PREFERENCES
    final prefs = await SharedPreferences.getInstance();
    final targetKey = 'challenge_target_${profileId}_${randomConfig.id}';
    final savedTarget = prefs.getInt(targetKey);

    // Если сохранённая цель больше базовой — используем её
    final effectiveTarget = (savedTarget != null && savedTarget > randomConfig.baseTarget)
        ? savedTarget
        : randomConfig.baseTarget;

    final newChallenge = DailyChallenge(
      profileId: profileId,
      date: today,
      challengeType: randomConfig.type,
      taskId: randomConfig.id,
      targetValue: effectiveTarget, // 👈 ПРИМЕНЯЕМ СОХРАНЁННУЮ ЦЕЛЬ
    );

    final id = await db.insert('daily_challenges', newChallenge.toMap());
    newChallenge.id = id;
    return newChallenge;
  }

  // Обновить прогресс
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

  // Кнопка "Могу больше" (увеличить цель)
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

  // Атомарно выдаёт награду. Возвращает true, если это первое начисление.
  static Future<bool> tryAwardReward({
    required int profileId,
    required int challengeId,
    required int energyAmount,
  }) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query(
      'daily_challenges',
      columns: ['rewardGranted', 'isCompleted'],
      where: 'id = ?',
      whereArgs: [challengeId],
      limit: 1,
    );
    if (maps.isEmpty) return false;
    final row = maps.first;
    final alreadyGranted = (row['rewardGranted'] as int? ?? 0) == 1;
    final isCompleted = (row['isCompleted'] as int? ?? 0) == 1;

    if (!isCompleted || alreadyGranted) return false;

    final success = await EnergyService.addEnergy(
      profileId: profileId,
      delta: energyAmount,
      reason: 'challenge_completed',
      refId: challengeId,
    );

    if (success) {
      await db.update(
        'daily_challenges',
        {'rewardGranted': 1},
        where: 'id = ?',
        whereArgs: [challengeId],
      );
    }

    return success;
  }
}