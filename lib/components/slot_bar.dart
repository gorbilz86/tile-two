
import 'package:flutter/material.dart';

// A Flutter widget that represents the bar at the top where collected
// tiles are placed.
class SlotBar extends StatelessWidget {
  const SlotBar({super.key});

  @override
  Widget build(BuildContext context) {
    // The main container for the slot bar, with a semi-transparent background
    // and rounded corners.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Take up only as much space as needed.
        children: List.generate(7, (index) {
          // Generate 7 empty slots.
          return _buildSlot();
        }),
      ),
    );
  }

  // Builds a single empty slot with a dashed border.
  Widget _buildSlot() {
    return Container(
      width: 52,  // Width of the slot.
      height: 52, // Height of the slot.
      margin: const EdgeInsets.symmetric(horizontal: 4), // Spacing between slots.
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(51),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
