import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class TileComponent extends PositionComponent with TapCallbacks, HasPaint {
  final String type;
  final Sprite sprite;
  final Future<void> Function(TileComponent tile) onTapTile;
  int row;
  int column;
  double tileSize;
  int layer;
  bool isTapEnabled;
  bool isInTransit = false;
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
      size: Vector2.all(tileSize * 0.5),
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
    final depthLevel = layer.clamp(0, 3).toDouble();
    final topness = (depthLevel / 3).clamp(0, 1).toDouble();
    final rect = Rect.fromLTWH(0, 0, width, height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tileSize * 0.16));
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha((((72 - (topness * 20)) * opacity)).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5);
    canvas.drawRRect(rrect.shift(Offset(0, 2.2 + ((1 - topness) * 1.4))), shadowPaint);
    final baseColor = isTapEnabled ? const Color(0xFFFFFFFF) : const Color(0xFFEAEAEA);
    final shadedColor = Color.lerp(
      baseColor.withAlpha(220),
      baseColor,
      topness,
    )!;
    final bgPaint = Paint()
      ..color = shadedColor.withAlpha((255 * opacity).toInt());
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withAlpha((46 + (topness * 26).toInt())),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    if (_hintRemaining > 0) {
      final glow = Paint()
        ..color = const Color(0xFFF9E26B).withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawRRect(rrect.inflate(4), glow);
    }
    final borderPaint = Paint()
      ..color = Colors.black.withAlpha(((20 + ((1 - topness) * 12)) * opacity).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rrect, borderPaint);
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
    _icon?.size.setValues(tileSize * 0.5, tileSize * 0.5);
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

  void highlightForSeconds(double seconds) {
    _hintRemaining = seconds;
  }

  void _syncDepthVisuals() {
    final depthLevel = layer.clamp(0, 3).toDouble();
    final topness = (depthLevel / 3).clamp(0, 1).toDouble();
    _icon?.opacity = 0.82 + (topness * 0.18);
  }
}
