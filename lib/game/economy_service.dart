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
    // Reward disabled: Player must focus on Rewarded Ads for boosters.
    return null;
  }
}
