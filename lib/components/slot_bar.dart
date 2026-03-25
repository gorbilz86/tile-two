import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SlotBarComponent extends PositionComponent {
  final int slotCount;
  double slotSize;
  double spacing;
  bool _warningActive = false;
  double _warningTime = 0;

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

  void setWarningActive(bool active) {
    if (_warningActive == active) {
      return;
    }
    _warningActive = active;
    if (!active) {
      _warningTime = 0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_warningActive) {
      _warningTime += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final pulse = _warningActive
        ? ((0.5 + (0.5 * math.sin(_warningTime * math.pi * 2 * 1.35)))
            .clamp(0, 1)
            .toDouble())
        : 0.0;
    final outerBorderColor = Color.lerp(
      Colors.black.withAlpha(210),
      const Color(0xFFFF3C2E),
      pulse,
    )!;
    final innerBorderColor = Color.lerp(
      Colors.black.withAlpha(75),
      const Color(0xFFFF8A80),
      pulse,
    )!;
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
          ..color = Colors.black.withAlpha(50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.1),
      );
      canvas.drawRRect(
        slotRect,
        Paint()
          ..isAntiAlias = true
          ..color = Colors.black.withAlpha(18),
      );
      canvas.drawRRect(
        slotRect,
        Paint()
          ..isAntiAlias = true
          ..color = outerBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.05,
      );
      canvas.drawRRect(
        slotRect.deflate(1.1),
        Paint()
          ..isAntiAlias = true
          ..color = innerBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.95,
      );
    }
  }
}
