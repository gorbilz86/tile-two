import 'package:tile_two/game/save_game_repository.dart';

class DailyLoginRewardGrant {
  final int undo;
  final int shuffle;
  final int hint;

  const DailyLoginRewardGrant({
    required this.undo,
    required this.shuffle,
    required this.hint,
  });

  bool get isEmpty => undo <= 0 && shuffle <= 0 && hint <= 0;
}

class DailyLoginRewardResult {
  final bool claimedToday;
  final bool streakReset;
  final int streak;
  final DailyLoginRewardGrant grant;
  final SaveGameData updatedData;

  const DailyLoginRewardResult({
    required this.claimedToday,
    required this.streakReset,
    required this.streak,
    required this.grant,
    required this.updatedData,
  });
}

class DailyLoginRewardService {
  DailyLoginRewardService._();

  static final DailyLoginRewardService instance = DailyLoginRewardService._();

  DailyLoginRewardResult claimIfEligible({
    required SaveGameData saveData,
    required DateTime now,
  }) {
    final today = _dayKey(now);
    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
    final lastClaim = saveData.lastDailyClaimDate;
    if (lastClaim == today) {
      return DailyLoginRewardResult(
        claimedToday: false,
        streakReset: false,
        streak: saveData.dailyLoginStreak,
        grant: const DailyLoginRewardGrant(undo: 0, shuffle: 0, hint: 0),
        updatedData: saveData,
      );
    }
    final isContinuing = lastClaim == yesterday;
    final streak = isContinuing ? (saveData.dailyLoginStreak + 1) : 1;
    final cappedStreak = streak.clamp(1, 999);
    final grant = _grantForStreak(cappedStreak);
    final nextInventory = saveData.inventory.copyWith(
      undo: saveData.inventory.undo + grant.undo,
      shuffle: saveData.inventory.shuffle + grant.shuffle,
      hint: saveData.inventory.hint + grant.hint,
    );
    final updated = saveData.copyWith(
      dailyLoginStreak: cappedStreak,
      lastDailyClaimDate: today,
      inventory: nextInventory,
    );
    return DailyLoginRewardResult(
      claimedToday: true,
      streakReset: lastClaim != null && !isContinuing,
      streak: cappedStreak,
      grant: grant,
      updatedData: updated,
    );
  }

  DailyLoginRewardGrant _grantForStreak(int streak) {
    final day = ((streak - 1) % 7) + 1;
    return switch (day) {
      1 => const DailyLoginRewardGrant(undo: 0, shuffle: 0, hint: 1),
      2 => const DailyLoginRewardGrant(undo: 1, shuffle: 0, hint: 0),
      3 => const DailyLoginRewardGrant(undo: 0, shuffle: 1, hint: 0),
      4 => const DailyLoginRewardGrant(undo: 0, shuffle: 0, hint: 2),
      5 => const DailyLoginRewardGrant(undo: 2, shuffle: 0, hint: 0),
      6 => const DailyLoginRewardGrant(undo: 0, shuffle: 2, hint: 0),
      _ => const DailyLoginRewardGrant(undo: 1, shuffle: 1, hint: 3),
    };
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
