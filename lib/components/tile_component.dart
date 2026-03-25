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
  static const double _iconScale = 0.82;
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
    final lowerLayerOpacity = 0.82 + (topness * 0.18);
    final rect = Rect.fromLTWH(0, 0, width, height);
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(tileSize * 0.2));
    final edgeInset = tileSize * 0.045;
    final innerRect = Rect.fromLTWH(
      edgeInset,
      edgeInset,
      width - (edgeInset * 2),
      height - (edgeInset * 2),
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(tileSize * 0.16),
    );
    final shadowOffset = tileShadowOffsetForLayer(layer);
    final deepShadow = Paint()
      ..isAntiAlias = true
      ..color =
          Colors.black.withAlpha(((110 - (topness * 28)) * opacity).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.2);
    canvas.drawRRect(rrect.shift(shadowOffset), deepShadow);
    final closeShadow = Paint()
      ..isAntiAlias = true
      ..color = Colors.black.withAlpha(((36 - (topness * 9)) * opacity).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    canvas.drawRRect(rrect.shift(const Offset(0, 1.0)), closeShadow);
    const lowerLayerColor = Color(0xFFCFD7EB);
    final upperLayerColor =
        isTapEnabled ? const Color(0xFFFFFFFF) : const Color(0xFFE8EDF8);
    final shadedColor = Color.lerp(lowerLayerColor, upperLayerColor, topness)!;
    final bgPaint = Paint()
      ..isAntiAlias = true
      ..color =
          shadedColor.withAlpha((255 * opacity * lowerLayerOpacity).toInt());
    canvas.drawRRect(rrect, bgPaint);
    final innerPaint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha((245 * opacity).toInt()),
          const Color(0xFFE6ECF7).withAlpha((240 * opacity).toInt()),
        ],
      ).createShader(innerRect);
    canvas.drawRRect(innerRRect, innerPaint);
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withAlpha((66 + (topness * 24).toInt())),
            Colors.transparent,
          ],
        ).createShader(innerRect),
    );
    if (_hintRemaining > 0) {
      final glow = Paint()
        ..color = const Color(0xFFF9E26B).withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawRRect(rrect.inflate(4), glow);
    }
    if (_isCoveredByHigher) {
      canvas.drawRRect(
        innerRRect,
        Paint()
          ..isAntiAlias = true
          ..color = Colors.black.withAlpha((66 * opacity).toInt()),
      );
    }
    final borderPaint = Paint()
      ..isAntiAlias = true
      ..color = Color.lerp(
        const Color(0xFF4E5E87),
        const Color(0xFFAFC0E2),
        topness,
      )!
          .withAlpha((230 * opacity).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45;
    canvas.drawRRect(rrect, borderPaint);
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..isAntiAlias = true
        ..color = const Color(0xFF93A4C6).withAlpha((145 * opacity).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
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
      _icon?.opacity = 0.62;
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
    _icon?.opacity = 0.8 + (topness * 0.2);
  }
}
