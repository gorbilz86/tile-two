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
          buttonSize: 60,
          iconScale: 0.46,
        ),
        const SizedBox(width: 24),
        _buildActionButton(
          iconPath: 'assets/images/shuffle_icon.svg',
          onTap: onShuffle,
          buttonSize: 66,
          iconScale: 0.48,
        ),
        const SizedBox(width: 24),
        _buildActionButton(
          iconPath: 'assets/images/next_icon.svg',
          onTap: onHint,
          buttonSize: 60,
          iconScale: 0.46,
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
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF6E8FAE),
                Color(0xFF4D6E8E),
              ],
            ),
            border: Border.all(color: Colors.white.withAlpha(235), width: 2.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(85),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: SvgPicture.asset(
              iconPath,
              width: buttonSize * iconScale,
              height: buttonSize * iconScale,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
