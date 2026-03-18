import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tile_two/game/game_audio_service.dart';
import 'package:tile_two/game/save_game_repository.dart';
import 'package:tile_two/game/tile_layout.dart';
import 'package:tile_two/screens/game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GameAudioService _audio = GameAudioService.instance;
  bool _isHomeSettingsOpen = false;
  bool _isLevelsPanelOpen = false;
  bool _isTutorialOpen = false;
  bool _isSfxEnabled = true;
  bool _isMusicEnabled = true;
  int _currentLevel = 1;
  int _completedLevels = 0;
  int _selectedStartLevel = 1;
  int _tutorialStep = 0;

  final List<_HomeTutorialStep> _tutorialSteps = const [
    _HomeTutorialStep(
      title: 'Selamat Datang',
      description: 'Tap ubin teratas untuk memindahkan ke slot bar.',
    ),
    _HomeTutorialStep(
      title: 'Buat Match 3',
      description: 'Kumpulkan 3 ubin buah sama untuk menghapusnya.',
    ),
    _HomeTutorialStep(
      title: 'Jaga Slot Tetap Aman',
      description: 'Kalau slot penuh sebelum board habis, level gagal.',
    ),
    _HomeTutorialStep(
      title: 'Gunakan Booster',
      description: 'Undo, Shuffle, dan Hint bantu selesaikan level sulit.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
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
              right: 12,
              child: GestureDetector(
                onTap: _openHomeSettings,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF6E8FAE),
                        Color(0xFF4D6E8E),
                      ],
                    ),
                    border: Border.all(
                        color: Colors.white.withAlpha(210), width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(70),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: 64),
                  Text(
                    'Tile Two',
                    style: GoogleFonts.poppins(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.1,
                      shadows: const [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Match 3 puzzle layered board',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(225),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 228,
                    child: _buildPlayButton(
                      onTap: () {
                        _startGame(level: _selectedStartLevel);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 228,
                    child: _buildPrimaryButton(
                      label: 'Keluar',
                      startColor: const Color(0xFF54627E),
                      endColor: const Color(0xFF3C4861),
                      onTap: () {
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
            if (_isHomeSettingsOpen) _buildHomeSettingsOverlay(),
            if (_isTutorialOpen) _buildTutorialOverlay(),
          ],
        ),
      ),
    );
  }

  void _openHomeSettings() {
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

  Future<void> _loadSaveData() async {
    final repository = SaveGameRepository();
    final saveData = await repository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentLevel = saveData.currentLevel;
      _completedLevels = saveData.completedLevels;
      _selectedStartLevel = _currentLevel;
    });
  }

  Future<void> _initializeHome() async {
    await _audio.init();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMusicEnabled = _audio.musicEnabled;
    });
    await _loadSaveData();
    await _audio.playHomeLoop();
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
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeHomeSettings,
        child: ColoredBox(
          color: Colors.black.withAlpha(155),
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
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                            label: 'Continue',
                            colorStart: const Color(0xFF00C896),
                            colorEnd: const Color(0xFF00A27C),
                            onTap: () {
                              _closeHomeSettings();
                              _startGame(level: _selectedStartLevel);
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildSettingsActionButton(
                            label: 'Restart',
                            colorStart: const Color(0xFF5569FF),
                            colorEnd: const Color(0xFF3F51D6),
                            onTap: () {
                              _closeHomeSettings();
                              _startGame(level: _selectedStartLevel);
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildSettingsActionButton(
                            label: 'Home',
                            colorStart: const Color(0xFF8A5CFF),
                            colorEnd: const Color(0xFF6A46D6),
                            onTap: _closeHomeSettings,
                          ),
                          const SizedBox(height: 10),
                          _buildSettingsActionButton(
                            label: 'Tutorial',
                            colorStart: const Color(0xFF28B8C7),
                            colorEnd: const Color(0xFF1F8F9B),
                            onTap: _openTutorial,
                          ),
                          const SizedBox(height: 10),
                          _buildSettingsActionButton(
                            label: 'Levels',
                            colorStart: const Color(0xFFFF7A59),
                            colorEnd: const Color(0xFFD85A3E),
                            onTap: _openLevelsPanel,
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

  Widget _buildTutorialOverlay() {
    final step = _tutorialSteps[_tutorialStep];
    final isLastStep = _tutorialStep == _tutorialSteps.length - 1;
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
                  'Tutorial ${_tutorialStep + 1}/${_tutorialSteps.length}',
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
                  children: List.generate(_tutorialSteps.length, (index) {
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
                        label: 'Skip',
                        onTap: _closeTutorial,
                        start: const Color(0xFF5A6783),
                        end: const Color(0xFF45526B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverlayActionButton(
                        label: _tutorialStep == 0 ? 'Back' : 'Prev',
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
                        label: isLastStep ? 'Mulai' : 'Next',
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00C896),
              Color(0xFF00A27C),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withAlpha(188), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(85),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 38,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
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
              fontSize: 22,
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
