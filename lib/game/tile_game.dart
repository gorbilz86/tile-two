import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:tile_two/components/board_component.dart';
import 'package:tile_two/components/slot_bar.dart';
import 'package:tile_two/components/tile_component.dart';
import 'package:tile_two/game/level_manager.dart';

class TileGame extends FlameGame {
  final double footerReservedHeight;
  final ValueNotifier<int> levelNotifier = ValueNotifier<int>(1);
  final ValueNotifier<String> levelBannerNotifier = ValueNotifier<String>('Level 1');
  final List<String> tileTypes = [
    'strawberry',
    'watermelon',
    'star',
    'crown',
    'burger',
    'ice_cream',
  ];

  late final BoardComponent board;
  late final SlotBarComponent slotBar;
  late final LevelManager levelManager;

  final List<TileComponent> _slotTiles = [];
  final List<_MoveRecord> _history = [];
  bool _busy = false;
  bool _componentsReady = false;
  double _tileSize = 64;
  final double _spacing = 6;

  TileGame({required this.footerReservedHeight});

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/images/';
    await images.loadAll([
      ...tileTypes.map((type) => 'tiles/$type.png'),
    ]);

    camera.viewport = MaxViewport();

    levelManager = LevelManager(tileTypes: tileTypes);
    board = BoardComponent(
      onTopTileTapped: _handleBoardTap,
      tileSize: _tileSize,
      spacing: _spacing,
    );
    slotBar = SlotBarComponent(
      slotSize: _tileSize,
      spacing: _spacing,
    );

