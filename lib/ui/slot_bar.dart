import 'package:flutter/material.dart';
import 'package:tile_two/game/game_state_controller.dart';
import 'package:tile_two/components/tile_component.dart';

/// Professional Slot Bar
/// 
/// Settings: 7 slots, size 65, spacing 8, centered horizontally.
class SlotBar extends StatelessWidget {
  final GameStateController controller;

  const SlotBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TileComponent>>(
      valueListenable: controller.selectedTiles,
      builder: (context, selectedTiles, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            const maxSlots = GameStateController.maxSlots;
            const spacing = 8.0;
            const horizontalPad = 16.0;
            // Fit-to-width calculation to avoid overflow on small screens
            final maxContentWidth = constraints.maxWidth - (horizontalPad * 2);
            // Correct formula: Total Width = 7 * (slotSize + spacing)
            // We need Total Width <= maxContentWidth
            // 7 * slotSize + 7 * spacing <= maxContentWidth
            // 7 * slotSize <= maxContentWidth - (7 * spacing)
            final computedSlotSize =
                (maxContentWidth - (maxSlots * spacing)) / maxSlots;
            // Allow dynamic shrinking, cap at 65 (slightly smaller to be safe)
            final slotSize = computedSlotSize.clamp(0.0, 65.0);

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPad,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(60), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(100),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(maxSlots, (index) {
                    final hasTile = index < selectedTiles.length;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      width: slotSize,
                      height: slotSize,
                      margin: const EdgeInsets.symmetric(
                        horizontal: spacing / 2,
                      ),
                      decoration: BoxDecoration(
                        color: hasTile
                            ? Colors.white.withAlpha(30)
                            : Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withAlpha(hasTile ? 80 : 30),
                          width: 1.5,
                        ),
                      ),
                      child: hasTile
                          ? Padding(
                              padding: EdgeInsets.all(slotSize * 0.22), // Dynamic padding to keep icon small
                              child: Image.asset(
                                'assets/images/tiles/${selectedTiles[index].type}.png',
                                fit: BoxFit.contain,
                              ),
                            )
                          : null,
                    );
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
