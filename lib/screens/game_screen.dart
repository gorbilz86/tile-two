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
  bool _isLevelsPanelOpen = false;
  bool _isOnboardingOpen = false;
  bool _isSfxEnabled = true;
  bool _isMusicEnabled = true;
  bool _isRewardedBusy = false;
  String _settingsNotice = '';
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
    setState(() {
      _isMusicEnabled = _audio.musicEnabled;
    });
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

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
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
                      margin: const EdgeInsets.symmetric(horizontal: 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(170),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: Colors.white.withAlpha(70), width: 1.6),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.tr('game.over.title'),
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.tr('game.over.description'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withAlpha(220),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 180,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _retryFromFailScreen,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC400),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                t.tr('game.retry'),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 220,
                            height: 44,
                            child: ElevatedButton(
                              onPressed:
                                  _isRewardedBusy ? null : _watchRewardedRevive,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C4A5),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF00C4A5).withAlpha(120),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                _isRewardedBusy
                                    ? t.tr('common.processing_ad')
                                    : t.tr('game.revive_via_ad'),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (_rewardNotice.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              _rewardNotice,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withAlpha(220),
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
        ],
      ),
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
                      fontSize: 18,
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
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<int>(
                valueListenable: _game.coinNotifier,
                builder: (context, coins, _) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(66),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withAlpha(120)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/coin_icon.png',
                          width: 18,
                          height: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$coins',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
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
                    size: 31,
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
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(200),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withAlpha(150), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
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
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFD700),
                        letterSpacing: 1.2,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 200,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(100),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _proceedToNextLevelAuto,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: Text(
                            t.tr('common.next_level'),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
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
                width: _isLevelsPanelOpen ? 324 : 304,
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
                child: _isLevelsPanelOpen
                    ? _buildLevelsContent()
                    : _buildSettingsContent(),
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
      _isLevelsPanelOpen = false;
      _settingsNotice = '';
    });
  }

  void _closeSettings() {
    if (!_isSettingsOpen) {
      return;
    }
    setState(() {
      _isSettingsOpen = false;
      _isLevelsPanelOpen = false;
      _settingsNotice = '';
    });
    _resumeGameIfNoOverlay();
  }

  void _toggleSfx() {
    setState(() {
      _isSfxEnabled = !_isSfxEnabled;
    });
  }

  Future<void> _toggleMusic() async {
    final nextValue = !_isMusicEnabled;
    await _audio.setMusicEnabled(nextValue);
    if (nextValue) {
      await _audio.playGameLoop();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isMusicEnabled = nextValue;
    });
  }

  Future<void> _onRestartPressed() async {
    _closeSettings();
    await _game.retryCurrentLevel();
  }

  void _onHomePressed() {
    _audio.playHomeLoop();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _onLevelsPressed() {
    setState(() {
      _settingsNotice = '';
      _isLevelsPanelOpen = true;
    });
  }

  void _onTutorialPressed() {
    _openOnboarding(resetStep: true);
  }

  void _closeLevelsPanel() {
    setState(() {
      _isLevelsPanelOpen = false;
    });
  }

  Future<void> _onLevelSelected(int level) async {
    _closeSettings();
    await _game.selectLevel(level);
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
    final ad = await _rewardedAds.showRewarded(
      placement: RewardedPlacement.revive,
    );
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

  Future<void> _watchRewardedBonusHint() async {
    final t = AppI18n.of(context);
    if (_isRewardedBusy || _isOnboardingOpen) {
      return;
    }
    setState(() {
      _isRewardedBusy = true;
      _rewardNotice = '';
    });
    final ad = await _rewardedAds.showRewarded(
      placement: RewardedPlacement.bonusHint,
    );
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
    await _game.grantBonusHint(amount: 1);
    if (!mounted) {
      return;
    }
    setState(() {
      _isRewardedBusy = false;
      _rewardNotice = t.tr('game.notice.hint_added');
    });
  }

  void _onUndoPressed() {
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
    unawaited(_game.provideHint());
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
      _isLevelsPanelOpen = false;
      _settingsNotice = '';
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
    final t = AppI18n.of(context);
    final wasShuffleUnlocked = _game.shuffleUnlockedNotifier.value;
    final wasHintUnlocked = _game.hintUnlockedNotifier.value;
    
    _game.pauseEngine();
    await _maybeShowInterstitialAd(InterstitialPlacement.levelComplete);
    _resumeGameIfNoOverlay();
    
    await _game.continueAfterLevelWin();
    if (!mounted) {
      return;
    }
    final unlockedNotice = <String>[];
    if (!wasShuffleUnlocked && _game.shuffleUnlockedNotifier.value) {
      unlockedNotice.add(t.tr('game.notice.shuffle_milestone_unlocked'));
    }
    if (!wasHintUnlocked && _game.hintUnlockedNotifier.value) {
      unlockedNotice.add(t.tr('game.notice.hint_milestone_unlocked'));
    }
    if (unlockedNotice.isNotEmpty) {
      setState(() {
        _rewardNotice = unlockedNotice.join(' • ');
      });
    }
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
        if (_settingsNotice.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF122035),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(42)),
            ),
            child: Text(
              _settingsNotice,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFBEE0FF),
              ),
            ),
          ),
        Text(
          t.tr('settings.title'),
          style: GoogleFonts.poppins(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFE7F4FF),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSoundToggleButton(
                icon: Icons.volume_up_rounded,
                active: _isSfxEnabled,
                onTap: _toggleSfx,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSoundToggleButton(
                icon: Icons.music_note_rounded,
                active: _isMusicEnabled,
                onTap: _toggleMusic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<int>(
          valueListenable: _game.coinNotifier,
          builder: (context, coins, _) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF173254),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(80)),
              ),
              child: Text(
                t.tr('game.coin_label', params: {'coins': '$coins'}),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFE08A),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: t.tr('common.continue'),
          colorStart: const Color(0xFF00C896),
          colorEnd: const Color(0xFF00A27C),
          onTap: _closeSettings,
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: t.tr('common.restart'),
          colorStart: const Color(0xFF5569FF),
          colorEnd: const Color(0xFF3F51D6),
          onTap: _onRestartPressed,
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: t.tr('common.home'),
          colorStart: const Color(0xFF8A5CFF),
          colorEnd: const Color(0xFF6A46D6),
          onTap: _onHomePressed,
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: t.tr('common.tutorial'),
          colorStart: const Color(0xFF28B8C7),
          colorEnd: const Color(0xFF1F8F9B),
          onTap: _onTutorialPressed,
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: t.tr('common.levels'),
          colorStart: const Color(0xFFFF7A59),
          colorEnd: const Color(0xFFD85A3E),
          onTap: _onLevelsPressed,
        ),
      ],
    );
  }

  Widget _buildLevelsContent() {
    final t = AppI18n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _closeLevelsPanel,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A63),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(110)),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.tr('levels.title'),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE7F4FF),
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 36),
          ],
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<int>(
          valueListenable: _game.progressNotifier,
          builder: (context, completedLevels, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _game.levelNotifier,
              builder: (context, currentLevel, __) {
                final unlockedByProgress = (completedLevels + 1).clamp(
                  TileGame.minLevel,
                  _game.maxPlayableLevel,
                );
                final unlockedUntil = currentLevel > unlockedByProgress
                    ? currentLevel
                    : unlockedByProgress;
                return SizedBox(
                  height: 292,
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _game.maxPlayableLevel,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final level = index + 1;
                      final unlocked = level <= unlockedUntil;
                      final selected = level == currentLevel;
                      final startColor = unlocked
                          ? (selected
                              ? const Color(0xFF56D4FF)
                              : const Color(0xFF3A7BFF))
                          : const Color(0xFF4A556B);
                      final endColor = unlocked
                          ? (selected
                              ? const Color(0xFF2A9AD6)
                              : const Color(0xFF3056CF))
                          : const Color(0xFF3A4358);
                      return GestureDetector(
                        onTap: unlocked ? () => _onLevelSelected(level) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [startColor, endColor],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    Colors.white.withAlpha(unlocked ? 180 : 90),
                                width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(60),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: unlocked
                                ? Text(
                                    '$level',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.lock_rounded,
                                    color: Color(0xFFB4BDCC),
                                    size: 18,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
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

  Widget _buildSoundToggleButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final startColor =
        active ? const Color(0xFF3BC0FF) : const Color(0xFF6B7592);
    final endColor = active ? const Color(0xFF2188E6) : const Color(0xFF505B76);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(168), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(58),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 23),
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
                                onAdHint: _isRewardedBusy ? null : _watchRewardedBonusHint,
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
          ValueListenableBuilder<int>(
            valueListenable: _game.levelNotifier,
            builder: (context, _, __) {
              final milestoneLabel = !_game.isBoosterUnlocked(BoosterType.shuffle)
                  ? t.tr(
                      'game.milestone.shuffle_next_level',
                      params: {'level': '${_game.shuffleUnlockLevel}'},
                    )
                  : !_game.isBoosterUnlocked(BoosterType.hint)
                      ? t.tr(
                          'game.milestone.hint_next_level',
                          params: {'level': '${_game.hintUnlockLevel}'},
                        )
                      : ''; // Removed "All boosters unlocked" text as requested by user
              return Text(
                milestoneLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withAlpha(228),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          if (_rewardNotice.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _rewardNotice,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withAlpha(230),
              ),
            ),
          ],
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
