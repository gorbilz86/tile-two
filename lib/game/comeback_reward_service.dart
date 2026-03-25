import 'package:tile_two/game/save_game_repository.dart';

class ComebackRewardGrant {
  final int coins;
  final int undo;
  final int shuffle;
  final int hint;

  const ComebackRewardGrant({
    required this.coins,
    required this.undo,
    required this.shuffle,
    required this.hint,
  });

  bool get isEmpty =>
      coins <= 0 && undo <= 0 && shuffle <= 0 && hint <= 0;
}

class ComebackRewardResult {
  final bool claimed;
  final int absentDays;
  final ComebackRewardGrant grant;
  final SaveGameData updatedData;

  const ComebackRewardResult({
    required this.claimed,
    required this.absentDays,
    required this.grant,
    required this.updatedData,
  });
}

class ComebackRewardService {
  ComebackRewardService._();

  static final ComebackRewardService instance = ComebackRewardService._();
  static const int minAbsentDays = 3;

  ComebackRewardResult processLogin({
    required SaveGameData saveData,
    required DateTime now,
  }) {
    final today = _dayKey(now);
    final lastLogin = saveData.lastLoginDate;
    final lastComebackClaimDate = saveData.lastComebackClaimDate;

    var updated = saveData.copyWith(lastLoginDate: today);
    if (lastLogin == null) {
      return ComebackRewardResult(
        claimed: false,
        absentDays: 0,
        grant: const ComebackRewardGrant(
          coins: 0,
          undo: 0,
          shuffle: 0,
          hint: 0,
        ),
        updatedData: updated,
      );
    }

    final absentDays = _absentDays(lastLogin, now);
    if (absentDays < minAbsentDays || lastComebackClaimDate == today) {
      return ComebackRewardResult(
        claimed: false,
        absentDays: absentDays,
        grant: const ComebackRewardGrant(
          coins: 0,
          undo: 0,
          shuffle: 0,
          hint: 0,
        ),
        updatedData: updated,
      );
    }

    final grant = _grantForAbsentDays(absentDays);
    final nextInventory = updated.inventory.copyWith(
      undo: updated.inventory.undo + grant.undo,
      shuffle: updated.inventory.shuffle + grant.shuffle,
      hint: updated.inventory.hint + grant.hint,
    );
    updated = updated.copyWith(
      coins: updated.coins + grant.coins,
      inventory: nextInventory,
      lastComebackClaimDate: today,
    );

    return ComebackRewardResult(
      claimed: true,
      absentDays: absentDays,
      grant: grant,
      updatedData: updated,
    );
  }

  ComebackRewardGrant _grantForAbsentDays(int absentDays) {
    if (absentDays >= 14) {
      return const ComebackRewardGrant(
        coins: 380,
        undo: 1,
        shuffle: 2,
        hint: 2,
      );
    }
    if (absentDays >= 7) {
      return const ComebackRewardGrant(
        coins: 220,
        undo: 0,
        shuffle: 1,
        hint: 2,
      );
    }
    return const ComebackRewardGrant(
      coins: 120,
      undo: 0,
      shuffle: 0,
      hint: 1,
    );
  }

  int _absentDays(String lastLoginDate, DateTime now) {
    final parsed = DateTime.tryParse(lastLoginDate);
    if (parsed == null) {
      return 0;
    }
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(last).inDays;
    if (diff <= 1) {
      return 0;
    }
    return diff - 1;
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
