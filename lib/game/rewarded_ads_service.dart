import 'dart:async';

import 'package:tile_two/game/ad_pressure_remote_config_service.dart';

enum RewardedPlacement {
  revive,
  bonusHint,
}

enum InterstitialPlacement {
  levelComplete,
  retryLevel,
}

class RewardedAdResult {
  final bool shown;
  final bool rewarded;

  const RewardedAdResult({
    required this.shown,
    required this.rewarded,
  });
}

class InterstitialAdResult {
  final bool shown;
  final bool blockedByCooldown;
  final bool blockedByFrequencyCap;

  const InterstitialAdResult({
    required this.shown,
    this.blockedByCooldown = false,
    this.blockedByFrequencyCap = false,
  });
}

class RewardedAdsService {
  RewardedAdsService._();

  static final RewardedAdsService instance = RewardedAdsService._();

  bool _isReady = false;
  bool _isShowing = false;
  final List<DateTime> _interstitialShownTimes = [];
  DateTime? _lastInterstitialShownAt;
  int _interstitialTriggerIndex = 0;
  int _lastInterstitialTriggerIndex = -999;

  Duration interstitialCooldown = const Duration(seconds: 90);
  Duration interstitialWindow = const Duration(minutes: 10);
  int maxInterstitialPerWindow = 3;
  int minTriggersBetweenInterstitial = 2;
  bool _syncingAdPressureConfig = false;

  bool get isReady => _isReady;
  bool get isShowing => _isShowing;

  Future<void> syncAdPressureConfig() async {
    if (_syncingAdPressureConfig) {
      return;
    }
    _syncingAdPressureConfig = true;
    try {
      final fallback = AdPressureConfig(
        interstitialCooldown: interstitialCooldown,
        interstitialWindow: interstitialWindow,
        maxInterstitialPerWindow: maxInterstitialPerWindow,
        minTriggersBetweenInterstitial: minTriggersBetweenInterstitial,
      );
      final cached = await AdPressureRemoteConfigService.instance.loadCached(
        fallback: fallback,
      );
      if (cached != null) {
        _applyAdPressureConfig(cached);
      }
      final remote = await AdPressureRemoteConfigService.instance.fetchAndCache(
        fallback: fallback,
      );
      if (remote != null) {
        _applyAdPressureConfig(remote);
      }
    } finally {
      _syncingAdPressureConfig = false;
    }
  }

  void _applyAdPressureConfig(AdPressureConfig config) {
    interstitialCooldown = config.interstitialCooldown;
    interstitialWindow = config.interstitialWindow;
    maxInterstitialPerWindow = config.maxInterstitialPerWindow;
    minTriggersBetweenInterstitial = config.minTriggersBetweenInterstitial;
  }

  Future<void> warmUp() async {
    if (_isReady) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _isReady = true;
  }

  Future<RewardedAdResult> showRewarded({
    required RewardedPlacement placement,
  }) async {
    if (_isShowing) {
      return const RewardedAdResult(shown: false, rewarded: false);
    }
    if (!_isReady) {
      await warmUp();
    }
    _isShowing = true;
    try {
      final waitMs = placement == RewardedPlacement.revive ? 1450 : 1200;
      await Future<void>.delayed(Duration(milliseconds: waitMs));
      return const RewardedAdResult(shown: true, rewarded: true);
    } finally {
      _isShowing = false;
    }
  }

  Future<InterstitialAdResult> maybeShowInterstitial({
    required InterstitialPlacement placement,
  }) async {
    _interstitialTriggerIndex += 1;
    if (_isShowing) {
      return const InterstitialAdResult(shown: false);
    }
    if (!_isReady) {
      await warmUp();
    }
    final now = DateTime.now();
    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!) < interstitialCooldown) {
      return const InterstitialAdResult(
        shown: false,
        blockedByCooldown: true,
      );
    }
    _interstitialShownTimes
        .removeWhere((time) => now.difference(time) > interstitialWindow);
    if (_interstitialShownTimes.length >= maxInterstitialPerWindow) {
      return const InterstitialAdResult(
        shown: false,
        blockedByFrequencyCap: true,
      );
    }
    final triggerGap =
        _interstitialTriggerIndex - _lastInterstitialTriggerIndex;
    if (triggerGap < minTriggersBetweenInterstitial) {
      return const InterstitialAdResult(
        shown: false,
        blockedByFrequencyCap: true,
      );
    }
    _isShowing = true;
    try {
      final waitMs = switch (placement) {
        InterstitialPlacement.levelComplete => 980,
        InterstitialPlacement.retryLevel => 760,
      };
      await Future<void>.delayed(Duration(milliseconds: waitMs));
      _lastInterstitialShownAt = DateTime.now();
      _interstitialShownTimes.add(_lastInterstitialShownAt!);
      _lastInterstitialTriggerIndex = _interstitialTriggerIndex;
      return const InterstitialAdResult(shown: true);
    } finally {
      _isShowing = false;
    }
  }
}
