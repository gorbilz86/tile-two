import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum ItemRarity { common, rare, epic, legendary }

class ItemCatalogEntry {
  final String id;
  final int spriteIndex;
  final ItemRarity rarity;
  final int minLevel;

  const ItemCatalogEntry({
    required this.id,
    required this.spriteIndex,
    required this.rarity,
    required this.minLevel,
  });
}

class ItemDropResult {
  final ItemCatalogEntry featuredItem;
  final ItemRarity rarity;
  final List<ItemCatalogEntry> levelPool;

  const ItemDropResult({
    required this.featuredItem,
    required this.rarity,
    required this.levelPool,
  });
}

class ItemDistributionSummary {
  final int common;
  final int rare;
  final int epic;
  final int legendary;

  const ItemDistributionSummary({
    required this.common,
    required this.rare,
    required this.epic,
    required this.legendary,
  });
}

class ItemSimulationReport {
  final int games;
  final ItemDistributionSummary distribution;
  final double rareRate;
  final double epicRate;
  final double legendaryRate;
  final double boredomRate;
  final bool boredomBelowFivePercent;

  const ItemSimulationReport({
    required this.games,
    required this.distribution,
    required this.rareRate,
    required this.epicRate,
    required this.legendaryRate,
    required this.boredomRate,
    required this.boredomBelowFivePercent,
  });
}

class _ItemRandomizationState {
  final Map<String, int> lastSeenLevel;
  final Map<String, int> obtainedCount;
  final List<List<String>> recentPools;
  final List<String> recentFeaturedDrops;

  const _ItemRandomizationState({
    required this.lastSeenLevel,
    required this.obtainedCount,
    required this.recentPools,
    required this.recentFeaturedDrops,
  });

  factory _ItemRandomizationState.initial() {
    return const _ItemRandomizationState(
      lastSeenLevel: {},
      obtainedCount: {},
      recentPools: [],
      recentFeaturedDrops: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lastSeenLevel': lastSeenLevel,
      'obtainedCount': obtainedCount,
      'recentPools': recentPools,
      'recentFeaturedDrops': recentFeaturedDrops,
    };
  }

  factory _ItemRandomizationState.fromMap(Map<String, dynamic> map) {
    final seen = <String, int>{};
    final rawSeen = map['lastSeenLevel'];
    if (rawSeen is Map) {
      for (final entry in rawSeen.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is num) {
          seen[key] = value.toInt();
        }
      }
    }
    final obtained = <String, int>{};
    final rawObtained = map['obtainedCount'];
    if (rawObtained is Map) {
      for (final entry in rawObtained.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is num) {
          obtained[key] = value.toInt();
        }
      }
    }
    final pools = <List<String>>[];
    final rawPools = map['recentPools'];
    if (rawPools is List) {
      for (final row in rawPools) {
        if (row is List) {
          pools.add(row.map((e) => e.toString()).toList());
        }
      }
    }
    final drops = <String>[];
    final rawDrops = map['recentFeaturedDrops'];
    if (rawDrops is List) {
      for (final value in rawDrops) {
        drops.add(value.toString());
      }
    }
    return _ItemRandomizationState(
      lastSeenLevel: seen,
      obtainedCount: obtained,
      recentPools: pools,
      recentFeaturedDrops: drops,
    );
  }
}

class ItemRandomizationService {
  ItemRandomizationService._();

  static final ItemRandomizationService instance = ItemRandomizationService._();
  static const String _prefsKey = 'item_randomization_state_v1';
  static const int _antiDupWindowLevels = 5;
  static const int _coverageWindowLevels = 20;
  static const int _minPoolSize = 6;

  final List<ItemCatalogEntry> _catalog = _buildCatalog();
  _ItemRandomizationState _state = _ItemRandomizationState.initial();
  bool _loaded = false;

