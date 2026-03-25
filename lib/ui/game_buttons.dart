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
    return MouseRegion(
      cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: canTap ? onTap : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: isUnlocked ? 1 : 0.45,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(buttonSize * 0.35),
                  color: Colors.black.withAlpha(26),
                  border:
                      Border.all(color: Colors.black.withAlpha(190), width: 1.85),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    iconData,
                    size: iconSize,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isUnlocked
                        ? const [
                            Color(0xFFFFE082),
                            Color(0xFFFFC107),
                          ]
                        : const [
                            Color(0xFF8B96A8),
                            Color(0xFF70798C),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.black.withAlpha(200), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeMode == BoosterBadgeMode.price) ...[
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 14,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 2.5),
                      Text(
                        '$price',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 1,
                        ),
                      ),
                    ] else if (badgeMode == BoosterBadgeMode.stock) ...[
                      const Icon(
                        Icons.inventory_2_rounded,
                        size: 12,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$stock',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 1,
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$levelShortLabel$unlockLevel',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
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
