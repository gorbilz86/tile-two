import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tile_two/game/ad_pressure_remote_config_service.dart';
import 'package:tile_two/game/game_analytics_service.dart';

enum RewardedPlacement {
  revive,
  bonusHint,
  booster,
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
  final GameAnalyticsService _analytics = GameAnalyticsService.instance;

  bool _isReady = false;
  bool _isShowing = false;
  final List<DateTime> _interstitialShownTimes = [];
  DateTime? _lastInterstitialShownAt;
  int _interstitialTriggerIndex = 0;
  int _lastInterstitialTriggerIndex = -999;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  Duration interstitialCooldown = const Duration(seconds: 90);
  Duration interstitialWindow = const Duration(minutes: 10);
  int maxInterstitialPerWindow = 3;
  int minTriggersBetweenInterstitial = 2;
  bool _syncingAdPressureConfig = false;
  RewardedAd? _rewardedAd;
  bool _isLoadingRewarded = false;

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
    unawaited(_loadInterstitialAd());
    unawaited(_loadRewardedAd());
  }

  Future<void> _loadRewardedAd() async {
    if (_rewardedAd != null || _isLoadingRewarded) {
      return;
    }
    _isLoadingRewarded = true;
    final adUnitId = Platform.isAndroid 
        ? 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-3940256099942544/1712485313';

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoadingRewarded = false;
          // Retry loading after a delay (e.g., 10 seconds)
          Future.delayed(const Duration(seconds: 10), _loadRewardedAd);
        },
      ),
    );
  }

  Future<void> _loadInterstitialAd() async {
    if (_interstitialAd != null || _isInterstitialLoading) {
      return;
    }
    _isInterstitialLoading = true;
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  Future<BannerAd> loadBannerAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) async {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';

    final banner = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    );

    await banner.load();
    return banner;
  }

  Future<RewardedAdResult> showRewarded({
    required RewardedPlacement placement,
  }) async {
    final placementName = placement.name;
    _analytics.trackAdRequest(
      adType: 'rewarded',
      placement: placementName,
    );
    if (_isShowing) {
      return const RewardedAdResult(shown: false, rewarded: false);
    }
    if (!_isReady) {
      await warmUp();
    }

    if (_rewardedAd == null) {
      unawaited(_loadRewardedAd());
      // On-demand load if cache empty (fallback)
      final tempAdCompleter = Completer<RewardedAdResult>();
      final adUnitId = Platform.isAndroid 
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
      
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _showRewardedAdInternal(ad, placementName, tempAdCompleter);
          },
          onAdFailedToLoad: (error) {
            tempAdCompleter.complete(const RewardedAdResult(shown: false, rewarded: false));
          },
        ),
      );
      
      try {
        return await tempAdCompleter.future;
      } finally {
        _isShowing = false;
      }
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    final completer = Completer<RewardedAdResult>();
    _showRewardedAdInternal(ad, placementName, completer);
    
    unawaited(_loadRewardedAd()); // Load next one

    try {
      return await completer.future;
    } finally {
      _isShowing = false;
    }
  }

  void _showRewardedAdInternal(
    RewardedAd ad, 
    String placementName, 
    Completer<RewardedAdResult> completer
  ) {
    bool userRewarded = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _analytics.trackAdImpression(
          adType: 'rewarded',
          placement: placementName,
        );
      },
      onAdClicked: (ad) {
        _analytics.trackAdClick(
          adType: 'rewarded',
          placement: placementName,
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd(); // Ensure next ad is pre-loading
        if (!completer.isCompleted) {
          completer.complete(RewardedAdResult(shown: true, rewarded: userRewarded));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(const RewardedAdResult(shown: false, rewarded: false));
        }
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      userRewarded = true;
      _analytics.trackRewardedComplete(
        placement: placementName,
      );
    });
  }

  Future<InterstitialAdResult> maybeShowInterstitial({
    required InterstitialPlacement placement,
  }) async {
    final placementName = placement.name;
    _analytics.trackAdRequest(
      adType: 'interstitial',
      placement: placementName,
    );
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

      if (_interstitialAd == null) {
        unawaited(_loadInterstitialAd());
        await Future<void>.delayed(Duration(milliseconds: waitMs));
        return const InterstitialAdResult(shown: false);
      }

      await Future<void>.delayed(Duration(milliseconds: waitMs));
      
      final completer = Completer<InterstitialAdResult>();

      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          _analytics.trackAdImpression(
            adType: 'interstitial',
            placement: placementName,
          );
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          unawaited(_loadInterstitialAd());
          if (!completer.isCompleted) {
            completer.complete(const InterstitialAdResult(shown: true));
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          unawaited(_loadInterstitialAd());
          if (!completer.isCompleted) {
            completer.complete(const InterstitialAdResult(shown: false));
          }
        },
      );

      _lastInterstitialShownAt = DateTime.now();
      _interstitialShownTimes.add(_lastInterstitialShownAt!);
      _lastInterstitialTriggerIndex = _interstitialTriggerIndex;

      await _interstitialAd!.show();
      return await completer.future;
    } finally {
      _isShowing = false;
    }
  }
}
