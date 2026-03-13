import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:tile_two/components/tile_component.dart';
import 'package:tile_two/game/level_manager.dart';
import 'package:tile_two/game/tile_game.dart';

class BoardComponent extends PositionComponent with HasGameReference<TileGame> {
  final int columns = 6;
  final int rows = 6;
  final double layerOffsetY = -7;
  final double layerOffsetX = 5;
  final Future<void> Function(TileComponent tile) onTopTileTapped;
  double tileSize;
  double spacing;
  final List<TileComponent> _tiles = [];
  final Map<int, List<TileComponent>> _cellStacks = {};

  BoardComponent({
    required this.onTopTileTapped,
    required this.tileSize,
    required this.spacing,
  }) : super(
          anchor: Anchor.topLeft,
        );

  @override
  Future<void> onLoad() async {}

  void applyLayout({
    required double newTileSize,
    required double newSpacing,
    required Vector2 topLeft,
  }) {
    tileSize = newTileSize;
    spacing = newSpacing;
    position = topLeft;
    size = Vector2(
      columns * tileSize + (columns - 1) * spacing,
      rows * tileSize + (rows - 1) * spacing,
    );
    for (final tile in _tiles) {
      tile.relayout(
        newTileSize: tileSize,
        newTopLeft: _gridPosition(tile.column, tile.row, tile.layer),
        newPriority: _priorityFor(tile.row, tile.column, tile.layer),
      );
    }
    _refreshTapStates();
  }

  Future<void> loadLayout(LevelLayout layout) async {
    for (final tile in _tiles) {
      tile.removeFromParent();
    }
    _tiles.clear();
    _cellStacks.clear();

    for (final seed in layout.seeds) {
      final tile = TileComponent(
        type: seed.type,
        sprite: game.spriteForType(seed.type),
        onTapTile: _onTileTap,
        row: seed.row,
        column: seed.column,
        layer: seed.layer,
        tileSize: tileSize,
        position: _gridPosition(seed.column, seed.row, seed.layer),
        priority: _priorityFor(seed.row, seed.column, seed.layer),
        isTapEnabled: false,
      );
      _tiles.add(tile);
      final key = _cellKey(seed.row, seed.column);
      _cellStacks.putIfAbsent(key, () => []).add(tile);
      add(tile);
    }

    for (final stack in _cellStacks.values) {
      stack.sort((a, b) => a.layer.compareTo(b.layer));
    }
    _refreshTapStates();
  }

  Vector2 worldTopLeftOf(TileComponent tile) {
    return absolutePosition + tile.position;
  }

  bool consumeTopTile(TileComponent tile) {
    final key = _cellKey(tile.row, tile.column);
    final stack = _cellStacks[key];
    if (stack == null || stack.isEmpty || stack.last != tile) {
      return false;
    }
    stack.removeLast();
    _tiles.remove(tile);
    tile.removeFromParent();
    _refreshTapStates();
    return true;
  }

  Vector2 worldPositionForCell({
    required int row,
    required int column,
    required int layer,
  }) {
    return absolutePosition + _gridPosition(column, row, layer);
  }

  Vector2 worldPositionForRestore({
    required int row,
    required int column,
  }) {
    final layer = _nextLayer(row, column);
    return absolutePosition + _gridPosition(column, row, layer);
  }

  void restoreTile({
    required TileComponent tile,
    required int row,
    required int column,
  }) {
    final key = _cellKey(row, column);
    final stack = _cellStacks.putIfAbsent(key, () => []);
    final layer = _nextLayer(row, column);
    tile.setGridPosition(
      newRow: row,
      newColumn: column,
      newLayer: layer,
      newPriority: _priorityFor(row, column, layer),
    );
    tile.relayout(
      newTileSize: tileSize,
      newTopLeft: _gridPosition(column, row, layer),
      newPriority: _priorityFor(row, column, layer),
    );
    stack.add(tile);
    _tiles.add(tile);
    add(tile);
    _refreshTapStates();
  }

