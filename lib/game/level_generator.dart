import 'dart:math';

import 'package:tile_two/game/tile_layout.dart';

class LevelPatternCoordinate {
  final double x;
  final double y;
  final int layer;

  const LevelPatternCoordinate({
    required this.x,
    required this.y,
    required this.layer,
  });
}

class LevelPattern {
  final String id;
  final List<LevelPatternCoordinate> coordinates;

  const LevelPattern({
    required this.id,
    required this.coordinates,
  });
}

class LevelGenerator {
  final int columns;
  final int rows;
  final int maxTileTypes;

  const LevelGenerator({
    required this.columns,
    required this.rows,
    required this.maxTileTypes,
  });

  GeneratedLevelLayout generateLevel(int levelNumber) {
    final safeLevel =
        levelNumber.clamp(TileLayoutRules.minLevel, TileLayoutRules.maxLevel);
    final seed = TileLayoutRules.seedForLevel(safeLevel);
    final random = Random(seed);
    final config = TileLayoutRules.configForLevel(safeLevel);
    final pattern = _pickPatternForLevel(
      levelNumber: safeLevel,
      pool: config.patternPool,
      random: random,
    );
    final tileCount = TileLayoutRules.pickTileCount(random, config);
    final positioned = generateLayout(
      levelNumber: safeLevel,
      tileCount: tileCount,
      pattern: pattern,
      random: random,
      config: config,
    );
    List<TileData> shuffled = const [];
    _SolvabilityReport? bestReport;
    final maxPeakSlot = _targetPeakSlotByLevel(safeLevel);
    for (var attempt = 0; attempt < 52; attempt++) {
      final attemptRandom = Random(seed + (attempt * 131));
      final candidate = shuffleTiles(
        positioned,
        tileTypeCount: config.tileTypes.clamp(1, maxTileTypes),
        random: attemptRandom,
        levelNumber: safeLevel + attempt,
      );
      final report = _solvabilityReport(candidate);
      final qualityPass = report.isSolvable && report.peakSlot <= maxPeakSlot;
      if (qualityPass) {
        shuffled = candidate;
        break;
      }
      if (bestReport == null || report.score > bestReport.score) {
        bestReport = report;
        shuffled = candidate;
      }
    }
    if (shuffled.isEmpty || !_solvabilityReport(shuffled).isSolvable) {
      shuffled = _buildFallbackSolvableLayout(
        layout: positioned,
        tileTypeCount: config.tileTypes.clamp(1, maxTileTypes),
        seed: seed,
      );
    }
    return GeneratedLevelLayout(
      levelNumber: safeLevel,
      seed: seed,
      config: config,
      tiles: shuffled,
      pattern: pattern,
    );
  }

  List<TileData> generateLayout({
    required int levelNumber,
    required int tileCount,
    required LayoutPattern pattern,
    required Random random,
    required LevelDifficultyConfig config,
  }) {
    final normalizedCount = TileLayoutRules.normalizedTileCount(tileCount);
    final templateTiles = _generateTemplatePatternLayout(
      levelNumber: levelNumber,
      count: normalizedCount,
      pattern: pattern,
      layers: config.layers,
      random: random,
    );
    if (templateTiles.isNotEmpty) {
      return templateTiles;
    }
    final perLayer = _layerDistribution(normalizedCount, config.layers, random);
    final levelBias =
        (levelNumber / TileLayoutRules.maxLevel).clamp(0, 1).toDouble();
    final layers = <List<(int, int)>>[];
    final layerPools = <List<(int, int)>>[];
    for (var layer = 0; layer < config.layers; layer++) {
      layerPools.add(
          _buildPatternCells(pattern: pattern, layer: layer, random: random));
    }
    for (var layer = 0; layer < config.layers; layer++) {
      final needed = perLayer[layer];
      final source = layerPools[layer];
      final previous = layer > 0 ? layers[layer - 1] : const <(int, int)>[];
      layers.add(
        _pickLayerCells(
          candidates: source,
          previousLayer: previous,
          count: needed,
          overlapStrength: config.overlapStrength,
          centerBias: config.centerBias + (levelBias * 0.12),
          random: random,
        ),
      );
    }
    final tiles = <TileData>[];
    for (var layer = 0; layer < layers.length; layer++) {
      final cells = layers[layer];
      for (final cell in cells) {
        tiles.add(
          TileData(
            type: 0,
            x: cell.$1,
            y: cell.$2,
            layer: layer,
            stackOffsetX: _stackJitter(
                levelNumber: levelNumber, layer: layer, random: random),
            stackOffsetY: _stackJitter(
                levelNumber: levelNumber + 7, layer: layer, random: random),
          ),
        );
      }
    }
    return tiles;
  }

