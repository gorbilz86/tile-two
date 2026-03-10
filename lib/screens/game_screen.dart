import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tile_two/game/game_state_controller.dart';
import 'package:tile_two/ui/slot_bar.dart';
import 'package:tile_two/ui/game_buttons.dart';
import 'package:tile_two/game/puzzle_game.dart';

/// Main Game Screen - Portrait Optimization
/// 
/// Combines the Flame Game Canvas with Flutter UI Overlays.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameStateController _gameStateController = GameStateController();
  late final PuzzleGame _game;

  @override
  void initState() {
    super.initState();
    _game = PuzzleGame(gameStateController: _gameStateController);
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

          // 2. UI Layer (Flutter Overlays)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: Level and Game Stats
                _buildHeader(),

                // Bottom: Slot Bar and Action Buttons
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
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(120),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'Level 1',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  const Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collected Tiles Slot Bar
          SlotBar(controller: _gameStateController),
          
          const SizedBox(height: 20),
          
          // Game Action Buttons (Undo, Shuffle, Hint)
          GameButtons(controller: _gameStateController),
        ],
      ),
    );
  }
}
