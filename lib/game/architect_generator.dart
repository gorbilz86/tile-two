import 'dart:math';
import 'package:tile_two/game/tile_layout.dart';

class ArchitectGenerator {
  final int columns;
  final int rows;

  ArchitectGenerator({
    required this.columns,
    required this.rows,
  });

  /// 1. Generation Phase (Symmetry-First & Structural Integrity)
  List<TileData> generateSymmetricLayout({
    required int maxTiles,
    required LevelDifficultyConfig config,
    required Random random,
    required int levelNumber,
  }) {
    final slotsByLayer = <int, List<TileData>>{};
    // Pivot for 6-column grid (6 units wide: -0.5 to 5.5 edges) is exactly 2.5 centers.
    const double pivotX = 2.5;

    for (int layer = 0; layer < config.layers; layer++) {
      slotsByLayer[layer] = [];
      final layerTargetLeft = (maxTiles / 2 / config.layers).ceil();
      
      // Determine if this layer is "Classic Grid" (0.0 fract) or "Diagonal Stagger" (0.5 fract)
      final double layerFract = (layer % 2 == 0) ? 0.0 : 0.5;

      final candidates = <(double, double)>[];
      // Only generate for the left side (0.0 to pivot 2.5)
      for (double x = 0.0; x <= pivotX; x += 0.5) {
        if (_snap(x) % 1.0 != layerFract) continue;
        for (double y = 0.0; y < rows; y += 0.5) {
          if (_snap(y) % 1.0 != layerFract) continue;
          
          final swX = _snap(x);
          final swY = _snap(y);
          if (layer == 0) {
            final dx = swX - pivotX;
            final dy = swY - (rows - 1) / 2;
            final dist = sqrt(dx * dx + dy * dy);
            if (dist < 4.0 || random.nextDouble() > 0.3) {
              candidates.add((swX, swY));
            }
          } else {
            if (_hasSupport(swX, swY, slotsByLayer[layer - 1]!)) {
              candidates.add((swX, swY));
            }
          }
        }
      }
      
      candidates.shuffle(random);
      
      int placedLeft = 0;
      for (final candidate in candidates) {
        if (placedLeft >= layerTargetLeft) break;
        bool overlaps = false;
        for (final existing in slotsByLayer[layer]!) {
          final dx = (existing.x - candidate.$1).abs();
          final dy = (existing.y - candidate.$2).abs();
          if (dx < 1.0 && dy < 1.0) {
            overlaps = true;
            break;
          }
        }
        
        if (!overlaps) {
          final leftAnchor = AnchorType.values[random.nextInt(AnchorType.values.length)];
          slotsByLayer[layer]!.add(TileData(
            type: 0,
            x: _snap(candidate.$1),
            y: _snap(candidate.$2),
            layer: layer,
            anchor: leftAnchor,
            gridOffsetX: 0,
            gridOffsetY: 0,
            stackOffsetX: 0.0,
            stackOffsetY: 0.0,
          ));
          placedLeft++;
        }
      }
    }
    
    final mirroredSlots = <TileData>[];
    for (final layer in slotsByLayer.values) {
      for (final leftTile in layer) {
        mirroredSlots.add(leftTile);
        if (leftTile.x < pivotX) {
          // Mirror to right across pivot 2.5 (mirroredX = 2 * 2.5 - leftX = 5.0 - leftX)
          mirroredSlots.add(TileData(
            type: 0,
            x: _snap(5.0 - leftTile.x),
            y: _snap(leftTile.y),
            layer: leftTile.layer,
            anchor: leftTile.anchor.mirrored,
            gridOffsetX: leftTile.gridOffsetX,
            gridOffsetY: leftTile.gridOffsetY,
            stackOffsetX: 0.0,
            stackOffsetY: 0.0,
          ));
        }
      }
    }
    
    while (mirroredSlots.length > maxTiles || mirroredSlots.length % TileLayoutRules.groupSize != 0) {
      final removables = _findRemovableSlots(mirroredSlots);
      if (removables.isEmpty) break;
      final toRemove = removables[random.nextInt(removables.length)];
      mirroredSlots.removeWhere((t) => t.x == toRemove.x && t.y == toRemove.y && t.layer == toRemove.layer);
    }
    
    return mirroredSlots;
  }

