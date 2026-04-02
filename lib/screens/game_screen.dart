import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:tile_two/game/economy_service.dart';
import 'package:tile_two/game/game_audio_service.dart';

import 'package:tile_two/l10n/app_i18n.dart';
import 'package:tile_two/game/rewarded_ads_service.dart';
import 'package:tile_two/ui/game_buttons.dart';
import 'package:tile_two/ui/google_fonts_proxy.dart';
import 'package:tile_two/game/tile_game.dart';

/// Main Game Screen - Portrait Optimization
///
/// Combines the Flame Game Canvas with Flutter UI Overlays.
class GameScreen extends StatefulWidget {
  final int? initialLevel;

  const GameScreen({
    super.key,
    this.initialLevel,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final GameAudioService _audio = GameAudioService.instance;
  final RewardedAdsService _rewardedAds = RewardedAdsService.instance;
  late final TileGame _game;
  bool _isSettingsOpen = false;
  bool _isOnboardingOpen = false;
  final bool _isSfxEnabled = true;
  bool _isRewardedBusy = false;
  String _rewardNotice = '';
  int _onboardingStep = 0;
  int _lastLevelWinSignal = 0;
  int _lastLevelStartSignal = 0;
  int _lastTapTileSfxSignal = 0;
  int _lastSmartHintSignal = 0;
  int _lastRareDropSignalLevel = 0;
  int _lastLevelCompleteCueSignal = 0;
  bool _lastGameOverState = false;

  List<_OnboardingStep> _onboardingSteps(AppI18n t) {
    return [
      _OnboardingStep(
        title: t.tr('tutorial.step1.title'),
        description: t.tr('tutorial.step1.description'),
      ),
      _OnboardingStep(
        title: t.tr('tutorial.step2.title'),
        description: t.tr('tutorial.step2.description'),
      ),
      _OnboardingStep(
        title: t.tr('tutorial.step3.title'),
        description: t.tr('tutorial.step3.description'),
      ),
      _OnboardingStep(
        title: t.tr('tutorial.step4.title'),
        description: t.tr('tutorial.step4.description'),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _game = TileGame(
      footerReservedHeight: 175,
      initialLevel: widget.initialLevel,
    );
    unawaited(_rewardedAds.syncAdPressureConfig());
    unawaited(_rewardedAds.warmUp());
    _initAudio();
    _game.onboardingRequiredNotifier
        .addListener(_handleOnboardingRequiredChanged);
    _game.levelWinTriggerNotifier.addListener(_handleLevelWinTrigger);
    _game.levelStartTriggerNotifier.addListener(_handleLevelStartTrigger);
    _game.slotFullWarningTriggerNotifier.addListener(_handleSlotFullWarningTrigger);
    _game.isGameOverNotifier.addListener(_handleGameOverStateChanged);
    _game.tapTileSfxTriggerNotifier.addListener(_handleTapTileSfxTrigger);
    _game.matchSfxNotifier.addListener(_handleMatchSfxTrigger);
    _game.smartHintTriggerNotifier.addListener(_handleSmartHintTrigger);
    _game.levelCompleteCueTriggerNotifier.addListener(_handleLevelCompleteCueTrigger);
    _game.rareItemDropNotifier.addListener(_handleRareItemDropNotice);
  }

  Future<void> _initAudio() async {
    await _audio.init();
    if (!mounted) {
      return;
    }

    await _audio.playGameLoop();
  }

  @override
  void dispose() {
    _game.onboardingRequiredNotifier
        .removeListener(_handleOnboardingRequiredChanged);
    _game.smartHintTriggerNotifier.removeListener(_handleSmartHintTrigger);
    _game.levelCompleteCueTriggerNotifier.removeListener(_handleLevelCompleteCueTrigger);
    _game.rareItemDropNotifier.removeListener(_handleRareItemDropNotice);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    _game.topOffset = topPadding;

    return ValueListenableBuilder<int>(
      valueListenable: _game.levelNotifier,
      builder: (context, level, _) {
        final bgIndex = ((level - 1) ~/ 5 % 10) + 1;
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background$bgIndex.png'),
              fit: BoxFit
                  .cover, // Ensures the background fills the entire device screen
            ),
          ),
          child: Stack(
            children: [
          // 1. The Game Loop Canvas (Flame)
          Positioned.fill(
            child: GameWidget(game: _game),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: _game.isGameOverNotifier,
            builder: (context, isGameOver, child) {
              if (!isGameOver) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withAlpha(140),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(210),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withAlpha(90), width: 1.4),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.tr('game.over.title'),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 160,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _retryFromFailScreen,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC400),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: Text(
                                t.tr('game.retry'),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 190,
                            height: 40,
                            child: ElevatedButton(
                              onPressed:
                                  _isRewardedBusy ? null : _watchRewardedRevive,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C4A5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                disabledBackgroundColor:
                                    const Color(0xFF00C4A5).withAlpha(120),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: Text(
                                _isRewardedBusy
                                    ? t.tr('common.processing_ad')
                                    : t.tr('game.revive_via_ad'),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (_rewardNotice.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _rewardNotice,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white.withAlpha(200),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. UI Layer (Flutter Overlays)
          Positioned.fill(
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top: Level and Game Stats
                  _buildHeader(),

                  // Bottom: Action Buttons
                  _buildFooter(),
                ],
              ),
            ),
          ),
          if (_isSettingsOpen) _buildSettingsOverlay(),
          if (_isOnboardingOpen) _buildOnboardingOverlay(),
          _buildLevelCompletePopup(),
          if (_isRewardedBusy) _buildAdLoadingOverlay(),
        ],
      ),
    );
      },
    );
  }

  Widget _buildHeader() {
    final t = AppI18n.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2.0, left: 12, right: 12),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: _game.levelBannerNotifier,
              builder: (context, label, child) {
                final displayLabel = label.replaceAll(' Complete', '');
                final localized = _localizedLevelBanner(t, displayLabel);
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  transitionBuilder: (child, animation) {
                    final fade = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    );
                    final scaleCurve = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    );
                    return FadeTransition(
                      opacity: fade,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1).animate(scaleCurve),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    localized,
                    key: ValueKey(localized),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.55,
                      shadows: const [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _openSettings,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 24,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedLevelBanner(AppI18n t, String rawLabel) {
    final match = RegExp(r'^Level (\d+)( Complete)?$').firstMatch(rawLabel);
    if (match == null) {
      return rawLabel;
    }
    final level = match.group(1) ?? '';
    if ((match.group(2) ?? '').isNotEmpty) {
      return t.tr('game.level_complete', params: {'level': level});
    }
    return t.tr('game.level', params: {'level': level});
  }

  Widget _buildLevelCompletePopup() {
    return Positioned.fill(
      child: ValueListenableBuilder<String>(
        valueListenable: _game.levelBannerNotifier,
        builder: (context, label, child) {
          if (!label.endsWith('Complete')) {
            return const SizedBox.shrink();
          }
          final t = AppI18n.of(context);
          final localized = _localizedLevelBanner(t, label);
          return Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(label),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(210),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withAlpha(180), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(150),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localized,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFD700),
                        letterSpacing: 1.0,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 170,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _proceedToNextLevelAuto,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            t.tr('common.next_level'),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeSettings,
        child: ColoredBox(
          color: Colors.black.withAlpha(160),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 304,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF102744).withAlpha(246),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFFBFE4FF).withAlpha(115),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(135),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: _buildSettingsContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    if (_isSettingsOpen) {
      return;
    }
    _game.pauseEngine();
    setState(() {
      _isSettingsOpen = true;
    });
  }

  void _closeSettings() {
    if (!_isSettingsOpen) {
      return;
    }
    setState(() {
      _isSettingsOpen = false;
    });
    _resumeGameIfNoOverlay();
  }



  Future<void> _onRestartPressed() async {
    _closeSettings();
    await _game.retryCurrentLevel();
  }

  void _onHomePressed() {
    _audio.playHomeLoop();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }





  Future<void> _retryFromFailScreen() async {
    if (_isRewardedBusy) {
      return;
    }
    await _maybeShowInterstitialAd(InterstitialPlacement.retryLevel);
    await _game.retryCurrentLevel();
  }

  Future<void> _watchRewardedRevive() async {
    final t = AppI18n.of(context);
    if (_isRewardedBusy || !_game.isGameOverNotifier.value) {
      return;
    }
    setState(() {
      _isRewardedBusy = true;
      _rewardNotice = '';
    });
    _game.pauseEngine();
    final ad = await _rewardedAds.showRewarded(
      placement: RewardedPlacement.revive,
    );
    _game.resumeEngine();
    if (!mounted) {
      return;
    }
    if (!ad.rewarded) {
      setState(() {
        _isRewardedBusy = false;
        _rewardNotice = t.tr('game.notice.ad_unavailable');
      });
      return;
    }
    final revived = await _game.reviveFromGameOver();
    if (!mounted) {
      return;
    }
    setState(() {
      _isRewardedBusy = false;
      _rewardNotice = revived
          ? t.tr('game.notice.revive_success')
          : t.tr('game.notice.revive_failed');
    });
  }


  void _onUndoPressed() {
    if (_game.undoBoosterNotifier.value <= 0) {
      _watchRewardedBooster(BoosterType.undo);
      return;
    }
    unawaited(_game.undoLastMove());
  }

  void _onShufflePressed() {
    final t = AppI18n.of(context);
    if (!_game.isBoosterUnlocked(BoosterType.shuffle)) {
      setState(() {
        _rewardNotice = t.tr(
          'game.notice.shuffle_unlock_at_level',
          params: {'level': '${_game.shuffleUnlockLevel}'},
        );
      });
      return;
    }
    if (_game.shuffleBoosterNotifier.value <= 0) {
      _watchRewardedBooster(BoosterType.shuffle);
      return;
    }
    unawaited(_game.shuffleBoard());
  }

  void _onHintPressed() {
    final t = AppI18n.of(context);
    if (!_game.isBoosterUnlocked(BoosterType.hint)) {
      setState(() {
        _rewardNotice = t.tr(
          'game.notice.hint_unlock_at_level',
          params: {'level': '${_game.hintUnlockLevel}'},
        );
      });
      return;
    }
    if (_game.hintBoosterNotifier.value <= 0) {
      _watchRewardedBooster(BoosterType.hint);
      return;
    }
    unawaited(_game.provideHint());
  }

  Future<void> _watchRewardedBooster(BoosterType type) async {
    final t = AppI18n.of(context);
    if (_isRewardedBusy) return;
    setState(() {
      _isRewardedBusy = true;
      _rewardNotice = '';
    });
    
    _game.pauseEngine();
    final ad = await _rewardedAds.showRewarded(
      placement: RewardedPlacement.booster,
    );
    _game.resumeEngine();

    if (!mounted) return;
    if (!ad.rewarded) {
      setState(() {
        _isRewardedBusy = false;
        _rewardNotice = t.tr('game.notice.ad_unavailable');
      });
      return;
    }
    await _game.buyBooster(type, amount: 1);
    if (!mounted) return;
    setState(() {
      _isRewardedBusy = false;
      _rewardNotice = t.tr('game.notice.reward_success');
    });
  }

  Future<void> _maybeShowInterstitialAd(InterstitialPlacement placement) async {
    if (_isRewardedBusy || _isOnboardingOpen) {
      return;
    }
    await _rewardedAds.maybeShowInterstitial(placement: placement);
  }

  void _handleOnboardingRequiredChanged() {
    if (!_game.onboardingRequiredNotifier.value || !mounted) {
      return;
    }
    _openOnboarding(resetStep: true);
  }

  void _handleLevelWinTrigger() {
    final signal = _game.levelWinTriggerNotifier.value;
    if (signal == _lastLevelWinSignal || !mounted) {
      return;
    }
    _lastLevelWinSignal = signal;
    // Disabled auto-transition per user request. 
    // Manual "Next Level" button now handles the transition.
    // _proceedToNextLevelAuto();
  }

  void _handleLevelCompleteCueTrigger() {
    final signal = _game.levelCompleteCueTriggerNotifier.value;
    if (signal == _lastLevelCompleteCueSignal || !mounted) {
      return;
    }
    _lastLevelCompleteCueSignal = signal;
    if (_isSfxEnabled) {
      unawaited(_audio.playLevelCompleteCue());
    }
  }

  void _handleLevelStartTrigger() {
    final signal = _game.levelStartTriggerNotifier.value;
    if (signal == _lastLevelStartSignal || !mounted) {
      return;
    }
    _lastLevelStartSignal = signal;
    if (_isSfxEnabled) {
      unawaited(_audio.playGameStartCue());
    }
  }

  void _handleSlotFullWarningTrigger() {
    if (!mounted || !_isSfxEnabled) {
      return;
    }
    unawaited(_audio.playSlotWarningCue());
  }

  void _handleGameOverStateChanged() {
    final nextState = _game.isGameOverNotifier.value;
    if (nextState == _lastGameOverState) {
      return;
    }
    _lastGameOverState = nextState;
    if (!nextState || !_isSfxEnabled) {
      return;
    }
    unawaited(_audio.playGameOverCue());
  }

  void _handleSmartHintTrigger() {
    final signal = _game.smartHintTriggerNotifier.value;
    if (signal == _lastSmartHintSignal || !mounted) {
      return;
    }
    _lastSmartHintSignal = signal;
    // Removed smart hint text notice as requested by user
    if (_isSfxEnabled) {
      unawaited(_audio.playTapTileCue());
    }
  }

  void _handleMatchSfxTrigger() {
    final event = _game.matchSfxNotifier.value;
    if (event == null || !_isSfxEnabled) {
      return;
    }
    unawaited(_audio.playMatchCue(combo: event.combo));
  }

  void _handleTapTileSfxTrigger() {
    final signal = _game.tapTileSfxTriggerNotifier.value;
    if (signal == _lastTapTileSfxSignal || !_isSfxEnabled) {
      return;
    }
    _lastTapTileSfxSignal = signal;
    unawaited(_audio.playTapTileCue());
  }

  void _handleRareItemDropNotice() {
    final event = _game.rareItemDropNotifier.value;
    if (event == null || !mounted) {
      return;
    }
    final dedupeKey = (event.level * 10) + event.spriteIndex;
    if (dedupeKey == _lastRareDropSignalLevel) {
      return;
    }
    _lastRareDropSignalLevel = dedupeKey;
    // Rare Item drop logic: notification text removed as requested.
    if (_isSfxEnabled) {
      unawaited(_audio.playRareItemCue());
    }
  }



  void _openOnboarding({required bool resetStep}) {
    _game.pauseEngine();
    setState(() {
      _isSettingsOpen = false;
      _isOnboardingOpen = true;
      if (resetStep) {
        _onboardingStep = 0;
      }
    });
  }

  Future<void> _finishOnboarding() async {
    await _game.completeOnboarding();
    if (!mounted) {
      return;
    }
    setState(() {
      _isOnboardingOpen = false;
      _onboardingStep = 0;
    });
    _resumeGameIfNoOverlay();
  }

  void _nextOnboardingStep() {
    final t = AppI18n.of(context);
    final onboardingSteps = _onboardingSteps(t);
    if (_onboardingStep >= onboardingSteps.length - 1) {
      _finishOnboarding();
      return;
    }
    setState(() {
      _onboardingStep += 1;
    });
  }

  void _previousOnboardingStep() {
    if (_onboardingStep == 0) {
      return;
    }
    setState(() {
      _onboardingStep -= 1;
    });
  }

  void _skipOnboarding() {
    _finishOnboarding();
  }

  Future<void> _proceedToNextLevelAuto() async {
    _game.pauseEngine();
    await _maybeShowInterstitialAd(InterstitialPlacement.levelComplete);
    _resumeGameIfNoOverlay();
    
    await _game.continueAfterLevelWin();
    if (!mounted) {
      return;
    }
    // Milestone and level notices removed as requested by user
  }

  void _resumeGameIfNoOverlay() {
    if (_isSettingsOpen || _isOnboardingOpen) {
      return;
    }
    _game.resumeEngine();
  }

  Widget _buildSettingsContent() {
    final t = AppI18n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSettingsActionButton(
          label: t.tr('common.restart'),
          colorStart: const Color(0xFF5569FF),
          colorEnd: const Color(0xFF3F51D6),
          onTap: _onRestartPressed,
        ),
        const SizedBox(height: 14),
        _buildSettingsActionButton(
          label: t.tr('common.home'),
          colorStart: const Color(0xFF8A5CFF),
          colorEnd: const Color(0xFF6A46D6),
          onTap: _onHomePressed,
        ),
      ],
    );
  }



  Widget _buildOnboardingOverlay() {
    final t = AppI18n.of(context);
    final onboardingSteps = _onboardingSteps(t);
    final step = onboardingSteps[_onboardingStep];
    final isLastStep = _onboardingStep == onboardingSteps.length - 1;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withAlpha(178),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF102744).withAlpha(246),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFFBFE4FF).withAlpha(120), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(135),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.tr(
                    'tutorial.progress',
                    params: {
                      'current': '${_onboardingStep + 1}',
                      'total': '${onboardingSteps.length}',
                    },
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFBEE0FF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  step.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withAlpha(222),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(onboardingSteps.length, (index) {
                    final active = index == _onboardingStep;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF56D4FF)
                            : Colors.white.withAlpha(80),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildOverlayActionButton(
                        label: t.tr('common.skip'),
                        onTap: _skipOnboarding,
                        start: const Color(0xFF5A6783),
                        end: const Color(0xFF45526B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverlayActionButton(
                        label: _onboardingStep == 0
                            ? t.tr('common.back')
                            : t.tr('common.prev'),
                        onTap: _previousOnboardingStep,
                        start: const Color(0xFF3B4A66),
                        end: const Color(0xFF2E3B56),
                        disabled: _onboardingStep == 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverlayActionButton(
                        label: isLastStep
                            ? t.tr('common.start')
                            : t.tr('common.next'),
                        onTap: _nextOnboardingStep,
                        start: const Color(0xFF00C896),
                        end: const Color(0xFF00A27C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }




  Widget _buildOverlayActionButton({
    required String label,
    required VoidCallback onTap,
    required Color start,
    required Color end,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.42 : 1,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [start, end],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(165), width: 1.2),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildSettingsActionButton({
    required String label,
    required Color colorStart,
    required Color colorEnd,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    final button = Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorStart, colorEnd],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(194), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(66),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: Colors.white.withAlpha(disabled ? 150 : 245),
            height: 1,
          ),
        ),
      ),
    );

    if (disabled) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.44,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.33,
              0.33,
              0.33,
              0,
              0,
              0.33,
              0.33,
              0.33,
              0,
              0,
              0.33,
              0.33,
              0.33,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: button,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: button,
    );
  }

  Widget _buildAdLoadingOverlay() {
    final t = AppI18n.of(context);
    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(40), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: Color(0xFF00FFD1),
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t.tr('common.processing_ad'),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final t = AppI18n.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 34),
          ValueListenableBuilder<bool>(
            valueListenable: _game.shuffleUnlockedNotifier,
            builder: (context, shuffleUnlocked, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _game.hintUnlockedNotifier,
                builder: (context, hintUnlocked, __) {
                  return ValueListenableBuilder<int>(
                    valueListenable: _game.undoBoosterNotifier,
                    builder: (context, undoStock, ___) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _game.shuffleBoosterNotifier,
                        builder: (context, shuffleStock, ____) {
                          return ValueListenableBuilder<int>(
                            valueListenable: _game.hintBoosterNotifier,
                            builder: (context, hintStock, _____) {
                              return GameButtons(
                                onUndo: _onUndoPressed,
                                onShuffle: _onShufflePressed,
                                onHint: _onHintPressed,
                                undoStock: undoStock,
                                shuffleStock: shuffleStock,
                                hintStock: hintStock,
                                shuffleUnlocked: shuffleUnlocked,
                                hintUnlocked: hintUnlocked,
                                shuffleUnlockLevel: _game.shuffleUnlockLevel,
                                hintUnlockLevel: _game.hintUnlockLevel,
                                levelShortLabel: t.tr('common.level_short'),
                                onAdHint: null, // Removed gift icon from gameButtons as requested
                                isAdBusy: _isRewardedBusy,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  final String title;
  final String description;

  const _OnboardingStep({
    required this.title,
    required this.description,
  });
}
