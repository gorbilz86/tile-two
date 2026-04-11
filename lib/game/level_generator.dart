import 'dart:math';

import 'package:tile_two/game/tile_layout.dart';
import 'package:tile_two/game/architect_generator.dart';

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
    final safeLevel = levelNumber.clamp(TileLayoutRules.minLevel, TileLayoutRules.maxLevel);
    final seed = TileLayoutRules.seedForLevel(safeLevel);
    final random = Random(seed);
    final config = TileLayoutRules.configForLevel(safeLevel);
    
    // Pattern logic is mostly legacy here but we pass it anyway
    final pattern = _pickPatternForLevel(
      levelNumber: safeLevel,
      pool: config.patternPool,
      random: random,
    );
    
    final maxTiles = TileLayoutRules.pickTileCount(random, config);

    final architect = ArchitectGenerator(
       columns: columns,
       rows: rows,
    );

    // 1. Generation Phase (Symmetry-First & Structural Integrity)
    final emptyLayout = architect.generateSymmetricLayout(
       maxTiles: maxTiles,
       config: config,
       random: random,
       levelNumber: safeLevel,
    );
    
    // 2. Assignment Phase (Staggered Solvable Backwards Algorithm)
    final tiles = architect.assignTypesBackwards(
       emptyLayout: emptyLayout,
       config: config,
       random: random,
       levelNumber: safeLevel,
    );

    return GeneratedLevelLayout(
      levelNumber: safeLevel,
      seed: seed,
      config: config,
      tiles: tiles,
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
    final layerConfigs = List.generate(
      config.layers,
      (layer) => _LayerStackingConfig.random(layer, random),
    );

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
          style: layerConfigs[layer].style,
          pattern: pattern,
        ),
      );
    }
    final tiles = <TileData>[];
    for (var layer = 0; layer < layers.length; layer++) {
      final cells = layers[layer];
      final layerConfig = layerConfigs[layer];

      for (final cell in cells) {
        final subGrid =
            _pickSubGridOffset(cell.$1, cell.$2, layer, random, layerConfig);
        tiles.add(
          TileData(
            type: 0,
            x: cell.$1.toDouble(),
            y: cell.$2.toDouble(),
            layer: layer,
            gridOffsetX: subGrid.$1,
            gridOffsetY: subGrid.$2,
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
    final template = pattern == LayoutPattern.diamond
        ? _buildDiamondPattern(layers)
        : pattern == LayoutPattern.pyramid
            ? _buildPyramidPattern(layers)
            : pattern == LayoutPattern.stair
                ? _buildStairPattern(layers)
                : pattern == LayoutPattern.heart
                    ? _buildLotusPattern(layers)
                    : pattern == LayoutPattern.cross
                        ? _buildCrossPattern(layers)
                        : null;
    if (template == null || template.coordinates.isEmpty) {
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
    final safeCount =
        (capped ~/ TileLayoutRules.groupSize) * TileLayoutRules.groupSize;
    if (safeCount < TileLayoutRules.groupSize) {
      return const [];
    }
    final picked = sorted.take(safeCount).toList();
    final tiles = <TileData>[];
    for (var layerIdx = 0; layerIdx < layers; layerIdx++) {
      final layerCoords = picked.where((c) => c.layer == layerIdx).toList();
      if (layerCoords.isEmpty) continue;

      final layerConfig = _LayerStackingConfig.random(layerIdx, random);

      for (final coord in layerCoords) {
        final cellX = coord.x.floor().clamp(0, columns - 1);
        final cellY = coord.y.floor().clamp(0, rows - 1);

        final subGrid =
            _pickSubGridOffset(cellX, cellY, coord.layer, random, layerConfig);

        // Ensure only 0, 0.5, or -0.5 offsets exist - rounding template's own offset
        final templateOffsetX = ((coord.x - cellX) * 2).round() / 2;
        final templateOffsetY = ((coord.y - cellY) * 2).round() / 2;

        final gridOffsetX =
            (templateOffsetX + subGrid.$1).clamp(-0.5, 0.5).toDouble();
        final gridOffsetY =
            (templateOffsetY + subGrid.$2).clamp(-0.5, 0.5).toDouble();

        tiles.add(
          TileData(
            type: 0,
            x: cellX.toDouble(),
            y: cellY.toDouble(),
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
          // Adjust limit for 6x9 grid
          final patternLimit = limit * 1.35;
          if (manhattan <= patternLimit) {
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
        final halfWidth =
            (1.1 + (1 - (progress - 0.5).abs() * 2) * 2.1) - (layer * 0.26);
        for (var x = 0; x < columns; x++) {
          final px = x + offset;
          final py = y + offset;
          if (px > columns - 1 || py > rows - 1) {
            continue;
          }
          final patternWidth = halfWidth * 1.15;
          if ((px - centerX).abs() <= patternWidth) {
            coordinates.add(
              LevelPatternCoordinate(x: px, y: py, layer: layer),
            );
          }
        }
      }
    }
    return LevelPattern(id: 'pyramid', coordinates: coordinates);
  }

  LevelPattern _buildStairPattern(int layers) {
    final coordinates = <LevelPatternCoordinate>[];
    for (var layer = 0; layer < layers; layer++) {
      final offset = layer * 0.5;
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < columns; x++) {
          if ((x + y) % 2 == 0) {
            coordinates.add(
              LevelPatternCoordinate(
                  x: x + offset, y: y + offset, layer: layer),
            );
          }
        }
      }
    }
    return LevelPattern(id: 'stair', coordinates: coordinates);
  }

  LevelPattern _buildLotusPattern(int layers) {
    final coordinates = <LevelPatternCoordinate>[];
    final centerX = (columns - 1) / 2;
    final centerY = (rows - 1) / 2;

    for (var layer = 0; layer < layers; layer++) {
      final layerScale = 1.0 - (layer * 0.12);
      // Lotus Core (Central Block)
      final coreRadius = (1.2 * layerScale) * 1.25;
      for (double y = centerY - coreRadius;
          y <= centerY + coreRadius;
          y += 0.5) {
        for (double x = centerX - coreRadius;
            x <= centerX + coreRadius;
            x += 0.5) {
          // Keep within grid
          if (x >= 0 && x <= columns - 1 && y >= 0 && y <= rows - 1) {
            coordinates.add(LevelPatternCoordinate(x: x, y: y, layer: layer));
          }
        }
      }

      // Lotus Petals (Symmetric offsets)
      final petalDistance = (2.4 * layerScale) * 1.4;
      const petalCount = 8;
      for (int i = 0; i < petalCount; i++) {
        final angle = (2 * pi / petalCount) * i;
        final px = centerX + cos(angle) * petalDistance;
        final py = centerY + sin(angle) * petalDistance;

        // Ensure within grid
        if (px >= 0 && px <= columns - 1 && py >= 0 && py <= rows - 1) {
          coordinates.add(LevelPatternCoordinate(x: px, y: py, layer: layer));
        }

        final petalShiftX =
            cos(angle) > 0 ? 0.5 : (cos(angle) < 0 ? -0.5 : 0.0);
        final petalShiftY =
            sin(angle) > 0 ? 0.5 : (sin(angle) < 0 ? -0.5 : 0.0);
        final sx = px + petalShiftX;
        final sy = py + petalShiftY;
        if (sx >= 0 && sx <= columns - 1 && sy >= 0 && sy <= rows - 1) {
          coordinates.add(LevelPatternCoordinate(x: sx, y: sy, layer: layer));
        }
      }
    }
    return LevelPattern(id: 'lotus', coordinates: coordinates);
  }

  LevelPattern _buildCrossPattern(int layers) {
    final coordinates = <LevelPatternCoordinate>[];
    final centerX = (columns - 1) / 2;
    final centerY = (rows - 1) / 2;
    for (var layer = 0; layer < layers; layer++) {
      final thickness = 1.2 - (layer * 0.2);
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < columns; x++) {
          final dx = (x - centerX).abs();
          final dy = (y - centerY).abs();
          if (dx <= thickness || dy <= thickness) {
            coordinates.add(
              LevelPatternCoordinate(
                  x: x.toDouble(), y: y.toDouble(), layer: layer),
            );
          }
        }
      }
    }
    return LevelPattern(id: 'cross', coordinates: coordinates);
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
    // We expect layout.length to be a multiple of 3 by the layout generator.
    final tileTypes = tileTypeCount.clamp(1, maxTileTypes);
    final typePool = <int>[];
    final tripleCount = count ~/ TileLayoutRules.groupSize;
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
    required _StackingStyle style,
    required LayoutPattern pattern,
  }) {
    if (count <= 0) return const [];

    final centerX = (columns - 1) / 2;
    final centerY = (rows - 1) / 2;
    final previousSet = previousLayer.toSet();

    // 1. Group candidates based on Symmetry if needed
    final groups = <List<(int, int)>>[];
    final used = <(int, int)>{};

    final isSymmetric = style == _StackingStyle.symmetric;

    for (final cell in candidates) {
      if (used.contains(cell)) continue;

      final group = [cell];
      used.add(cell);

      // Support 4-way symmetry if pattern allows
      final canHaveVerticalSymmetry =
          pattern != LayoutPattern.stair && pattern != LayoutPattern.zigzag;

      if (isSymmetric) {
        final mirrorX = (columns - 1 - cell.$1);
        final mirrorCellX = (mirrorX, cell.$2);

        if (candidates.contains(mirrorCellX) && !used.contains(mirrorCellX)) {
          group.add(mirrorCellX);
          used.add(mirrorCellX);
        }

        if (canHaveVerticalSymmetry) {
          final mirrorY = (rows - 1 - cell.$2);
          final mirrorCellY = (cell.$1, mirrorY);
          final mirrorCellXY = (mirrorX, mirrorY);

          if (candidates.contains(mirrorCellY) && !used.contains(mirrorCellY)) {
            group.add(mirrorCellY);
            used.add(mirrorCellY);
          }
          if (candidates.contains(mirrorCellXY) &&
              !used.contains(mirrorCellXY)) {
            group.add(mirrorCellXY);
            used.add(mirrorCellXY);
          }
        }
      }
      groups.add(group);
    }

    // 2. Score groups based on Pattern Priority
    groups.sort((a, b) {
      final aRep = a.first;
      final bRep = b.first;

      double scoreA = 0;
      double scoreB = 0;

      final distA = sqrt(pow(aRep.$1 - centerX, 2) + pow(aRep.$2 - centerY, 2));
      final distB = sqrt(pow(bRep.$1 - centerX, 2) + pow(bRep.$2 - centerY, 2));

      // Strategy: Inward vs Outward
      if (pattern == LayoutPattern.ring || pattern == LayoutPattern.radial) {
        // Perimeter priority (Ideal ring radius is ~2.2)
        scoreA = -(distA - 2.2).abs();
        scoreB = -(distB - 2.2).abs();
      } else {
        // Center priority (Normal)
        scoreA = -distA;
        scoreB = -distB;
      }

      // Overlap bonus
      final overlapA = a.any((c) => previousSet.contains(c)) ? 1 : 0;
      final overlapB = b.any((c) => previousSet.contains(c)) ? 1 : 0;

      scoreA += (overlapA * overlapStrength * 5);
      scoreB += (overlapB * overlapStrength * 5);

      // Normalizing score to 0-1 range roughly before jitter
      scoreA /= 10.0;
      scoreB /= 10.0;

      // Random jitter for variety (Reduced for patterned levels)
      final jitterScale = (pattern == LayoutPattern.irregular ||
              pattern == LayoutPattern.randomCluster)
          ? 0.5
          : 0.05;
      scoreA += random.nextDouble() * jitterScale;
      scoreB += random.nextDouble() * jitterScale;

      return scoreB.compareTo(scoreA);
    });

    // 3. Pick groups until we reach target count (with some tolerance)
    final picked = <(int, int)>[];
    int totalPicked = 0;

    // Safety tolerance: can go ±3 tiles to complete a symmetry or pattern
    for (final group in groups) {
      if (totalPicked >= count + 3) break;
      if (totalPicked >= count && group.length > 1) {
        // Don't start a new pair if we are already at or over target
        continue;
      }

      picked.addAll(group);
      totalPicked += group.length;
    }

    // Final Normalize to multiple of 3 (Architect adjustment)
    while (picked.length % 3 != 0) {
      if (candidates.length > picked.length) {
        // Find a candidate not picked yet
        final extra = candidates.firstWhere((c) => !picked.contains(c),
            orElse: () => (-1, -1));
        if (extra.$1 != -1) {
          picked.add(extra);
        } else {
          // If no extra found in candidates, we MUST remove until multiple of 3
          picked.removeLast();
        }
      } else {
        // We already have all candidates or more than target count, so we must remove
        if (picked.isNotEmpty) {
          picked.removeLast();
        } else {
          break;
        }
      }
    }

    return picked;
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
        (tile.layer * TileLayoutRules.stackingOffsetRatio * 60.0 * offsetScale);
    final top = ((tile.y + tile.gridOffsetY) * (tileSize + spacing)) +
        (tile.layer * (-TileLayoutRules.stackingOffsetRatio) * 60.0 * offsetScale);
    return _SimRect(
      left: left,
      top: top,
      right: left + tileSize,
      bottom: top + tileSize,
    );
  }

  (double, double) _pickSubGridOffset(
    int x,
    int y,
    int layer,
    Random random,
    _LayerStackingConfig config,
  ) {
    if (layer == 0) return (0.0, 0.0);

    switch (config.style) {
      case _StackingStyle.uniform:
        return config.primaryOffset;

      case _StackingStyle.symmetric:
        final centerX = (columns - 1) / 2;
        final centerY = (rows - 1) / 2;
        final leftSide = x < centerX;
        final topSide = y < centerY;

        double ox = config.primaryOffset.$1;
        double oy = config.primaryOffset.$2;

        if (!leftSide) ox = -ox;
        if (!topSide) oy = -oy; // Add vertical mirroring

        return (ox, oy);

      case _StackingStyle.checkerboard:
        final isCorner = (x + y) % 2 != 0;
        return isCorner ? config.primaryOffset : (0.0, 0.0);

      case _StackingStyle.radial:
        final centerX = (columns - 1) / 2;
        final centerY = (rows - 1) / 2;
        final dx = x - centerX;
        final dy = y - centerY;
        final ox = dx > 0 ? 0.5 : (dx < 0 ? -0.5 : 0.0);
        final oy = dy > 0 ? 0.5 : (dy < 0 ? -0.5 : 0.0);
        return (ox, oy);

      case _StackingStyle.spiral:
        final centerX = (columns - 1) / 2;
        final centerY = (rows - 1) / 2;
        final dx = x - centerX;
        final dy = y - centerY;
        final angle = atan2(dy, dx);
        // Rotate direction by 90 degrees for spiral feel
        final rotAngle = angle + pi / 2;
        final ox =
            cos(rotAngle) > 0.3 ? 0.5 : (cos(rotAngle) < -0.3 ? -0.5 : 0.0);
        final oy =
            sin(rotAngle) > 0.3 ? 0.5 : (sin(rotAngle) < -0.3 ? -0.5 : 0.0);
        return (ox, oy);

      case _StackingStyle.wave:
        // Alternating horizontal shift by row
        final ox = (y % 2 == 0) ? 0.5 : -0.5;
        return (ox, 0.0);

      case _StackingStyle.staircase:
        // Diagonal progression pattern
        final isStep = (x + y) % 2 == 0;
        return isStep ? (0.5, 0.5) : (-0.5, -0.5);

      case _StackingStyle.inward:
        final centerX = (columns - 1) / 2;
        final centerY = (rows - 1) / 2;
        final dx = x - centerX;
        final dy = y - centerY;
        // Inverse of radial: pull towards center
        final ox = dx > 0 ? -0.5 : (dx < 0 ? 0.5 : 0.0);
        final oy = dy > 0 ? -0.5 : (dy < 0 ? 0.5 : 0.0);
        return (ox, oy);
    }
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
    // Jitter disabled: Only use precision 5-way subgrid offsets.
    return 0;
  }

  double _templateFineJitter({
    required int levelNumber,
    required Random random,
  }) {
    // Jitter disabled: Only use precision 5-way subgrid offsets.
    return 0;
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
      return 5;
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
        final aDistance =
            (a.x - (columns / 2)).abs() + (a.y - (rows / 2)).abs();
        final bDistance =
            (b.x - (columns / 2)).abs() + (b.y - (rows / 2)).abs();
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
    if (sortedLayout.isEmpty) return const [];

    final unassigned = [...sortedLayout];
    final result = List<TileData>.filled(sortedLayout.length, sortedLayout[0]);
    final assignedIndices = <int>{};

    // 1. Identify which tiles are initially playable (on the surface)
    final simTiles = unassigned.asMap().entries.map((e) {
      final t = e.value;
      return _SimTile(
        id: e.key,
        type: 0,
        x: t.x,
        y: t.y,
        layer: t.layer,
        gridOffsetX: t.gridOffsetX,
        gridOffsetY: t.gridOffsetY,
      );
    }).toList();

    final playable = _playableTiles(simTiles);
    final surfaceIndices = playable.map((t) => t.id).toSet();

    // 2. Group types into triples pool
    final triplesPool = <int>[];
    final typeCounts = <int, int>{};
    for (final t in typePool) {
      typeCounts.update(t, (v) => v + 1, ifAbsent: () => 1);
    }
    typeCounts.forEach((type, count) {
      final numTriples = count ~/ TileLayoutRules.groupSize;
      for (var i = 0; i < numTriples; i++) {
        triplesPool.add(type);
      }
    });

    // Shuffle types to avoid predictable ordering
    triplesPool.shuffle(random);

    // 3. Priority Assignment: Surface-to-Buried (Hardening)
    // Goal: Populate surface with unique types first, then bury their partners.
    
    // We process surface tiles first to ensure variety
    final sortedSurface = surfaceIndices.toList()..sort((a, b) {
      // Sort surface by layer (top down) and then random
      if (unassigned[a].layer != unassigned[b].layer) {
        return unassigned[b].layer.compareTo(unassigned[a].layer);
      }
      return random.nextDouble() > 0.5 ? 1 : -1;
    });

    for (final idx in sortedSurface) {
      if (assignedIndices.contains(idx)) continue;
      if (triplesPool.isEmpty) break;

      final type = triplesPool.removeLast();
      
      // Assign the surface tile
      result[idx] = unassigned[idx].copyWith(type: type);
      assignedIndices.add(idx);

      // Now find 2 partners for this triple
      // Preference: 
      // 1. Buried tiles in different layers
      // 2. Buried tiles in same layer but far away
      // 3. Other surface tiles as far away as possible
      for (var p = 0; p < TileLayoutRules.groupSize - 1; p++) {
        int bestPartnerIdx = -1;
        double bestScore = -1.0;

        for (var i = 0; i < unassigned.length; i++) {
          if (assignedIndices.contains(i)) continue;

          final candidate = unassigned[i];
          final base = unassigned[idx];
          
          double score = 0;
          
          // Different layer check (High priority for hardening)
          if (candidate.layer != base.layer) {
            score += 2000.0 + (candidate.layer - base.layer).abs() * 50;
          }

          // Buried bonus (Hardening - hide partners)
          if (!surfaceIndices.contains(i)) {
            score += 5000.0;
          }

          // Distance bonus (Spread them out)
          final distSq = pow(candidate.x - base.x, 2) + pow(candidate.y - base.y, 2);
          score += sqrt(distSq.toDouble()) * 20.0;

          // Random jitter
          score += random.nextDouble() * 10.0;

          if (score > bestScore) {
            bestScore = score;
            bestPartnerIdx = i;
          }
        }

        if (bestPartnerIdx != -1) {
          result[bestPartnerIdx] = unassigned[bestPartnerIdx].copyWith(type: type);
          assignedIndices.add(bestPartnerIdx);
        }
      }
    }

    // 4. Cleanup: Assign remaining triples to remaining unassigned slots
    final remainingIndices = <int>[];
    for (var i = 0; i < unassigned.length; i++) {
      if (!assignedIndices.contains(i)) {
        remainingIndices.add(i);
      }
    }

    // Sort remaining by layer depth (shallowest first for consistency)
    remainingIndices.sort((a, b) => unassigned[a].layer.compareTo(unassigned[b].layer));

    while (remainingIndices.isNotEmpty && triplesPool.isNotEmpty) {
      final type = triplesPool.removeLast();
      
      // Pick first unassigned
      final baseIdx = remainingIndices.removeAt(0);
      result[baseIdx] = unassigned[baseIdx].copyWith(type: type);
      assignedIndices.add(baseIdx);

      // Find 2 partners for this triple
      for (var p = 0; p < TileLayoutRules.groupSize - 1; p++) {
        if (remainingIndices.isEmpty) break;

        int bestPartnerIdx = -1;
        double bestScore = -1.0;

        for (var i = 0; i < remainingIndices.length; i++) {
          final idxCandidate = remainingIndices[i];
          final candidate = unassigned[idxCandidate];
          final base = unassigned[baseIdx];

          double score = 0;
          
          // Same layer? Try to spread out
          if (candidate.layer == base.layer) {
            final distSq = pow(candidate.x - base.x, 2) + pow(candidate.y - base.y, 2);
            score += sqrt(distSq) * 100.0;
          } else {
            // Different layer? Excellent for burying
            score += 200.0 + (candidate.layer - base.layer).abs() * 50;
          }

          score += random.nextDouble() * 20.0;

          if (score > bestScore) {
            bestScore = score;
            bestPartnerIdx = i;
          }
        }

        if (bestPartnerIdx != -1) {
          final idx = remainingIndices.removeAt(bestPartnerIdx);
          result[idx] = unassigned[idx].copyWith(type: type);
          assignedIndices.add(idx);
        }
      }
    }

    return result;
  }
}

class _SimTile {
  final int id;
  final int type;
  final double x;
  final double y;
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

enum _StackingStyle {
  uniform,
  symmetric,
  checkerboard,
  radial,
  spiral,
  wave,
  staircase,
  inward,
}

class _LayerStackingConfig {
  final _StackingStyle style;
  final (double, double) primaryOffset;

  const _LayerStackingConfig({
    required this.style,
    required this.primaryOffset,
  });

  factory _LayerStackingConfig.random(int layer, Random random) {
    if (layer == 0) {
      return const _LayerStackingConfig(
        style: _StackingStyle.uniform,
        primaryOffset: (0.0, 0.0),
      );
    }

    final styles = _StackingStyle.values;
    final style = styles[random.nextInt(styles.length)];

    const possibleOffsets = [
      (0.5, -0.5), // TR
      (0.5, 0.5), // BR
      (-0.5, -0.5), // TL
      (-0.5, 0.5), // BL
    ];
    final primaryOffset =
        possibleOffsets[random.nextInt(possibleOffsets.length)];

    return _LayerStackingConfig(
      style: style,
      primaryOffset: primaryOffset,
    );
  }
}
