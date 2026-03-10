
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// A custom button widget designed for the game's UI.
class UiButton extends StatelessWidget {
  final String iconPath;
  final VoidCallback? onTap;

  const UiButton({super.key, required this.iconPath, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Using GestureDetector for tap handling, as it's more lightweight
    // than InkWell or other Material buttons and gives us more control.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,  // Button width.
        height: 64, // Button height.
        decoration: BoxDecoration(
          shape: BoxShape.circle, // Circular button shape.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[800]!,
              Colors.grey[900]!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(128),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4), // Shadow position.
            ),
          ],
          border: Border.all(color: Colors.grey[700]!, width: 2),
        ),
        child: Center(
          child: SvgPicture.asset(
            iconPath,
            width: 32,
            height: 32,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
