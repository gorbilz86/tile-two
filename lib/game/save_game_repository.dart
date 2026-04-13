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
      undo: 1,
      shuffle: 1,
      hint: 1,
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
      undo: (map['undo'] as num?)?.toInt() ?? 1,
      shuffle: (map['shuffle'] as num?)?.toInt() ?? 1,
      hint: (map['hint'] as num?)?.toInt() ?? 1,
    );
  }
}

class SaveGameData {
  final int currentLevel;
  final int completedLevels;
  final int streak;
  final int dailyLoginStreak;
  final String? lastDailyClaimDate;
  final String? lastLoginDate;
  final String? lastComebackClaimDate;
  final String selectedLanguageCode;
  final BoosterInventory inventory;
  final MissionState missionState;
  final bool onboardingCompleted;
  final bool firstWinClaimed;

  const SaveGameData({
    required this.currentLevel,
    required this.completedLevels,
    required this.streak,
    required this.dailyLoginStreak,
    required this.lastDailyClaimDate,
    required this.lastLoginDate,
    required this.lastComebackClaimDate,
    required this.selectedLanguageCode,
    required this.inventory,
    required this.missionState,
    required this.onboardingCompleted,
    required this.firstWinClaimed,
  });

  factory SaveGameData.initial() {
    return SaveGameData(
      currentLevel: 1,
      completedLevels: 0,
      streak: 0,
      dailyLoginStreak: 0,
      lastDailyClaimDate: null,
      lastLoginDate: null,
      lastComebackClaimDate: null,
      selectedLanguageCode: 'id',
      inventory: BoosterInventory.initial(),
      missionState: MissionState.initial(),
      onboardingCompleted: false,
      firstWinClaimed: false,
    );
  }

  SaveGameData copyWith({
    int? currentLevel,
    int? completedLevels,
    int? streak,
    int? dailyLoginStreak,
    String? lastDailyClaimDate,
    String? lastLoginDate,
    String? lastComebackClaimDate,
    String? selectedLanguageCode,
    BoosterInventory? inventory,
    MissionState? missionState,
    bool? onboardingCompleted,
    bool? firstWinClaimed,
  }) {
    return SaveGameData(
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
      streak: streak ?? this.streak,
      dailyLoginStreak: dailyLoginStreak ?? this.dailyLoginStreak,
      lastDailyClaimDate: lastDailyClaimDate ?? this.lastDailyClaimDate,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      lastComebackClaimDate:
          lastComebackClaimDate ?? this.lastComebackClaimDate,
      selectedLanguageCode:
          selectedLanguageCode ?? this.selectedLanguageCode,
      inventory: inventory ?? this.inventory,
      missionState: missionState ?? this.missionState,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      firstWinClaimed: firstWinClaimed ?? this.firstWinClaimed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentLevel': currentLevel,
      'completedLevels': completedLevels,
      'streak': streak,
      'dailyLoginStreak': dailyLoginStreak,
      'lastDailyClaimDate': lastDailyClaimDate,
      'lastLoginDate': lastLoginDate,
      'lastComebackClaimDate': lastComebackClaimDate,
      'selectedLanguageCode': selectedLanguageCode,
      'inventory': inventory.toMap(),
      'missionState': missionState.toMap(),
      'onboardingCompleted': onboardingCompleted,
      'firstWinClaimed': firstWinClaimed,
    };
  }

