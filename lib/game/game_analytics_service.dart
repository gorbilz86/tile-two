import 'package:flutter/foundation.dart';

class GameAnalyticsService {
  GameAnalyticsService._();

  static final GameAnalyticsService instance = GameAnalyticsService._();
  bool _sessionStarted = false;

  void trackSessionStart() {
    if (_sessionStarted) {
      return;
    }
    _sessionStarted = true;
    _emit(
      event: 'session_start',
      parameters: const {},
    );
  }

  void trackLevelStart({required int level}) {
    _emit(
      event: 'level_start',
      parameters: {
        'level': level,
      },
    );
  }

  void trackLevelFail({
    required int level,
    required int slotUsed,
    required int slotCapacity,
  }) {
    _emit(
      event: 'level_fail',
      parameters: {
        'level': level,
        'slot_used': slotUsed,
        'slot_capacity': slotCapacity,
      },
    );
  }

  void trackLevelClear({
    required int level,
    required int streak,
  }) {
    _emit(
      event: 'level_clear',
      parameters: {
        'level': level,
        'streak': streak,
      },
    );
  }

  void _emit({
    required String event,
    required Map<String, Object> parameters,
  }) {
    final payload = parameters.entries.map((entry) => '${entry.key}=${entry.value}').join(',');
    if (payload.isEmpty) {
      debugPrint('[analytics] $event');
      return;
    }
    debugPrint('[analytics] $event|$payload');
  }
}
