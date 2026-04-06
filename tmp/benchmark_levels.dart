
import 'dart:math';
import 'package:tile_two/game/level_generator.dart';
import 'package:tile_two/game/tile_layout.dart';

void main() {
  const generator = LevelGenerator(
    columns: TileLayoutRules.boardColumns,
    rows: TileLayoutRules.boardRows,
    maxTileTypes: 30,
  );

  for (int level = 26; level <= 150; level++) {
    final stopwatch = Stopwatch()..start();
    try {
      final layout = generator.generateLevel(level);
      stopwatch.stop();
      print('Level $level: ${layout.tiles.length} tiles, generated in ${stopwatch.elapsedMilliseconds}ms');
      if (stopwatch.elapsedMilliseconds > 100) {
        print('  WARNING: Slow generation at level $level');
      }
    } catch (e, stack) {
      print('Level $level: FAILED with error $e');
      print(stack);
    }
  }
}
