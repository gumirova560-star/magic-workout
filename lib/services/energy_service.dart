import 'database_helper.dart';

class EnergyService {
  /// Текущий баланс энергии (кэш в user_profiles).
  static Future<int> getBalance(int profileId) async {
    return await DatabaseHelper.instance.getEnergyBalance(profileId);
  }

  /// Пытается начислить энергию. Защита от двойного начисления:
  /// если (profileId, reason, refId) уже было — вернёт false и НЕ начислит.
  ///
  /// Примеры использования:
  ///   addEnergy(profileId, 50, 'workout_completed', workoutDayId)
  ///   addEnergy(profileId, 20, 'challenge_completed', challengeId)
  ///   addEnergy(profileId, 5, 'daily_login', null) // refId может быть null
  static Future<bool> addEnergy({
    required int profileId,
    required int delta,
    required String reason,
    int? refId,
  }) async {
    if (delta == 0) return false;
    return await DatabaseHelper.instance.tryAddEnergy(
      profileId: profileId,
      delta: delta,
      reason: reason,
      refId: refId,
    );
  }

  /// История транзакций (для экрана «Откуда энергия»).
  static Future<List<Map<String, dynamic>>> getHistory(int profileId, {int limit = 50}) async {
    return await DatabaseHelper.instance.getEnergyHistory(profileId, limit: limit);
  }
}