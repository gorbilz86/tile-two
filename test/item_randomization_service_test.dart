import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tile_two/game/item_randomization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ItemRandomizationService', () {
    test('featured drop tidak duplikat dalam window 5 level', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ItemRandomizationService.instance;
      final drops = <String>[];
      for (var level = 1; level <= 40; level++) {
        final result = await service.pickForLevel(
          level: level,
          requestedPoolSize: 8,
        );
        drops.add(result.featuredItem.id);
      }
      for (var i = 5; i < drops.length; i++) {
        final window = drops.sublist(i - 5, i);
        expect(window.contains(drops[i]), isFalse);
      }
    });

    test('simulasi 1000 game menjaga distribusi dan boredom rendah', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ItemRandomizationService.instance;
      final report = await service.runSimulation(games: 1000, seed: 1234);
      expect(report.games, 1000);
      expect(report.rareRate, greaterThan(0.18));
      expect(report.rareRate, lessThan(0.28));
      expect(report.epicRate, greaterThan(0.06));
      expect(report.epicRate, lessThan(0.12));
      expect(report.legendaryRate, greaterThan(0.015));
      expect(report.legendaryRate, lessThan(0.04));
      expect(report.boredomRate, lessThan(0.05));
      expect(report.boredomBelowFivePercent, isTrue);
    });
  });
}
