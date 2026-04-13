import 'package:tile_two/game/tile_layout.dart';
import 'package:tile_two/game/level_generator.dart';

void main() {
  final generator = LevelGenerator(columns: 6, rows: 9, maxTileTypes: 64);
  bool hasErrors = false;
  
  for (int level = 1; level <= 150; level++) {
    final layout = generator.generateLevel(level);
    
    final counts = <int, int>{};
    for (var tile in layout.tiles) {
      counts[tile.type] = (counts[tile.type] ?? 0) + 1;
    }
    
    final invalidCounts = counts.entries.where((e) => e.value != 3).toList();
    if (invalidCounts.isNotEmpty) {
      print('Level $level ERROR! Invalid tile grouping found (Not exactly 3 of each type): $invalidCounts');
      hasErrors = true;
    }
  }
  
  if (!hasErrors) {
    print('SUCCESS! ALL 150 LEVELS ARE 100% SECURE.');
    print('No duplicated tile sets were found across all generated configurations.');
    print('Setiap gambar buah hanya muncul tepat 3 kali per papan (1 pasang).');
  }
}
