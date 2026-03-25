import 'package:tile_two/game/save_game_repository.dart';

enum MissionScope { daily, weekly }

enum MissionMetric { clearLevels, useHints, useShuffles }

class MissionReward {
  final int undo;
  final int shuffle;
  final int hint;

  const MissionReward({
    required this.undo,
    required this.shuffle,
    required this.hint,
  });
}

class MissionDefinition {
  final String id;
  final MissionScope scope;
  final MissionMetric metric;
  final int target;
  final String title;
  final MissionReward reward;

  const MissionDefinition({
    required this.id,
    required this.scope,
    required this.metric,
    required this.target,
    required this.title,
    required this.reward,
  });
}

class MissionEntry {
  final MissionDefinition definition;
  final int progress;
  final bool claimed;

  const MissionEntry({
    required this.definition,
    required this.progress,
    required this.claimed,
  });

  bool get claimable => !claimed && progress >= definition.target;
}

class MissionBoardState {
  final List<MissionEntry> daily;
  final List<MissionEntry> weekly;

  const MissionBoardState({
    required this.daily,
    required this.weekly,
  });
}

class MissionClaimResult {
  final bool claimed;
  final MissionClaimStatus status;
  final SaveGameData updatedData;
  final MissionReward reward;

  const MissionClaimResult({
    required this.claimed,
    required this.status,
    required this.updatedData,
    required this.reward,
  });
}

enum MissionClaimStatus {
  missionNotFound,
  alreadyClaimed,
  progressInsufficient,
  success,
}

class MissionService {
  MissionService._();

  static final MissionService instance = MissionService._();

  static const List<MissionDefinition> _allMissions = [
    MissionDefinition(
      id: 'daily_clear_3',
      scope: MissionScope.daily,
      metric: MissionMetric.clearLevels,
      target: 3,
      title: 'Clear 3 level hari ini',
      reward: MissionReward(undo: 1, shuffle: 0, hint: 2),
    ),
    MissionDefinition(
      id: 'daily_hint_2',
      scope: MissionScope.daily,
      metric: MissionMetric.useHints,
      target: 2,
      title: 'Gunakan Hint 2 kali',
      reward: MissionReward(undo: 0, shuffle: 1, hint: 0),
    ),
    MissionDefinition(
      id: 'daily_shuffle_1',
      scope: MissionScope.daily,
      metric: MissionMetric.useShuffles,
      target: 1,
      title: 'Gunakan Shuffle 1 kali',
      reward: MissionReward(undo: 1, shuffle: 0, hint: 0),
    ),
    MissionDefinition(
      id: 'weekly_clear_18',
      scope: MissionScope.weekly,
      metric: MissionMetric.clearLevels,
      target: 18,
      title: 'Clear 18 level minggu ini',
      reward: MissionReward(undo: 2, shuffle: 2, hint: 4),
    ),
    MissionDefinition(
      id: 'weekly_hint_12',
      scope: MissionScope.weekly,
      metric: MissionMetric.useHints,
      target: 12,
      title: 'Gunakan Hint 12 kali',
      reward: MissionReward(undo: 3, shuffle: 0, hint: 2),
    ),
    MissionDefinition(
      id: 'weekly_shuffle_8',
      scope: MissionScope.weekly,
      metric: MissionMetric.useShuffles,
      target: 8,
      title: 'Gunakan Shuffle 8 kali',
      reward: MissionReward(undo: 0, shuffle: 3, hint: 2),
    ),
  ];