  List<TileData> _generateTemplatePatternLayout({
    required int levelNumber,
    required int count,
    required LayoutPattern pattern,
    required int layers,
    required Random random,
  }) {
    if (pattern != LayoutPattern.diamond && pattern != LayoutPattern.pyramid) {
      return const [];
    }
    final template = pattern == LayoutPattern.diamond
        ? _buildDiamondPattern(layers)
        : _buildPyramidPattern(layers);
    if (template.coordinates.isEmpty) {
      return const [];
    }
    final sorted = [...template.coordinates]..sort((a, b) {
        if (a.layer != b.layer) {
          return a.layer.compareTo(b.layer);
        }
        final aDist = ((a.x - ((columns - 1) / 2)).abs()) +
            ((a.y - ((rows - 1) / 2)).abs());
        final bDist = ((b.x - ((columns - 1) / 2)).abs()) +
            ((b.y - ((rows - 1) / 2)).abs());
        if (aDist != bDist) {
          return aDist.compareTo(bDist);
        }
        final yComp = a.y.compareTo(b.y);
        if (yComp != 0) {
          return yComp;
        }
        return a.x.compareTo(b.x);
      });
    final capped = sorted.length < count ? sorted.length : count;
    final safeCount = (capped ~/ TileLayoutRules.groupSize) * TileLayoutRules.groupSize;
    if (safeCount < TileLayoutRules.groupSize) {
      return const [];
    }
    final picked = sorted.take(safeCount).toList();
    final tiles = <TileData>[];
    for (final coord in picked) {
      final cellX = coord.x.floor().clamp(0, columns - 1);
      final cellY = coord.y.floor().clamp(0, rows - 1);
      final gridOffsetX = coord.x - cellX;
      final gridOffsetY = coord.y - cellY;
      tiles.add(
        TileData(
          type: 0,
          x: cellX,
          y: cellY,
          layer: coord.layer,
          gridOffsetX: gridOffsetX,
          gridOffsetY: gridOffsetY,
          stackOffsetX: _templateFineJitter(
            levelNumber: levelNumber + coord.layer,
            random: random,
          ),
          stackOffsetY: _templateFineJitter(
            levelNumber: levelNumber + coord.layer + 11,
            random: random,
          ),
        ),
      );
    }
    return tiles;
  }

