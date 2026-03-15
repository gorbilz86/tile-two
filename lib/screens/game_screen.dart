import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tile_two/ui/game_buttons.dart';
import 'package:tile_two/game/tile_game.dart';

/// Main Game Screen - Portrait Optimization
/// 
/// Combines the Flame Game Canvas with Flutter UI Overlays.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TileGame _game;

  @override
  void initState() {
    super.initState();
    _game = TileGame(footerReservedHeight: 175);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover, // Ensures the background fills the entire device screen
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(170),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withAlpha(70), width: 1.6),
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ValueListenableBuilder<String>(
        valueListenable: _game.levelBannerNotifier,
        builder: (context, label, child) {
          return Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          );
        },
      ),
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
        ],
      ),
    );
  }
}
