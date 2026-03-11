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
    final pattern = _stackPattern(columns: columns, rows: rows);
    final layerCounts = _tilesPerLayer(
      totalTiles: config.tiles,
      maxLayers: config.maxLayers,
    );

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
    for (var layer = 0; layer < layerCounts.length; layer++) {
      final layerTiles = layerCounts[layer];
      for (var i = 0; i < layerTiles; i++) {
        final cell = pattern[i];
        seeds.add(
          TileSeed(
            row: cell.$1,
            column: cell.$2,
            layer: layer,
            type: pool[index++],
          ),
        );
      }
    }
    return LevelLayout(seeds: seeds);
  }

  List<int> _tilesPerLayer({
    required int totalTiles,
    required int maxLayers,
  }) {
    if (maxLayers == 1) {
      return [totalTiles];
    }
    if (maxLayers == 2) {
      final top = (totalTiles / 3).round();
      return [totalTiles - top, top];
    }
    final top = (totalTiles * 0.2).round();
    final middle = (totalTiles * 0.3).round();
    final bottom = totalTiles - top - middle;
    return [bottom, middle, top];
  }

  List<(int, int)> _stackPattern({
    required int columns,
    required int rows,
  }) {
    final result = <(int, int)>[];
    final center = (columns - 1) / 2;
    for (var row = 0; row < rows; row++) {
      final normalized = (row - (rows - 1) / 2).abs() / ((rows - 1) / 2);
      final width = (columns - (normalized * 3)).round().clamp(2, columns);
      final start = ((center - (width - 1) / 2)).floor().clamp(0, columns - width);
      for (var col = start; col < start + width; col++) {
        result.add((row, col));
      }
    }
    return result;
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