    await add(board);
    await add(slotBar);
    _componentsReady = true;
    _relayout(size);
    await _loadLevel(levelNotifier.value);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _relayout(size);
  }

  Future<void> _loadLevel(int level) async {
    _slotTiles.clear();
    _history.clear();
    levelNotifier.value = level.clamp(1, 50);
    levelBannerNotifier.value = 'Level $level';
    final layout = levelManager.build(level: level, columns: board.columns, rows: board.rows);
    await board.loadLayout(layout);
  }

  void _relayout(Vector2 canvasSize) {
    if (!_componentsReady || canvasSize.x <= 0 || canvasSize.y <= 0) {
      return;
    }
    final baseTileSize = canvasSize.x / 8;
    _tileSize = baseTileSize * 0.92;
    final slotSize = _tileSize * 0.9;
    slotBar.updateLayout(
      topLeft: Vector2(
        (canvasSize.x - ((slotBar.slotCount * slotSize) + ((slotBar.slotCount - 1) * _spacing))) / 2,
        canvasSize.y - footerReservedHeight + 8,
      ),
      newSlotSize: slotSize,
      newSpacing: _spacing,
    );

    final boardWidth = (board.columns * _tileSize) + ((board.columns - 1) * _spacing);
    final boardHeight = (board.rows * _tileSize) + ((board.rows - 1) * _spacing);
    final playAreaBottom = slotBar.position.y - 18;
    final top = ((playAreaBottom - boardHeight) / 2)
        .clamp(30, playAreaBottom - boardHeight)
        .toDouble();

    board.applyLayout(
      newTileSize: _tileSize,
      newSpacing: _spacing,
      topLeft: Vector2((canvasSize.x - boardWidth) / 2, top),
    );

    for (var i = 0; i < _slotTiles.length; i++) {
      _slotTiles[i].relayout(
        newTileSize: slotSize,
        newTopLeft: slotBar.slotTopLeft(i),
        newPriority: 3000 + i,
      );
    }
  }

  Future<void> _handleBoardTap(TileComponent tile) async {
    if (_busy || _slotTiles.length >= slotBar.slotCount) {
      return;
    }
    final originRow = tile.row;
    final originColumn = tile.column;
    final worldTopLeft = board.worldTopLeftOf(tile);
    final consumed = board.consumeTopTile(tile);
    if (!consumed) {
      return;
    }

    tile
      ..isInTransit = true
      ..setTapEnabled(false)
      ..position = worldTopLeft
      ..priority = 3000;
    tile.relayout(
      newTileSize: slotBar.slotSize,
      newTopLeft: worldTopLeft,
      newPriority: 3000,
    );
    add(tile);

    final slotIndex = _slotTiles.length;
    final target = slotBar.slotTopLeft(slotIndex);
    tile.add(
      MoveEffect.to(
        target,
        EffectController(duration: 0.25, curve: Curves.easeOutCubic),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 250));
    tile.isInTransit = false;
    _slotTiles.add(tile);
    _history.add(
      _MoveRecord(
        tile: tile,
        row: originRow,
        column: originColumn,
      ),
    );

    await _resolveMatches();
    await _checkLevelProgression();
  }

  Future<void> _resolveMatches() async {
    final grouped = <String, List<TileComponent>>{};
    for (final tile in _slotTiles) {
      grouped.putIfAbsent(tile.type, () => []).add(tile);
    }

    final entry = grouped.entries.firstWhere(
      (element) => element.value.length >= 3,
      orElse: () => const MapEntry('', []),
    );
    if (entry.key.isEmpty) {
      return;
    }

    _busy = true;
    final matched = entry.value.take(3).toList();
    for (final tile in matched) {
      _spawnMatchBurst(tile.position + (tile.size / 2));
      tile.add(
        SequenceEffect(
          [
            ScaleEffect.to(
              Vector2.all(1.12),
              EffectController(duration: 0.08),
            ),
            ScaleEffect.to(
              Vector2.zero(),
              EffectController(duration: 0.14, curve: Curves.easeInBack),
            ),
            OpacityEffect.to(
              0,
              EffectController(duration: 0.08),
            ),
          ],
        ),
      );
    }
    await Future.delayed(const Duration(milliseconds: 260));

    for (final tile in matched) {
      _slotTiles.remove(tile);
      _history.removeWhere((record) => record.tile == tile);
      tile.removeFromParent();
    }
    await _shiftSlotTilesLeft();
    _busy = false;
  }

  Future<void> _shiftSlotTilesLeft() async {
    for (var i = 0; i < _slotTiles.length; i++) {
      final tile = _slotTiles[i];
      final target = slotBar.slotTopLeft(i);
      tile.add(
        MoveEffect.to(
          target,
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
      tile.priority = 3000 + i;
    }
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _checkLevelProgression() async {
    if (!board.isEmpty) {
      return;
    }
    _busy = true;
    levelBannerNotifier.value = 'Level ${levelNotifier.value} Complete';
    await Future.delayed(const Duration(milliseconds: 700));
    for (final tile in _slotTiles) {
      tile.removeFromParent();
    }
    _slotTiles.clear();
    final nextLevel = levelNotifier.value >= 50 ? 1 : levelNotifier.value + 1;
    await _loadLevel(nextLevel);
    _busy = false;
  }

  Future<void> shuffleBoard() async {
    if (_busy) {
      return;
    }
    _busy = true;
    await board.shuffleRemainingTiles();
    _busy = false;
  }

  void provideHint() {
    if (_busy) {
      return;
    }
    final hint = board.hintTriple();
    if (hint.isEmpty) {
      return;
    }
    board.highlightTiles(hint, seconds: 1);
  }

  Future<void> undoLastMove() async {
    if (_busy || _history.isEmpty || _slotTiles.isEmpty) {
      return;
    }
    final record = _history.removeLast();
    if (!_slotTiles.contains(record.tile)) {
      return;
    }
    _busy = true;
    _slotTiles.remove(record.tile);
    await _shiftSlotTilesLeft();
    final target = board.worldPositionForRestore(
      row: record.row,
      column: record.column,
    );
    record.tile
      ..isInTransit = true
      ..setTapEnabled(false);
    record.tile.add(
      MoveEffect.to(
        target,
        EffectController(duration: 0.25, curve: Curves.easeOut),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 250));
    record.tile.isInTransit = false;
    record.tile.removeFromParent();
    board.restoreTile(
      tile: record.tile,
      row: record.row,
      column: record.column,
    );
    _busy = false;
  }

  void _spawnMatchBurst(Vector2 center) {
    final random = math.Random();
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 12,
          lifespan: 0.28,
          generator: (index) {
            final angle = (math.pi * 2 * index) / 12;
            final speed = 45 + random.nextDouble() * 60;
            return AcceleratedParticle(
              acceleration: Vector2(0, 120),
              speed: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
              position: center.clone(),
              child: CircleParticle(
                radius: 1.5 + random.nextDouble() * 1.8,
                paint: Paint()..color = const Color(0xFFFFE082),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MoveRecord {
  final TileComponent tile;
  final int row;
  final int column;

  const _MoveRecord({
    required this.tile,
    required this.row,
    required this.column,
  });
}