  SaveGameData normalize({
    required SaveGameData saveData,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final nextDailyKey = _dailyKey(date);
    final nextWeeklyKey = _weeklyKey(date);
    var mission = saveData.missionState;
    if (mission.dailyKey != nextDailyKey) {
      mission = mission.copyWith(
        dailyKey: nextDailyKey,
        dailyLevelsCleared: 0,
        dailyHintsUsed: 0,
        dailyShufflesUsed: 0,
        claimedDailyMissionIds: const [],
      );
    }
    if (mission.weeklyKey != nextWeeklyKey) {
      mission = mission.copyWith(
        weeklyKey: nextWeeklyKey,
        weeklyLevelsCleared: 0,
        weeklyHintsUsed: 0,
        weeklyShufflesUsed: 0,
        claimedWeeklyMissionIds: const [],
      );
    }
    return saveData.copyWith(missionState: mission);
  }

  SaveGameData recordLevelClear({
    required SaveGameData saveData,
    DateTime? now,
  }) {
    final normalized = normalize(saveData: saveData, now: now);
    final mission = normalized.missionState;
    return normalized.copyWith(
      missionState: mission.copyWith(
        dailyLevelsCleared: mission.dailyLevelsCleared + 1,
        weeklyLevelsCleared: mission.weeklyLevelsCleared + 1,
      ),
    );
  }

  SaveGameData recordHintUsed({
    required SaveGameData saveData,
    DateTime? now,
  }) {
    final normalized = normalize(saveData: saveData, now: now);
    final mission = normalized.missionState;
    return normalized.copyWith(
      missionState: mission.copyWith(
        dailyHintsUsed: mission.dailyHintsUsed + 1,
        weeklyHintsUsed: mission.weeklyHintsUsed + 1,
      ),
    );
  }

  SaveGameData recordShuffleUsed({
    required SaveGameData saveData,
    DateTime? now,
  }) {
    final normalized = normalize(saveData: saveData, now: now);
    final mission = normalized.missionState;
    return normalized.copyWith(
      missionState: mission.copyWith(
        dailyShufflesUsed: mission.dailyShufflesUsed + 1,
        weeklyShufflesUsed: mission.weeklyShufflesUsed + 1,
      ),
    );
  }

  MissionBoardState board({
    required SaveGameData saveData,
    DateTime? now,
  }) {
    final normalized = normalize(saveData: saveData, now: now);
    final mission = normalized.missionState;
    final daily = <MissionEntry>[];
    final weekly = <MissionEntry>[];
    for (final definition in _allMissions) {
      final claimed = definition.scope == MissionScope.daily
          ? mission.claimedDailyMissionIds.contains(definition.id)
          : mission.claimedWeeklyMissionIds.contains(definition.id);
      final progress =
          _progressFor(definition.metric, definition.scope, mission);
      final entry = MissionEntry(
        definition: definition,
        progress: progress,
        claimed: claimed,
      );
      if (definition.scope == MissionScope.daily) {
        daily.add(entry);
      } else {
        weekly.add(entry);
      }
    }
    return MissionBoardState(daily: daily, weekly: weekly);
  }

  MissionClaimResult claim({
    required SaveGameData saveData,
    required MissionScope scope,
    required String missionId,
    DateTime? now,
  }) {
    final normalized = normalize(saveData: saveData, now: now);
    final mission = normalized.missionState;
    MissionDefinition? definition;
    for (final missionDef in _allMissions) {
      if (missionDef.id == missionId) {
        definition = missionDef;
        break;
      }
    }
    if (definition == null || definition.scope != scope) {
      return MissionClaimResult(
        claimed: false,
        status: MissionClaimStatus.missionNotFound,
        updatedData: normalized,
        reward: const MissionReward(undo: 0, shuffle: 0, hint: 0),
      );
    }
    final claimedList = scope == MissionScope.daily
        ? mission.claimedDailyMissionIds
        : mission.claimedWeeklyMissionIds;
    if (claimedList.contains(missionId)) {
      return MissionClaimResult(
        claimed: false,
        status: MissionClaimStatus.alreadyClaimed,
        updatedData: normalized,
        reward: const MissionReward(undo: 0, shuffle: 0, hint: 0),
      );
    }
    final progress = _progressFor(definition.metric, scope, mission);
    if (progress < definition.target) {
      return MissionClaimResult(
        claimed: false,
        status: MissionClaimStatus.progressInsufficient,
        updatedData: normalized,
        reward: const MissionReward(undo: 0, shuffle: 0, hint: 0),
      );
    }
    final nextClaimed = [...claimedList, missionId];
    final nextMission = scope == MissionScope.daily
        ? mission.copyWith(claimedDailyMissionIds: nextClaimed)
        : mission.copyWith(claimedWeeklyMissionIds: nextClaimed);
    final reward = definition.reward;
    final nextData = normalized.copyWith(
      missionState: nextMission,
      inventory: normalized.inventory.copyWith(
        undo: normalized.inventory.undo + reward.undo,
        shuffle: normalized.inventory.shuffle + reward.shuffle,
        hint: normalized.inventory.hint + reward.hint,
      ),
    );
    return MissionClaimResult(
      claimed: true,
      status: MissionClaimStatus.success,
      updatedData: nextData,
      reward: reward,
    );
  }

  int _progressFor(
    MissionMetric metric,
    MissionScope scope,
    MissionState state,
  ) {
    if (scope == MissionScope.daily) {
      return switch (metric) {
        MissionMetric.clearLevels => state.dailyLevelsCleared,
        MissionMetric.useHints => state.dailyHintsUsed,
        MissionMetric.useShuffles => state.dailyShufflesUsed,
      };
    }
    return switch (metric) {
      MissionMetric.clearLevels => state.weeklyLevelsCleared,
      MissionMetric.useHints => state.weeklyHintsUsed,
      MissionMetric.useShuffles => state.weeklyShufflesUsed,
    };
  }

  int _dailyKey(DateTime date) {
    return (date.year * 10000) + (date.month * 100) + date.day;
  }

  int _weeklyKey(DateTime date) {
    final first = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(first).inDays + 1;
    final week = ((dayOfYear - 1) / 7).floor() + 1;
    return (date.year * 100) + week;
  }
}
