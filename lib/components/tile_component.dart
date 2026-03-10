import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:tile_two/game/game_state_controller.dart';

/// Professional Tile Component
/// 
/// Design: Square, rounded corners, white background, soft shadow, centered icon.
class TileComponent extends PositionComponent with TapCallbacks, HasPaint {
  final String type;
  final GameStateController controller;
  final Sprite iconSprite;
  final double tileSize;
  
  // State properties
  bool isBlocked = false;
  bool isSelected = false;

  TileComponent({
    required this.type,
    required this.controller,
    required this.iconSprite,
    required this.tileSize,
    super.position,
    super.priority,
  }) : super(size: Vector2.all(tileSize));

  @override
  Future<void> onLoad() async {
    // Add the icon as a child sprite component, centered
    final icon = SpriteComponent(
      sprite: iconSprite,
      size: Vector2.all(tileSize * 0.55), // Icon occupies 55% of tile (Smaller & Neater)
      position: Vector2.all(tileSize / 2),
      anchor: Anchor.center,
    );
    add(icon);

    // Initial entry animation
    scale = Vector2.zero();
    add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(
          duration: 0.3,
          curve: Curves.easeOutBack,
          startDelay: (priority * 0.02).clamp(0, 0.8),
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, width, height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tileSize * 0.15));
    
    final currentOpacity = opacity;

    // 1. Soft Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha((50 * currentOpacity).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect.shift(const Offset(0, 4)), shadowPaint);

    // 2. White Tile Background
    final bgPaint = Paint()
      ..color = (isBlocked ? const Color(0xFFE0E0E0) : Colors.white)
          .withAlpha((255 * currentOpacity).toInt());
    canvas.drawRRect(rrect, bgPaint);

    // 3. Subtle Inner Border (Optional for professional look)
    final borderPaint = Paint()
      ..color = Colors.black.withAlpha((20 * currentOpacity).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect, borderPaint);

    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isBlocked || isSelected) return;

    // Juice feedback
    add(
      ScaleEffect.to(
        Vector2.all(0.9),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );

    controller.selectTile(this);
  }

  void highlight() {
    add(
      ColorEffect(
        Colors.yellow.withAlpha(120),
        EffectController(duration: 0.5, alternate: true, repeatCount: 2),
        opacityTo: 0.6,
      ),
    );
  }
}
