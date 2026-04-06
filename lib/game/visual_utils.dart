library visual_utils;
import 'package:flutter/widgets.dart';

/// Returns the background image path based on the given level.
///
/// Logics:
/// Rotate through 15 backgrounds every 10 levels.
String getBackgroundPath(int level) {
  // Rotate through 15 backgrounds every 10 levels
  final int bgIndex = ((level - 1) ~/ 10) % 15 + 1;
  return 'assets/images/background$bgIndex.png';
}

/// Pre-caches all background images to avoid hitching during gameplay transitions.
Future<void> precacheBackgrounds(BuildContext context) async {
  for (int i = 1; i <= 15; i++) {
    final path = 'assets/images/background$i.png';
    await precacheImage(AssetImage(path), context);
  }
}
