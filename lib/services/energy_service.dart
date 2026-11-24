import 'database_helper.dart';
import 'energy_refresh_notifier.dart';

class EnergyService {
  // 👇 ПРИВЕТСТВЕННАЯ ЭНЕРГИЯ: выдаётся один раз при создании профиля.
  static const int welcomeBonusAmount = 30;
  static const String welcomeBonusReason = 'welcome_bonus';

  /// Начисляет приветственные 30⚡. Возвращает true, если начислены сейчас,
  /// false — если бонус уже выдавался (защита через UNIQUE-констрейнт).
  static Future<bool> grantWelcomeBonus(int profileId) async {
    return await addEnergy(
      profileId: profileId,
      delta: welcomeBonusAmount,
      reason: welcomeBonusReason,
      // refId = id профиля: UNIQUE (profileId, reason, refId) гарантирует,
      // что второй вызов для того же профиля не начислит энергию повторно
      refId: profileId,
    );
  }

  static Future<int> getBalance(int profileId) async {
    return await DatabaseHelper.instance.getEnergyBalance(profileId);
  }

  static Future<bool> addEnergy({
    required int profileId,
    required int delta,
    required String reason,
    int? refId,
  }) async {
    if (delta == 0) return false;
    final result = await DatabaseHelper.instance.tryAddEnergy(
      profileId: profileId,
      delta: delta,
      reason: reason,
      refId: refId,
    );
    // 👇 будим все UI, кто слушает баланс
    if (result) EnergyRefreshNotifier.trigger();
    return result;
  }

  static Future<List<Map<String, dynamic>>> getHistory(int profileId, {int limit = 50}) async {
    return await DatabaseHelper.instance.getEnergyHistory(profileId, limit: limit);
  }
}
