/// Visual Utilities for the game
///
/// Contains helper functions for assets and UI styling.
library visual_utils;

/// Returns the background image path based on the given level.
///
/// Logics:
/// Rotate through 15 backgrounds every 5 levels.
String getBackgroundPath(int level) {
  // Rotate through 15 backgrounds every 5 levels
  final int bgIndex = ((level - 1) ~/ 5) % 15 + 1;
  return 'assets/images/background$bgIndex.png';
}
