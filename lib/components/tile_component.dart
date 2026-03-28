import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

int normalizedSlotVisualLayer() {
  return 0;
}

Offset tileShadowOffsetForLayer(int layer) {
  return Offset(3 + (layer * 0.3), 3 + (layer * 0.2));
}

class TileComponent extends PositionComponent with TapCallbacks, HasPaint {
  static const double _iconScale = 0.76;
  static const double _baseThicknessRatio = 0.12;
  final String type;
  final Sprite sprite;
  final Future<void> Function(TileComponent tile) onTapTile;
  int row;
  int column;
  double tileSize;
  int layer;
  final double gridOffsetX;
  final double gridOffsetY;
  final double stackOffsetX;
  final double stackOffsetY;
  bool isTapEnabled;
  bool isInTransit = false;
  bool _isCoveredByHigher = false;
  double _hintRemaining = 0;
  SpriteComponent? _icon;

  TileComponent({
    required this.type,
    required this.sprite,
    required this.onTapTile,
    required this.row,
    required this.column,
    required this.layer,
    required this.tileSize,
    this.gridOffsetX = 0,
    this.gridOffsetY = 0,
    this.stackOffsetX = 0,
    this.stackOffsetY = 0,
    required Vector2 position,
    required int priority,
    this.isTapEnabled = false,
  }) : super(
          position: position,
          priority: priority,
          size: Vector2.all(tileSize),
          anchor: Anchor.topLeft,
        );

