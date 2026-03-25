import 'dart:math' as math;

import 'package:tile_two/game/economy_service.dart';
import 'package:tile_two/game/mission_service.dart';
import 'package:tile_two/game/save_game_repository.dart';

class BoosterSystem {
  final EconomyService economy;
  final int shuffleUnlockLevel;
  final int hintUnlockLevel;

  const BoosterSystem({
    required this.economy,
    this.shuffleUnlockLevel = 3,
    this.hintUnlockLevel = 6,
  });

  int boosterPrice(BoosterType type) {
    return economy.boosterPrice(type);
  }

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
    return switch (type) {
      BoosterType.undo =>
        saveData.inventory.undo > 0 ||
            saveData.coins >= economy.boosterPrice(BoosterType.undo),
      BoosterType.shuffle =>
        saveData.inventory.shuffle > 0 ||
            saveData.coins >= economy.boosterPrice(BoosterType.shuffle),
      BoosterType.hint =>
        saveData.inventory.hint > 0 ||
            saveData.coins >= economy.boosterPrice(BoosterType.hint),
    };
  }

  SaveGameData? consumeUseCost({
    required BoosterType type,
    required SaveGameData saveData,
  }) {
    if (!canUse(type: type, saveData: saveData)) {
      return null;
    }
    if (type == BoosterType.undo && saveData.inventory.undo > 0) {
      return saveData.copyWith(
        inventory: saveData.inventory.copyWith(
          undo: saveData.inventory.undo - 1,
        ),
      );
    }
    if (type == BoosterType.shuffle && saveData.inventory.shuffle > 0) {
      return saveData.copyWith(
        inventory: saveData.inventory.copyWith(
          shuffle: saveData.inventory.shuffle - 1,
        ),
      );
    }
    if (type == BoosterType.hint && saveData.inventory.hint > 0) {
      return saveData.copyWith(
        inventory: saveData.inventory.copyWith(
          hint: saveData.inventory.hint - 1,
        ),
      );
    }
    final price = economy.boosterPrice(type);
    return saveData.copyWith(coins: saveData.coins - price);
  }

  SaveGameData? buy({
    required BoosterType type,
    required int amount,
    required SaveGameData saveData,
  }) {
    if (amount <= 0) {
      return null;
    }
    final totalPrice = economy.boosterPrice(type) * amount;
    if (saveData.coins < totalPrice) {
      return null;
    }
    var inventory = saveData.inventory;
    if (type == BoosterType.undo) {
      inventory = inventory.copyWith(undo: inventory.undo + amount);
    } else if (type == BoosterType.shuffle) {
      inventory = inventory.copyWith(shuffle: inventory.shuffle + amount);
    } else {
      inventory = inventory.copyWith(hint: inventory.hint + amount);
    }
    return saveData.copyWith(
      coins: saveData.coins - totalPrice,
      inventory: inventory,
    );
  }
}

class ProgressionSystem {
  final EconomyService economy;
  final MissionService missionService;

  const ProgressionSystem({
    required this.economy,
    required this.missionService,
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
    final updated = saveData.copyWith(
      currentLevel: nextLevel,
      completedLevels: math.max(saveData.completedLevels, clearedLevel),
      streak: saveData.streak + 1,
      coins: saveData.coins +
          economy.levelClearReward(
            level: clearedLevel,
            streak: saveData.streak + 1,
          ),
    );
    return missionService.recordLevelClear(saveData: updated);
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
