enum BoosterType {
  undo,
  shuffle,
  hint,
}

class EconomyService {
  EconomyService._();

  static final EconomyService instance = EconomyService._();

  BoosterType? levelClearBoosterReward({
    required int level,
    required int streak,
  }) {
    // Reward a random booster every 3 levels or based on streak
    if (level % 3 == 0 || (streak > 0 && streak % 5 == 0)) {
      const types = BoosterType.values;
      return types[level % types.length];
    }
    return null;
  }
}
