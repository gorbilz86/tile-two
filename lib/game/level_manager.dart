import 'package:tile_two/game/level_generator.dart';

class TileSeed {
  final int row;
  final int column;
  final int layer;
  final String type;

  const TileSeed({
    required this.row,
    required this.column,
    required this.layer,
    required this.type,
  });
}

class LevelLayout {
  final List<TileSeed> seeds;

  const LevelLayout({required this.seeds});
}

class LevelManager {
  final List<String> tileTypes;

  const LevelManager({required this.tileTypes});

  LevelLayout build({
    required int level,
    required int columns,
    required int rows,
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
        ),
      );
    }
    return LevelLayout(seeds: seeds);
  }
}
