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
    final bottomFootprint = _stackPattern(columns: columns, rows: rows);
    final middleFootprint = _footprintByRowWidths(
      columns: columns,
      rows: rows,
      widths: const [2, 4, 4, 4, 4, 2],
    );
    final topFootprint = _footprintByRowWidths(
      columns: columns,
      rows: rows,
      widths: const [0, 2, 4, 4, 2, 0],
    );
    final layers = _layerCells(
      totalTiles: config.tiles,
      maxLayers: config.maxLayers,
      bottomFootprint: bottomFootprint,
      middleFootprint: middleFootprint,
      topFootprint: topFootprint,
      columns: columns,
      rows: rows,
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
    for (var layer = 0; layer < layers.length; layer++) {
      final cells = layers[layer];
      for (var i = 0; i < cells.length; i++) {
        final cell = cells[i];
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

  List<List<(int, int)>> _layerCells({
    required int totalTiles,
    required int maxLayers,
    required List<(int, int)> bottomFootprint,
    required List<(int, int)> middleFootprint,
    required List<(int, int)> topFootprint,
    required int columns,
    required int rows,
  }) {
    if (maxLayers == 1) {
      return [_centerOrdered(bottomFootprint, columns: columns, rows: rows).take(totalTiles).toList()];
    }
    if (maxLayers == 2) {
      var top = (totalTiles * 0.38).round();
      top = top.clamp(6, middleFootprint.length);
      var bottom = totalTiles - top;
      if (bottom > bottomFootprint.length) {
        final overflow = bottom - bottomFootprint.length;
        top = (top + overflow).clamp(0, middleFootprint.length);
        bottom = totalTiles - top;
      }
      return [
        _centerOrdered(bottomFootprint, columns: columns, rows: rows).take(bottom).toList(),
        _centerOrdered(middleFootprint, columns: columns, rows: rows).take(top).toList(),
      ];
    }
    var top = (totalTiles * 0.22).round().clamp(6, topFootprint.length);
    var middle = (totalTiles * 0.33).round().clamp(9, middleFootprint.length);
    var bottom = totalTiles - top - middle;
    if (bottom > bottomFootprint.length) {
      var overflow = bottom - bottomFootprint.length;
      final middleHeadroom = middleFootprint.length - middle;
      final addMiddle = overflow.clamp(0, middleHeadroom);
      middle += addMiddle;
      overflow -= addMiddle;
      if (overflow > 0) {
        final topHeadroom = topFootprint.length - top;
        final addTop = overflow.clamp(0, topHeadroom);
        top += addTop;
      }
      bottom = totalTiles - top - middle;
    }
    return [
      _centerOrdered(bottomFootprint, columns: columns, rows: rows).take(bottom).toList(),
      _centerOrdered(middleFootprint, columns: columns, rows: rows).take(middle).toList(),
      _centerOrdered(topFootprint, columns: columns, rows: rows).take(top).toList(),
    ];
  }

  List<(int, int)> _stackPattern({
    required int columns,
    required int rows,
  }) {
    return _footprintByRowWidths(
      columns: columns,
      rows: rows,
      widths: const [2, 4, 6, 6, 4, 2],
    );
  }

  List<(int, int)> _footprintByRowWidths({
    required int columns,
    required int rows,
    required List<int> widths,
  }) {
    final result = <(int, int)>[];
    for (var row = 0; row < rows; row++) {
      final rowWidth = widths[row.clamp(0, widths.length - 1)];
      final start = ((columns - rowWidth) / 2).round();
      for (var col = start; col < start + rowWidth; col++) {
        result.add((row, col));
      }
    }
    return result;
  }

  List<(int, int)> _centerOrdered(
    List<(int, int)> source, {
    required int columns,
    required int rows,
  }) {
    final centerRow = (rows - 1) / 2;
    final centerColumn = (columns - 1) / 2;
    final ordered = List<(int, int)>.from(source);
    ordered.sort((a, b) {
      final da = (a.$1 - centerRow).abs() + (a.$2 - centerColumn).abs();
      final db = (b.$1 - centerRow).abs() + (b.$2 - centerColumn).abs();
      if (da == db) {
        return a.$1.compareTo(b.$1);
      }
      return da.compareTo(db);
    });
    return ordered;
  }

  _LevelConfig _configForLevel(int level) {
    final safeLevel = level.clamp(1, 50);
    if (safeLevel <= 10) {
      return const _LevelConfig(tiles: 27, maxLayers: 3);
    }
    if (safeLevel <= 20) {
      return const _LevelConfig(tiles: 33, maxLayers: 3);
    }
    if (safeLevel <= 35) {
      return const _LevelConfig(tiles: 39, maxLayers: 3);
    }
    return const _LevelConfig(tiles: 45, maxLayers: 3);
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
