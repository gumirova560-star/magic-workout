import 'database_helper.dart';
import 'energy_refresh_notifier.dart';

class EnergyService {
  // 👇 ПРИВЕТСТВЕННАЯ ЭНЕРГИЯ: выдаётся один раз при создании профиля.
  static const int welcomeBonusAmount = 30;
  static const String welcomeBonusReason = 'welcome_bonus';

  // 👇 ЕЖЕДНЕВНЫЙ ВХОД: +5⚡ один раз в календарный день.
  // Защита от повтора — UNIQUE (profileId, reason, refId),
  // refId кодирует дату: 26.11.2026 → 20261126.
  static const int dailyLoginAmount = 5;
  static const String dailyLoginReason = 'daily_login';

  // 👇 ЙОГА: +15⚡ один раз в календарный день за любую завершённую сессию.
  // refId кодирует дату (как у ежедневного входа): если бы refId был
  // id сессии, то повторное прохождение той же практики навсегда
  // заблокировало бы награду — а дата честнее: каждый день новая.
  static const int yogaBonusAmount = 15;
  static const String yogaBonusReason = 'yoga_session';

  // Кэш в памяти: не долбим базу при каждом переключении вкладок.
  // profileId -> код даты, за которую вход уже засчитан.
  static final Map<int, int> _dailyLoginDone = {};

  /// Код календарного дня: 2026-11-26 → 20261126.
  static int _dateCode(DateTime now) =>
      now.year * 10000 + now.month * 100 + now.day;

  /// Начисляет приветственные 30⚡. Возвращает true, если начислены сейчас,
  /// false — если бонус уже выдавался (защита через UNIQUE-констрейнт).
  static Future<bool> grantWelcomeBonus(int profileId) async {
    return await addEnergy(
      profileId: profileId,
      delta: welcomeBonusAmount,
      reason: welcomeBonusReason,
      refId: profileId,
    );
  }

  /// +5⚡ за ежедневный вход. Вызывать можно сколько угодно раз —
  /// за один день начислится только один раз, повторные вызовы безопасны.
  static Future<bool> grantDailyLogin(int profileId) async {
    final dateCode = _dateCode(DateTime.now());

    if (_dailyLoginDone[profileId] == dateCode) return false;

    final granted = await addEnergy(
      profileId: profileId,
      delta: dailyLoginAmount,
      reason: dailyLoginReason,
      refId: dateCode,
    );
    if (granted) _dailyLoginDone[profileId] = dateCode;
    return granted;
  }

  /// +15⚡ за завершённую йога-сессию. Один раз в календарный день —
  /// повторные вызовы в тот же день безопасны (UNIQUE-констрейнт).
  static Future<bool> grantYogaBonus(int profileId) async {
    return await addEnergy(
      profileId: profileId,
      delta: yogaBonusAmount,
      reason: yogaBonusReason,
      refId: _dateCode(DateTime.now()),
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
