import 'package:flutter/foundation.dart';
import 'package:tile_two/components/tile_component.dart';

class GameStateController {
  final ValueNotifier<List<TileComponent>> selectedTiles = ValueNotifier([]);
  final List<TileComponent> boardTiles = [];
  static const int maxSlots = 7;
  VoidCallback? onMatch;
  VoidCallback? onShuffle;
  VoidCallback? onHint;
  void Function(TileComponent)? onTileSelected;
  void Function(TileComponent)? onUndo;

  void selectTile(TileComponent tile) {
    if (selectedTiles.value.length >= maxSlots) {
      return;
    }
    final current = List<TileComponent>.from(selectedTiles.value)..add(tile);
    selectedTiles.value = current;
    onShuffle?.call();
    onTileSelected?.call(tile);
  }

  void undoLastMove() {
    if (selectedTiles.value.isEmpty) {
      return;
    }
    final current = List<TileComponent>.from(selectedTiles.value);
    final tile = current.removeLast();
    selectedTiles.value = current;
    onUndo?.call(tile);
  }

  void shuffleBoard() {
    onShuffle?.call();
  }

  void provideHint() {
    onHint?.call();
  }
}
