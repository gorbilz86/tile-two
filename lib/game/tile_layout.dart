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
  stair,
  heart,
  radial,
}

enum AnchorType {
  center,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  AnchorType get mirrored {
    switch (this) {
      case AnchorType.center:
        return AnchorType.center;
      case AnchorType.topLeft:
        return AnchorType.topRight;
      case AnchorType.topRight:
        return AnchorType.topLeft;
      case AnchorType.bottomLeft:
        return AnchorType.bottomRight;
      case AnchorType.bottomRight:
        return AnchorType.bottomLeft;
    }
  }
}

enum StackingTheme {
  consistentCenter,
  cornerPyramid,
  mixed,
}

class TileData {
  final int type;
  final double x;
  final double y;
  final int layer;
  final AnchorType anchor;
  final double gridOffsetX;
  final double gridOffsetY;
  final double stackOffsetX;
  final double stackOffsetY;

  const TileData({
    required this.type,
    required this.x,
    required this.y,
    required this.layer,
    this.anchor = AnchorType.center,
    this.gridOffsetX = 0,
    this.gridOffsetY = 0,
    this.stackOffsetX = 0,
    this.stackOffsetY = 0,
  });

  TileData copyWith({
    int? type,
    double? x,
    double? y,
    int? layer,
    AnchorType? anchor,
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
      anchor: anchor ?? this.anchor,
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
  final StackingTheme stackingTheme;

  const LevelDifficultyConfig({
    required this.tier,
    required this.tileTypes,
    required this.layers,
    required this.minTiles,
    required this.maxTiles,
    required this.overlapStrength,
    required this.centerBias,
    required this.patternPool,
    required this.stackingTheme,
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
  static const int maxLevel = 150;
  static const int boardColumns = 6;
  static const int boardRows = 9;
  static const int groupSize = 3;
  static const int seedPrime = 997;
  static const double layerOffsetX = 4.2;
  static const double layerOffsetY = -4.2;

  static int seedForLevel(int levelNumber) {
    return levelNumber * seedPrime;
  }

  static LevelDifficultyConfig configForLevel(int levelNumber) {
    final safeLevel = levelNumber.clamp(minLevel, maxLevel);
    if (safeLevel <= 10) {
      final progress = ((safeLevel - 1) / 9).clamp(0, 1).toDouble();
      return _buildCurveConfig(
        tier: 'tutorial',
        minTilesStart: 27,
        minTilesEnd: 33,
        maxTilesStart: 33,
        maxTilesEnd: 39,
        overlapStart: 0.22,
        overlapEnd: 0.32,
        centerBiasStart: 0.25,
        centerBiasEnd: 0.32,
        tileTypesStart: 6,
        tileTypesEnd: 8,
        layersStart: 2,
        layersEnd: 3,
        progress: progress,
        patternPool: const [
          LayoutPattern.irregular,
          LayoutPattern.pyramid,
          LayoutPattern.cross,
          LayoutPattern.diamond,
        ],
        stackingTheme: StackingTheme.consistentCenter,
      );
    }
    if (safeLevel <= 30) {
      final progress = ((safeLevel - 11) / 19).clamp(0, 1).toDouble();
      return _buildCurveConfig(
        tier: 'easy',
        minTilesStart: 42,
        minTilesEnd: 48,
        maxTilesStart: 48,
        maxTilesEnd: 57,
        overlapStart: 0.35,
        overlapEnd: 0.48,
        centerBiasStart: 0.35,
        centerBiasEnd: 0.45,
        tileTypesStart: 8,
        tileTypesEnd: 11,
        layersStart: 3,
        layersEnd: 4,
        progress: progress,
        patternPool: const [
          LayoutPattern.irregular,
          LayoutPattern.pyramid,
          LayoutPattern.cross,
          LayoutPattern.ring,
          LayoutPattern.diamond,
          LayoutPattern.wave,
        ],
        stackingTheme: StackingTheme.consistentCenter,
      );
    }
    if (safeLevel <= 70) {
      final progress = ((safeLevel - 31) / 39).clamp(0, 1).toDouble();
      return _buildCurveConfig(
        tier: 'medium',
        minTilesStart: 63,
        minTilesEnd: 72,
        maxTilesStart: 72,
        maxTilesEnd: 81,
        overlapStart: 0.5,
        overlapEnd: 0.65,
        centerBiasStart: 0.5,
        centerBiasEnd: 0.6,
        tileTypesStart: 11,
        tileTypesEnd: 14,
        layersStart: 4,
        layersEnd: 5,
        progress: progress,
        patternPool: const [
          LayoutPattern.ring,
          LayoutPattern.spiral,
          LayoutPattern.cross,
          LayoutPattern.zigzag,
          LayoutPattern.wave,
          LayoutPattern.randomCluster,
          LayoutPattern.canyon,
          LayoutPattern.stair,
          LayoutPattern.heart,
        ],
        stackingTheme: StackingTheme.cornerPyramid,
      );
    }
    if (safeLevel <= 110) {
      final progress = ((safeLevel - 71) / 39).clamp(0, 1).toDouble();
      return _buildCurveConfig(
        tier: 'hard',
        minTilesStart: 84,
        minTilesEnd: 96,
        maxTilesStart: 96,
        maxTilesEnd: 105,
        overlapStart: 0.65,
        overlapEnd: 0.8,
        centerBiasStart: 0.65,
        centerBiasEnd: 0.75,
        tileTypesStart: 14,
        tileTypesEnd: 18,
        layersStart: 5,
        layersEnd: 6,
        progress: progress,
        patternPool: const [
          LayoutPattern.spiral,
          LayoutPattern.randomCluster,
          LayoutPattern.ring,
          LayoutPattern.wave,
          LayoutPattern.canyon,
          LayoutPattern.zigzag,
          LayoutPattern.diamond,
          LayoutPattern.stair,
          LayoutPattern.heart,
        ],
        stackingTheme: StackingTheme.mixed,
      );
    }
    final progress = ((safeLevel - 111) / 39).clamp(0, 1).toDouble();
    return _buildCurveConfig(
      tier: 'expert',
      minTilesStart: 108,
      minTilesEnd: 120,
      maxTilesStart: 120,
      maxTilesEnd: 129,
      overlapStart: 0.82,
      overlapEnd: 0.95,
      centerBiasStart: 0.8,
      centerBiasEnd: 0.9,
      tileTypesStart: 18,
      tileTypesEnd: 24,
      layersStart: 6,
      layersEnd: 7,
      progress: progress,
      patternPool: const [
        LayoutPattern.spiral,
        LayoutPattern.ring,
        LayoutPattern.randomCluster,
        LayoutPattern.zigzag,
        LayoutPattern.canyon,
        LayoutPattern.diamond,
      ],
      stackingTheme: StackingTheme.mixed,
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
    required StackingTheme stackingTheme,
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
      stackingTheme: stackingTheme,
    );
  }

  static int _lerpInt(int from, int to, double t) {
    return (from + ((to - from) * t)).round();
  }

  static double _lerpDouble(double from, double to, double t) {
    return from + ((to - from) * t);
  }
}
