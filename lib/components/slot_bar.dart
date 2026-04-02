import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SlotBarComponent extends PositionComponent {
  final int slotCount;
  double slotSize;
  double spacing;
  bool _warningActive = false;
  double _warningTime = 0;
  static const double innerPaddingRatio = 0.095;


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
    // Exact position of the inner "hole" top-left corner
    final padding = slotSize * innerPaddingRatio;
    return Vector2(
      position.x + padding + (index * (slotSize + spacing)),
      position.y + padding,
    );
  }

  double get innerSize => slotSize * (1.0 - (2.0 * innerPaddingRatio));


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

    const Color activeBaseColor = Color(0xFF3B9FFF);
    const Color warningBaseColor = Color(0xFFFF3C2E);
    final Color currentBaseColor = Color.lerp(activeBaseColor, warningBaseColor, pulse)!;

    for (var i = 0; i < slotCount; i++) {
       final dx = i * (slotSize + spacing);
       final slotRect = Rect.fromLTWH(dx, 0, slotSize, slotSize);
       final slotRRect = RRect.fromRectAndRadius(
         slotRect,
         Radius.circular(slotSize * 0.22),
       );

       // 1. External Shadow (Gives the slot frame some elevation)
       canvas.drawRRect(
         slotRRect.shift(const Offset(0, 1.8)),
         Paint()
           ..isAntiAlias = true
           ..color = Colors.black.withAlpha(35)
           ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.8),
       );

       // 2. 3D Frame Base (The sides of the slot box)
       final framePaint = Paint()
         ..isAntiAlias = true
         ..color = currentBaseColor.withAlpha(240);
       
       const Color activeBottomEdge = Color(0xFF247CC4);
       const Color warningBottomEdge = Color(0xFFC42424);
       final Color currentBottomEdge = Color.lerp(activeBottomEdge, warningBottomEdge, pulse)!;

       final bottomEdgePaint = Paint()
         ..isAntiAlias = true
         ..color = currentBottomEdge;

       // Draw base thickness (3D side)
       canvas.drawRRect(slotRRect, bottomEdgePaint);
       canvas.drawRRect(
         RRect.fromRectAndRadius(
           Rect.fromLTWH(dx, 0, slotSize, slotSize - 3.2),
           Radius.circular(slotSize * 0.22),
         ),
         framePaint,
       );

       // 3. Top Face of the Frame (The shiny surface)
       final borderThickness = slotSize * innerPaddingRatio;
       final innerRect = slotRect.deflate(borderThickness);
       final innerRRect = RRect.fromRectAndRadius(
         innerRect,
         Radius.circular(slotSize * 0.16),
       );

       final topFacePaint = Paint()
         ..isAntiAlias = true
         ..shader = LinearGradient(
           begin: Alignment.topCenter,
           end: Alignment.bottomCenter,
           colors: [
             Colors.white.withAlpha(225),
             const Color(0xFFE3F2FD).withAlpha(200),
           ],
         ).createShader(slotRect);

       // Draw the frame top using path subtraction (keeps center transparent)
       canvas.save();
       final framePath = Path()
         ..addRRect(RRect.fromRectAndRadius(
           Rect.fromLTWH(dx, 0, slotSize, slotSize - 4.5), 
           Radius.circular(slotSize * 0.22)))
         ..addRRect(innerRRect)
         ..fillType = PathFillType.evenOdd;
       
       canvas.drawPath(framePath, topFacePaint);
       
       // 4. Specular Highlight (Glint)
       final glintPaint = Paint()
         ..isAntiAlias = true
         ..color = Colors.white.withAlpha(160)
         ..style = PaintingStyle.stroke
         ..strokeWidth = 1.1;
       
       canvas.drawPath(
         Path()
           ..moveTo(dx + slotSize * 0.25, 1.2)
           ..lineTo(dx + slotSize * 0.75, 1.2),
         glintPaint,
       );

       // 5. Inner "Hole" depth shadow (reveals background but adds depth)
       final holeDepthPaint = Paint()
         ..isAntiAlias = true
         ..color = Colors.black.withAlpha(65)
         ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8);
       
       canvas.clipRRect(innerRRect);
       canvas.drawRRect(innerRRect.shift(const Offset(0, 1.8)), holeDepthPaint);
       
       canvas.restore();

       // 6. Polished outer border line
       final outerBorderPaint = Paint()
         ..isAntiAlias = true
         ..color = const Color(0xFF1E5BB1).withAlpha(50)
         ..style = PaintingStyle.stroke
         ..strokeWidth = 0.9;
       canvas.drawRRect(
         RRect.fromRectAndRadius(
           Rect.fromLTWH(dx, 0, slotSize, slotSize - 4.5), 
           Radius.circular(slotSize * 0.22)), 
         outerBorderPaint);
    }
  }
}
