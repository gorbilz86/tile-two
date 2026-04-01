import 'package:flutter/material.dart';

enum BoosterType {
  undo,
  shuffle,
  hint,
}

class Booster3DIcon extends StatelessWidget {
  final BoosterType type;
  final double size;
  final bool isUnlocked;
  final double depthFactor;

  const Booster3DIcon({
    super.key,
    required this.type,
    this.size = 32.0,
    this.isUnlocked = true,
    this.depthFactor = 0.067, // 3.5 / 52.0 approx
  });

  @override
  Widget build(BuildContext context) {
    final IconData iconData;
    final Color baseColor;
    final Color topFaceStart;
    final Color topFaceEnd;
    final Color glintColor = Colors.white.withAlpha(isUnlocked ? 140 : 80);

    if (!isUnlocked) {
      iconData = _getIconData();
      baseColor = const Color(0xFF6C7C96);
      topFaceStart = const Color(0xFFBCC6D5);
      topFaceEnd = const Color(0xFFAAB5C5);
    } else {
      switch (type) {
        case BoosterType.undo:
          iconData = Icons.undo_rounded;
          baseColor = const Color(0xFF880E4F); // Deep Pink
          topFaceStart = const Color(0xFFEC407A);
          topFaceEnd = const Color(0xFFD81B60);
          break;
        case BoosterType.shuffle:
          iconData = Icons.shuffle_rounded;
          baseColor = const Color(0xFF1B5E20); // Deep Green
          topFaceStart = const Color(0xFF81C784);
          topFaceEnd = const Color(0xFF43A047);
          break;
        case BoosterType.hint:
          iconData = Icons.lightbulb_rounded;
          baseColor = const Color(0xFFE65100); // Deep Orange
          topFaceStart = const Color(0xFFFFD54F);
          topFaceEnd = const Color(0xFFFFA000);
          break;
      }
    }

    final double depthOffset = size * depthFactor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Shadow
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: size * 0.15,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
        ),

        // 2. 3D Base
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.32),
            color: baseColor,
            border: Border.all(
              color: Colors.black.withAlpha(30),
              width: 0.8,
            ),
          ),
        ),

        // 3. Top Face
        Container(
          width: size,
          height: size - depthOffset,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topFaceStart, topFaceEnd],
            ),
            border: Border.all(
              color: Colors.white.withAlpha(isUnlocked ? 40 : 15),
              width: 0.6,
            ),
          ),
          child: Center(
            child: Icon(
              iconData,
              size: size * 0.42,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),

        // 4. Glossy Glint
        Positioned(
          top: size * 0.04,
          left: size * 0.22,
          right: size * 0.22,
          child: Container(
            height: size * 0.02,
            decoration: BoxDecoration(
              color: glintColor,
              borderRadius: BorderRadius.circular(0.5),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconData() {
    switch (type) {
      case BoosterType.undo:
        return Icons.undo_rounded;
      case BoosterType.shuffle:
        return Icons.shuffle_rounded;
      case BoosterType.hint:
        return Icons.lightbulb_rounded;
    }
  }
}