  factory SaveGameData.fromMap(Map<String, dynamic> map) {
    return SaveGameData(
      currentLevel: (map['currentLevel'] as num?)?.toInt() ?? 1,
      completedLevels: (map['completedLevels'] as num?)?.toInt() ?? 0,
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      dailyLoginStreak: (map['dailyLoginStreak'] as num?)?.toInt() ?? 0,
      lastDailyClaimDate: map['lastDailyClaimDate'] as String?,
      lastLoginDate: map['lastLoginDate'] as String?,
      lastComebackClaimDate: map['lastComebackClaimDate'] as String?,
      selectedLanguageCode:
          (map['selectedLanguageCode'] as String?) ?? 'id',
      inventory: BoosterInventory.fromMap(
        (map['inventory'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      missionState: MissionState.fromMap(
        (map['missionState'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      firstWinClaimed: map['firstWinClaimed'] as bool? ?? false,
    );
  }
}

class MissionState {
  final int dailyKey;
  final int weeklyKey;
  final int dailyLevelsCleared;
  final int dailyHintsUsed;
  final int dailyShufflesUsed;
  final int weeklyLevelsCleared;
  final int weeklyHintsUsed;
  final int weeklyShufflesUsed;
  final List<String> claimedDailyMissionIds;
  final List<String> claimedWeeklyMissionIds;

  const MissionState({
    required this.dailyKey,
    required this.weeklyKey,
    required this.dailyLevelsCleared,
    required this.dailyHintsUsed,
    required this.dailyShufflesUsed,
    required this.weeklyLevelsCleared,
    required this.weeklyHintsUsed,
    required this.weeklyShufflesUsed,
    required this.claimedDailyMissionIds,
    required this.claimedWeeklyMissionIds,
  });

  factory MissionState.initial() {
    return const MissionState(
      dailyKey: 0,
      weeklyKey: 0,
      dailyLevelsCleared: 0,
      dailyHintsUsed: 0,
      dailyShufflesUsed: 0,
      weeklyLevelsCleared: 0,
      weeklyHintsUsed: 0,
      weeklyShufflesUsed: 0,
      claimedDailyMissionIds: [],
      claimedWeeklyMissionIds: [],
    );
  }

  MissionState copyWith({
    int? dailyKey,
    int? weeklyKey,
    int? dailyLevelsCleared,
    int? dailyHintsUsed,
    int? dailyShufflesUsed,
    int? weeklyLevelsCleared,
    int? weeklyHintsUsed,
    int? weeklyShufflesUsed,
    List<String>? claimedDailyMissionIds,
    List<String>? claimedWeeklyMissionIds,
  }) {
    return MissionState(
      dailyKey: dailyKey ?? this.dailyKey,
      weeklyKey: weeklyKey ?? this.weeklyKey,
      dailyLevelsCleared: dailyLevelsCleared ?? this.dailyLevelsCleared,
      dailyHintsUsed: dailyHintsUsed ?? this.dailyHintsUsed,
      dailyShufflesUsed: dailyShufflesUsed ?? this.dailyShufflesUsed,
      weeklyLevelsCleared: weeklyLevelsCleared ?? this.weeklyLevelsCleared,
      weeklyHintsUsed: weeklyHintsUsed ?? this.weeklyHintsUsed,
      weeklyShufflesUsed: weeklyShufflesUsed ?? this.weeklyShufflesUsed,
      claimedDailyMissionIds:
          claimedDailyMissionIds ?? this.claimedDailyMissionIds,
      claimedWeeklyMissionIds:
          claimedWeeklyMissionIds ?? this.claimedWeeklyMissionIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyKey': dailyKey,
      'weeklyKey': weeklyKey,
      'dailyLevelsCleared': dailyLevelsCleared,
      'dailyHintsUsed': dailyHintsUsed,
      'dailyShufflesUsed': dailyShufflesUsed,
      'weeklyLevelsCleared': weeklyLevelsCleared,
      'weeklyHintsUsed': weeklyHintsUsed,
      'weeklyShufflesUsed': weeklyShufflesUsed,
      'claimedDailyMissionIds': claimedDailyMissionIds,
      'claimedWeeklyMissionIds': claimedWeeklyMissionIds,
    };
  }

  factory MissionState.fromMap(Map<String, dynamic> map) {
    return MissionState(
      dailyKey: (map['dailyKey'] as num?)?.toInt() ?? 0,
      weeklyKey: (map['weeklyKey'] as num?)?.toInt() ?? 0,
      dailyLevelsCleared: (map['dailyLevelsCleared'] as num?)?.toInt() ?? 0,
      dailyHintsUsed: (map['dailyHintsUsed'] as num?)?.toInt() ?? 0,
      dailyShufflesUsed: (map['dailyShufflesUsed'] as num?)?.toInt() ?? 0,
      weeklyLevelsCleared: (map['weeklyLevelsCleared'] as num?)?.toInt() ?? 0,
      weeklyHintsUsed: (map['weeklyHintsUsed'] as num?)?.toInt() ?? 0,
      weeklyShufflesUsed: (map['weeklyShufflesUsed'] as num?)?.toInt() ?? 0,
      claimedDailyMissionIds:
          (map['claimedDailyMissionIds'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      claimedWeeklyMissionIds:
          (map['claimedWeeklyMissionIds'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
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
