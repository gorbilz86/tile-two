import 'package:tile_two/game/game_state_controller.dart';
import 'package:tile_two/game/tile_game.dart';

class PuzzleGame extends TileGame {
  PuzzleGame({required GameStateController gameStateController})
      : super(footerReservedHeight: 235);
}
