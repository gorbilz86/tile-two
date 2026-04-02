import 'dart:math' as math;

import 'package:tile_two/game/economy_service.dart';
import 'package:tile_two/game/save_game_repository.dart';

class BoosterSystem {
  final int shuffleUnlockLevel;
  final int hintUnlockLevel;

  const BoosterSystem({
    this.shuffleUnlockLevel = 3,
    this.hintUnlockLevel = 6,
  });

  int unlockLevelFor(BoosterType type) {
    return switch (type) {
      BoosterType.undo => 1,
      BoosterType.shuffle => shuffleUnlockLevel,
      BoosterType.hint => hintUnlockLevel,
    };
  }

  bool isUnlocked({
    required BoosterType type,
    required SaveGameData saveData,
  }) {
    final unlockLevel = unlockLevelFor(type);
    if (unlockLevel <= 1) {
      return true;
    }
    final highestLevelReached =
        math.max(saveData.currentLevel, saveData.completedLevels + 1);
    return highestLevelReached >= unlockLevel;
  }

  bool canUse({
    required BoosterType type,
    required SaveGameData saveData,
  }) {
    if (!isUnlocked(type: type, saveData: saveData)) {
      return false;
    }
    // Boosters can always be 'used' if unlocked because 0 stock triggers an ad
    return true;
  }

  SaveGameData? consumeUseCost({
    required BoosterType type,
    required SaveGameData saveData,
  }) {
    if (!isUnlocked(type: type, saveData: saveData)) {
      return null;
    }
    // If we have stock, consume it. Otherwise return the same data
    // (caller handles the AD reward flow if stock was 0)
    if (type == BoosterType.undo && saveData.inventory.undo > 0) {
      return saveData.copyWith(
        inventory: saveData.inventory.copyWith(undo: saveData.inventory.undo - 1),
      );
    }
    if (type == BoosterType.shuffle && saveData.inventory.shuffle > 0) {
      return saveData.copyWith(
        inventory: saveData.inventory.copyWith(shuffle: saveData.inventory.shuffle - 1),
      );
    }
    if (type == BoosterType.hint && saveData.inventory.hint > 0) {
      return saveData.copyWith(
        inventory: saveData.inventory.copyWith(hint: saveData.inventory.hint - 1),
      );
    }
    return saveData;
  }

  SaveGameData buy({
    required BoosterType type,
    required int amount,
    required SaveGameData saveData,
  }) {
    if (amount <= 0) return saveData;
    var inventory = saveData.inventory;
    if (type == BoosterType.undo) {
      inventory = inventory.copyWith(undo: inventory.undo + amount);
    } else if (type == BoosterType.shuffle) {
      inventory = inventory.copyWith(shuffle: inventory.shuffle + amount);
    } else {
      inventory = inventory.copyWith(hint: inventory.hint + amount);
    }
    return saveData.copyWith(inventory: inventory);
  }
}

class ProgressionSystem {
  final EconomyService economy;

  const ProgressionSystem({
    required this.economy,
  });

  int nextLevel({
    required int currentLevel,
    required int maxLevel,
  }) {
    if (currentLevel >= maxLevel) {
      return 1;
    }
    return currentLevel + 1;
  }

  SaveGameData applyLevelClear({
    required SaveGameData saveData,
    required int clearedLevel,
    required int nextLevel,
  }) {
    var updated = saveData.copyWith(
      currentLevel: nextLevel,
      completedLevels: math.max(saveData.completedLevels, clearedLevel),
      streak: saveData.streak + 1,
    );

    // Dynamic booster reward
    final reward = economy.levelClearBoosterReward(
      level: clearedLevel,
      streak: updated.streak,
    );

    if (reward != null) {
      final inv = updated.inventory;
      updated = updated.copyWith(
        inventory: matchServiceReward(inv, reward),
      );
    }

    return updated;
  }

  BoosterInventory matchServiceReward(BoosterInventory inv, BoosterType type) {
    return switch (type) {
      BoosterType.undo => inv.copyWith(undo: inv.undo + 1),
      BoosterType.shuffle => inv.copyWith(shuffle: inv.shuffle + 1),
      BoosterType.hint => inv.copyWith(hint: inv.hint + 1),
    };
  }

  SaveGameData resetStreakOnFail({
    required SaveGameData saveData,
  }) {
    if (saveData.streak == 0) {
      return saveData;
    }
    return saveData.copyWith(streak: 0);
  }
}
