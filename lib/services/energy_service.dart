import 'database_helper.dart';
import 'energy_refresh_notifier.dart';

class EnergyService {
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
    // 👇 будем все UI, кто слушает баланс
    if (result) EnergyRefreshNotifier.trigger();
    return result;
  }

  static Future<List<Map<String, dynamic>>> getHistory(int profileId, {int limit = 50}) async {
    return await DatabaseHelper.instance.getEnergyHistory(profileId, limit: limit);
  }
}