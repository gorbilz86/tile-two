import 'dart:math';

enum LayoutPattern {
  irregular,
  pyramid,
  ring,
  spiral,
  cross,
  randomCluster,
  diamond,
  zigzag,
  wave,
  canyon,
}

class TileData {
  final int type;
  final int x;
  final int y;
  final int layer;
  final double gridOffsetX;
  final double gridOffsetY;
  final double stackOffsetX;
  final double stackOffsetY;

  const TileData({
    required this.type,
    required this.x,
    required this.y,
    required this.layer,
    this.gridOffsetX = 0,
    this.gridOffsetY = 0,
    this.stackOffsetX = 0,
    this.stackOffsetY = 0,
  });

  TileData copyWith({
    int? type,
    int? x,
    int? y,
    int? layer,
    double? gridOffsetX,
    double? gridOffsetY,
    double? stackOffsetX,
    double? stackOffsetY,
  }) {
    return TileData(
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      layer: layer ?? this.layer,
      gridOffsetX: gridOffsetX ?? this.gridOffsetX,
      gridOffsetY: gridOffsetY ?? this.gridOffsetY,
      stackOffsetX: stackOffsetX ?? this.stackOffsetX,
      stackOffsetY: stackOffsetY ?? this.stackOffsetY,
    );
  }
}

class LevelDifficultyConfig {
  final String tier;
  final int tileTypes;
  final int layers;
  final int minTiles;
  final int maxTiles;
  final double overlapStrength;
  final double centerBias;
  final List<LayoutPattern> patternPool;

  const LevelDifficultyConfig({
    required this.tier,
    required this.tileTypes,
    required this.layers,
    required this.minTiles,
    required this.maxTiles,
    required this.overlapStrength,
    required this.centerBias,
    required this.patternPool,
  });
}

class GeneratedLevelLayout {
  final int levelNumber;
  final int seed;
  final LevelDifficultyConfig config;
  final List<TileData> tiles;
  final LayoutPattern pattern;

  const GeneratedLevelLayout({
    required this.levelNumber,
    required this.seed,
    required this.config,
    required this.tiles,
    required this.pattern,
  });
}

class TileLayoutRules {
  static const int minLevel = 1;
  static const int maxLevel = 100;
  static const int boardColumns = 6;
  static const int boardRows = 6;
  static const int groupSize = 3;
  static const int seedPrime = 997;
  static const double layerOffsetX = 6;
  static const double layerOffsetY = -6;

  static int seedForLevel(int levelNumber) {
    return levelNumber * seedPrime;
  }

