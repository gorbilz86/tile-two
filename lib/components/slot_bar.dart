import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SlotBarComponent extends PositionComponent {
  final int slotCount;
  double slotSize;
  double spacing;

  SlotBarComponent({
    this.slotCount = 7,
    required this.slotSize,
    required this.spacing,
  }) : super(anchor: Anchor.topLeft);

  void updateLayout({
    required Vector2 topLeft,
    required double newSlotSize,
    required double newSpacing,
  }) {
    slotSize = newSlotSize;
    spacing = newSpacing;
    position = topLeft;
    size = Vector2(
      (slotCount * slotSize) + ((slotCount - 1) * spacing),
      slotSize,
    );
  }

  Vector2 slotTopLeft(int index) {
    return Vector2(
      position.x + (index * (slotSize + spacing)),
      position.y,
    );
  }

  @override
  void render(Canvas canvas) {
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-12, -10, size.x + 24, size.y + 20),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.black.withAlpha(130),
    );
    for (var i = 0; i < slotCount; i++) {
      final dx = i * (slotSize + spacing);
      final slotRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, 0, slotSize, slotSize),
        Radius.circular(slotSize * 0.2),
      );
      canvas.drawRRect(
        slotRect,
        Paint()..color = Colors.white.withAlpha(28),
      );
      canvas.drawRRect(
        slotRect,
        Paint()
          ..color = Colors.white.withAlpha(55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
  }
}
