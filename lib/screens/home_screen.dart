import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tile_two/game/comeback_reward_service.dart';
import 'package:tile_two/l10n/app_i18n.dart';
import 'package:tile_two/game/daily_login_reward_service.dart';
import 'package:tile_two/game/game_audio_service.dart';
import 'package:tile_two/game/mission_service.dart';
import 'package:tile_two/game/save_game_repository.dart';
import 'package:tile_two/game/tile_layout.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tile_two/game/rewarded_ads_service.dart';
import 'package:tile_two/screens/game_screen.dart';
import 'package:tile_two/ui/google_fonts_proxy.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final GameAudioService _audio = GameAudioService.instance;
  bool _isHomeSettingsOpen = false;
  bool _isLevelsPanelOpen = false;
  bool _isMissionsPanelOpen = false;
  bool _isTutorialOpen = false;
  bool _isDailyRewardOpen = false;
  bool _isComebackRewardOpen = false;
  bool _isLanguagePanelOpen = false;
  bool _isSfxEnabled = true;
  bool _isMusicEnabled = true;
  int _currentLevel = 1;
  int _completedLevels = 0;
  int _selectedStartLevel = 1;
  int _tutorialStep = 0;
  DailyLoginRewardResult? _dailyRewardResult;
  DailyLoginRewardResult? _pendingDailyRewardResult;
  ComebackRewardResult? _comebackRewardResult;
  SaveGameData? _homeSaveData;
  MissionBoardState? _missionBoard;
  String _missionNotice = '';
  String _selectedLanguageCode = 'id';
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  late final AnimationController _playPulseController;
  late final Animation<double> _playPulse;
  late final AnimationController _logoFloatingController;
  late final Animation<double> _logoFloating;

  final List<_LanguageOption> _languageOptions = const [
    _LanguageOption(code: 'en', nativeName: 'English', localizedName: 'Inggris'),
    _LanguageOption(code: 'it', nativeName: 'Italiano', localizedName: 'Italia'),
    _LanguageOption(code: 'ru', nativeName: 'русский', localizedName: 'Rusia'),
    _LanguageOption(
      code: 'zh',
      nativeName: '简体中文',
      localizedName: 'Mandarin - Tiongkok',
    ),
    _LanguageOption(
      code: 'pt',
      nativeName: 'português',
      localizedName: 'Portugis',
    ),
    _LanguageOption(code: 'ja', nativeName: '日本語', localizedName: 'Jepang'),
    _LanguageOption(code: 'th', nativeName: 'ไทย', localizedName: 'Thailand'),
    _LanguageOption(code: 'ar', nativeName: 'عربى', localizedName: 'Arab'),
    _LanguageOption(code: 'fr', nativeName: 'Français', localizedName: 'Prancis'),
    _LanguageOption(code: 'pl', nativeName: 'Polskie', localizedName: 'Polandia'),
    _LanguageOption(
      code: 'vi',
      nativeName: 'Tiếng Việt',
      localizedName: 'Vietnam',
    ),
    _LanguageOption(
      code: 'es',
      nativeName: 'español',
      localizedName: 'Spanyol',
    ),
    _LanguageOption(code: 'de', nativeName: 'deutsch', localizedName: 'Jerman'),
    _LanguageOption(
      code: 'hi',
      nativeName: 'हिन्दी',
      localizedName: 'Hindi - India',
    ),
    _LanguageOption(
      code: 'id',
      nativeName: 'Indonesia',
      localizedName: 'Indonesia',
    ),
  ];

  List<_HomeTutorialStep> _tutorialSteps(AppI18n t) {
    return [
      _HomeTutorialStep(
        title: t.tr('tutorial.step1.title'),
        description: t.tr('tutorial.step1.description'),
      ),
      _HomeTutorialStep(
        title: t.tr('tutorial.step2.title'),
        description: t.tr('tutorial.step2.description'),
      ),
      _HomeTutorialStep(
        title: t.tr('tutorial.step3.title'),
        description: t.tr('tutorial.step3.description'),
      ),
      _HomeTutorialStep(
        title: t.tr('tutorial.step4.title'),
        description: t.tr('tutorial.step4.description'),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _playPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat();
    _playPulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.045)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.045, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_playPulseController);

    _logoFloatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _logoFloating = Tween<double>(begin: 0, end: 12.0).animate(
      CurvedAnimation(parent: _logoFloatingController, curve: Curves.easeInOut),
    );

    _initializeHome();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    RewardedAdsService.instance.loadBannerAd(
      onAdLoaded: (ad) {
        if (!mounted) {
          ad.dispose();
          return;
        }
        setState(() {
          _bannerAd = ad as BannerAd;
          _isBannerLoaded = true;
        });
      },
      onAdFailedToLoad: (ad, error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isBannerLoaded = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _playPulseController.dispose();
    _logoFloatingController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handleSystemBack();
      },
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(20),
                          Colors.black.withAlpha(55),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _buildTopCircleActionButton(
                  icon: Icons.language_rounded,
                  onTap: _openLanguagePanel,
                  gradientColors: const [
                    Color(0xFF00E5FF),
                    Color(0xFF00ACC1),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _buildTopCircleActionButton(
                  icon: Icons.settings_rounded,
                  onTap: _openHomeSettings,
                  gradientColors: const [
                    Color(0xFFB388FF),
                    Color(0xFF673AB7),
                  ],
                ),
              ),
              Positioned(
                top: 58,
                right: 12,
                child: GestureDetector(
                  onTap: _openMissionsPanel,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTopCircleActionButton(
                        icon: Icons.event_note_rounded,
                        onTap: null,
                        gradientColors: const [
                          Color(0xFFFFC864),
                          Color(0xFFEF9D30),
                        ],
                        iconSize: 18,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppI18n.of(context).tr('mission.title'),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(150),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Column(
                  children: [
                    const SizedBox(height: 64),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final logoWidth = (constraints.maxWidth * 0.82)
                            .clamp(270.0, 520.0)
                            .toDouble();
                        return _buildHomeTitleLogo(logoWidth);
                      },
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 190,
                      child: _buildPlayButton(
                        onTap: () {
                          _startGame(level: _selectedStartLevel);
                        },
                      ),
                    ),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
              if (_isHomeSettingsOpen) _buildHomeSettingsOverlay(),
              if (_isLanguagePanelOpen) _buildLanguageOverlay(),
              if (_isTutorialOpen) _buildTutorialOverlay(),
              if (_isComebackRewardOpen && _comebackRewardResult != null)
                _buildComebackRewardOverlay(),
              if (_isDailyRewardOpen && _dailyRewardResult != null)
                _buildDailyRewardOverlay(),
              if (_isBannerLoaded && _bannerAd != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    alignment: Alignment.center,
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTitleLogo(double width) {
    return AnimatedBuilder(
      animation: _logoFloating,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_logoFloating.value),
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/title_logo.png',
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          final localPath =
              '${Directory.current.path}${Platform.pathSeparator}assets${Platform.pathSeparator}images${Platform.pathSeparator}title_logo.png';
          return Image.file(
            File(localPath),
            width: width,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return Image.asset(
                'assets/images/icon_launcher.png',
                width: 124,
                fit: BoxFit.contain,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleSystemBack() async {
    if (_isLanguagePanelOpen) {
      _closeLanguagePanel();
      return;
    }
    if (_isComebackRewardOpen) {
      _closeComebackRewardOverlay();
      return;
    }
    if (_isDailyRewardOpen) {
      _closeDailyRewardOverlay();
      return;
    }
    if (_isTutorialOpen) {
      _closeTutorial();
      return;
    }
    if (_isHomeSettingsOpen) {
      _closeHomeSettings();
      return;
    }
    final shouldExit = await _showExitConfirmation();
    if (!mounted || !shouldExit) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    await SystemNavigator.pop(animated: true);
  }

  Future<bool> _showExitConfirmation() async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            final t = AppI18n.of(context);
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF102744).withAlpha(248),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFBFE4FF).withAlpha(110),
                    width: 1.3,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.tr('exit.title'),
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.tr('exit.description'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(222),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrimaryButton(
                            label: t.tr('common.no'),
                            startColor: const Color(0xFF576885),
                            endColor: const Color(0xFF3F4E68),
                            height: 48,
                            onTap: () {
                              Navigator.of(context).pop(false);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPrimaryButton(
                            label: t.tr('common.yes'),
                            startColor: const Color(0xFF00C896),
                            endColor: const Color(0xFF00A27C),
                            height: 48,
                            onTap: () {
                              Navigator.of(context).pop(true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        )) ??
        false;
  }

  void _openHomeSettings() {
    if (_isDailyRewardOpen || _isComebackRewardOpen || _isLanguagePanelOpen) {
      return;
    }
    setState(() {
      _isHomeSettingsOpen = true;
      _isLevelsPanelOpen = false;
      _isMissionsPanelOpen = false;
      _missionNotice = '';
    });
  }

  void _closeHomeSettings() {
    setState(() {
      _isHomeSettingsOpen = false;
      _isLevelsPanelOpen = false;
      _isMissionsPanelOpen = false;
      _missionNotice = '';
    });
  }

  void _openLanguagePanel() {
    if (_isDailyRewardOpen || _isComebackRewardOpen || _isHomeSettingsOpen) {
      return;
    }
    setState(() {
      _isLanguagePanelOpen = true;
      _missionNotice = '';
    });
  }

  void _closeLanguagePanel() {
    setState(() {
      _isLanguagePanelOpen = false;
    });
  }

  Future<void> _selectLanguage(String code) async {
    final saveData = _homeSaveData;
    if (saveData == null || _selectedLanguageCode == code) {
      _closeLanguagePanel();
      return;
    }
    final repository = SaveGameRepository();
    final updated = saveData.copyWith(selectedLanguageCode: code);
    await repository.save(updated);
    AppLanguageController.instance.setLanguage(code);
    if (!mounted) {
      return;
    }
    setState(() {
      _homeSaveData = updated;
      _selectedLanguageCode = code;
      _isLanguagePanelOpen = false;
      _missionBoard = MissionService.instance.board(saveData: updated);
    });
  }

  Future<SaveGameData> _loadSaveData() async {
    final repository = SaveGameRepository();
    var saveData = await repository.load();
    saveData = MissionService.instance.normalize(saveData: saveData);
    await repository.save(saveData);
    if (!mounted) {
      return saveData;
    }
    AppLanguageController.instance.setLanguage(saveData.selectedLanguageCode);
    setState(() {
      _homeSaveData = saveData;
      _missionBoard = MissionService.instance.board(saveData: saveData);
      _currentLevel = saveData.currentLevel;
      _completedLevels = saveData.completedLevels;
      _selectedStartLevel = _currentLevel;
      _selectedLanguageCode = saveData.selectedLanguageCode;
    });
    return saveData;
  }

  Future<void> _initializeHome() async {
    await _audio.init();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMusicEnabled = _audio.musicEnabled;
    });
    var saveData = await _loadSaveData();
    saveData = await _applyComebackReward(saveData);
    saveData = await _applyDailyLoginReward(saveData);
    await _audio.playHomeLoop();
  }

  Future<SaveGameData> _applyComebackReward(SaveGameData saveData) async {
    final result = ComebackRewardService.instance.processLogin(
      saveData: saveData,
      now: DateTime.now(),
    );
    if (result.updatedData != saveData) {
      final repository = SaveGameRepository();
      await repository.save(result.updatedData);
    }
    if (!mounted) {
      return result.updatedData;
    }
    if (!result.claimed || result.grant.isEmpty) {
      setState(() {
        _homeSaveData = result.updatedData;
        _missionBoard = MissionService.instance.board(saveData: result.updatedData);
      });
      return result.updatedData;
    }
    setState(() {
      _homeSaveData = result.updatedData;
      _missionBoard = MissionService.instance.board(saveData: result.updatedData);
      _comebackRewardResult = result;
      _isComebackRewardOpen = true;
    });
    return result.updatedData;
  }

  Future<SaveGameData> _applyDailyLoginReward(SaveGameData saveData) async {
    final result = DailyLoginRewardService.instance.claimIfEligible(
      saveData: saveData,
      now: DateTime.now(),
    );
    if (!result.claimedToday || result.grant.isEmpty) {
      return saveData;
    }
    final repository = SaveGameRepository();
    await repository.save(result.updatedData);
    if (!mounted) {
      return result.updatedData;
    }
    setState(() {
      _homeSaveData = result.updatedData;
      _missionBoard =
          MissionService.instance.board(saveData: result.updatedData);
      if (_isComebackRewardOpen) {
        _pendingDailyRewardResult = result;
      } else {
        _dailyRewardResult = result;
        _isDailyRewardOpen = true;
      }
    });
    return result.updatedData;
  }

  void _startGame({required int level}) {
    _audio.playGameLoop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(initialLevel: level),
      ),
    );
  }


  void _openLevelsPanel() {
    if (_isDailyRewardOpen || _isComebackRewardOpen || _isLanguagePanelOpen) {
      return;
    }
    setState(() {
      _isLevelsPanelOpen = true;
      _isMissionsPanelOpen = false;
      _missionNotice = '';
    });
  }

  void _closeLevelsPanel() {
    setState(() {
      _isLevelsPanelOpen = false;
    });
  }

  void _openMissionsPanel() {
    if (_isDailyRewardOpen || _isComebackRewardOpen || _isLanguagePanelOpen) {
      return;
    }
    setState(() {
      _isMissionsPanelOpen = true;
      _isLevelsPanelOpen = false;
      _missionNotice = '';
    });
  }

  void _closeMissionsPanel() {
    setState(() {
      _isMissionsPanelOpen = false;
      _missionNotice = '';
    });
  }

  Future<void> _claimMission(
    MissionScope scope,
    String missionId,
  ) async {
    final t = AppI18n.of(context);
    final saveData = _homeSaveData;
    if (saveData == null) {
      return;
    }
    final result = MissionService.instance.claim(
      saveData: saveData,
      scope: scope,
      missionId: missionId,
      now: DateTime.now(),
    );
    final repository = SaveGameRepository();
    await repository.save(result.updatedData);
    if (!mounted) {
      return;
    }
    setState(() {
      _homeSaveData = result.updatedData;
      _missionBoard =
          MissionService.instance.board(saveData: result.updatedData);
      _missionNotice = result.claimed
          ? t.tr(
              'mission.notice.reward_received',
              params: {
                'hint': '${result.reward.hint}',
                'undo': '${result.reward.undo}',
                'shuffle': '${result.reward.shuffle}',
              },
            )
          : _missionNoticeByStatus(t, result.status);
    });
  }

  String _missionNoticeByStatus(AppI18n t, MissionClaimStatus status) {
    return switch (status) {
      MissionClaimStatus.missionNotFound => t.tr('mission.notice.not_found'),
      MissionClaimStatus.alreadyClaimed =>
        t.tr('mission.notice.already_claimed'),
      MissionClaimStatus.progressInsufficient =>
        t.tr('mission.notice.progress_insufficient'),
      MissionClaimStatus.success => t.tr('common.claim'),
    };
  }

  void _openTutorial() {
    if (_isDailyRewardOpen || _isComebackRewardOpen || _isLanguagePanelOpen) {
      return;
    }
    setState(() {
      _isHomeSettingsOpen = false;
      _isLevelsPanelOpen = false;
      _isMissionsPanelOpen = false;
      _isTutorialOpen = true;
      _tutorialStep = 0;
    });
  }

  void _closeTutorial() {
    setState(() {
      _isTutorialOpen = false;
      _tutorialStep = 0;
    });
  }

  Widget _buildHomeSettingsOverlay() {
    final t = AppI18n.of(context);
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeHomeSettings,
        child: ColoredBox(
          color: Colors.black.withAlpha(155),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: (_isLevelsPanelOpen || _isMissionsPanelOpen) ? 328 : 304,
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
                    : _isMissionsPanelOpen
                        ? _buildMissionsContent()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                    child: _buildTinyToggle(
                                      icon: Icons.volume_up_rounded,
                                      active: _isSfxEnabled,
                                      onTap: () {
                                        setState(() {
                                          _isSfxEnabled = !_isSfxEnabled;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildTinyToggle(
                                      icon: Icons.music_note_rounded,
                                      active: _isMusicEnabled,
                                      onTap: () async {
                                        final nextValue = !_isMusicEnabled;
                                        await _audio.setMusicEnabled(nextValue);
                                        if (nextValue) {
                                          await _audio.playHomeLoop();
                                        }
                                        if (!mounted) {
                                          return;
                                        }
                                        setState(() {
                                          _isMusicEnabled = nextValue;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildSettingsActionButton(
                                label: t.tr('common.continue'),
                                colorStart: const Color(0xFF00C896),
                                colorEnd: const Color(0xFF00A27C),
                                onTap: () {
                                  _closeHomeSettings();
                                  _startGame(level: _selectedStartLevel);
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildSettingsActionButton(
                                label: t.tr('common.restart'),
                                colorStart: const Color(0xFF5569FF),
                                colorEnd: const Color(0xFF3F51D6),
                                onTap: () {
                                  _closeHomeSettings();
                                  _startGame(level: _selectedStartLevel);
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildSettingsActionButton(
                                label: t.tr('common.home'),
                                colorStart: const Color(0xFF8A5CFF),
                                colorEnd: const Color(0xFF6A46D6),
                                onTap: _closeHomeSettings,
                              ),
                              const SizedBox(height: 10),
                              _buildSettingsActionButton(
                                label: t.tr('common.tutorial'),
                                colorStart: const Color(0xFF28B8C7),
                                colorEnd: const Color(0xFF1F8F9B),
                                onTap: _openTutorial,
                              ),
                              const SizedBox(height: 10),
                              _buildSettingsActionButton(
                                label: t.tr('common.levels'),
                                colorStart: const Color(0xFFFF7A59),
                                colorEnd: const Color(0xFFD85A3E),
                                onTap: _openLevelsPanel,
                              ),
                              const SizedBox(height: 10),
                              _buildSettingsActionButton(
                                label: t.tr('common.missions'),
                                colorStart: const Color(0xFFFFB347),
                                colorEnd: const Color(0xFFEA8B1A),
                                onTap: _openMissionsPanel,
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelsContent() {
    final t = AppI18n.of(context);
    final unlockedByProgress =
        (_completedLevels + 1).clamp(1, TileLayoutRules.maxLevel);
    final unlockedUntil =
        _currentLevel > unlockedByProgress ? _currentLevel : unlockedByProgress;
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
        SizedBox(
          height: 292,
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: TileLayoutRules.maxLevel,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final level = index + 1;
              final unlocked = level <= unlockedUntil;
              final selected = level == _selectedStartLevel;
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
                onTap: unlocked
                    ? () {
                        setState(() {
                          _selectedStartLevel = level;
                          _isLevelsPanelOpen = false;
                        });
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [startColor, endColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withAlpha(unlocked ? 180 : 90),
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
        ),
      ],
    );
  }

  Widget _buildMissionsContent() {
    final t = AppI18n.of(context);
    final board = _missionBoard;
    if (board == null) {
      return const SizedBox(height: 260);
    }
    return SizedBox(
      height: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _closeMissionsPanel,
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
                  t.tr('missions.title'),
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
          if (_missionNotice.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _missionNotice,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFBEE0FF),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                Text(
                  t.tr('common.daily'),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                for (final mission in board.daily)
                  _buildMissionTile(
                    entry: mission,
                    onClaim: () => _claimMission(
                      MissionScope.daily,
                      mission.definition.id,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  t.tr('common.weekly'),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                for (final mission in board.weekly)
                  _buildMissionTile(
                    entry: mission,
                    onClaim: () => _claimMission(
                      MissionScope.weekly,
                      mission.definition.id,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionTile({
    required MissionEntry entry,
    required VoidCallback onClaim,
  }) {
    final t = AppI18n.of(context);
    final progress = entry.progress.clamp(0, entry.definition.target);
    final progressValue = entry.definition.target == 0
        ? 0.0
        : (progress / entry.definition.target).clamp(0, 1).toDouble();
    final rewardText =
        '+${entry.definition.reward.hint} ${t.tr('resource.hint')}  +${entry.definition.reward.undo} ${t.tr('resource.undo')}  +${entry.definition.reward.shuffle} ${t.tr('resource.shuffle')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3558),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.tr('mission.${entry.definition.id}'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progressValue,
            minHeight: 6,
            backgroundColor: const Color(0xFF2B4568),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ED3FF)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$progress/${entry.definition.target}  •  $rewardText',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(220),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildOverlayActionButton(
                label: entry.claimed
                    ? t.tr('common.done')
                    : (entry.claimable
                        ? t.tr('common.claim')
                        : t.tr('common.locked')),
                onTap: onClaim,
                start: const Color(0xFF00C896),
                end: const Color(0xFF00A27C),
                disabled: !entry.claimable,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    final t = AppI18n.of(context);
    final tutorialSteps = _tutorialSteps(t);
    final step = tutorialSteps[_tutorialStep];
    final isLastStep = _tutorialStep == tutorialSteps.length - 1;
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
                      'current': '${_tutorialStep + 1}',
                      'total': '${tutorialSteps.length}',
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
                  children: List.generate(tutorialSteps.length, (index) {
                    final active = index == _tutorialStep;
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
                        onTap: _closeTutorial,
                        start: const Color(0xFF5A6783),
                        end: const Color(0xFF45526B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverlayActionButton(
                        label: _tutorialStep == 0
                            ? t.tr('common.back')
                            : t.tr('common.prev'),
                        onTap: () {
                          if (_tutorialStep == 0) {
                            return;
                          }
                          setState(() {
                            _tutorialStep -= 1;
                          });
                        },
                        start: const Color(0xFF3B4A66),
                        end: const Color(0xFF2E3B56),
                        disabled: _tutorialStep == 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverlayActionButton(
                        label: isLastStep
                            ? t.tr('common.start')
                            : t.tr('common.next'),
                        onTap: () {
                          if (isLastStep) {
                            _closeTutorial();
                            return;
                          }
                          setState(() {
                            _tutorialStep += 1;
                          });
                        },
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

  void _closeDailyRewardOverlay() {
    setState(() {
      _isDailyRewardOpen = false;
    });
  }

  void _closeComebackRewardOverlay() {
    setState(() {
      _isComebackRewardOpen = false;
      if (_pendingDailyRewardResult != null) {
        _dailyRewardResult = _pendingDailyRewardResult;
        _pendingDailyRewardResult = null;
        _isDailyRewardOpen = true;
      }
    });
  }

  Widget _buildComebackRewardOverlay() {
    final t = AppI18n.of(context);
    final reward = _comebackRewardResult!;
    final rewards = <String>[];
    if (reward.grant.coins > 0) {
      rewards.add('+${reward.grant.coins} ${t.tr('resource.coins')}');
    }
    if (reward.grant.hint > 0) {
      rewards.add('+${reward.grant.hint} ${t.tr('resource.hint')}');
    }
    if (reward.grant.undo > 0) {
      rewards.add('+${reward.grant.undo} ${t.tr('resource.undo')}');
    }
    if (reward.grant.shuffle > 0) {
      rewards.add('+${reward.grant.shuffle} ${t.tr('resource.shuffle')}');
    }
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
                color: const Color(0xFFBFE4FF).withAlpha(120),
                width: 1.4,
              ),
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
                  t.tr('reward.welcome_back_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.tr(
                    'reward.return_after_days',
                    params: {'days': '${reward.absentDays}'},
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFBEE0FF),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3558),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(70)),
                  ),
                  child: Text(
                    rewards.join('  •  '),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildOverlayActionButton(
                  label: t.tr('common.claim'),
                  onTap: _closeComebackRewardOverlay,
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

  Widget _buildLanguageOverlay() {
    final t = AppI18n.of(context);
    final selected = _languageOptions.firstWhere(
      (item) => item.code == _selectedLanguageCode,
      orElse: () => _languageOptions.last,
    );
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withAlpha(178),
        child: Center(
          child: Container(
            width: 336,
            height: 490,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF102744).withAlpha(246),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFBFE4FF).withAlpha(120),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(135),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  t.tr('language.title'),
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.tr(
                    'language.active',
                    params: {'language': selected.nativeName},
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFBEE0FF),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _languageOptions.length,
                    itemBuilder: (context, index) {
                      final item = _languageOptions[index];
                      final isSelected = item.code == _selectedLanguageCode;
                      return GestureDetector(
                        onTap: () {
                          _selectLanguage(item.code);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isSelected
                                  ? const [
                                      Color(0xFF4BD8A5),
                                      Color(0xFF26A780),
                                    ]
                                  : const [
                                      Color(0xFF274264),
                                      Color(0xFF1A3454),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withAlpha(
                                isSelected ? 205 : 95,
                              ),
                              width: 1.1,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildLanguageChip(item.code, isSelected),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  '${item.nativeName} (${item.localizedName})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _buildOverlayActionButton(
                  label: t.tr('common.close'),
                  onTap: _closeLanguagePanel,
                  start: const Color(0xFF5A6783),
                  end: const Color(0xFF45526B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRewardOverlay() {
    final t = AppI18n.of(context);
    final reward = _dailyRewardResult!;
    final rewards = <String>[];
    if (reward.grant.hint > 0) {
      rewards.add('+${reward.grant.hint} ${t.tr('resource.hint')}');
    }
    if (reward.grant.undo > 0) {
      rewards.add('+${reward.grant.undo} ${t.tr('resource.undo')}');
    }
    if (reward.grant.shuffle > 0) {
      rewards.add('+${reward.grant.shuffle} ${t.tr('resource.shuffle')}');
    }
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
                  t.tr('reward.daily_login_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.tr(
                    'reward.daily_streak',
                    params: {'streak': '${reward.streak}'},
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFBEE0FF),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3558),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(70)),
                  ),
                  child: Text(
                    rewards.join('  •  '),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (reward.streakReset) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.tr('reward.streak_reset'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(205),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _buildOverlayActionButton(
                  label: t.tr('common.claim'),
                  onTap: _closeDailyRewardOverlay,
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

  Widget _buildTopCircleActionButton({
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback? onTap,
    double iconSize = 19,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          border: Border.all(color: Colors.white.withAlpha(210), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildLanguageChip(String code, bool selected) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(selected ? 72 : 42),
        border: Border.all(color: Colors.white.withAlpha(195), width: 1),
      ),
      child: Center(
        child: Text(
          code.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              color: Colors.white.withAlpha(245),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTinyToggle({
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
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(165), width: 1.2),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildPlayButton({
    required VoidCallback onTap,
  }) {
    final t = AppI18n.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _playPulse,
        builder: (context, child) {
          return Transform.scale(
            scale: _playPulse.value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF00C896),
                Color(0xFF00A27C),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(188), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              t.tr(
                'game.level',
                params: {'level': '$_selectedStartLevel'},
              ),
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required Color startColor,
    required Color endColor,
    required VoidCallback onTap,
    double height = 58,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(188), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(85),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: height <= 48 ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTutorialStep {
  final String title;
  final String description;

  const _HomeTutorialStep({
    required this.title,
    required this.description,
  });
}

class _LanguageOption {
  final String code;
  final String nativeName;
  final String localizedName;

  const _LanguageOption({
    required this.code,
    required this.nativeName,
    required this.localizedName,
  });
}
