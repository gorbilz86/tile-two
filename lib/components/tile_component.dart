import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

int normalizedSlotVisualLayer() {
  return 0;
}

Offset tileShadowOffsetForLayer(int layer) {
  return const Offset(4, 4);
}

class TileComponent extends PositionComponent with TapCallbacks, HasPaint {
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
  static const double _iconScale = 0.72;
  static const double _baseThicknessRatio = 0.22;

  // Caching for 60 FPS Performance
  bool _needsVisualsUpdate = true;
  late final Paint _paintShadow;
  late final Paint _paintBase;
  late final Paint _paintBottomEdge;
  late final Paint _paintFace;
  late final Paint _paintGlint;
  late final Paint _paintGlow;
  late final Paint _paintLockOverlay;
  late final Paint _paintIconDarken;
  late final Paint _paintBorder;
  RRect? _rrectShadow;
  RRect? _rrectBase;
  RRect? _rrectFace;
  RRect? _rrectGlow;
  Path? _pathGlint;

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
        ) {
    _initCaches();
  }

  void _initCaches() {
    _paintShadow = Paint()..isAntiAlias = true;
    _paintBase = Paint()..isAntiAlias = true;
    _paintBottomEdge = Paint()..isAntiAlias = true;
    _paintFace = Paint()..isAntiAlias = true;
    _paintGlint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    _paintGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.5);
    _paintLockOverlay = Paint()..isAntiAlias = true;
    _paintIconDarken = Paint()..isAntiAlias = true..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    _paintBorder = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95;
  }

  void _updateVisualsCache() {
    if (!_needsVisualsUpdate) return;

    final baseThickness = tileSize * _baseThicknessRatio;
    final radius = tileSize * 0.22;
    final topFaceInset = tileSize * 0.022;

    _rrectShadow = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(radius),
    );

    _rrectBase = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(radius),
    );

    _rrectFace = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        topFaceInset,
        topFaceInset,
        width - (topFaceInset * 2),
        height - baseThickness,
      ),
      Radius.circular(tileSize * 0.18),
    );

    _rrectGlow = _rrectBase!.inflate(4.8);

    _pathGlint = Path()
      ..moveTo(topFaceInset + tileSize * 0.16, topFaceInset + 1.3)
      ..lineTo(width - topFaceInset - tileSize * 0.16, topFaceInset + 1.3);

    // Color Setup - Blue 3D Theme from image
    const Color activeBaseColor = Color(0xFF409BFF); // Vibrant Blue Body
    const Color lockedBaseColor = Color(0xFFC1CAD8);
    const Color activeBottomEdge = Color(0xFF1E60E2); // Dark Blue Depth
    const Color lockedBottomEdge = Color(0xFFA8B2C0);
    
    _paintBase.color = (_isCoveredByHigher ? lockedBaseColor : activeBaseColor);
    _paintBottomEdge.color = (_isCoveredByHigher ? lockedBottomEdge : activeBottomEdge);
    
    final faceRect = _rrectFace!.outerRect;
    _paintFace.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: _isCoveredByHigher 
        ? [const Color(0xFFBCC6D5), const Color(0xFFAAB5C5)]
        : [const Color(0xFFFBFCFF), const Color(0xFFF1F5F9)], // Bright White/Light Face
    ).createShader(faceRect);

    _paintShadow.color = const Color(0xFF8ED1FF).withValues(alpha: 0.65);
    _paintShadow.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    _paintGlint.color = Colors.white.withAlpha(165);
    _paintGlint.strokeWidth = 1.35;
    _paintLockOverlay.color = const Color(0xFF1E2E4A).withAlpha(58);
    _paintIconDarken.color = Colors.black.withAlpha(24);
    _paintBorder.color = const Color(0xFF123E84).withAlpha(82);

    _needsVisualsUpdate = false;
  }

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
    if (_needsVisualsUpdate) {
      _updateVisualsCache();
    }

    final alpha = (255 * opacity).toInt();
    final shadowOffset = tileShadowOffsetForLayer(layer);

    // 1. Shadow
    _paintShadow.color = _paintShadow.color.withAlpha((94 * opacity).toInt());
    canvas.drawRRect(_rrectShadow!.shift(shadowOffset), _paintShadow);

    // 2. 3D Body
    _paintBottomEdge.color = _paintBottomEdge.color.withAlpha(alpha);
    canvas.drawRRect(_rrectBase!, _paintBottomEdge);

    final baseThickness = tileSize * _baseThicknessRatio;
    _paintBase.color = _paintBase.color.withAlpha(alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height - (baseThickness * 0.35)),
        Radius.circular(tileSize * 0.22),
      ),
      _paintBase,
    );

    // 3. Face Cap
    canvas.drawRRect(_rrectFace!, _paintFace);

    // 4. Glint
    if (!_isCoveredByHigher) {
      _paintGlint.color = _paintGlint.color.withAlpha((160 * opacity).toInt());
      canvas.drawPath(_pathGlint!, _paintGlint);
    }

    // 5. Glow
    if (_hintRemaining > 0) {
      _paintGlow.color = const Color(0xFFFFF176).withAlpha((125 * opacity).toInt());
      canvas.drawRRect(_rrectGlow!, _paintGlow);
    }

    // 6. Overlays
    if (_isCoveredByHigher) {
      _paintLockOverlay.color = _paintLockOverlay.color.withAlpha((60 * opacity).toInt());
      canvas.drawRRect(_rrectBase!, _paintLockOverlay);
      
      _paintIconDarken.color = _paintIconDarken.color.withAlpha((28 * opacity).toInt());
      canvas.drawRRect(_rrectFace!, _paintIconDarken);
    }

    // 7. Border
    _paintBorder.color = _paintBorder.color.withAlpha((85 * opacity).toInt());
    canvas.drawRRect(_rrectBase!, _paintBorder);

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
    if (tileSize != newTileSize) {
      tileSize = newTileSize;
      _needsVisualsUpdate = true;
    }
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
    if (_isCoveredByHigher != value) {
      _isCoveredByHigher = value;
      _needsVisualsUpdate = true;
      if (_isCoveredByHigher) {
        _icon?.opacity = 0.52;
      } else {
        _syncDepthVisuals();
      }
    }
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
