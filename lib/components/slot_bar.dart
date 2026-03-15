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
    for (var i = 0; i < slotCount; i++) {
      final dx = i * (slotSize + spacing);
      final slotRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, 0, slotSize, slotSize),
        Radius.circular(slotSize * 0.22),
      );
      canvas.drawRRect(
        slotRect.shift(const Offset(0, 1.6)),
        Paint()
          ..isAntiAlias = true
          ..color = Colors.black.withAlpha(55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      canvas.drawRRect(
        slotRect,
        Paint()
          ..isAntiAlias = true
          ..color = const Color(0xFF376996),
      );
      canvas.drawRRect(
        slotRect,
        Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withAlpha(78),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(dx, 0, slotSize, slotSize)),
      );
      canvas.drawRRect(
        slotRect,
        Paint()
          ..isAntiAlias = true
          ..color = const Color(0xFFD5E7FF).withAlpha(215)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }
}
