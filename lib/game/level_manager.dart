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
    final totalTiles = _normalizeTileCount(config.tiles);
    final bottomFootprint = _referenceFootprint(
      columns: columns,
      rows: rows,
      legWidth: 2,
      rowStart: 0,
      rowEnd: rows - 1,
      bridgeRows: const [1, 3],
      bridgeWidth: 4,
    );
    final middleFootprint = _referenceFootprint(
      columns: columns,
      rows: rows,
      legWidth: 2,
      rowStart: 1,
      rowEnd: rows - 2,
      bridgeRows: const [2, 3],
      bridgeWidth: 4,
    );
    final topFootprint = _referenceFootprint(
      columns: columns,
      rows: rows,
      legWidth: 1,
      rowStart: 1,
      rowEnd: rows - 2,
      bridgeRows: const [2],
      bridgeWidth: 2,
    );
    final layers = _layerCells(
      totalTiles: totalTiles,
      maxLayers: config.maxLayers,
      bottomFootprint: bottomFootprint,
      middleFootprint: middleFootprint,
      topFootprint: topFootprint,
      columns: columns,
      rows: rows,
    );

    final tripleCount = totalTiles ~/ 3;
    final remaining = <String, int>{for (final type in tileTypes) type: 0};
    for (var i = 0; i < tripleCount; i++) {
      final pick = tileTypes[_random.nextInt(tileTypes.length)];
      remaining[pick] = (remaining[pick] ?? 0) + 3;
    }

    final seeds = <TileSeed>[];
    for (var layer = 0; layer < layers.length; layer++) {
      final cells = layers[layer];
      final assigned = <String, String>{};
      for (var i = 0; i < cells.length; i++) {
        final cell = cells[i];
        final type = _pickTypeForCell(
          row: cell.$1,
          column: cell.$2,
          remaining: remaining,
          assignedInLayer: assigned,
        );
        assigned['${cell.$1}:${cell.$2}'] = type;
        remaining[type] = (remaining[type] ?? 0) - 1;
        seeds.add(
          TileSeed(
            row: cell.$1,
            column: cell.$2,
            layer: layer,
            type: type,
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
      return [_orderedForPattern(bottomFootprint, columns: columns, rows: rows).take(totalTiles).toList()];
    }
    if (maxLayers == 2) {
      var top = (totalTiles * 0.38).round();
      top = _safeClamp(top, min: 6, max: middleFootprint.length);
      var bottom = totalTiles - top;
      if (bottom > bottomFootprint.length) {
        final overflow = bottom - bottomFootprint.length;
        top = _safeClamp(top + overflow, min: 0, max: middleFootprint.length);
        bottom = totalTiles - top;
      }
      return [
        _orderedForPattern(bottomFootprint, columns: columns, rows: rows).take(bottom).toList(),
        _orderedForPattern(middleFootprint, columns: columns, rows: rows).take(top).toList(),
      ];
    }
    var top = _safeClamp((totalTiles * 0.22).round(), min: 6, max: topFootprint.length);
    var middle = _safeClamp((totalTiles * 0.33).round(), min: 9, max: middleFootprint.length);
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
      _orderedForPattern(bottomFootprint, columns: columns, rows: rows).take(bottom).toList(),
      _orderedForPattern(middleFootprint, columns: columns, rows: rows).take(middle).toList(),
      _orderedForPattern(topFootprint, columns: columns, rows: rows).take(top).toList(),
    ];
  }

  int _safeClamp(int value, {required int min, required int max}) {
    if (max < min) {
      return max < 0 ? 0 : max;
    }
    return value.clamp(min, max).toInt();
  }

  List<(int, int)> _referenceFootprint({
    required int columns,
    required int rows,
    required int legWidth,
    required int rowStart,
    required int rowEnd,
    required List<int> bridgeRows,
    required int bridgeWidth,
  }) {
    final result = <(int, int)>[];
    final leftLegEnd = legWidth - 1;
    final rightLegStart = columns - legWidth;
    final bridgeStart = ((columns - bridgeWidth) / 2).round();
    final bridgeEnd = bridgeStart + bridgeWidth - 1;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final inRowRange = row >= rowStart && row <= rowEnd;
        final inLeftPillar = inRowRange && col <= leftLegEnd;
        final inRightPillar = inRowRange && col >= rightLegStart;
        final inBridgeRow = bridgeRows.contains(row) && col >= bridgeStart && col <= bridgeEnd;
        if (inLeftPillar || inRightPillar || inBridgeRow) {
          result.add((row, col));
        }
      }
    }
    return result;
  }

  String _pickTypeForCell({
    required int row,
    required int column,
    required Map<String, int> remaining,
    required Map<String, String> assignedInLayer,
  }) {
    final left = assignedInLayer['$row:${column - 1}'];
    final up = assignedInLayer['${row - 1}:$column'];
    final block = {if (left != null) left, if (up != null) up};
    final candidates = remaining.entries
        .where((e) => e.value > 0 && !block.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (candidates.isNotEmpty) {
      final topWeight = candidates.first.value;
      final tied = candidates.where((e) => e.value == topWeight).toList();
      return tied[_random.nextInt(tied.length)].key;
    }
    final fallback = remaining.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (fallback.isEmpty) {
      return tileTypes[_random.nextInt(tileTypes.length)];
    }
    final threshold = fallback.first.value;
    final tied = fallback.where((e) => e.value == threshold).toList();
    return tied[_random.nextInt(tied.length)].key;
  }

  List<(int, int)> _orderedForPattern(
    List<(int, int)> source, {
    required int columns,
    required int rows,
  }) {
    final cellSet = source.toSet();
    final ordered = <(int, int)>[];
    final minCol = source.map((e) => e.$2).reduce((a, b) => a < b ? a : b);
    final maxCol = source.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final leftInner = minCol + 1;
    final rightInner = maxCol - 1;
    final centerRow = rows ~/ 2;
    final rowOrder = <int>[];
    for (var offset = 0; offset < rows; offset++) {
      final up = centerRow - offset;
      final down = centerRow + offset;
      if (up >= 0 && !rowOrder.contains(up)) {
        rowOrder.add(up);
      }
      if (down < rows && !rowOrder.contains(down)) {
        rowOrder.add(down);
      }
    }

    void pushCell((int, int) cell) {
      if (!cellSet.contains(cell) || ordered.contains(cell)) {
        return;
      }
      ordered.add(cell);
    }

    for (final r in rowOrder) {
      pushCell((r, minCol));
      pushCell((r, maxCol));
    }
    for (final r in rowOrder) {
      pushCell((r, leftInner));
      pushCell((r, rightInner));
    }
    for (final bridgeRow in [centerRow, centerRow - 1, centerRow + 1]) {
      if (bridgeRow < 0 || bridgeRow >= rows) {
        continue;
      }
      for (var c = leftInner; c <= rightInner; c++) {
        pushCell((bridgeRow, c));
      }
    }

    for (final row in rowOrder) {
      final rowCells = source.where((e) => e.$1 == row).toList()
        ..sort((a, b) {
          final da = (a.$2 - (columns / 2)).abs();
          final db = (b.$2 - (columns / 2)).abs();
          return da.compareTo(db);
        });
      for (final cell in rowCells) {
        pushCell(cell);
      }
    }
    return ordered;
  }

  int _normalizeTileCount(int tiles) {
    final remainder = tiles % 3;
    if (remainder == 0) {
      return tiles;
    }
    return tiles + (3 - remainder);
  }

  _LevelConfig _configForLevel(int level) {
    final safeLevel = level.clamp(1, 50);
    if (safeLevel <= 15) {
      return const _LevelConfig(tiles: 42, maxLayers: 3);
    }
    if (safeLevel <= 35) {
      return const _LevelConfig(tiles: 42, maxLayers: 3);
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
