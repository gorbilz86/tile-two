import 'package:flutter/material.dart';
import 'package:tile_two/ui/google_fonts_proxy.dart';
import 'package:tile_two/ui/booster_3d_icon.dart';

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
  final VoidCallback? onAdHint;
  final bool isAdBusy;
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
    this.onAdHint,
    this.isAdBusy = false,
    this.levelShortLabel = 'Lv',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onAdHint != null) ...[
          _buildAdChestButton(),
          const SizedBox(width: 12),
        ],
        _buildActionButton(
          type: BoosterType.undo,
          onTap: onUndo,
          buttonSize: 44,
          price: 45,
          isUnlocked: true,
          stock: undoStock,
          unlockLevel: 1,
        ),
        const SizedBox(width: 20),
        _buildActionButton(
          type: BoosterType.shuffle,
          onTap: onShuffle,
          buttonSize: 44,
          price: 55,
          isUnlocked: shuffleUnlocked,
          stock: shuffleStock,
          unlockLevel: shuffleUnlockLevel,
        ),
        const SizedBox(width: 20),
        _buildActionButton(
          type: BoosterType.hint,
          onTap: onHint,
          buttonSize: 44,
          price: 35,
          isUnlocked: hintUnlocked,
          stock: hintStock,
          unlockLevel: hintUnlockLevel,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BoosterType type,
    required VoidCallback onTap,
    required double buttonSize,
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
            Booster3DIcon(
              type: type,
              size: buttonSize,
              isUnlocked: isUnlocked,
            ),
            // Badge (Price / Stock / Locked)
            Positioned(
              top: -10,
              right: -5,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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

  Widget _buildAdChestButton() {
    const double size = 30.0;
    const double iconSize = 16.0;
    const double depthOffsetSize = 2.5;

    const Color baseColor = Color(0xFF5D4037); // Rich Brown
    const Color topStart = Color(0xFFFFD700); // Gold
    const Color topEnd = Color(0xFFFFA000); // Amber

    return MouseRegion(
      cursor: isAdBusy ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isAdBusy ? null : onAdHint,
        child: Opacity(
          opacity: isAdBusy ? 0.6 : 1.0,
          child: Stack(
            children: [
              // Shadow
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              // Base
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.3),
                  color: baseColor,
                ),
              ),
              // Face
              Container(
                width: size,
                height: size - depthOffsetSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.28),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [topStart, topEnd],
                  ),
                ),
                child: Center(
                  child: isAdBusy
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(
                          Icons.redeem_rounded, // Treasure chest look
                          size: iconSize,
                          color: Color(0xFF3E2723),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
