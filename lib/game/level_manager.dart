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
    final centerRow = (rows - 1) / 2;
    final centerColumn = (columns - 1) / 2;
    final rowsData = <({int row, List<int> columns})>[];
    for (var row = 0; row < rows; row++) {
      final normalized = (row - centerRow).abs() / centerRow;
      final width = (columns - (normalized * 3)).round().clamp(2, columns);
      final start = ((centerColumn - (width - 1) / 2)).floor().clamp(0, columns - width);
      final cols = <int>[];
      for (var col = start; col < start + width; col++) {
        cols.add(col);
      }
      cols.sort((a, b) {
        final da = (a - centerColumn).abs();
        final db = (b - centerColumn).abs();
        if (da == db) {
          return a.compareTo(b);
        }
        return da.compareTo(db);
      });
      rowsData.add((row: row, columns: cols));
    }
    rowsData.sort((a, b) {
      final da = (a.row - centerRow).abs();
      final db = (b.row - centerRow).abs();
      if (da == db) {
        return a.row.compareTo(b.row);
      }
      return da.compareTo(db);
    });
    final result = <(int, int)>[];
    for (final rowData in rowsData) {
      for (final col in rowData.columns) {
        result.add((rowData.row, col));
      }
    }
    return result;
  }

  _LevelConfig _configForLevel(int level) {
    final safeLevel = level.clamp(1, 50);
    if (safeLevel <= 10) {
      return const _LevelConfig(tiles: 15, maxLayers: 2);
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
