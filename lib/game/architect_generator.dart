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

  /// 2. Assignment Phase (100% Solvable Backwards Algorithm)
  List<TileData> assignTypesBackwards({
    required List<TileData> emptyLayout,
    required LevelDifficultyConfig config,
    required Random random,
  }) {
    final layout = List<TileData>.from(emptyLayout);
    final result = List<TileData>.filled(layout.length, layout.first);
    final maxTypes = config.tileTypes;
    final groupSize = TileLayoutRules.groupSize;
    
    while (layout.isNotEmpty) {
      if (layout.length < groupSize) break;
      
      final openSlots = _findRemovableSlots(layout);
      if (openSlots.length < groupSize) break;
      
      openSlots.shuffle(random);
      final picked = openSlots.sublist(0, groupSize);
      
      final assignedType = random.nextInt(maxTypes) + 1;
      
      for (final p in picked) {
         final indexInOriginal = emptyLayout.indexWhere((t) => t.x == p.x && t.y == p.y && t.layer == p.layer);
         if (indexInOriginal != -1) {
           result[indexInOriginal] = emptyLayout[indexInOriginal].copyWith(type: assignedType);
         }
         layout.removeWhere((t) => t.x == p.x && t.y == p.y && t.layer == p.layer);
      }
    }
    
    return result.where((t) => t.type != 0).toList();
  }

  double _snap(double value) {
    return (value * 2).round() / 2.0;
  }
}
