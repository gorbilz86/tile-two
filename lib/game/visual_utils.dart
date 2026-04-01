/// Visual Utilities for the game
///
/// Contains helper functions for assets and UI styling.
library visual_utils;

/// Returns the background image path based on the given level.
///
/// Logics:
/// Level 1-5: assets/images/background.png
/// Level 6-10: assets/images/background2.png
/// Level 11-15: assets/images/background3.png
/// Level 16-20: assets/images/background4.png
/// Level 21-25+: assets/images/background5.png
String getBackgroundPath(int level) {
  // Rotate through 10 backgrounds every 5 levels
  final int bgIndex = ((level - 1) ~/ 5) % 10 + 1;
  if (bgIndex == 1) {
    return 'assets/images/background.png';
  }
  return 'assets/images/background$bgIndex.png';
}
