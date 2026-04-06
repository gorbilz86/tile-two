import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:tile_two/components/tile_component.dart';
import 'package:tile_two/game/level_manager.dart';
import 'package:tile_two/game/tile_layout.dart';
import 'package:tile_two/game/tile_game.dart';

class BoardComponent extends PositionComponent with HasGameReference<TileGame> {
  final int columns = TileLayoutRules.boardColumns;
  final int rows = TileLayoutRules.boardRows;
  double get layerOffsetX => tileSize * TileLayoutRules.stackingOffsetRatio;
  double get layerOffsetY => -tileSize * TileLayoutRules.stackingOffsetRatio;
  final Future<void> Function(TileComponent tile) onTopTileTapped;
  double tileSize;
  double spacing;
  final List<TileComponent> _tiles = [];
  final Map<int, List<TileComponent>> _cellStacks = {};

  Vector2 _contentOffset = Vector2.zero();

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
    
    // Stabilize: Recalculate content offset BEFORE updating tile positions
    _updateContentOffsetFromTiles();
    
    for (final tile in _tiles) {
      // PREMIUM FIX: Abort active movement effects to prevent "messy" drift 
      // during screen transitions or ad-resizes.
      tile.removeAll(tile.children.whereType<MoveEffect>());
      
      tile.relayout(
        newTileSize: tileSize,
        newTopLeft: _gridPosition(
          tile.column,
          tile.row,
          tile.layer,
          tile.tileAnchor,
          tile.gridOffsetX,
          tile.gridOffsetY,
          tile.stackOffsetX,
          tile.stackOffsetY,
        ),
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
    _updateContentOffsetFromSeeds(layout);

    for (final seed in layout.seeds) {
      final tile = TileComponent(
        type: seed.type,
        sprite: game.spriteForType(seed.type),
        onTapTile: _onTileTap,
        row: seed.row,
        column: seed.column,
        layer: seed.layer,
        tileSize: tileSize,
        position: _gridPosition(
          seed.column,
          seed.row,
          seed.layer,
          seed.anchor,
          seed.gridOffsetX,
          seed.gridOffsetY,
          seed.stackOffsetX,
          seed.stackOffsetY,
        ),
        gridOffsetX: seed.gridOffsetX,
        gridOffsetY: seed.gridOffsetY,
        stackOffsetX: seed.stackOffsetX,
        stackOffsetY: seed.stackOffsetY,
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
    required double row,
    required double column,
    required int layer,
  }) {
    return absolutePosition + _gridPosition(column, row, layer, AnchorType.center);
  }

  Vector2 worldPositionForRestore({
    required double row,
    required double column,
  }) {
    final layer = _nextLayer(row, column);
    return absolutePosition + _gridPosition(column, row, layer, AnchorType.center);
  }

  void restoreTile({
    required TileComponent tile,
    required double row,
    required double column,
  }) {
    final key = _cellKey(row, column);
    final stack = _cellStacks.putIfAbsent(key, () => []);
    final layer = _nextLayer(row, column);
    tile.setGridPosition(
      newRow: row,
      newColumn: column,
      newLayer: layer,
      newPriority: _priorityFor(row, column, layer),
      newAnchor: tile.tileAnchor,
    );
    tile.relayout(
      newTileSize: tileSize,
      newTopLeft: _gridPosition(
        column,
        row,
        layer,
        tile.tileAnchor,
        tile.gridOffsetX,
        tile.gridOffsetY,
        tile.stackOffsetX,
        tile.stackOffsetY,
      ),
      newPriority: _priorityFor(row, column, layer),
    );
    stack.add(tile);
    _tiles.add(tile);
    add(tile);
    _refreshTapStates();
  }

  Future<bool> shuffleRemainingTiles() async {
    if (_tiles.length < 2) {
      return false;
    }
    final slots = <({double row, double column, int layer, AnchorType anchor})>[];
    for (final tile in _tiles) {
      slots.add((row: tile.row, column: tile.column, layer: tile.layer, anchor: tile.tileAnchor));
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
        newAnchor: slot.anchor,
      );
      tile.add(
        MoveEffect.to(
          _gridPosition(
            slot.column,
            slot.row,
            slot.layer,
            tile.tileAnchor,
            tile.gridOffsetX,
            tile.gridOffsetY,
            tile.stackOffsetX,
            tile.stackOffsetY,
          ),
          EffectController(duration: 0.28, curve: Curves.easeInOut),
        ),
      );
    }
    _rebuildStacks();
    await Future.delayed(const Duration(milliseconds: 300));
    _refreshTapStates();
    return true;
  }

  Future<void> playLevelStartIntro() async {
    if (_tiles.isEmpty) {
      return;
    }
    const moveDuration = 0.68;
    const staggerDelay = 0.006;
    angle = -0.014;
    scale = Vector2.all(0.975);
    add(
      SequenceEffect(
        [
          ScaleEffect.to(
            Vector2.all(1.01),
            EffectController(duration: 0.24, curve: Curves.easeOut),
          ),
          ScaleEffect.to(
            Vector2.all(1),
            EffectController(duration: 0.2, curve: Curves.easeInOut),
          ),
        ],
      ),
    );
    add(
      SequenceEffect(
        [
          RotateEffect.to(
            0.006,
            EffectController(duration: 0.22, curve: Curves.easeOut),
          ),
          RotateEffect.to(
            0,
            EffectController(duration: 0.2, curve: Curves.easeInOut),
          ),
        ],
      ),
    );
    final center = Vector2(size.x / 2, size.y / 2);
    for (var i = 0; i < _tiles.length; i++) {
      final tile = _tiles[i];
      final target = _gridPosition(
        tile.column,
        tile.row,
        tile.layer,
        tile.tileAnchor,
        tile.gridOffsetX,
        tile.gridOffsetY,
        tile.stackOffsetX,
        tile.stackOffsetY,
      );
      final drift = (target - center)..scale(0.18);
      tile.position = target + Vector2(drift.x * 0.72, -30 - ((i % 5) * 6));
      tile.scale = Vector2.all(0.05); // Start tiny instead of transparent
      tile.opacity = 1; // Fully opaque to prevent expensive alpha composition rendering
      tile.setTapEnabled(false);
      tile.add(
        MoveEffect.to(
          target,
          EffectController(
            duration: moveDuration,
            curve: Curves.easeOutCubic,
            startDelay: i * staggerDelay,
          ),
        ),
      );
      tile.add(
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(
            duration: moveDuration * 0.85,
            curve: Curves.easeOutBack,
            startDelay: i * staggerDelay,
          ),
        ),
      );
    }
    final totalSeconds = moveDuration + ((_tiles.length - 1) * staggerDelay) + 0.06;
    await Future<void>.delayed(
      Duration(milliseconds: (totalSeconds * 1000).round()),
    );
    angle = 0;
    scale = Vector2.all(1);
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

  Vector2 _gridPosition(
    double column,
    double row,
    int layer,
    AnchorType anchor, [
    double gridOffsetX = 0,
    double gridOffsetY = 0,
    double stackOffsetX = 0,
    double stackOffsetY = 0,
  ]) {
    return _rawGridPosition(
      column,
      row,
      layer,
      anchor,
      gridOffsetX,
      gridOffsetY,
      stackOffsetX,
      stackOffsetY,
    ) + _contentOffset;
  }

  Vector2 _rawGridPosition(
    double column,
    double row,
    int layer,
    AnchorType anchor, [
    double gridOffsetX = 0,
    double gridOffsetY = 0,
    double stackOffsetX = 0,
    double stackOffsetY = 0,
  ]) {
    final tileStep = tileSize + spacing;
    final double unit = tileSize * TileLayoutRules.stackingOffsetRatio;
    Vector2 anchorOffset = Vector2.zero();
    switch (anchor) {
      case AnchorType.center: break;
      case AnchorType.topLeft: anchorOffset = Vector2(-unit, -unit); break;
      case AnchorType.topRight: anchorOffset = Vector2(unit, -unit); break;
      case AnchorType.bottomLeft: anchorOffset = Vector2(-unit, unit); break;
      case AnchorType.bottomRight: anchorOffset = Vector2(unit, unit); break;
    }
    return Vector2(
      (column + gridOffsetX) * tileStep + (layer * layerOffsetX) + stackOffsetX + anchorOffset.x,
      (row + gridOffsetY) * tileStep + (layer * layerOffsetY) + stackOffsetY + anchorOffset.y,
    );
  }

  void _updateContentOffsetFromTiles() {
    if (_tiles.isEmpty) {
      _contentOffset = Vector2.zero();
      return;
    }
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final tile in _tiles) {
      final pos = _rawGridPosition(
        tile.column,
        tile.row,
        tile.layer,
        tile.tileAnchor,
        tile.gridOffsetX,
        tile.gridOffsetY,
        tile.stackOffsetX,
        tile.stackOffsetY,
      );
      if (pos.x < minX) minX = pos.x;
      if (pos.x > maxX) maxX = pos.x;
      if (pos.y < minY) minY = pos.y;
      if (pos.y > maxY) maxY = pos.y;
    }
    _finalizeContentOffset(minX, maxX, minY, maxY);
  }

