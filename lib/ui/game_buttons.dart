import 'package:flutter/material.dart';
import 'package:tile_two/ui/google_fonts_proxy.dart';

enum BoosterBadgeMode {
  locked,
  stock,
  price,
}

BoosterBadgeMode resolveBoosterBadgeMode({
  required bool isUnlocked,
  required int stock,
}) {
  if (!isUnlocked) {
    return BoosterBadgeMode.locked;
  }
  if (stock > 0) {
    return BoosterBadgeMode.stock;
  }
  return BoosterBadgeMode.price;
}

class GameButtons extends StatelessWidget {
  final VoidCallback onUndo;
  final VoidCallback onShuffle;
  final VoidCallback onHint;
  final int undoStock;
  final int shuffleStock;
  final int hintStock;
  final bool shuffleUnlocked;
  final bool hintUnlocked;
  final int shuffleUnlockLevel;
  final int hintUnlockLevel;
  final String levelShortLabel;

  const GameButtons({
    super.key,
    required this.onUndo,
    required this.onShuffle,
    required this.onHint,
    required this.undoStock,
    required this.shuffleStock,
    required this.hintStock,
    required this.shuffleUnlocked,
    required this.hintUnlocked,
    required this.shuffleUnlockLevel,
    required this.hintUnlockLevel,
    this.levelShortLabel = 'Lv',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          iconData: Icons.undo_rounded,
          onTap: onUndo,
          buttonSize: 52,
          iconSize: 22,
          price: 45,
          isUnlocked: true,
          stock: undoStock,
          unlockLevel: 1,
        ),
        const SizedBox(width: 20),
        _buildActionButton(
          iconData: Icons.shuffle_rounded,
          onTap: onShuffle,
          buttonSize: 56,
          iconSize: 24,
          price: 55,
          isUnlocked: shuffleUnlocked,
          stock: shuffleStock,
          unlockLevel: shuffleUnlockLevel,
        ),
        const SizedBox(width: 20),
        _buildActionButton(
          iconData: Icons.lightbulb_rounded,
          onTap: onHint,
          buttonSize: 52,
          iconSize: 22,
          price: 35,
          isUnlocked: hintUnlocked,
          stock: hintStock,
          unlockLevel: hintUnlockLevel,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData iconData,
    required VoidCallback onTap,
    required double buttonSize,
    required double iconSize,
    required int price,
    required bool isUnlocked,
    required int stock,
    required int unlockLevel,
  }) {
    final canTap = isUnlocked;
    final badgeMode = resolveBoosterBadgeMode(
      isUnlocked: isUnlocked,
      stock: stock,
    );

    // Color definitions based on icon
    Color baseColor;
    Color topFaceStart;
    Color topFaceEnd;
    Color glintColor = Colors.white.withAlpha(140);

    if (!isUnlocked) {
      baseColor = const Color(0xFF6C7C96);
      topFaceStart = const Color(0xFFBCC6D5);
      topFaceEnd = const Color(0xFFAAB5C5);
      glintColor = Colors.white.withAlpha(80);
    } else if (iconData == Icons.undo_rounded) {
      baseColor = const Color(0xFF880E4F); // Deep Pink
      topFaceStart = const Color(0xFFEC407A);
      topFaceEnd = const Color(0xFFD81B60);
    } else if (iconData == Icons.shuffle_rounded) {
      baseColor = const Color(0xFF1B5E20); // Deep Green
      topFaceStart = const Color(0xFF81C784);
      topFaceEnd = const Color(0xFF43A047);
    } else {
      // Hint / Lightbulb
      baseColor = const Color(0xFFE65100); // Deep Orange
      topFaceStart = const Color(0xFFFFD54F);
      topFaceEnd = const Color(0xFFFFA000);
    }

    const double depthOffset = 3.5;

    return MouseRegion(
      cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: canTap ? onTap : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Shadow (Drop shadow for the whole button)
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(buttonSize * 0.32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(65),
                    blurRadius: 10,
                    offset: const Offset(0, 4.5),
                  ),
                ],
              ),
            ),

            // 2. 3D Base (Depth side)
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(buttonSize * 0.32),
                color: baseColor,
                border: Border.all(
                  color: Colors.black.withAlpha(35),
                  width: 1.0,
                ),
              ),
            ),

            // 3. Top Face (Floating part)
            Container(
              width: buttonSize,
              height: buttonSize - depthOffset,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(buttonSize * 0.28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [topFaceStart, topFaceEnd],
                ),
                border: Border.all(
                  color: Colors.white.withAlpha(isUnlocked ? 45 : 20),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Icon(
                  iconData,
                  size: iconSize,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withAlpha(70),
                      blurRadius: 3,
                      offset: const Offset(0, 1.2),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Glossy Glint (Top Highlight)
            Positioned(
              top: 2.2,
              left: buttonSize * 0.22,
              right: buttonSize * 0.22,
              child: Container(
                height: 1.1,
                decoration: BoxDecoration(
                  color: glintColor,
                  borderRadius: BorderRadius.circular(0.5),
                ),
              ),
            ),

            // 5. Badge (Price / Stock / Locked)
            Positioned(
              top: -10,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isUnlocked
                        ? const [
                            Color(0xFFFFEE58),
                            Color(0xFFFBC02D),
                          ]
                        : const [
                            Color(0xFF9EA7B5),
                            Color(0xFF7E899B),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF1A1F2B).withAlpha(160),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(90),
                      blurRadius: 4.5,
                      offset: const Offset(0, 1.8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeMode == BoosterBadgeMode.price) ...[
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 13,
                        color: Color(0xFF3E2723),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$price',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF3E2723),
                          height: 1,
                        ),
                      ),
                    ] else if (badgeMode == BoosterBadgeMode.stock) ...[
                      const Icon(
                        Icons.bolt_rounded,
                        size: 13,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 2.5),
                      Text(
                        '$stock',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1B5E20),
                          height: 1,
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2.5),
                      Text(
                        '$levelShortLabel$unlockLevel',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
