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
  final double stackOffsetX;
  final double stackOffsetY;

  const TileData({
    required this.type,
    required this.x,
    required this.y,
    required this.layer,
    this.stackOffsetX = 0,
    this.stackOffsetY = 0,
  });

  TileData copyWith({
    int? type,
    int? x,
    int? y,
    int? layer,
    double? stackOffsetX,
    double? stackOffsetY,
  }) {
    return TileData(
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      layer: layer ?? this.layer,
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
    if (safeLevel <= 10) {
      return const LevelDifficultyConfig(
        tier: 'easy',
        tileTypes: 6,
        layers: 2,
        minTiles: 24,
        maxTiles: 30,
        overlapStrength: 0.26,
        centerBias: 0.34,
        patternPool: [
          LayoutPattern.irregular,
          LayoutPattern.pyramid,
          LayoutPattern.cross,
          LayoutPattern.diamond,
        ],
      );
    }
    if (safeLevel <= 30) {
      return const LevelDifficultyConfig(
        tier: 'medium',
        tileTypes: 8,
        layers: 3,
        minTiles: 36,
        maxTiles: 48,
        overlapStrength: 0.38,
        centerBias: 0.48,
        patternPool: [
          LayoutPattern.irregular,
          LayoutPattern.pyramid,
          LayoutPattern.ring,
          LayoutPattern.cross,
          LayoutPattern.zigzag,
          LayoutPattern.wave,
        ],
      );
    }
    if (safeLevel <= 60) {
      return const LevelDifficultyConfig(
        tier: 'hard',
        tileTypes: 10,
        layers: 3,
        minTiles: 48,
        maxTiles: 60,
        overlapStrength: 0.5,
        centerBias: 0.62,
        patternPool: [
          LayoutPattern.ring,
          LayoutPattern.spiral,
          LayoutPattern.cross,
          LayoutPattern.randomCluster,
          LayoutPattern.wave,
          LayoutPattern.canyon,
        ],
      );
    }
    return const LevelDifficultyConfig(
      tier: 'expert',
      tileTypes: 12,
      layers: 4,
      minTiles: 60,
      maxTiles: 72,
      overlapStrength: 0.66,
      centerBias: 0.78,
      patternPool: [
        LayoutPattern.spiral,
        LayoutPattern.ring,
        LayoutPattern.randomCluster,
        LayoutPattern.cross,
        LayoutPattern.zigzag,
        LayoutPattern.diamond,
        LayoutPattern.canyon,
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
}
