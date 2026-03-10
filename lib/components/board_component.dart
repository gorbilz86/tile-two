import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:tile_two/components/tile_component.dart';
import 'package:tile_two/game/game_state_controller.dart';
import 'package:tile_two/game/puzzle_game.dart';

class BoardComponent extends PositionComponent with HasGameReference<PuzzleGame> {
  final GameStateController controller;
  final List<String> tileTypes;
  final int columns;
  final int rows;
  double tileSize;
  final double spacing;

  late List<List<TileComponent?>> _grid;
  final Map<TileComponent, Point<int>> _tileCell = {};
  _BoardBackground? _background;

  BoardComponent({
    required this.controller,
    required this.tileTypes,
    required this.columns,
    required this.rows,
    required this.tileSize,
    required this.spacing,
    super.position,
  }) : super(
          size: Vector2(
            columns * tileSize + (columns - 1) * spacing,
            rows * tileSize + (rows - 1) * spacing,
          ),
          anchor: Anchor.center, // Kunci: Board sendiri di tengah
        );

  @override
  Future<void> onLoad() async {
    // Add a semi-transparent panel behind the tiles for readability
    _background = _BoardBackground(
      size: size,
      radius: 24,
      color: Colors.black.withAlpha(60),
    );
    add(_background!);

    _initializeGrid();
    _generateLevel();

    controller.onShuffle = _shuffleTiles;
    controller.onTileSelected = _handleTileSelected;
    controller.onUndo = _handleUndo;
  }

  @override
  void onGameResize(Vector2 screenSize) {
    super.onGameResize(screenSize);
    // Hitung tileSize agar grid pas di layar dan tetap terpusat
    final availableWidth = screenSize.x;
    final availableHeight = screenSize.y;
    final tileFromWidth = (availableWidth - (columns - 1) * spacing) / columns;
    final tileFromHeight = (availableHeight - (rows - 1) * spacing) / rows;
    tileSize = min(tileFromWidth, tileFromHeight);

    size = Vector2(
      columns * tileSize + (columns - 1) * spacing,
      rows * tileSize + (rows - 1) * spacing,
    );
    position = screenSize / 2;
    if (_background != null) {
      _background!
        ..size = size;
    }

    // Relayout semua tile ke pusat sel masing-masing
    for (final entry in _tileCell.entries) {
      final tile = entry.key;
      final cell = entry.value;
      final xPos = cell.x * (tileSize + spacing) + tileSize / 2;
      final yPos = cell.y * (tileSize + spacing) + tileSize / 2;
      tile.relayout(
        newTileSize: tileSize,
        newCenter: Vector2(xPos, yPos),
      );
    }
  }

  void _initializeGrid() {
    _grid = List.generate(columns, (_) => List.generate(rows, (_) => null));
  }

  void _handleTileSelected(TileComponent tile) {
    final cell = _tileCell[tile];
    if (cell != null) {
      _grid[cell.x][cell.y] = null;
      _tileCell.remove(tile);
    }

    // Hitung posisi global slot bar (relatif terhadap layar game)
    final targetGlobal = Vector2(game.size.x * 0.5, game.size.y * 0.78);
    // Ubah ke koordinat lokal board
    final targetLocal = targetGlobal - (game.size / 2 - size / 2);

    tile.priority = 1000;
    tile.add(
      SequenceEffect([
        MoveEffect.to(
          targetLocal,
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
        ScaleEffect.to(Vector2.all(0.8), EffectController(duration: 0.1)),
        OpacityEffect.to(0, EffectController(duration: 0.05)),
      ]),
    );

    _updateBlockingState();
  }

  void _handleUndo(TileComponent tile, Vector2 originalPos, int originalPriority) {
    tile.isSelected = false;
    tile.priority = originalPriority;

    final col = (originalPos.x / (tileSize + spacing)).round().clamp(0, columns - 1);
    final row = (originalPos.y / (tileSize + spacing)).round().clamp(0, rows - 1);
    _grid[col][row] = tile;
    _tileCell[tile] = Point(col, row);

    tile.add(
      SequenceEffect([
        OpacityEffect.to(1, EffectController(duration: 0.1)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.1)),
        MoveEffect.to(
          originalPos,
          EffectController(duration: 0.25, curve: Curves.easeOutBack),
        ),
      ]),
    );

    _updateBlockingState();
  }

  void _generateLevel() {
    final random = Random();
    final totalCells = columns * rows;

    final pool = <String>[];
    while (pool.length < totalCells) {
      final type = tileTypes[random.nextInt(tileTypes.length)];
      pool.addAll([type, type, type]);
    }
    pool.shuffle();

    int index = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final type = pool[index++];
        
        // Kalkulasi posisi setiap tile agar pas di grid board
        final xPos = col * (tileSize + spacing) + tileSize / 2;
        final yPos = row * (tileSize + spacing) + tileSize / 2;

        final tile = TileComponent(
          type: type,
          controller: controller,
          iconSprite: Sprite(game.images.fromCache('tiles/$type.png')),
          tileSize: tileSize,
          position: Vector2(xPos, yPos),
          priority: row * columns + col,
        );

        add(tile);
        controller.boardTiles.add(tile);
        _grid[col][row] = tile;
        _tileCell[tile] = Point(col, row);
      }
    }

    _updateBlockingState();
  }

  void _updateBlockingState() {
    for (final tile in controller.boardTiles) {
      tile.isBlocked = false;
    }
  }

  void _shuffleTiles() {
    final tiles = List<TileComponent>.from(controller.boardTiles);
    final positions = <Point<int>>[];
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        positions.add(Point(col, row));
      }
    }
    positions.shuffle();

    _grid = List.generate(columns, (_) => List.generate(rows, (_) => null));
    _tileCell.clear();

    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      final cell = positions[i];
      
      final xPos = cell.x * (tileSize + spacing) + tileSize / 2;
      final yPos = cell.y * (tileSize + spacing) + tileSize / 2;

      tile.add(
        MoveEffect.to(
          Vector2(xPos, yPos),
          EffectController(duration: 0.4, curve: Curves.easeInOut),
        ),
      );
      _grid[cell.x][cell.y] = tile;
      _tileCell[tile] = cell;
    }

    Future.delayed(const Duration(milliseconds: 450), _updateBlockingState);
  }
}

class _BoardBackground extends PositionComponent {
  final double radius;
  final Color color;

  _BoardBackground({
    required Vector2 size,
    required this.radius,
    required this.color,
  }) : super(size: size);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = color);
  }
}
