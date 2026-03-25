import 'package:flutter_test/flutter_test.dart';
import 'package:tile_two/components/tile_component.dart';

void main() {
  group('Tile slot visual normalization', () {
    test('layer slot selalu dinormalisasi ke baseline slot', () {
      expect(normalizedSlotVisualLayer(), 0);
    });

    test('offset shadow layer bawah berbeda dari baseline slot', () {
      final baseline = tileShadowOffsetForLayer(normalizedSlotVisualLayer());
      final deepLayer = tileShadowOffsetForLayer(4);
      expect(deepLayer.dx, greaterThan(baseline.dx));
      expect(deepLayer.dy, greaterThan(baseline.dy));
    });

    test('item hasil pindah ke slot memakai offset shadow baseline slot', () {
      final movedToSlotOffset =
          tileShadowOffsetForLayer(normalizedSlotVisualLayer());
      final existingSlotOffset = tileShadowOffsetForLayer(0);
      expect(movedToSlotOffset, existingSlotOffset);
    });
  });
}
