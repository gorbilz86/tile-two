import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tile_two/game/game_audio_service.dart';
import 'package:tile_two/game/rewarded_ads_service.dart';
import 'package:tile_two/ui/game_buttons.dart';
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
    with SingleTickerProviderStateMixin {
  final GameAudioService _audio = GameAudioService.instance;
  final RewardedAdsService _rewardedAds = RewardedAdsService.instance;
  late final TileGame _game;
  bool _isSettingsOpen = false;
  bool _isLevelsPanelOpen = false;
  bool _isOnboardingOpen = false;
  bool _isFirstWinOpen = false;
  bool _isLevelWinOpen = false;
  bool _isSfxEnabled = true;
  bool _isMusicEnabled = true;
  bool _isRewardedBusy = false;
  String _settingsNotice = '';
  String _rewardNotice = '';
  int _onboardingStep = 0;
  int _lastFirstWinSignal = 0;
  int _lastLevelWinSignal = 0;
  late final AnimationController _winFxController;
  late final Animation<double> _winPopupScale;
  late final Animation<double> _winPopupOpacity;
  late final Animation<double> _medalBounceScale;
  late final Animation<double> _confettiProgress;

  final List<_OnboardingStep> _onboardingSteps = const [
    _OnboardingStep(
      title: 'Selamat Datang',
      description: 'Tap ubin teratas untuk memindahkan ke slot bar.',
    ),
    _OnboardingStep(
      title: 'Buat Match 3',
      description: 'Kumpulkan 3 ubin buah sama untuk menghapusnya.',
    ),
    _OnboardingStep(
      title: 'Jaga Slot Tetap Aman',
      description: 'Kalau slot penuh sebelum board habis, level gagal.',
    ),
    _OnboardingStep(
      title: 'Gunakan Booster',
      description: 'Undo, Shuffle, dan Hint bantu selesaikan level sulit.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _winFxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _winPopupScale = Tween<double>(begin: 0.78, end: 1).animate(
      CurvedAnimation(
        parent: _winFxController,
        curve: const Interval(0, 0.42, curve: Curves.easeOutBack),
      ),
    );
    _winPopupOpacity = CurvedAnimation(
      parent: _winFxController,
      curve: const Interval(0, 0.24, curve: Curves.easeOut),
    );
    _medalBounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.82, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _winFxController,
        curve: const Interval(0.2, 0.9),
      ),
    );
    _confettiProgress = CurvedAnimation(
      parent: _winFxController,
      curve: const Interval(0, 1, curve: Curves.easeOutCubic),
    );
    _game = TileGame(
      footerReservedHeight: 175,
      initialLevel: widget.initialLevel,
    );
    unawaited(_rewardedAds.warmUp());
    _initAudio();
    _game.onboardingRequiredNotifier
        .addListener(_handleOnboardingRequiredChanged);
    _game.firstWinTriggerNotifier.addListener(_handleFirstWinTrigger);
    _game.levelWinTriggerNotifier.addListener(_handleLevelWinTrigger);
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
    _game.firstWinTriggerNotifier.removeListener(_handleFirstWinTrigger);
    _game.levelWinTriggerNotifier.removeListener(_handleLevelWinTrigger);
    _winFxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _game.matchFlashNotifier,
                builder: (context, alpha, child) {
                  return ColoredBox(
                    color: const Color(0xFFFFF6D4).withValues(alpha: alpha),
                  );
                },
              ),
            ),
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
                            'Game Over',
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Slot penuh. Coba ulang level ini.',
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
                              onPressed: _game.retryCurrentLevel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC400),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                'Coba Lagi',
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
                                    ? 'Memuat Iklan...'
                                    : 'Revive via Iklan',
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
          SafeArea(
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
          if (_isSettingsOpen) _buildSettingsOverlay(),
          if (_isOnboardingOpen) _buildOnboardingOverlay(),
          if (_isFirstWinOpen) _buildFirstWinOverlay(),
          if (_isLevelWinOpen) _buildLevelWinOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                return Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                    shadows: const [
                      Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
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
    await _maybeShowInterstitialAd(InterstitialPlacement.retryLevel);
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
    await _maybeShowInterstitialAd(InterstitialPlacement.manualLevelSelect);
    await _game.selectLevel(level);
  }

  Future<void> _watchRewardedRevive() async {
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
        _rewardNotice = 'Iklan belum tersedia.';
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
          ? 'Revive aktif, 3 slot terakhir dihapus.'
          : 'Revive gagal, coba ulang level.';
    });
  }

  Future<void> _watchRewardedBonusHint() async {
    if (_isRewardedBusy ||
        _isLevelWinOpen ||
        _isFirstWinOpen ||
        _isOnboardingOpen) {
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
        _rewardNotice = 'Iklan belum tersedia.';
      });
      return;
    }
    await _game.grantBonusHint(amount: 1);
    if (!mounted) {
      return;
    }
    setState(() {
      _isRewardedBusy = false;
      _rewardNotice = '+1 Hint berhasil ditambahkan.';
    });
  }

  Future<void> _maybeShowInterstitialAd(InterstitialPlacement placement) async {
    if (_isRewardedBusy || _isLevelWinOpen || _isOnboardingOpen) {
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

  void _handleFirstWinTrigger() {
    final signal = _game.firstWinTriggerNotifier.value;
    if (signal == _lastFirstWinSignal || !mounted || _isLevelWinOpen) {
      return;
    }
    _lastFirstWinSignal = signal;
    _openFirstWinFlow();
  }

  void _handleLevelWinTrigger() {
    final signal = _game.levelWinTriggerNotifier.value;
    if (signal == _lastLevelWinSignal || !mounted) {
      return;
    }
    _lastLevelWinSignal = signal;
    _openLevelWinFlow();
  }

  void _openOnboarding({required bool resetStep}) {
    _game.pauseEngine();
    setState(() {
      _isSettingsOpen = false;
      _isLevelsPanelOpen = false;
      _isFirstWinOpen = false;
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
    if (_onboardingStep >= _onboardingSteps.length - 1) {
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

  void _openFirstWinFlow() {
    _game.pauseEngine();
    setState(() {
      _isFirstWinOpen = true;
    });
  }

  void _openLevelWinFlow() {
    _game.pauseEngine();
    _winFxController
      ..stop()
      ..value = 0
      ..forward();
    setState(() {
      _isFirstWinOpen = false;
      _isLevelWinOpen = true;
    });
  }

  void _closeFirstWinFlow() {
    setState(() {
      _isFirstWinOpen = false;
    });
    _resumeGameIfNoOverlay();
  }

  Future<void> _continueAfterLevelWin() async {
    if (!_isLevelWinOpen) {
      return;
    }
    setState(() {
      _isLevelWinOpen = false;
    });
    _winFxController.stop();
    await _maybeShowInterstitialAd(InterstitialPlacement.levelComplete);
    _resumeGameIfNoOverlay();
    await _game.continueAfterLevelWin();
  }

  void _resumeGameIfNoOverlay() {
    if (_isSettingsOpen ||
        _isOnboardingOpen ||
        _isFirstWinOpen ||
        _isLevelWinOpen) {
      return;
    }
    _game.resumeEngine();
  }

  Widget _buildSettingsContent() {
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
          'SETTINGS',
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
        _buildSettingsActionButton(
          label: 'Continue',
          colorStart: const Color(0xFF00C896),
          colorEnd: const Color(0xFF00A27C),
          onTap: _closeSettings,
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: 'Restart',
          colorStart: const Color(0xFF5569FF),
          colorEnd: const Color(0xFF3F51D6),
          onTap: _onRestartPressed,
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: 'Home',
          colorStart: const Color(0xFF8A5CFF),
          colorEnd: const Color(0xFF6A46D6),
          onTap: _onHomePressed,
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: 'Tutorial',
          colorStart: const Color(0xFF28B8C7),
          colorEnd: const Color(0xFF1F8F9B),
          onTap: _onTutorialPressed,
        ),
        const SizedBox(height: 10),
        _buildSettingsActionButton(
          label: 'Levels',
          colorStart: const Color(0xFFFF7A59),
          colorEnd: const Color(0xFFD85A3E),
          onTap: _onLevelsPressed,
        ),
      ],
    );
  }

  Widget _buildLevelsContent() {
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
                'LEVELS',
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
    final step = _onboardingSteps[_onboardingStep];
    final isLastStep = _onboardingStep == _onboardingSteps.length - 1;
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
                  'Tutorial ${_onboardingStep + 1}/${_onboardingSteps.length}',
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
                  children: List.generate(_onboardingSteps.length, (index) {
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
                        label: 'Skip',
                        onTap: _skipOnboarding,
                        start: const Color(0xFF5A6783),
                        end: const Color(0xFF45526B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverlayActionButton(
                        label: _onboardingStep == 0 ? 'Back' : 'Prev',
                        onTap: _previousOnboardingStep,
                        start: const Color(0xFF3B4A66),
                        end: const Color(0xFF2E3B56),
                        disabled: _onboardingStep == 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverlayActionButton(
                        label: isLastStep ? 'Mulai' : 'Next',
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

  Widget _buildFirstWinOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withAlpha(178),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFF102744).withAlpha(246),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFFBFE4FF).withAlpha(120), width: 1.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD166),
                  size: 42,
                ),
                const SizedBox(height: 10),
                Text(
                  'First Win!',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kamu berhasil clear level pertama. Lanjutkan streak untuk skor lebih tinggi.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withAlpha(218),
                  ),
                ),
                const SizedBox(height: 16),
                _buildOverlayActionButton(
                  label: 'Lanjut Main',
                  onTap: _closeFirstWinFlow,
                  start: const Color(0xFF00C896),
                  end: const Color(0xFF00A27C),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelWinOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _winFxController,
        builder: (context, _) {
          return ColoredBox(
            color: Colors.black
                .withAlpha((130 + (_winPopupOpacity.value * 48)).round()),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.9,
                      child: CustomPaint(
                        painter: _WinConfettiPainter(
                          progress: _confettiProgress.value,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: _winPopupOpacity.value,
                    child: Transform.scale(
                      scale: _winPopupScale.value,
                      child: Container(
                        width: 320,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFF17A98),
                                    Color(0xFFE86A83),
                                  ],
                                ),
                                border: Border.all(
                                    color: Colors.white.withAlpha(170),
                                    width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(100),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 72, 20, 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'You Win',
                                    style: GoogleFonts.poppins(
                                      fontSize: 54,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 0.96,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black38,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Transform.translate(
                                    offset: Offset(
                                      0,
                                      (1 - _medalBounceScale.value) * 40,
                                    ),
                                    child: Transform.scale(
                                      scale: _medalBounceScale.value,
                                      child: Container(
                                        width: 122,
                                        height: 122,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const RadialGradient(
                                            colors: [
                                              Color(0xFFFFF2A8),
                                              Color(0xFFFACB43),
                                              Color(0xFFF0A91D),
                                            ],
                                            stops: [0.2, 0.7, 1],
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFF5C2),
                                            width: 5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFFD55A)
                                                  .withAlpha(130),
                                              blurRadius: 16,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFFFF2A8),
                                            size: 62,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  GestureDetector(
                                    onTap: _continueAfterLevelWin,
                                    child: Container(
                                      width: double.infinity,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(32),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF6FD94A),
                                            Color(0xFF44B81F),
                                          ],
                                        ),
                                        border: Border.all(
                                            color: Colors.white.withAlpha(184),
                                            width: 1.4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(80),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Continue',
                                          style: GoogleFonts.poppins(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 34,
                              right: 34,
                              child: ValueListenableBuilder<int>(
                                valueListenable: _game.levelNotifier,
                                builder: (context, clearedLevel, _) {
                                  return Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFFA05BFF),
                                          Color(0xFF8A43F7),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(65),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Level $clearedLevel',
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 34,
                              right: -10,
                              child: GestureDetector(
                                onTap: _continueAfterLevelWin,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withAlpha(55),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 34),
          GameButtons(
            onUndo: _game.undoLastMove,
            onShuffle: _game.shuffleBoard,
            onHint: _game.provideHint,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isRewardedBusy ? null : _watchRewardedBonusHint,
            child: Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 46),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _isRewardedBusy
                      ? [
                          const Color(0xFF4B6E84),
                          const Color(0xFF375267),
                        ]
                      : [
                          const Color(0xFF00B9E8),
                          const Color(0xFF008BC6),
                        ],
                ),
                border:
                    Border.all(color: Colors.white.withAlpha(160), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(65),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _isRewardedBusy
                      ? 'Memuat Iklan...'
                      : 'Dapatkan +1 Hint (Iklan)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
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

class _WinConfettiPainter extends CustomPainter {
  final double progress;

  const _WinConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final palette = <Color>[
      const Color(0xFFFFE066),
      const Color(0xFFFF8FB1),
      const Color(0xFF8D7CFF),
      const Color(0xFF57D0FF),
      const Color(0xFF71E36A),
    ];
    final clamped = progress.clamp(0, 1).toDouble();
    for (var i = 0; i < 46; i++) {
      final seed = i * 97.0;
      final baseX = (math.sin(seed) * 0.5 + 0.5) * size.width;
      final swing = math.sin((clamped * 10) + seed) * (9 + (i % 7) * 1.3);
      final drop = ((clamped * 1.18) - ((i % 8) * 0.048)).clamp(0, 1.3);
      final y = (-26 + (drop * (size.height * 0.86)));
      final x = baseX + swing;
      final pieceSize = 4.2 + (i % 4) * 1.1;
      final rotation = (clamped * 10) + seed;
      final color = palette[i % palette.length].withAlpha(
        (70 + ((1 - clamped) * 170)).round().clamp(0, 255),
      );
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: pieceSize * 1.1,
            height: pieceSize,
          ),
          Radius.circular(pieceSize * 0.3),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WinConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