  List<ItemCatalogEntry> get catalog => _catalog;

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _state = _ItemRandomizationState.fromMap(decoded);
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_state.toMap()));
  }

  Future<ItemDropResult> pickForLevel({
    required int level,
    required int requestedPoolSize,
  }) async {
    await _ensureLoaded();
    return _pickForLevelInternal(
      level: level,
      requestedPoolSize: requestedPoolSize,
      random: Random((level * 1193) + (_state.recentPools.length * 97)),
      persist: true,
    );
  }

  ItemDropResult _pickForLevelInternal({
    required int level,
    required int requestedPoolSize,
    required Random random,
    required bool persist,
  }) {
    final safeLevel = level.clamp(1, 100);
    final targetPoolSize = requestedPoolSize.clamp(_minPoolSize, 12);
    final available = _catalog.where((item) => safeLevel >= item.minLevel).toList();
    if (available.isEmpty) {
      throw StateError('Catalog item kosong untuk level $safeLevel');
    }

    final recentPoolSet = <String>{};
    for (final pool in _state.recentPools) {
      recentPoolSet.addAll(pool);
    }
    final staleCoverage = available.where((item) {
      final lastSeen = _state.lastSeenLevel[item.id];
      if (lastSeen == null) {
        return true;
      }
      return (safeLevel - lastSeen) >= _coverageWindowLevels;
    }).toList()
      ..sort((a, b) {
        final aLevel = _state.lastSeenLevel[a.id] ?? -9999;
        final bLevel = _state.lastSeenLevel[b.id] ?? -9999;
        return aLevel.compareTo(bLevel);
      });

    final dropRarity = _pickRarityByDropRate(
      level: safeLevel,
      random: random,
    );
    final featuredItem = _pickFeaturedItem(
      available: available,
      rarity: dropRarity,
      recentDrops: _state.recentFeaturedDrops,
      random: random,
    );

    final selected = <ItemCatalogEntry>[featuredItem];
    for (final item in staleCoverage) {
      if (selected.length >= targetPoolSize) {
        break;
      }
      if (item.id == featuredItem.id || selected.any((e) => e.id == item.id)) {
        continue;
      }
      if (!recentPoolSet.contains(item.id)) {
        selected.add(item);
      }
    }

    while (selected.length < targetPoolSize) {
      final next = _pickFairItem(
        level: safeLevel,
        candidates: available,
        selected: selected,
        recentPoolSet: recentPoolSet,
        random: random,
      );
      if (next == null) {
        break;
      }
      selected.add(next);
    }

    if (selected.length < targetPoolSize) {
      for (final item in available) {
        if (selected.length >= targetPoolSize) {
          break;
        }
        if (selected.any((e) => e.id == item.id)) {
          continue;
        }
        selected.add(item);
      }
    }

    final finalized = selected.take(targetPoolSize).toList();
    _updateStateForLevel(
      level: safeLevel,
      pool: finalized,
      featured: featuredItem,
    );
    if (persist) {
      _persist();
    }
    return ItemDropResult(
      featuredItem: featuredItem,
      rarity: dropRarity,
      levelPool: finalized,
    );
  }

  ItemCatalogEntry _pickFeaturedItem({
    required List<ItemCatalogEntry> available,
    required ItemRarity rarity,
    required List<String> recentDrops,
    required Random random,
  }) {
    final rareCandidates = available.where((item) => item.rarity == rarity).toList();
    final noDupCandidates = rareCandidates
        .where((item) => !recentDrops.contains(item.id))
        .toList();
    final source = noDupCandidates.isNotEmpty
        ? noDupCandidates
        : (rareCandidates.isNotEmpty ? rareCandidates : available);
    return source[random.nextInt(source.length)];
  }

  ItemCatalogEntry? _pickFairItem({
    required int level,
    required List<ItemCatalogEntry> candidates,
    required List<ItemCatalogEntry> selected,
    required Set<String> recentPoolSet,
    required Random random,
  }) {
    final selectedIds = selected.map((e) => e.id).toSet();
    final weighted = <(ItemCatalogEntry, double)>[];
    for (final item in candidates) {
      if (selectedIds.contains(item.id)) {
        continue;
      }
      var weight = _rarityWeightForPool(level, item.rarity);
      if (recentPoolSet.contains(item.id)) {
        weight *= 0.06;
      }
      final lastSeen = _state.lastSeenLevel[item.id];
      if (lastSeen == null) {
        weight *= 2.6;
      } else {
        final gap = level - lastSeen;
        if (gap >= _coverageWindowLevels) {
          weight *= 2.3;
        } else if (gap >= 10) {
          weight *= 1.4;
        } else if (gap <= 2) {
          weight *= 0.35;
        }
      }
      if (weight > 0) {
        weighted.add((item, weight));
      }
    }
    if (weighted.isEmpty) {
      return null;
    }
    final sum = weighted.fold<double>(0, (acc, e) => acc + e.$2);
    var roll = random.nextDouble() * sum;
    for (final entry in weighted) {
      roll -= entry.$2;
      if (roll <= 0) {
        return entry.$1;
      }
    }
    return weighted.last.$1;
  }

  ItemRarity _pickRarityByDropRate({
    required int level,
    required Random random,
  }) {
    final roll = random.nextDouble();
    if (level <= 20) {
      if (roll < 0.10) {
        return ItemRarity.rare;
      }
      return ItemRarity.common;
    }
    if (level <= 50) {
      if (roll < 0.05) {
        return ItemRarity.epic;
      }
      if (roll < 0.25) {
        return ItemRarity.rare;
      }
      return ItemRarity.common;
    }
    if (roll < 0.05) {
      return ItemRarity.legendary;
    }
    if (roll < 0.20) {
      return ItemRarity.epic;
    }
    if (roll < 0.50) {
      return ItemRarity.rare;
    }
    return ItemRarity.common;
  }

  double _rarityWeightForPool(int level, ItemRarity rarity) {
    if (level <= 20) {
      return switch (rarity) {
        ItemRarity.common => 9,
        ItemRarity.rare => 1,
        ItemRarity.epic => 0,
        ItemRarity.legendary => 0,
      };
    }
    if (level <= 50) {
      return switch (rarity) {
        ItemRarity.common => 7.5,
        ItemRarity.rare => 2,
        ItemRarity.epic => 0.5,
        ItemRarity.legendary => 0,
      };
    }
    return switch (rarity) {
      ItemRarity.common => 5,
      ItemRarity.rare => 3,
      ItemRarity.epic => 1.5,
      ItemRarity.legendary => 0.5,
    };
  }

  void _updateStateForLevel({
    required int level,
    required List<ItemCatalogEntry> pool,
    required ItemCatalogEntry featured,
  }) {
    final nextSeen = Map<String, int>.from(_state.lastSeenLevel);
    final nextObtained = Map<String, int>.from(_state.obtainedCount);
    for (final item in pool) {
      nextSeen[item.id] = level;
      nextObtained.update(item.id, (value) => value + 1, ifAbsent: () => 1);
    }
    final nextPools = [..._state.recentPools, pool.map((e) => e.id).toList()];
    while (nextPools.length > _antiDupWindowLevels) {
      nextPools.removeAt(0);
    }
    final nextDrops = [..._state.recentFeaturedDrops, featured.id];
    while (nextDrops.length > _antiDupWindowLevels) {
      nextDrops.removeAt(0);
    }
    _state = _ItemRandomizationState(
      lastSeenLevel: nextSeen,
      obtainedCount: nextObtained,
      recentPools: nextPools,
      recentFeaturedDrops: nextDrops,
    );
  }

  Future<ItemSimulationReport> runSimulation({
    int games = 1000,
    int seed = 77,
  }) async {
    await _ensureLoaded();
    final backup = _state;
    _state = _ItemRandomizationState.initial();
    final random = Random(seed);
    final rarityCounts = <ItemRarity, int>{
      ItemRarity.common: 0,
      ItemRarity.rare: 0,
      ItemRarity.epic: 0,
      ItemRarity.legendary: 0,
    };
    var boredomSignals = 0;
    final recentPools = <Set<String>>[];

    for (var i = 0; i < games; i++) {
      final level = (i % 100) + 1;
      final requestedPoolSize = 6 + (level % 7);
      final runSeed = random.nextInt(1 << 31);
      final result = _pickForLevelInternal(
        level: level,
        requestedPoolSize: requestedPoolSize,
        random: Random(runSeed),
        persist: false,
      );
      rarityCounts.update(result.rarity, (value) => value + 1);
      final currentPoolSet = result.levelPool.map((e) => e.id).toSet();
      if (recentPools.isNotEmpty) {
        final overlaps = recentPools
            .map((prev) => _overlapRatio(prev, currentPoolSet))
            .toList();
        final highOverlap = overlaps.where((value) => value >= 0.7).length;
        if (highOverlap >= 2) {
          boredomSignals += 1;
        }
      }
      recentPools.add(currentPoolSet);
      while (recentPools.length > _antiDupWindowLevels) {
        recentPools.removeAt(0);
      }
    }

    final total = games.toDouble();
    final rareRate = (rarityCounts[ItemRarity.rare] ?? 0) / total;
    final epicRate = (rarityCounts[ItemRarity.epic] ?? 0) / total;
    final legendaryRate = (rarityCounts[ItemRarity.legendary] ?? 0) / total;
    final boredomRate = boredomSignals / total;
    final report = ItemSimulationReport(
      games: games,
      distribution: ItemDistributionSummary(
        common: rarityCounts[ItemRarity.common] ?? 0,
        rare: rarityCounts[ItemRarity.rare] ?? 0,
        epic: rarityCounts[ItemRarity.epic] ?? 0,
        legendary: rarityCounts[ItemRarity.legendary] ?? 0,
      ),
      rareRate: rareRate,
      epicRate: epicRate,
      legendaryRate: legendaryRate,
      boredomRate: boredomRate,
      boredomBelowFivePercent: boredomRate < 0.05,
    );
    _state = backup;
    return report;
  }

  double _overlapRatio(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }
    final intersection = a.intersection(b).length;
    final basis = a.length > b.length ? b.length : a.length;
    return intersection / basis;
  }

  static List<ItemCatalogEntry> _buildCatalog() {
    final items = <ItemCatalogEntry>[];
    for (var index = 0; index < 64; index++) {
      final rarity = index < 32
          ? ItemRarity.common
          : index < 48
              ? ItemRarity.rare
              : index < 56
                  ? ItemRarity.epic
                  : ItemRarity.legendary;
      final minLevel = switch (rarity) {
        ItemRarity.common => 1,
        ItemRarity.rare => 1,
        ItemRarity.epic => 21,
        ItemRarity.legendary => 51,
      };
      items.add(
        ItemCatalogEntry(
          id: 'item_${index.toString().padLeft(2, '0')}',
          spriteIndex: index,
          rarity: rarity,
          minLevel: minLevel,
        ),
      );
    }
    return items;
  }
}
