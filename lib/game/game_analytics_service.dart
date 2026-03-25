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

  void trackAdRequest({
    required String adType,
    required String placement,
  }) {
    _emit(
      event: 'ad_request',
      parameters: {
        'ad_type': adType,
        'placement': placement,
      },
    );
  }

  void trackAdImpression({
    required String adType,
    required String placement,
  }) {
    _emit(
      event: 'ad_impression',
      parameters: {
        'ad_type': adType,
        'placement': placement,
      },
    );
  }

  void trackAdClick({
    required String adType,
    required String placement,
  }) {
    _emit(
      event: 'ad_click',
      parameters: {
        'ad_type': adType,
        'placement': placement,
      },
    );
  }

  void trackRewardedComplete({
    required String placement,
  }) {
    _emit(
      event: 'rewarded_complete',
      parameters: {
        'ad_type': 'rewarded',
        'placement': placement,
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
