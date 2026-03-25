import 'package:tile_two/game/level_generator.dart';

class TileSeed {
  final int row;
  final int column;
  final int layer;
  final String type;
  final double gridOffsetX;
  final double gridOffsetY;
  final double stackOffsetX;
  final double stackOffsetY;

  const TileSeed({
    required this.row,
    required this.column,
    required this.layer,
    required this.type,
    this.gridOffsetX = 0,
    this.gridOffsetY = 0,
    this.stackOffsetX = 0,
    this.stackOffsetY = 0,
  });
}

class LevelLayout {
  final List<TileSeed> seeds;

  const LevelLayout({required this.seeds});
}

class LevelManager {
  const LevelManager();

  LevelLayout build({
    required int level,
    required int columns,
    required int rows,
    required List<String> tileTypes,
  }) {
    final generator = LevelGenerator(
      columns: columns,
      rows: rows,
      maxTileTypes: tileTypes.length,
    );
    final generated = generator.generateLevel(level);
    final seeds = <TileSeed>[];
    for (final tile in generated.tiles) {
      final tileIndex = tile.type.clamp(0, tileTypes.length - 1);
      seeds.add(
        TileSeed(
          row: tile.y,
          column: tile.x,
          layer: tile.layer,
          type: tileTypes[tileIndex],
          gridOffsetX: tile.gridOffsetX,
          gridOffsetY: tile.gridOffsetY,
          stackOffsetX: tile.stackOffsetX,
          stackOffsetY: tile.stackOffsetY,
        ),
      );
    }
    return LevelLayout(seeds: seeds);
  }
}
