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

  // Caching variables for rendering optimization (60 FPS)
  final Paint _shadowPaint = Paint()
    ..isAntiAlias = true
    ..color = Colors.black.withAlpha(35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.8);
    
  final Paint _framePaint = Paint()..isAntiAlias = true;
  final Paint _bottomEdgePaint = Paint()..isAntiAlias = true;
  final Paint _topFacePaint = Paint()..isAntiAlias = true;
  
  final Paint _glintPaint = Paint()
    ..isAntiAlias = true
    ..color = Colors.white.withAlpha(160)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  final Paint _holeDepthPaint = Paint()
    ..isAntiAlias = true
    ..color = Colors.black.withAlpha(65)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8);

  final Paint _outerBorderPaint = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFF1E5BB1).withAlpha(50)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;

  RRect? _slotRRect;
  RRect? _slotRRectShifted;
  RRect? _frameRect;
  RRect? _innerRRect;
  RRect? _innerRRectShifted;
  RRect? _outerBorderRRect;
  Path? _framePath;
  Path? _glintPath;

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
    
    _buildRenderCache();
  }

  void _buildRenderCache() {
    final slotRect = Rect.fromLTWH(0, 0, slotSize, slotSize);
    _slotRRect = RRect.fromRectAndRadius(slotRect, Radius.circular(slotSize * 0.22));
    _slotRRectShifted = _slotRRect!.shift(const Offset(0, 1.8));

    _frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, slotSize, slotSize - 3.2),
      Radius.circular(slotSize * 0.22),
    );

    final borderThickness = slotSize * innerPaddingRatio;
    final innerRect = slotRect.deflate(borderThickness);
    _innerRRect = RRect.fromRectAndRadius(innerRect, Radius.circular(slotSize * 0.16));
    _innerRRectShifted = _innerRRect!.shift(const Offset(0, 1.8));

    _topFacePaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withAlpha(225),
        const Color(0xFFE3F2FD).withAlpha(200),
      ],
    ).createShader(slotRect);

    _outerBorderRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, slotSize, slotSize - 4.5), 
      Radius.circular(slotSize * 0.22),
    );

    _framePath = Path()
      ..addRRect(_outerBorderRRect!)
      ..addRRect(_innerRRect!)
      ..fillType = PathFillType.evenOdd;

    _glintPath = Path()
      ..moveTo(slotSize * 0.25, 1.2)
      ..lineTo(slotSize * 0.75, 1.2);
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
    if (_slotRRect == null) return;

    final pulse = _warningActive
        ? ((0.5 + (0.5 * math.sin(_warningTime * math.pi * 2 * 1.35)))
            .clamp(0, 1)
            .toDouble())
        : 0.0;

    const Color activeBaseColor = Color(0xFF3B9FFF);
    const Color warningBaseColor = Color(0xFFFF3C2E);
    final Color currentBaseColor = Color.lerp(activeBaseColor, warningBaseColor, pulse)!;

    const Color activeBottomEdge = Color(0xFF247CC4);
    const Color warningBottomEdge = Color(0xFFC42424);
    final Color currentBottomEdge = Color.lerp(activeBottomEdge, warningBottomEdge, pulse)!;

    _framePaint.color = currentBaseColor.withAlpha(240);
    _bottomEdgePaint.color = currentBottomEdge;

    for (var i = 0; i < slotCount; i++) {
       final dx = i * (slotSize + spacing);
       
       canvas.save();
       canvas.translate(dx, 0);

       // 1. External Shadow
       canvas.drawRRect(_slotRRectShifted!, _shadowPaint);

       // 2. 3D Frame Base
       canvas.drawRRect(_slotRRect!, _bottomEdgePaint);
       canvas.drawRRect(_frameRect!, _framePaint);

       // 3. Inner Hole & Top Face
       canvas.save();
       canvas.drawPath(_framePath!, _topFacePaint);
       
       // 4. Glint
       canvas.drawPath(_glintPath!, _glintPaint);

       // 5. Hole Depth Shadow
       canvas.clipRRect(_innerRRect!);
       canvas.drawRRect(_innerRRectShifted!, _holeDepthPaint);
       canvas.restore();

       // 6. Polished outer border line
       canvas.drawRRect(_outerBorderRRect!, _outerBorderPaint);
       
       canvas.restore();
    }
  }
}
