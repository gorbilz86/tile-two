import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BoosterInventory {
  final int undo;
  final int shuffle;
  final int hint;

  const BoosterInventory({
    required this.undo,
    required this.shuffle,
    required this.hint,
  });

  factory BoosterInventory.initial() {
    return const BoosterInventory(
      undo: 3,
      shuffle: 3,
      hint: 3,
    );
  }

  BoosterInventory copyWith({
    int? undo,
    int? shuffle,
    int? hint,
  }) {
    return BoosterInventory(
      undo: undo ?? this.undo,
      shuffle: shuffle ?? this.shuffle,
      hint: hint ?? this.hint,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'undo': undo,
      'shuffle': shuffle,
      'hint': hint,
    };
  }

  factory BoosterInventory.fromMap(Map<String, dynamic> map) {
    return BoosterInventory(
      undo: (map['undo'] as num?)?.toInt() ?? 3,
      shuffle: (map['shuffle'] as num?)?.toInt() ?? 3,
      hint: (map['hint'] as num?)?.toInt() ?? 3,
    );
  }
}

class SaveGameData {
  final int currentLevel;
  final int completedLevels;
  final int streak;
  final BoosterInventory inventory;
  final bool onboardingCompleted;
  final bool firstWinClaimed;

  const SaveGameData({
    required this.currentLevel,
    required this.completedLevels,
    required this.streak,
    required this.inventory,
    required this.onboardingCompleted,
    required this.firstWinClaimed,
  });

  factory SaveGameData.initial() {
    return SaveGameData(
      currentLevel: 1,
      completedLevels: 0,
      streak: 0,
      inventory: BoosterInventory.initial(),
      onboardingCompleted: false,
      firstWinClaimed: false,
    );
  }

  SaveGameData copyWith({
    int? currentLevel,
    int? completedLevels,
    int? streak,
    BoosterInventory? inventory,
    bool? onboardingCompleted,
    bool? firstWinClaimed,
  }) {
    return SaveGameData(
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
      streak: streak ?? this.streak,
      inventory: inventory ?? this.inventory,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      firstWinClaimed: firstWinClaimed ?? this.firstWinClaimed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentLevel': currentLevel,
      'completedLevels': completedLevels,
      'streak': streak,
      'inventory': inventory.toMap(),
      'onboardingCompleted': onboardingCompleted,
      'firstWinClaimed': firstWinClaimed,
    };
  }

  factory SaveGameData.fromMap(Map<String, dynamic> map) {
    return SaveGameData(
      currentLevel: (map['currentLevel'] as num?)?.toInt() ?? 1,
      completedLevels: (map['completedLevels'] as num?)?.toInt() ?? 0,
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      inventory: BoosterInventory.fromMap(
        (map['inventory'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      firstWinClaimed: map['firstWinClaimed'] as bool? ?? false,
    );
  }
}

class SaveGameRepository {
  static const String _saveKey = 'save_game_v1';

  Future<SaveGameData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw == null || raw.isEmpty) {
      return SaveGameData.initial();
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return SaveGameData.initial();
    }
    return SaveGameData.fromMap(decoded);
  }

  Future<void> save(SaveGameData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(data.toMap()));
  }
}