  bool _hasSupport(double tx, double ty, List<TileData> layerBelow) {
    int points = 0;
    for (final b in layerBelow) {
      final dx = (tx - b.x).abs();
      final dy = (ty - b.y).abs();
      // Physical check: a tile must be supported by tiles directly 
      // or partially underneath it in the half-grid system.
      if (dx >= 1.0 || dy >= 1.0) continue;
      if (dx == 0.0 && dy == 0.0) { points += 4; }
      else if (dx == 0.5 && dy == 0.0) { points += 2; }
      else if (dx == 0.0 && dy == 0.5) { points += 2; }
      else if (dx == 0.5 && dy == 0.5) { points += 1; }
    }
    return points >= 2;
  }
  
  List<TileData> _findRemovableSlots(List<TileData> layout) {
    final open = <TileData>[];
    for (int i = 0; i < layout.length; i++) {
        final t = layout[i];
        bool isCovered = false;
        for (int j = 0; j < layout.length; j++) {
            if (i == j) continue;
            final o = layout[j];
            if (o.layer > t.layer) {
                final dx = (t.x - o.x).abs();
                final dy = (t.y - o.y).abs();
                if (dx < 1.0 && dy < 1.0) {
                     isCovered = true;
                     break;
                }
            }
        }
        if (!isCovered) {
            open.add(t);
        }
    }
    return open;
  }

  /// 2. Assignment Phase (Staggered Solvable Algorithm)
  List<TileData> assignTypesBackwards({
    required List<TileData> emptyLayout,
    required LevelDifficultyConfig config,
    required Random random,
    required int levelNumber,
  }) {
    final layout = List<TileData>.from(emptyLayout);
    final clearingSequence = <TileData>[];
    
    // 1. Generate a valid, single-step clearing sequence (Simulation)
    while (layout.isNotEmpty) {
      final openSlots = _findRemovableSlots(layout);
      if (openSlots.isEmpty) break;
      
      openSlots.shuffle(random);
      final picked = openSlots.first;
      clearingSequence.add(picked);
      layout.removeWhere((t) => t.x == picked.x && t.y == picked.y && t.layer == picked.layer);
    }
    
    if (clearingSequence.isEmpty) return const [];

    // 2. Prepare for Staggered Assignment
    final result = List<TileData>.from(emptyLayout);
    final groupSize = TileLayoutRules.groupSize; // Default 3
    final totalGroups = clearingSequence.length ~/ groupSize;
    
    if (totalGroups == 0) return emptyLayout.where((t) => t.type != 0).toList();

    // Determine stagger depth based on levelNumber
    // Higher stagger = tiles of the same type are further apart in the clearing sequence.
    int stagger;
    if (levelNumber < 10) {
      stagger = 1; // Easy: Pairs are close to each other
    } else if (levelNumber < 30) {
      stagger = 2; // Medium: Pairs are slightly separated
    } else {
      stagger = 3; // Hard/Expert: Pairs are deeply separated (requires hand management)
    }

    // Partition the sequence into triplets using a staggered jump approach.
    final unassignedIndices = List<int>.generate(clearingSequence.length, (i) => i);
    final assignedTypes = List<int>.filled(clearingSequence.length, 0);
    final availableTypes = List<int>.generate(config.tileTypes, (i) => i + 1);

    // Create a shuffled copy for sequential picking
    final shuffledTypes = List<int>.from(availableTypes)..shuffle(random);
    int typePointer = 0;

    while (unassignedIndices.length >= groupSize) {
      final type = shuffledTypes[typePointer % shuffledTypes.length];
      typePointer++;
      
      // Start with the first available unassigned index
      final firstIdx = unassignedIndices.removeAt(0);
      assignedTypes[firstIdx] = type;
      
      // Pick next members with a stagger jump to bury them
      for (int k = 1; k < groupSize; k++) {
        // We jump 'stagger' steps in the unassigned list to hide the next part of the set
        int jump = stagger - 1; 
        int pickIdx = jump.clamp(0, unassignedIndices.length - 1);
        final nextIdx = unassignedIndices.removeAt(pickIdx);
        assignedTypes[nextIdx] = type;
      }
    }

    // Fill any remainders (usually zero if total % groupSize == 0)
    for (int idx in unassignedIndices) {
      assignedTypes[idx] = shuffledTypes[typePointer % shuffledTypes.length];
      typePointer++;
    }

    // 3. Re-map types back to the actual TileData results
    for (int i = 0; i < clearingSequence.length; i++) {
      final tile = clearingSequence[i];
      final type = assignedTypes[i];
      
      final indexInOriginal = result.indexWhere((t) => t.x == tile.x && t.y == tile.y && t.layer == tile.layer);
      if (indexInOriginal != -1) {
        result[indexInOriginal] = result[indexInOriginal].copyWith(type: type);
      }
    }
    
    return result.where((t) => t.type != 0).toList();
  }

  double _snap(double value) {
    return (value * 2).round() / 2.0;
  }
}
