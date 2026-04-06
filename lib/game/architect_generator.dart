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
    final centerLineX = (columns - 1) / 2.0;

    for (int layer = 0; layer < config.layers; layer++) {
      slotsByLayer[layer] = [];
      final layerTargetLeft = (maxTiles / 2 / config.layers).ceil();
      
      final candidates = <(double, double)>[];
      for (double x = 0.0; x <= centerLineX; x += 0.5) {
        for (double y = 0.0; y < rows; y += 0.5) {
          if (layer == 0) {
            final dx = x - centerLineX;
            final dy = y - (rows - 1) / 2;
            final dist = sqrt(dx * dx + dy * dy);
            if (dist < 4.0 || random.nextDouble() > 0.3) {
              candidates.add((x, y));
            }
          } else {
            if (_hasSupport(x, y, slotsByLayer[layer - 1]!)) {
              candidates.add((x, y));
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
            x: candidate.$1,
            y: candidate.$2,
            layer: layer,
            anchor: leftAnchor,
            gridOffsetX: 0,
            gridOffsetY: 0,
            stackOffsetX: _stackJitter(levelNumber: levelNumber, layer: layer, random: random),
            stackOffsetY: _stackJitter(levelNumber: levelNumber + 7, layer: layer, random: random),
          ));
          placedLeft++;
        }
      }
    }
    
    final mirroredSlots = <TileData>[];
    for (final layer in slotsByLayer.values) {
      for (final leftTile in layer) {
        mirroredSlots.add(leftTile);
        if (leftTile.x < centerLineX) {
          // Mirror to right
          mirroredSlots.add(TileData(
            type: 0,
            x: (columns - 1) - leftTile.x,
            y: leftTile.y,
            layer: leftTile.layer,
            anchor: leftTile.anchor.mirrored,
            gridOffsetX: leftTile.gridOffsetX,
            gridOffsetY: leftTile.gridOffsetY,
            stackOffsetX: -leftTile.stackOffsetX,
            stackOffsetY: leftTile.stackOffsetY,
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

  double _stackJitter({
    required int levelNumber,
    required int layer,
    required Random random,
  }) {
    if (layer == 0 || levelNumber < 5) return 0.0;
    return (random.nextDouble() - 0.5) * 2.0;
  }
}
