/// Эмоции феи — определяют, какую картинку показывать.
enum FairyMood {
  happy,   // 😊 обычная фраза
  wink,    // 😉 мотивация, старт тренировки
  think,   // 🤔 совет
  party,   // 🎉 рекорд, завершение
  sleepy,  // 😴 comeback, ночь
}

extension FairyMoodAsset on FairyMood {
  /// Путь к картинке для эмоции.
  String get asset {
    switch (this) {
      case FairyMood.happy:
        return 'assets/fairy/fairy_happy.png';
      case FairyMood.wink:
        return 'assets/fairy/fairy_wink.png';
      case FairyMood.think:
        return 'assets/fairy/fairy_think.png';
      case FairyMood.party:
        return 'assets/fairy/fairy_party.png';
      case FairyMood.sleepy:
        return 'assets/fairy/fairy_sleepy.png';
    }
  }
}