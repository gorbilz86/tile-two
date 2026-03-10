import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flame/camera.dart';
import 'package:flutter/painting.dart'; // Import for Color
import 'package:tile_two/components/board_component.dart';
import 'package:tile_two/game/game_state_controller.dart';

/// Professional Tile Puzzle Game Class
/// 
/// Manages the game world, camera, and high-level logic with responsive scaling.
class PuzzleGame extends FlameGame {
  final GameStateController gameStateController;
  late final BoardComponent board;

  PuzzleGame({required this.gameStateController});

  final List<String> tileTypes = [
    'strawberry', 'watermelon', 'star', 'crown', 'burger', 'ice_cream'
  ];

  @override
  Color backgroundColor() => const Color(0x00000000); // Transparent to show Flutter background

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/images';
    await images.loadAll(
      [
        'background.png',
        ...tileTypes.map((type) => 'tiles/$type.png'),
      ],
    );

    camera.viewport = FixedResolutionViewport(resolution: Vector2(720, 1280));

    // Background handled by Flutter (GameScreen) for better full-screen scaling

    const columns = 3;
    const rows = 4;
    const spacing = 16.0;

    board = BoardComponent(
      controller: gameStateController,
      tileTypes: tileTypes,
      columns: columns,
      rows: rows,
      tileSize: 1.0, // Will be recalculated on first onGameResize
      spacing: spacing,
      position: size / 2, // Perfectly centered on screen
    );
    add(board);

    gameStateController.onMatch = () {
      camera.viewfinder.add(
        MoveEffect.by(
          Vector2(10, 10),
          EffectController(duration: 0.1, alternate: true, repeatCount: 2),
        ),
      );
    };

    return super.onLoad();
  }
}