  LevelPattern _buildDiamondPattern(int layers) {
    final coordinates = <LevelPatternCoordinate>[];
    final centerX = (columns - 1) / 2;
    final centerY = (rows - 1) / 2;
    for (var layer = 0; layer < layers; layer++) {
      final offset = layer.isOdd ? 0.5 : 0.0;
      final radius = (rows <= columns ? rows : columns) / 2 - (layer * 0.58);
      final limit = radius.clamp(0.8, 3.3).toDouble();
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < columns; x++) {
          final px = x + offset;
          final py = y + offset;
          if (px > columns - 1 || py > rows - 1) {
            continue;
          }
          final manhattan = (px - centerX).abs() + (py - centerY).abs();
          if (manhattan <= limit) {
            coordinates.add(
              LevelPatternCoordinate(x: px, y: py, layer: layer),
            );
          }
        }
      }
    }
    return LevelPattern(id: 'diamond', coordinates: coordinates);
  }

  LevelPattern _buildPyramidPattern(int layers) {
    final coordinates = <LevelPatternCoordinate>[];
    final centerX = (columns - 1) / 2;
    for (var layer = 0; layer < layers; layer++) {
      final offset = layer.isOdd ? 0.5 : 0.0;
      final top = layer;
      final bottom = rows - 1 - layer;
      if (top > bottom) {
        continue;
      }
      for (var y = top; y <= bottom; y++) {
        final progress = ((y - top) / ((bottom - top) + 0.0001)).clamp(0, 1);
        final halfWidth = (1.1 + (1 - (progress - 0.5).abs() * 2) * 2.1) -
            (layer * 0.26);
        for (var x = 0; x < columns; x++) {
          final px = x + offset;
          final py = y + offset;
          if (px > columns - 1 || py > rows - 1) {
            continue;
          }
          if ((px - centerX).abs() <= halfWidth) {
            coordinates.add(
              LevelPatternCoordinate(x: px, y: py, layer: layer),
            );
          }
        }
      }
    }
    return LevelPattern(id: 'pyramid', coordinates: coordinates);
  }

  List<TileData> shuffleTiles(
    List<TileData> layout, {
    required int tileTypeCount,
    required Random random,
    required int levelNumber,
  }) {
    final count = layout.length;
    if (count == 0) {
      return const [];
    }
    final normalizedCount = TileLayoutRules.normalizedTileCount(count);
    final tileTypes = tileTypeCount.clamp(1, maxTileTypes);
    final typePool = <int>[];
    final tripleCount = normalizedCount ~/ TileLayoutRules.groupSize;
    final dominantLimiter = <int, int>{};
    for (var i = 0; i < tripleCount; i++) {
      final type = _pickNextType(
        tileTypes: tileTypes,
        pickIndex: i,
        random: random,
        usedCount: dominantLimiter,
      );
      typePool
        ..add(type)
        ..add(type)
        ..add(type);
      dominantLimiter.update(type, (value) => value + 3, ifAbsent: () => 3);
    }
    typePool.shuffle(random);
    final rotation = levelNumber % typePool.length;
    if (rotation > 0) {
      final head = typePool.sublist(0, rotation);
      typePool
        ..removeRange(0, rotation)
        ..addAll(head);
    }
    final sortedLayout = [...layout]..sort((a, b) {
        final layerCompare = a.layer.compareTo(b.layer);
        if (layerCompare != 0) {
          return layerCompare;
        }
        final yCompare = a.y.compareTo(b.y);
        if (yCompare != 0) {
          return yCompare;
        }
        return a.x.compareTo(b.x);
      });
    return _assignDiversifiedTypes(sortedLayout, typePool, random);
  }

  List<int> _layerDistribution(int total, int layers, Random random) {
    if (layers <= 1) {
      return [total];
    }
    final distribution = List<int>.filled(layers, TileLayoutRules.groupSize);
    var remaining = total - (layers * TileLayoutRules.groupSize);
    final weightedOrder = List<int>.generate(layers, (i) => i)
      ..sort((a, b) => (layers - a).compareTo(layers - b));
    while (remaining > 0) {
      for (final layer in weightedOrder) {
        if (remaining <= 0) {
          break;
        }
        distribution[layer] += TileLayoutRules.groupSize;
        remaining -= TileLayoutRules.groupSize;
      }
    }
    distribution.shuffle(random);
    return distribution;
  }

  List<(int, int)> _buildPatternCells({
    required LayoutPattern pattern,
    required int layer,
    required Random random,
  }) {
    final all = <(int, int)>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        all.add((x, y));
      }
    }
    final centerX = (columns - 1) / 2;
    final centerY = (rows - 1) / 2;
    final set = <(int, int)>{};
    for (final cell in all) {
      final dx = cell.$1 - centerX;
      final dy = cell.$2 - centerY;
      final radial = sqrt((dx * dx) + (dy * dy));
      if (pattern == LayoutPattern.irregular) {
        final threshold = 2.7 - (layer * 0.36);
        if (radial <= threshold || random.nextDouble() > 0.52) {
          set.add(cell);
        }
      } else if (pattern == LayoutPattern.pyramid) {
        final threshold = 2.8 - (layer * 0.55);
        if (radial <= threshold) {
          set.add(cell);
        }
      } else if (pattern == LayoutPattern.ring) {
        final outer = 2.8 - (layer * 0.22);
        final inner = 1.15 - (layer * 0.2);
        if (radial <= outer && radial >= inner) {
          set.add(cell);
        }
        if (layer == 0 && radial <= 1.1 && random.nextDouble() > 0.65) {
          set.add(cell);
        }
      } else if (pattern == LayoutPattern.spiral) {
        final angle = atan2(dy, dx);
        final norm = (angle + pi) / (2 * pi);
        final arm = ((norm * 5) + (radial * 0.7) + (layer * 0.33)) % 1;
        if (arm < 0.36 || radial < 1.1) {
          set.add(cell);
        }
      } else if (pattern == LayoutPattern.cross) {
        final centerColumn = (columns / 2).floor();
        final centerRow = (rows / 2).floor();
        final distToCenterLineX = (cell.$1 - centerColumn).abs();
        final distToCenterLineY = (cell.$2 - centerRow).abs();
        if (distToCenterLineX <= (1 + (layer == 0 ? 0 : -1)) ||
            distToCenterLineY <= (1 + (layer == 0 ? 0 : -1))) {
          set.add(cell);
        }
      } else if (pattern == LayoutPattern.randomCluster) {
        final clusters = 3 + random.nextInt(2);
        var inCluster = false;
        for (var i = 0; i < clusters; i++) {
          final cx = random.nextInt(columns);
          final cy = random.nextInt(rows);
          final dist = sqrt(pow(cell.$1 - cx, 2) + pow(cell.$2 - cy, 2));
          final radius = (1.5 - (layer * 0.2)).clamp(0.8, 2.0);
          if (dist <= radius) {
            inCluster = true;
            break;
          }
        }
        if (inCluster) {
          set.add(cell);
        }
      } else if (pattern == LayoutPattern.diamond) {
        final manhattan = dx.abs() + dy.abs();
        final limit = 3.6 - (layer * 0.52);
        if (manhattan <= limit + (random.nextDouble() * 0.35)) {
          set.add(cell);
        }
      } else if (pattern == LayoutPattern.zigzag) {
        final slope = ((cell.$2 + layer) % 2) == 0;
        final inMid = radial <= (2.7 - (layer * 0.2));
        if ((slope && inMid) || radial <= 1.2) {
          set.add(cell);
        }
      } else if (pattern == LayoutPattern.wave) {
        final wave = sin((cell.$1 * 1.1) + (layer * 0.7)) * 1.2;
        final bandDistance = (cell.$2 - centerY - wave).abs();
        if (bandDistance <= 1.35 + (random.nextDouble() * 0.5)) {
          set.add(cell);
        }
      } else {
        final ridge = ((cell.$1 - centerX).abs() * 0.55) +
            ((cell.$2 - centerY).abs() * 1.15);
        final gate = 2.9 - (layer * 0.35);
        if (ridge <= gate ||
            (cell.$1 == layer || cell.$1 == columns - layer - 1)) {
          set.add(cell);
        }
      }
    }
    final result = set.toList();
    result.shuffle(random);
    if (result.isEmpty) {
      return all;
    }
    return result;
  }

  List<(int, int)> _pickLayerCells({
    required List<(int, int)> candidates,
    required List<(int, int)> previousLayer,
    required int count,
    required double overlapStrength,
    required double centerBias,
    required Random random,
  }) {
    if (count <= 0) {
      return const [];
    }
    final picked = <(int, int)>[];
    final available = [...candidates];
    final centerX = (columns - 1) / 2;
    final centerY = (rows - 1) / 2;
    final previousSet = previousLayer.toSet();
    while (picked.length < count && available.isNotEmpty) {
      available.sort((a, b) {
        final aDistance = ((a.$1 - centerX).abs() + (a.$2 - centerY).abs());
        final bDistance = ((b.$1 - centerX).abs() + (b.$2 - centerY).abs());
        final aOverlap = previousSet.contains(a) ? 1 : 0;
        final bOverlap = previousSet.contains(b) ? 1 : 0;
        final aScore = (aOverlap * overlapStrength * 6) -
            (aDistance * centerBias) +
            random.nextDouble();
        final bScore = (bOverlap * overlapStrength * 6) -
            (bDistance * centerBias) +
            random.nextDouble();
        return bScore.compareTo(aScore);
      });
      final next = available.removeAt(0);
      picked.add(next);
    }
    if (picked.length < count) {
      final fallback = <(int, int)>[];
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < columns; x++) {
          fallback.add((x, y));
        }
      }
      fallback.shuffle(random);
      for (final cell in fallback) {
        if (picked.length >= count) {
          break;
        }
        picked.add(cell);
      }
    }
    return picked.take(count).toList();
  }

  _SolvabilityReport _solvabilityReport(List<TileData> tiles) {
    const strategies = [
      _SolveStrategy.finishTriplesFirst,
      _SolveStrategy.lowRiskSlot,
      _SolveStrategy.maxUnlock,
      _SolveStrategy.playableDensity,
    ];
    _SolvabilityReport? bestSolved;
    _SolvabilityReport? bestUnsolved;
    for (final strategy in strategies) {
      final report = _simulateSolvability(
        tiles: tiles,
        strategy: strategy,
      );
      if (report.isSolvable) {
        if (bestSolved == null || report.score > bestSolved.score) {
          bestSolved = report;
        }
      } else if (bestUnsolved == null || report.score > bestUnsolved.score) {
        bestUnsolved = report;
      }
    }
    return bestSolved ?? bestUnsolved ?? const _SolvabilityReport.unsolved();
  }

  _SolvabilityReport _simulateSolvability({
    required List<TileData> tiles,
    required _SolveStrategy strategy,
  }) {
    final pool = tiles
        .asMap()
        .entries
        .map(
          (entry) => _SimTile(
            id: entry.key,
            type: entry.value.type,
            x: entry.value.x,
            y: entry.value.y,
            layer: entry.value.layer,
            gridOffsetX: entry.value.gridOffsetX,
            gridOffsetY: entry.value.gridOffsetY,
          ),
        )
        .toList();
    final slot = <int>[];
    var peakSlot = 0;
    while (pool.isNotEmpty) {
      final playable = _playableTiles(pool);
      if (playable.isEmpty) {
        return _SolvabilityReport(
          isSolvable: false,
          peakSlot: peakSlot,
          clearedTiles: tiles.length - pool.length,
        );
      }
      final next = _chooseBestPlayable(
        playable,
        slot,
        strategy: strategy,
      );
      pool.remove(next);
      slot.add(next.type);
      if (slot.length > peakSlot) {
        peakSlot = slot.length;
      }
      if (slot.length > 7) {
        return _SolvabilityReport(
          isSolvable: false,
          peakSlot: peakSlot,
          clearedTiles: tiles.length - pool.length,
        );
      }
      final typeCount = <int, int>{};
      for (final type in slot) {
        typeCount.update(type, (value) => value + 1, ifAbsent: () => 1);
      }
      final matchedType = typeCount.entries
          .firstWhere(
            (entry) => entry.value >= 3,
            orElse: () => const MapEntry(-1, 0),
          )
          .key;
      if (matchedType >= 0) {
        var removed = 0;
        slot.removeWhere((value) {
          if (value == matchedType && removed < 3) {
            removed++;
            return true;
          }
          return false;
        });
      }
    }
    return _SolvabilityReport(
      isSolvable: true,
      peakSlot: peakSlot,
      clearedTiles: tiles.length,
    );
  }

  List<_SimTile> _playableTiles(List<_SimTile> tiles) {
    final playable = <_SimTile>[];
    for (final tile in tiles) {
      if (_isCoveredByHigher(tile, tiles)) {
        continue;
      }
      playable.add(tile);
    }
    return playable;
  }

  _SimTile _chooseBestPlayable(
    List<_SimTile> playable,
    List<int> slot, {
    required _SolveStrategy strategy,
  }) {
    final slotCounts = <int, int>{};
    for (final type in slot) {
      slotCounts.update(type, (value) => value + 1, ifAbsent: () => 1);
    }
    final playableCounts = <int, int>{};
    for (final tile in playable) {
      playableCounts.update(tile.type, (value) => value + 1, ifAbsent: () => 1);
    }
    playable.sort((a, b) {
      final aScore = _pickScore(
        tile: a,
        slotCounts: slotCounts,
        playableCounts: playableCounts,
        slotLength: slot.length,
        strategy: strategy,
      );
      final bScore = _pickScore(
        tile: b,
        slotCounts: slotCounts,
        playableCounts: playableCounts,
        slotLength: slot.length,
        strategy: strategy,
      );
      if (aScore != bScore) {
        return bScore.compareTo(aScore);
      }
      if (a.layer != b.layer) {
        return b.layer.compareTo(a.layer);
      }
      final aDistance = (a.x - (columns / 2)).abs() + (a.y - (rows / 2)).abs();
      final bDistance = (b.x - (columns / 2)).abs() + (b.y - (rows / 2)).abs();
      if (aDistance != bDistance) {
        return aDistance.compareTo(bDistance);
      }
      return a.id.compareTo(b.id);
    });
    return playable.first;
  }

  double _pickScore({
    required _SimTile tile,
    required Map<int, int> slotCounts,
    required Map<int, int> playableCounts,
    required int slotLength,
    required _SolveStrategy strategy,
  }) {
    final slotHit = (slotCounts[tile.type] ?? 0).toDouble();
    final playableHit = (playableCounts[tile.type] ?? 0).toDouble();
    final layerScore = tile.layer.toDouble();
    final centerDistance =
        (tile.x - (columns / 2)).abs() + (tile.y - (rows / 2)).abs();
    final centerScore = 6 - centerDistance;
    if (strategy == _SolveStrategy.finishTriplesFirst) {
      return (slotHit * 7.4) + (playableHit * 1.8) + (layerScore * 0.9);
    }
    if (strategy == _SolveStrategy.lowRiskSlot) {
      final risk = slotLength >= 5 && slotHit == 0 ? 4.2 : 0;
      return (slotHit * 5.2) + (playableHit * 1.2) + centerScore - risk;
    }
    if (strategy == _SolveStrategy.maxUnlock) {
      return (layerScore * 2.9) + (slotHit * 3.4) + (playableHit * 1.1);
    }
    return (playableHit * 3.8) + (slotHit * 2.7) + (centerScore * 0.6);
  }

  bool _isCoveredByHigher(_SimTile tile, List<_SimTile> tiles) {
    final rect = _tileRect(tile);
    for (final other in tiles) {
      if (identical(tile, other) || other.layer <= tile.layer) {
        continue;
      }
      if (rect.overlaps(_tileRect(other))) {
        return true;
      }
    }
    return false;
  }

  _SimRect _tileRect(_SimTile tile) {
    const tileSize = 1.0;
    const spacing = 0.06;
    const offsetScale = 1 / 64;
    final left = ((tile.x + tile.gridOffsetX) * (tileSize + spacing)) +
        (tile.layer * TileLayoutRules.layerOffsetX * offsetScale);
    final top = ((tile.y + tile.gridOffsetY) * (tileSize + spacing)) +
        (tile.layer * TileLayoutRules.layerOffsetY * offsetScale);
    return _SimRect(
      left: left,
      top: top,
      right: left + tileSize,
      bottom: top + tileSize,
    );
  }

  LayoutPattern _pickPatternForLevel({
    required int levelNumber,
    required List<LayoutPattern> pool,
    required Random random,
  }) {
    if (pool.isEmpty) {
      return LayoutPattern.irregular;
    }
    final baseIndex = (levelNumber + (levelNumber ~/ 7)) % pool.length;
    if (random.nextDouble() < 0.25) {
      return pool[random.nextInt(pool.length)];
    }
    return pool[baseIndex];
  }

  double _stackJitter({
    required int levelNumber,
    required int layer,
    required Random random,
  }) {
    if (layer == 0) {
      return 0;
    }
    final intensity = (0.6 + ((levelNumber / TileLayoutRules.maxLevel) * 1.6))
        .clamp(0.6, 2.2)
        .toDouble();
    final swing = (random.nextDouble() * 2 - 1) * intensity;
    return swing;
  }

  double _templateFineJitter({
    required int levelNumber,
    required Random random,
  }) {
    final intensity =
        (0.18 + ((levelNumber / TileLayoutRules.maxLevel) * 0.22))
            .clamp(0.18, 0.4)
            .toDouble();
    return (random.nextDouble() * 2 - 1) * intensity;
  }

  int _pickNextType({
    required int tileTypes,
    required int pickIndex,
    required Random random,
    required Map<int, int> usedCount,
  }) {
    final base = (pickIndex + random.nextInt(tileTypes)) % tileTypes;
    final limitPerType = ((pickIndex + 1) * 3 / tileTypes).ceil() + 3;
    for (var offset = 0; offset < tileTypes; offset++) {
      final candidate = (base + offset) % tileTypes;
      final used = usedCount[candidate] ?? 0;
      if (used < limitPerType) {
        return candidate;
      }
    }
    return base;
  }

  int _targetPeakSlotByLevel(int levelNumber) {
    if (levelNumber <= 15) {
      return 4;
    }
    if (levelNumber <= 40) {
      return 5;
    }
    if (levelNumber <= 75) {
      return 6;
    }
    return 7;
  }

  List<TileData> _buildFallbackSolvableLayout({
    required List<TileData> layout,
    required int tileTypeCount,
    required int seed,
  }) {
    if (layout.isEmpty) {
      return const [];
    }
    final remaining = layout
        .asMap()
        .entries
        .map(
          (entry) => _SimTile(
            id: entry.key,
            type: 0,
            x: entry.value.x,
            y: entry.value.y,
            layer: entry.value.layer,
            gridOffsetX: entry.value.gridOffsetX,
            gridOffsetY: entry.value.gridOffsetY,
          ),
        )
        .toList();
    final removalOrder = <int>[];
    while (remaining.isNotEmpty) {
      final playable = _playableTiles(remaining);
      if (playable.isEmpty) {
        break;
      }
      playable.sort((a, b) {
        if (a.layer != b.layer) {
          return b.layer.compareTo(a.layer);
        }
        final aDistance = (a.x - (columns / 2)).abs() + (a.y - (rows / 2)).abs();
        final bDistance = (b.x - (columns / 2)).abs() + (b.y - (rows / 2)).abs();
        if (aDistance != bDistance) {
          return aDistance.compareTo(bDistance);
        }
        return a.id.compareTo(b.id);
      });
      final next = playable.first;
      removalOrder.add(next.id);
      remaining.remove(next);
    }
    if (removalOrder.length != layout.length) {
      return shuffleTiles(
        layout,
        tileTypeCount: tileTypeCount,
        random: Random(seed + 971),
        levelNumber: seed,
      );
    }
    final types = tileTypeCount.clamp(1, maxTileTypes);
    for (var offset = 0; offset < types; offset++) {
      final assigned = _assignTypesFromRemovalOrder(
        layout: layout,
        removalOrder: removalOrder,
        tileTypeCount: types,
        seedOffset: offset + seed,
      );
      if (_solvabilityReport(assigned).isSolvable) {
        return assigned;
      }
    }
    return _assignTypesFromRemovalOrder(
      layout: layout,
      removalOrder: removalOrder,
      tileTypeCount: types,
      seedOffset: seed,
    );
  }

  List<TileData> _assignTypesFromRemovalOrder({
    required List<TileData> layout,
    required List<int> removalOrder,
    required int tileTypeCount,
    required int seedOffset,
  }) {
    final assigned = [...layout];
    const groupSize = TileLayoutRules.groupSize;
    for (var i = 0; i < removalOrder.length; i++) {
      final id = removalOrder[i];
      final type = ((i ~/ groupSize) + seedOffset) % tileTypeCount;
      assigned[id] = assigned[id].copyWith(type: type);
    }
    return assigned;
  }

  List<TileData> _assignDiversifiedTypes(
    List<TileData> sortedLayout,
    List<int> typePool,
    Random random,
  ) {
    final available = <int, int>{};
    for (final type in typePool) {
      available.update(type, (value) => value + 1, ifAbsent: () => 1);
    }
    final result = <TileData>[];
    for (final tile in sortedLayout) {
      final neighborTypes = <int>{};
      for (final placed in result) {
        if (placed.layer != tile.layer) {
          continue;
        }
        final dx = (placed.x - tile.x).abs();
        final dy = (placed.y - tile.y).abs();
        if (dx + dy <= 1) {
          neighborTypes.add(placed.type);
        }
      }
      final ranked =
          available.entries.where((entry) => entry.value > 0).toList()
            ..sort((a, b) {
              final aPenalty = neighborTypes.contains(a.key) ? 1 : 0;
              final bPenalty = neighborTypes.contains(b.key) ? 1 : 0;
              if (aPenalty != bPenalty) {
                return aPenalty.compareTo(bPenalty);
              }
              if (a.value != b.value) {
                return b.value.compareTo(a.value);
              }
              return random.nextBool() ? -1 : 1;
            });
      final pick = ranked.first.key;
      available.update(pick, (value) => value - 1);
      result.add(tile.copyWith(type: pick));
    }
    return result;
  }
}

class _SimTile {
  final int id;
  final int type;
  final int x;
  final int y;
  final int layer;
  final double gridOffsetX;
  final double gridOffsetY;

  const _SimTile({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.layer,
    this.gridOffsetX = 0,
    this.gridOffsetY = 0,
  });
}

enum _SolveStrategy {
  finishTriplesFirst,
  lowRiskSlot,
  maxUnlock,
  playableDensity,
}

class _SolvabilityReport {
  final bool isSolvable;
  final int peakSlot;
  final int clearedTiles;

  const _SolvabilityReport({
    required this.isSolvable,
    required this.peakSlot,
    required this.clearedTiles,
  });

  const _SolvabilityReport.unsolved()
      : isSolvable = false,
        peakSlot = 7,
        clearedTiles = 0;

  double get score {
    final solvedBonus = isSolvable ? 10000 : 0;
    return solvedBonus + (clearedTiles * 12) - (peakSlot * 70);
  }
}

class _SimRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _SimRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  bool overlaps(_SimRect other) {
    return left < other.right &&
        right > other.left &&
        top < other.bottom &&
        bottom > other.top;
  }
}
