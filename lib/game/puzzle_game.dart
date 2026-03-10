import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flame/camera.dart';
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
  Future<void> onLoad() async {
    await images.loadAll([
      'background.png',
      ...tileTypes.map((type) => 'tiles/$type.png'),
    ]);

    camera.viewport = FixedResolutionViewport(resolution: Vector2(720, 1280));

    // Background: Cover the viewport
    final bgSprite = Sprite(images.fromCache('background.png'));
    final bgSize = bgSprite.srcSize;
    // Calculate scale to COVER the viewport (BoxFit.cover equivalent)
    final scaleX = size.x / bgSize.x;
    final scaleY = size.y / bgSize.y;
    final scale = math.max(scaleX, scaleY);
    
    final drawSize = bgSize * scale;
    
    add(
      SpriteComponent(
        sprite: bgSprite,
        size: drawSize,
        position: size / 2,
        anchor: Anchor.center,
        priority: -10, // Ensure background is behind everything
      ),
    );

    const columns = 6;
    const rows = 8; // User requested 8 rows
    const spacing = 8.0; // User requested 8 spacing
    
    // Board positioning
    final boardWidth = size.x * 0.90; // Use 90% of width
    final boardHeight = size.y * 0.65; // Increased height allowance
    
    final tileFromWidth = (boardWidth - (columns - 1) * spacing) / columns;
    final tileFromHeight = (boardHeight - (rows - 1) * spacing) / rows;
    
    // User requested tile size 90. We cap at 85 to ensure it looks less "huge"
    final tileSize = math.min(85.0, math.min(tileFromWidth, tileFromHeight));

    board = BoardComponent(
      controller: gameStateController,
      tileTypes: tileTypes,
      columns: columns,
      rows: rows,
      tileSize: tileSize,
      spacing: spacing,
      position: Vector2(size.x / 2, size.y * 0.40), // Moved up significantly to avoid overlapping UI
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