  Future<void> shuffleRemainingTiles() async {
    if (_tiles.length < 2) {
      return;
    }
    final slots = <({int row, int column, int layer})>[];
    for (final tile in _tiles) {
      slots.add((row: tile.row, column: tile.column, layer: tile.layer));
      tile.setTapEnabled(false);
    }
    slots.shuffle();
    for (var i = 0; i < _tiles.length; i++) {
      final tile = _tiles[i];
      final slot = slots[i];
      tile.setGridPosition(
        newRow: slot.row,
        newColumn: slot.column,
        newLayer: slot.layer,
        newPriority: _priorityFor(slot.row, slot.column, slot.layer),
      );
      tile.add(
        MoveEffect.to(
          _gridPosition(slot.column, slot.row, slot.layer),
          EffectController(duration: 0.28, curve: Curves.easeInOut),
        ),
      );
    }
    _rebuildStacks();
    await Future.delayed(const Duration(milliseconds: 300));
    _refreshTapStates();
  }

  List<TileComponent> hintTriple() {
    final playable = playableTopTiles();
    final byType = <String, List<TileComponent>>{};
    for (final tile in playable) {
      byType.putIfAbsent(tile.type, () => []).add(tile);
    }
    for (final entry in byType.entries) {
      if (entry.value.length >= 3) {
        return entry.value.take(3).toList();
      }
    }
    return const [];
  }

  List<TileComponent> playableTopTiles() {
    final playable = <TileComponent>[];
    for (final stack in _cellStacks.values) {
      if (stack.isNotEmpty) {
        playable.add(stack.last);
      }
    }
    return playable;
  }

  void highlightTiles(List<TileComponent> tiles, {double seconds = 1}) {
    for (final tile in tiles) {
      tile.highlightForSeconds(seconds);
    }
  }

  bool get isEmpty => _tiles.isEmpty;

  int get remainingTiles => _tiles.length;

  Future<void> _onTileTap(TileComponent tile) async {
    await onTopTileTapped(tile);
  }

  Vector2 _gridPosition(int column, int row, int layer) {
    return Vector2(
      column * (tileSize + spacing) + (layer * layerOffsetX),
      row * (tileSize + spacing) + (layer * layerOffsetY),
    );
  }

  int _cellKey(int row, int column) {
    return row * columns + column;
  }

  int _priorityFor(int row, int column, int layer) {
    return (layer * 2000) + (row * 50) + column;
  }

  int _nextLayer(int row, int column) {
    final key = _cellKey(row, column);
    final stack = _cellStacks[key];
    if (stack == null || stack.isEmpty) {
      return 0;
    }
    return stack.last.layer + 1;
  }

  void _syncStackTapState(List<TileComponent> stack) {
    for (var i = 0; i < stack.length; i++) {
      final tile = stack[i];
      final isTopInCell = i == stack.length - 1;
      tile.setTapEnabled(isTopInCell && !_isCoveredByHigher(tile));
    }
  }

  void _rebuildStacks() {
    _cellStacks.clear();
    for (final tile in _tiles) {
      final key = _cellKey(tile.row, tile.column);
      _cellStacks.putIfAbsent(key, () => []).add(tile);
    }
    for (final stack in _cellStacks.values) {
      stack.sort((a, b) => a.layer.compareTo(b.layer));
    }
  }

  void _refreshTapStates() {
    for (final stack in _cellStacks.values) {
      _syncStackTapState(stack);
    }
  }

  bool _isCoveredByHigher(TileComponent tile) {
    final tileRect = Rect.fromLTWH(
      tile.position.x,
      tile.position.y,
      tile.size.x,
      tile.size.y,
    );
    for (final other in _tiles) {
      if (identical(other, tile) || other.layer <= tile.layer) {
        continue;
      }
      final otherRect = Rect.fromLTWH(
        other.position.x,
        other.position.y,
        other.size.x,
        other.size.y,
      );
      if (tileRect.overlaps(otherRect)) {
        return true;
      }
    }
    return false;
  }
}