  void _updateContentOffsetFromSeeds(LevelLayout layout) {
    if (layout.seeds.isEmpty) {
      _contentOffset = Vector2.zero();
      return;
    }
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final seed in layout.seeds) {
      final pos = _rawGridPosition(
        seed.column,
        seed.row,
        seed.layer,
        seed.anchor,
        seed.gridOffsetX,
        seed.gridOffsetY,
        seed.stackOffsetX,
        seed.stackOffsetY,
      );
      if (pos.x < minX) minX = pos.x;
      if (pos.x > maxX) maxX = pos.x;
      if (pos.y < minY) minY = pos.y;
      if (pos.y > maxY) maxY = pos.y;
    }
    _finalizeContentOffset(minX, maxX, minY, maxY);
  }

  void _finalizeContentOffset(double minX, double maxX, double minY, double maxY) {
    final contentWidth = (maxX - minX) + tileSize;
    final contentHeight = (maxY - minY) + tileSize;
    final boardWidth = columns * tileSize + (columns - 1) * spacing;
    final boardHeight = rows * tileSize + (rows - 1) * spacing;
    _contentOffset = Vector2(
      (boardWidth - contentWidth) / 2 - minX,
      (boardHeight - contentHeight) / 2 - minY,
    );
  }

  int _cellKey(double row, double column) {
    return (row * 2).round() * (columns * 2) + (column * 2).round();
  }

  int _priorityFor(double row, double column, int layer) {
    return (layer * 1000) + (row * 10).toInt() + column.toInt();
  }

  int _nextLayer(double row, double column) {
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
      final coveredByHigher = _isCoveredByHigher(tile);
      tile.setCoveredByHigher(coveredByHigher);
      tile.setTapEnabled(isTopInCell && !coveredByHigher);
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
    // BAROMETER FIX: Use the actual white 'Face' rectangle with a small extra tolerance.
    // This ignores 3D "side" visual overlaps and provides a forgiving margin for the player.
    const double extraTolerance = 4.0;
    final tileFace = tile.faceRectInBoard.deflate(extraTolerance);
    
    for (final other in _tiles) {
      if (identical(other, tile) || other.layer <= tile.layer) {
        continue;
      }
      // Compare face-to-face overlap for high precision
      if (tileFace.overlaps(other.faceRectInBoard.deflate(extraTolerance))) {
        return true;
      }
    }
    return false;
  }
}
