import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GameButtons extends StatelessWidget {
  final VoidCallback onUndo;
  final VoidCallback onShuffle;
  final VoidCallback onHint;

  const GameButtons({
    super.key,
    required this.onUndo,
    required this.onShuffle,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          iconPath: 'assets/images/undo_icon.svg',
          onTap: onUndo,
          buttonSize: 64,
          iconScale: 0.5,
        ),
        const SizedBox(width: 24),
        _buildActionButton(
          iconPath: 'assets/images/shuffle_icon.svg',
          onTap: onShuffle,
          buttonSize: 68,
          iconScale: 0.5,
        ),
        const SizedBox(width: 24),
        _buildActionButton(
          iconPath: 'assets/images/next_icon.svg',
          onTap: onHint,
          buttonSize: 64,
          iconScale: 0.5,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String iconPath,
    required VoidCallback onTap,
    required double buttonSize,
    required double iconScale,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(buttonSize * 0.35),
            color: Colors.black.withAlpha(26),
            border: Border.all(color: Colors.black.withAlpha(190), width: 1.85),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: buttonSize * (iconScale + 0.02),
                  height: buttonSize * (iconScale + 0.02),
                  colorFilter: const ColorFilter.mode(
                    Colors.black54,
                    BlendMode.srcIn,
                  ),
                ),
                SvgPicture.asset(
                  iconPath,
                  width: buttonSize * iconScale,
                  height: buttonSize * iconScale,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
