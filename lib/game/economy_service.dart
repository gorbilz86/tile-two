enum BoosterType {
  undo,
  shuffle,
  hint,
}

class EconomyService {
  EconomyService._();

  static final EconomyService instance = EconomyService._();

  int boosterPrice(BoosterType type) {
    return switch (type) {
      BoosterType.undo => 45,
      BoosterType.shuffle => 55,
      BoosterType.hint => 35,
    };
  }

  int levelClearReward({
    required int level,
    required int streak,
  }) {
    final levelFactor = (12 + (level * 0.65)).round().clamp(12, 90);
    final streakBonus = (streak * 2).clamp(0, 20);
    return levelFactor + streakBonus;
  }
}
