
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// A custom button widget designed for the game's UI.
class UiButton extends StatelessWidget {
  final String iconPath;
  final VoidCallback? onTap;

  const UiButton({super.key, required this.iconPath, this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber[400]!,
                Colors.amber[700]!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withAlpha(80),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withAlpha(100),
                blurRadius: 2,
                spreadRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border.all(color: Colors.white.withAlpha(150), width: 2),
          ),
          child: Center(
            child: SvgPicture.asset(
              iconPath,
              width: 30,
              height: 30,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
