import '../models/daily_challenge.dart';
import '../data/challenge_data.dart';
import 'database_helper.dart';

class ChallengeService {
  // Получить задание на сегодня (или создать новое, если его нет)
  static Future<DailyChallenge?> getTodayChallenge(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Ищем задание на сегодня
    final maps = await db.query('daily_challenges', where: 'profileId = ? AND date = ?', whereArgs: [profileId, today]);

    if (maps.isNotEmpty) {
      return DailyChallenge.fromMap(maps.first);
    }

    // Если нет — выбираем случайное
    final randomConfig = (List.from(kDailyChallenges)..shuffle()).first;

    final newChallenge = DailyChallenge(
      profileId: profileId,
      date: today,
      challengeType: randomConfig.type,
      taskId: randomConfig.id,
      targetValue: randomConfig.baseTarget,
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

    await db.update('daily_challenges', {
      'currentProgress': newProgress,
      'isCompleted': isCompleted ? 1 : 0,
    }, where: 'id = ?', whereArgs: [challengeId]);
  }

  // Кнопка "Могу больше" (увеличить цель)
  static Future<void> increaseTarget(int challengeId, int extraValue) async {
    final db = await DatabaseHelper.instance.database;

    final maps = await db.query('daily_challenges', where: 'id = ?', whereArgs: [challengeId]);
    if (maps.isEmpty) return;

    final challenge = DailyChallenge.fromMap(maps.first);
    final newTarget = challenge.targetValue + extraValue;

    await db.update('daily_challenges', {
      'targetValue': newTarget,
      'isCompleted': 0, // Сбрасываем галочку, чтобы пользователь доделал
    }, where: 'id = ?', whereArgs: [challengeId]);
  }
}