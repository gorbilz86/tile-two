import 'package:flutter/foundation.dart';

class GameStateController {
  VoidCallback? onMatch;
  VoidCallback? onShuffle;
  VoidCallback? onHint;
  VoidCallback? onUndo;

  void shuffleBoard() {
    onShuffle?.call();
  }

  void provideHint() {
    onHint?.call();
  }

  void undoLastMove() {
    onUndo?.call();
  }
}
