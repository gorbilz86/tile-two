import 'dart:math';

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
  final Random _random = Random();

  LevelManager({required this.tileTypes});

  LevelLayout build({
    required int level,
    required int columns,
    required int rows,
  }) {
    final config = _configForLevel(level);
    final cellCount = columns * rows;
    final depths = List<int>.filled(cellCount, 0);
    var assigned = 0;
    while (assigned < config.tiles) {
      final target = _random.nextInt(cellCount);
      if (depths[target] >= config.maxLayers) {
        continue;
      }
      depths[target] += 1;
      assigned += 1;
    }

    final tripleCount = config.tiles ~/ 3;
    final pool = <String>[];
    for (var i = 0; i < tripleCount; i++) {
      final type = tileTypes[_random.nextInt(tileTypes.length)];
      pool.add(type);
      pool.add(type);
      pool.add(type);
    }
    pool.shuffle(_random);

    final seeds = <TileSeed>[];
    var index = 0;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final depth = depths[row * columns + column];
        for (var layer = 0; layer < depth; layer++) {
          seeds.add(
            TileSeed(
              row: row,
              column: column,
              layer: layer,
              type: pool[index++],
            ),
          );
        }
      }
    }
    return LevelLayout(seeds: seeds);
  }

  _LevelConfig _configForLevel(int level) {
    final safeLevel = level.clamp(1, 50);
    if (safeLevel <= 10) {
      return const _LevelConfig(tiles: 12, maxLayers: 1);
    }
    if (safeLevel <= 20) {
      return const _LevelConfig(tiles: 18, maxLayers: 2);
    }
    if (safeLevel <= 35) {
      return const _LevelConfig(tiles: 24, maxLayers: 2);
    }
    return const _LevelConfig(tiles: 30, maxLayers: 3);
  }
}

class _LevelConfig {
  final int tiles;
  final int maxLayers;

  const _LevelConfig({
    required this.tiles,
    required this.maxLayers,
  });
}
