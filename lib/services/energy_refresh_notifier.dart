import 'package:flutter/foundation.dart';

/// Глобальный нотификатор для обновления UI после изменения энергии.
/// Любой виджет с балансом может подписаться на ticker и обновляться
/// автоматически, откуда бы энергия ни начислилась.
class EnergyRefreshNotifier {
  static final ValueNotifier<int> ticker = ValueNotifier<int>(0);

  static void trigger() {
    ticker.value++;
  }
}