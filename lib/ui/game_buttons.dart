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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        // Fit three buttons + two gaps (target gap 40); clamp to avoid overflow
        const targetGap = 40.0;
        final maxButtonSize = (maxWidth - (2 * targetGap)) / 3.0;
        final buttonSize = maxButtonSize.clamp(45.0, 60.0); // Slightly smaller max size
        final gap = ((maxWidth - (3 * buttonSize)) / 2.0).clamp(20.0, 40.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              iconPath: 'assets/images/undo_icon.svg',
              label: 'Undo',
              onTap: onUndo,
              buttonSize: buttonSize,
            ),
            SizedBox(width: gap),
            _buildActionButton(
              iconPath: 'assets/images/shuffle_icon.svg',
              label: 'Shuffle',
              onTap: onShuffle,
              buttonSize: buttonSize,
            ),
            SizedBox(width: gap),
            _buildActionButton(
              iconPath: 'assets/images/next_icon.svg',
              label: 'Hint',
              onTap: onHint,
              buttonSize: buttonSize,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
    required double buttonSize,
  }) {
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFFA500),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withAlpha(100),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconPath,
                  width: buttonSize * 0.5,
                  height: buttonSize * 0.5,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
        ),
      ],
    );
  }
}
