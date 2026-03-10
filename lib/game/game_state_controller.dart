import 'package:flutter/foundation.dart';
import 'package:flame/effects.dart';
import 'package:flame/components.dart';
import 'package:tile_two/components/tile_component.dart';

/// State Controller for the Tile Puzzle Game
/// 
/// Manages selected tiles, matching logic, Undo, Shuffle, and Hint systems.
class GameStateController {
  // Selected tiles currently in the slot bar
  final ValueNotifier<List<TileComponent>> selectedTiles = ValueNotifier([]);
  
  // Tiles currently active on the game board
  final List<TileComponent> boardTiles = [];
  
  // History for Undo (stacks the last move)
  final List<TileComponent> history = [];

  static const int maxSlots = 7;
  
  // Callbacks for game effects
  VoidCallback? onMatch;
  VoidCallback? onShuffle;
  VoidCallback? onHint;

  /// Selection logic: moves tile from board to slot bar
  void selectTile(TileComponent tile) {
    if (selectedTiles.value.length < maxSlots) {
      tile.isSelected = true;
      
      // Store original position and priority for Undo
      final originalPos = tile.position.clone();
      final originalPriority = tile.priority;
      
      // Add to history for Undo (using a record to store data)
      _historyData.add((tile, originalPos, originalPriority));
      
      // Remove from board list
      boardTiles.remove(tile);

      // Trigger move to slot animation in the board/game
      onTileSelected?.call(tile);

      // Add to selected tiles list
      final currentSelected = List<TileComponent>.from(selectedTiles.value);
      currentSelected.add(tile);
      selectedTiles.value = currentSelected;

      // Check for matches
      _checkForMatches();
    }
  }

  // Internal history tracking
  final List<(TileComponent, Vector2, int)> _historyData = [];

  /// Undo the last move
  void undoLastMove() {
    if (_historyData.isNotEmpty) {
      final (lastTile, originalPos, originalPriority) = _historyData.removeLast();
      
      // Remove from selected tiles
      final currentSelected = List<TileComponent>.from(selectedTiles.value);
      currentSelected.remove(lastTile);
      selectedTiles.value = currentSelected;
      
      // Move back to board
      lastTile.isSelected = false;
      boardTiles.add(lastTile);
      
      // Trigger undo animation
      onUndo?.call(lastTile, originalPos, originalPriority);
    }
  }

  // Callbacks for coordination with BoardComponent
  void Function(TileComponent)? onTileSelected;
  void Function(TileComponent, Vector2, int)? onUndo;

  /// Shuffle remaining tiles on board
  void shuffleBoard() {
    if (boardTiles.isEmpty) return;
    onShuffle?.call();
  }

  /// Provide a hint (highlight 3 matching tiles)
  void provideHint() {
    if (boardTiles.isEmpty) return;
    
    final typeMap = <String, List<TileComponent>>{};
    for (var tile in boardTiles) {
      if (!tile.isBlocked) {
        typeMap.putIfAbsent(tile.type, () => []).add(tile);
      }
    }

    for (var type in typeMap.keys) {
      if (typeMap[type]!.length >= 3) {
        final hintGroup = typeMap[type]!.take(3);
        for (var t in hintGroup) {
          t.highlight();
        }
        onHint?.call();
        return;
      }
    }
  }

  /// Matching logic for 3 tiles
  void _checkForMatches() {
    final current = selectedTiles.value;
    if (current.isEmpty) return;

    final typeCount = <String, List<TileComponent>>{};
    for (var tile in current) {
      typeCount.putIfAbsent(tile.type, () => []).add(tile);
    }

    String? matchType;
    typeCount.forEach((type, list) {
      if (list.length >= 3) {
        matchType = type;
      }
    });

    if (matchType != null) {
      final matchingTiles = current.where((t) => t.type == matchType).toList();
      final newSelected = List<TileComponent>.from(current)
        ..removeWhere((t) => t.type == matchType);
      
      Future.delayed(const Duration(milliseconds: 300), () {
        for (var t in matchingTiles) {
          _animateMatch(t);
        }
        selectedTiles.value = newSelected;
        onMatch?.call();
      });
    }
  }

  /// Private helper for match animation
  void _animateMatch(TileComponent tile) {
    tile.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.2), EffectController(duration: 0.1)),
        ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2)),
        RemoveEffect(),
      ]),
    );
  }
}