  @override
  Future<void> onLoad() async {
    final icon = SpriteComponent(
      sprite: sprite,
      size: Vector2.all(tileSize * _iconScale),
      position: size / 2,
      anchor: Anchor.center,
    );
    _icon = icon;
    _syncDepthVisuals();
    add(icon);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hintRemaining > 0) {
      _hintRemaining -= dt;
      if (_hintRemaining < 0) {
        _hintRemaining = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final depthLevel = layer.clamp(0, 5).toDouble();
    final topness = (depthLevel / 5).clamp(0, 1).toDouble();
    
    // 1. Overall Shadow (Drop Shadow on Board)
    final shadowOffset = tileShadowOffsetForLayer(layer);
    final shadowRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(tileSize * 0.22),
    );
    final elevationShadow = Paint()
      ..isAntiAlias = true
      ..color = Colors.black.withAlpha(((105 - (topness * 30)) * opacity).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.5);
    canvas.drawRRect(shadowRRect.shift(shadowOffset), elevationShadow);

    // 2. 3D Side/Base (The thick part)
    final baseThickness = tileSize * _baseThicknessRatio;
    final baseRect = Rect.fromLTWH(0, 0, width, height);
    final baseRRect = RRect.fromRectAndRadius(
      baseRect,
      Radius.circular(tileSize * 0.22),
    );

    // Dynamic colors based on locked state
    const Color activeBaseColor = Color(0xFF3B9FFF);
    const Color lockedBaseColor = Color(0xFF8B9BB4);
    const Color activeBottomEdge = Color(0xFF247CC4);
    const Color lockedBottomEdge = Color(0xFF6C7C96);

    final basePaint = Paint()
      ..isAntiAlias = true
      ..color = (_isCoveredByHigher ? lockedBaseColor : activeBaseColor)
          .withAlpha((255 * opacity).toInt());
    
    // Darker bottom edge for depth
    final bottomEdgePaint = Paint()
      ..isAntiAlias = true
      ..color = (_isCoveredByHigher ? lockedBottomEdge : activeBottomEdge)
          .withAlpha((255 * opacity).toInt());

    canvas.drawRRect(baseRRect, bottomEdgePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height - (baseThickness * 0.4)),
        Radius.circular(tileSize * 0.22),
      ),
      basePaint,
    );

    // 3. Top Face (The white/light-blue part)
    final topFaceInset = tileSize * 0.02;
    final topFaceRect = Rect.fromLTWH(
      topFaceInset,
      topFaceInset,
      width - (topFaceInset * 2),
      height - baseThickness,
    );
    final topFaceRRect = RRect.fromRectAndRadius(
      topFaceRect,
      Radius.circular(tileSize * 0.18),
    );

    const Color topFaceStartActive = Color(0xFFFFFFFF);
    const Color topFaceEndActive = Color(0xFFF0F8FF);
    const Color topFaceStartLocked = Color(0xFFBCC6D5);
    const Color topFaceEndLocked = Color(0xFFAAB5C5);

    final Color topFaceStart = _isCoveredByHigher ? topFaceStartLocked : topFaceStartActive;
    final Color topFaceEnd = _isCoveredByHigher ? topFaceEndLocked : topFaceEndActive;

    final topFacePaint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          topFaceStart.withAlpha((255 * opacity).toInt()),
          topFaceEnd.withAlpha((255 * opacity).toInt()),
        ],
      ).createShader(topFaceRect);

    canvas.drawRRect(topFaceRRect, topFacePaint);

    // 4. Subtle Top Edge Highlight (Glint) - only for active tiles
    if (!_isCoveredByHigher) {
      final highlightPaint = Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withAlpha((140 * opacity).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      
      canvas.drawPath(
        Path()
          ..moveTo(topFaceInset + tileSize * 0.16, topFaceInset + 1.2)
          ..lineTo(width - topFaceInset - tileSize * 0.16, topFaceInset + 1.2),
        highlightPaint,
      );
    }

    // 5. Hint Glow (if enabled)
    if (_hintRemaining > 0) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFF176).withAlpha(125)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.5);
      canvas.drawRRect(baseRRect.inflate(4.5), glowPaint);
    }

    // 6. Extra "Locked" Overlay for lower layers/covered tiles
    if (_isCoveredByHigher) {
      final lockOverlay = Paint()
        ..isAntiAlias = true
        ..color = const Color(0xFF1E2E4A).withAlpha((54 * opacity).toInt());
      canvas.drawRRect(baseRRect, lockOverlay);
      
      // Grayish darkening of the icon area
      final iconDarken = Paint()
        ..isAntiAlias = true
        ..color = Colors.black.withAlpha((24 * opacity).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRRect(topFaceRRect, iconDarken);
    } else if (!isTapEnabled && layer > 0) {
      // Just a subtle darkening for non-covered but also non-top tiles if applicable
      // (Usually handled by _isCoveredByHigher in BoardComponent)
    }

    // 7. Borders
    final outerBorderPaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFF1E5BB1).withAlpha((75 * opacity).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;
    canvas.drawRRect(baseRRect, outerBorderPaint);

    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isTapEnabled || isInTransit) {
      return;
    }
    onTapTile(this);
  }

  void relayout({
    required double newTileSize,
    required Vector2 newTopLeft,
    required int newPriority,
  }) {
    tileSize = newTileSize;
    size.setValues(tileSize, tileSize);
    position = newTopLeft;
    priority = newPriority;
    _icon?.size.setValues(tileSize * _iconScale, tileSize * _iconScale);
    _icon?.position = size / 2;
  }

  void setGridPosition({
    required int newRow,
    required int newColumn,
    required int newLayer,
    required int newPriority,
  }) {
    row = newRow;
    column = newColumn;
    layer = newLayer;
    priority = newPriority;
    _syncDepthVisuals();
  }

  void setLayer(int newLayer) {
    layer = newLayer;
    _syncDepthVisuals();
  }

  void setTapEnabled(bool value) {
    isTapEnabled = value;
  }

  void setCoveredByHigher(bool value) {
    _isCoveredByHigher = value;
    if (_isCoveredByHigher) {
      _icon?.opacity = 0.54;
      return;
    }
    _syncDepthVisuals();
  }

  void highlightForSeconds(double seconds) {
    _hintRemaining = seconds;
  }

  void prepareForSlotVisual() {
    setCoveredByHigher(false);
    setLayer(normalizedSlotVisualLayer());
  }

  void _syncDepthVisuals() {
    final depthLevel = layer.clamp(0, 5).toDouble();
    final topness = (depthLevel / 5).clamp(0, 1).toDouble();
    _icon?.opacity = (0.92 + (topness * 0.08)).clamp(0, 1).toDouble();
  }
}
