import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tile_two/l10n/app_i18n.dart';
import 'package:tile_two/game/game_audio_service.dart';
import 'package:tile_two/game/save_game_repository.dart';
import 'package:tile_two/game/tile_layout.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tile_two/game/rewarded_ads_service.dart';
import 'package:tile_two/screens/game_screen.dart';
import 'package:tile_two/ui/google_fonts_proxy.dart';
import 'package:tile_two/game/visual_utils.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isTutorialOpen = false;
  bool _isLanguagePanelOpen = false;
  bool _isSfxEnabled = true;
  bool _isMusicEnabled = true;
  int _currentLevel = 1;
  int _completedLevels = 0;
  final bool _devUnlockAll = false;
  int _selectedStartLevel = 1;
  int _tutorialStep = 0;
  SaveGameData? _homeSaveData;
  String _selectedLanguageCode = 'id';
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  late final AnimationController _playPulseController;
  late final Animation<double> _playPulse;
  late final AnimationController _logoFloatingController;
  late final Animation<double> _logoFloating;
  final GlobalKey _adKey = GlobalKey();

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
    final bgPath = getBackgroundPath(_currentLevel);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handleSystemBack();
      },
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgPath),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // 1. Background Gradient (Full Screen)
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

            // 2. Interactive UI (Safe Area)
            Positioned.fill(
              child: SafeArea(
                child: Stack(
                  children: [
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
                            width: 160,
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
                  ],
                ),
              ),
            ),

            // 3. Full Screen Overlays (Dimming effect must be full)
            if (_isHomeSettingsOpen) _buildHomeSettingsOverlay(),
            if (_isLanguagePanelOpen) _buildLanguageOverlay(),
            if (_isTutorialOpen) _buildTutorialOverlay(),

            // 4. Banner Ad (Safe Area at Bottom)
            if (_isBannerLoaded && _bannerAd != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    alignment: Alignment.center,
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(key: _adKey, ad: _bannerAd!),
                  ),
                ),
              ),
          ],
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
    if (_isLanguagePanelOpen) {
      return;
    }
    setState(() {
      _isHomeSettingsOpen = true;
      _isLevelsPanelOpen = false;
    });
  }

  void _closeHomeSettings() {
    setState(() {
      _isHomeSettingsOpen = false;
      _isLevelsPanelOpen = false;
    });
  }

  void _openLanguagePanel() {
    if (_isHomeSettingsOpen) {
      return;
    }
    setState(() {
      _isLanguagePanelOpen = true;
    });
  }

  void _closeLanguagePanel() {
    setState(() {
      _isLanguagePanelOpen = false;
    });
  }

  Future<void> _launchPrivacyPolicy() async {
    final url = Uri.parse('https://eamonstudio.com/tile-two/privacy-policy');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Privacy Policy')),
        );
      }
    }
  }

  Future<void> _launchTermsOfService() async {
    final url = Uri.parse('https://eamonstudio.com/tile-two/terms-of-service');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Terms of Service')),
        );
      }
    }
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
    });
  }

  Future<SaveGameData> _loadSaveData() async {
    final repository = SaveGameRepository();
    final saveData = await repository.load();
    if (!mounted) {
      return saveData;
    }
    AppLanguageController.instance.setLanguage(saveData.selectedLanguageCode);
    setState(() {
      _homeSaveData = saveData;
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
      _isSfxEnabled = _audio.sfxEnabled;
    });
    await _loadSaveData();
    if (mounted) {
      unawaited(precacheBackgrounds(context));
    }
    await _audio.playHomeLoop();
  }

  void _startGame({required int level}) {
    _audio.playGameLoop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(initialLevel: level),
      ),
    ).then((_) => _loadSaveData());
  }

  void _openLevelsPanel() {
    if (_isLanguagePanelOpen) {
      return;
    }
    setState(() {
      _isLevelsPanelOpen = true;
    });
  }

  void _closeLevelsPanel() {
    setState(() {
      _isLevelsPanelOpen = false;
    });
  }

  void _openTutorial() {
    if (_isLanguagePanelOpen) {
      return;
    }
    setState(() {
      _isHomeSettingsOpen = false;
      _isLevelsPanelOpen = false;
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
                width: _isLevelsPanelOpen ? 328 : 304,
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
                    : SingleChildScrollView(
                        child: Column(
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
                                    onTap: () async {
                                      final nextValue = !_isSfxEnabled;
                                      await _audio.setSfxEnabled(nextValue);
                                      if (!mounted) return;
                                      setState(() {
                                        _isSfxEnabled = nextValue;
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
                            const SizedBox(height: 14),
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
                              label: t.tr('settings.privacy_policy'),
                              colorStart: const Color(0xFF6B7592),
                              colorEnd: const Color(0xFF505B76),
                              onTap: _launchPrivacyPolicy,
                            ),
                            const SizedBox(height: 10),
                            _buildSettingsActionButton(
                              label: t.tr('settings.terms_of_service'),
                              colorStart: const Color(0xFF6B7592),
                              colorEnd: const Color(0xFF505B76),
                              onTap: _launchTermsOfService,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'v1.0.0+3',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(120),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCircleActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> gradientColors,
    double iconSize = 21,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(color: Colors.white.withAlpha(155), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
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
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(168), width: 1.3),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 20),
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
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Colors.white.withAlpha(245),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton({required VoidCallback onTap}) {
    return AnimatedBuilder(
      animation: _playPulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _playPulse.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF00E676), Color(0xFF00C853)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C853).withAlpha(115),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              AppI18n.of(context).tr('common.start').toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.8,
                shadows: [
                  Shadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
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
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(165), width: 1.2),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
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
              final unlocked = _devUnlockAll || level <= _completedLevels + 1;
              final selected = level == _selectedStartLevel;
              final startColor = unlocked
                  ? (selected ? const Color(0xFF56D4FF) : const Color(0xFF3A7BFF))
                  : const Color(0xFF4A556B);
              final endColor = unlocked
                  ? (selected ? const Color(0xFF2A9AD6) : const Color(0xFF3056CF))
                  : const Color(0xFF3A4358);
              return GestureDetector(
                onTap: unlocked
                    ? () {
                        setState(() {
                          _selectedStartLevel = level;
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
                        : const Icon(Icons.lock_rounded,
                            color: Color(0xFFB4BDCC), size: 18),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
                      final List<List<Color>> itemGradients = [
                        [const Color(0xFF5AC2FF), const Color(0xFF3B82F6)], // Blue
                        [const Color(0xFFA78BFF), const Color(0xFF7C3AED)], // Purple
                        [const Color(0xFF3BE2FF), const Color(0xFF0891B2)], // Cyan
                        [const Color(0xFFFF8B5A), const Color(0xFFEA580C)], // Orange
                        [const Color(0xFFF472B6), const Color(0xFFDB2777)], // Pink
                      ];
                      final gradient = isSelected
                        ? [const Color(0xFF34D399), const Color(0xFF059669)] // Green for selected
                        : itemGradients[index % itemGradients.length];

                      return GestureDetector(
                        onTap: () {
                          _selectLanguage(item.code);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradient,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withAlpha(isSelected ? 220 : 110),
                              width: 1.25,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(45),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.nativeName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    final t = AppI18n.of(context);
    final steps = _tutorialSteps(t);
    final step = steps[_tutorialStep];
    final isLastStep = _tutorialStep == steps.length - 1;
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.tr(
                    'tutorial.progress',
                    params: {
                      'current': '${_tutorialStep + 1}',
                      'total': '${steps.length}',
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildPrimaryButton(
                        label: isLastStep ? t.tr('common.start') : t.tr('common.next'),
                        startColor: const Color(0xFF00C896),
                        endColor: const Color(0xFF00A27C),
                        height: 48,
                        onTap: () {
                          if (isLastStep) {
                            _closeTutorial();
                          } else {
                            setState(() {
                              _tutorialStep++;
                            });
                          }
                        },
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
}

class _LanguageOption {
  final String code;
  final String nativeName;
  final String localizedName;
  const _LanguageOption({required this.code, required this.nativeName, required this.localizedName});
}

class _HomeTutorialStep {
  final String title;
  final String description;
  const _HomeTutorialStep({required this.title, required this.description});
}