  static LevelDifficultyConfig configForLevel(int levelNumber) {
    final safeLevel = levelNumber.clamp(minLevel, maxLevel);
    if (safeLevel <= 8) {
      final progress = ((safeLevel - 1) / 7).clamp(0, 1).toDouble();
      return _buildCurveConfig(
        tier: 'tutorial',
        minTilesStart: 21,
        minTilesEnd: 27,
        maxTilesStart: 27,
        maxTilesEnd: 33,
        overlapStart: 0.2,
        overlapEnd: 0.28,
        centerBiasStart: 0.26,
        centerBiasEnd: 0.35,
        tileTypesStart: 5,
        tileTypesEnd: 6,
        layersStart: 2,
        layersEnd: 2,
        progress: progress,
        patternPool: const [
          LayoutPattern.irregular,
          LayoutPattern.pyramid,
          LayoutPattern.cross,
          LayoutPattern.diamond,
        ],
      );
    }
    if (safeLevel <= 25) {
      final progress = ((safeLevel - 9) / 16).clamp(0, 1).toDouble();
      return _buildCurveConfig(
        tier: 'easy',
        minTilesStart: 30,
        minTilesEnd: 39,
        maxTilesStart: 36,
        maxTilesEnd: 48,
        overlapStart: 0.3,
        overlapEnd: 0.4,
        centerBiasStart: 0.38,
        centerBiasEnd: 0.5,
        tileTypesStart: 6,
        tileTypesEnd: 8,
        layersStart: 2,
        layersEnd: 3,
        progress: progress,
        patternPool: const [
          LayoutPattern.irregular,
          LayoutPattern.pyramid,
          LayoutPattern.cross,
          LayoutPattern.ring,
          LayoutPattern.diamond,
          LayoutPattern.wave,
        ],
      );
    }
    if (safeLevel <= 50) {
      final progress = ((safeLevel - 26) / 24).clamp(0, 1).toDouble();
      return _buildCurveConfig(
        tier: 'medium',
        minTilesStart: 42,
        minTilesEnd: 54,
        maxTilesStart: 48,
        maxTilesEnd: 60,
        overlapStart: 0.42,
        overlapEnd: 0.55,
        centerBiasStart: 0.52,
        centerBiasEnd: 0.66,
        tileTypesStart: 8,
        tileTypesEnd: 10,
        layersStart: 3,
        layersEnd: 3,
        progress: progress,
        patternPool: const [
          LayoutPattern.ring,
          LayoutPattern.spiral,
          LayoutPattern.cross,
          LayoutPattern.zigzag,
          LayoutPattern.wave,
          LayoutPattern.randomCluster,
          LayoutPattern.canyon,
        ],
      );
    }
    if (safeLevel <= 80) {
      final progress = ((safeLevel - 51) / 29).clamp(0, 1).toDouble();
      return _buildCurveConfig(
        tier: 'hard',
        minTilesStart: 54,
        minTilesEnd: 66,
        maxTilesStart: 60,
        maxTilesEnd: 72,
        overlapStart: 0.56,
        overlapEnd: 0.7,
        centerBiasStart: 0.68,
        centerBiasEnd: 0.82,
        tileTypesStart: 10,
        tileTypesEnd: 12,
        layersStart: 3,
        layersEnd: 4,
        progress: progress,
        patternPool: const [
          LayoutPattern.spiral,
          LayoutPattern.randomCluster,
          LayoutPattern.ring,
          LayoutPattern.wave,
          LayoutPattern.canyon,
          LayoutPattern.zigzag,
          LayoutPattern.diamond,
        ],
      );
    }
    final progress = ((safeLevel - 81) / 19).clamp(0, 1).toDouble();
    return _buildCurveConfig(
      tier: 'expert',
      minTilesStart: 66,
      minTilesEnd: 72,
      maxTilesStart: 72,
      maxTilesEnd: 78,
      overlapStart: 0.72,
      overlapEnd: 0.84,
      centerBiasStart: 0.84,
      centerBiasEnd: 0.94,
      tileTypesStart: 12,
      tileTypesEnd: 12,
      layersStart: 4,
      layersEnd: 4,
      progress: progress,
      patternPool: const [
        LayoutPattern.spiral,
        LayoutPattern.ring,
        LayoutPattern.randomCluster,
        LayoutPattern.zigzag,
        LayoutPattern.canyon,
        LayoutPattern.diamond,
      ],
    );
  }

  static int normalizedTileCount(int tileCount) {
    final remainder = tileCount % groupSize;
    if (remainder == 0) {
      return tileCount;
    }
    return tileCount + (groupSize - remainder);
  }

  static int pickTileCount(Random random, LevelDifficultyConfig config) {
    final span = config.maxTiles - config.minTiles;
    final rawCount = config.minTiles + random.nextInt(span + 1);
    return normalizedTileCount(rawCount);
  }

  static LevelDifficultyConfig _buildCurveConfig({
    required String tier,
    required int minTilesStart,
    required int minTilesEnd,
    required int maxTilesStart,
    required int maxTilesEnd,
    required double overlapStart,
    required double overlapEnd,
    required double centerBiasStart,
    required double centerBiasEnd,
    required int tileTypesStart,
    required int tileTypesEnd,
    required int layersStart,
    required int layersEnd,
    required double progress,
    required List<LayoutPattern> patternPool,
  }) {
    final t = progress.clamp(0, 1).toDouble();
    final minTiles = normalizedTileCount(_lerpInt(minTilesStart, minTilesEnd, t));
    final maxTiles = normalizedTileCount(_lerpInt(maxTilesStart, maxTilesEnd, t));
    final clampedMin = min(minTiles, maxTiles);
    final clampedMax = max(minTiles, maxTiles);
    return LevelDifficultyConfig(
      tier: tier,
      tileTypes: _lerpInt(tileTypesStart, tileTypesEnd, t),
      layers: _lerpInt(layersStart, layersEnd, t),
      minTiles: clampedMin,
      maxTiles: clampedMax,
      overlapStrength: _lerpDouble(overlapStart, overlapEnd, t),
      centerBias: _lerpDouble(centerBiasStart, centerBiasEnd, t),
      patternPool: patternPool,
    );
  }

  static int _lerpInt(int from, int to, double t) {
    return (from + ((to - from) * t)).round();
  }

  static double _lerpDouble(double from, double to, double t) {
    return from + ((to - from) * t);
  }
}
