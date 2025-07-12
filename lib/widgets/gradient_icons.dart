import 'package:flutter/material.dart';

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const GradientIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Color(0xFF0D0D0D), // ~5% black
      ],
      stops: [0.0, 1.0],
    );

    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      blendMode: BlendMode.srcIn,
      child: IconButton(icon: Icon(icon), iconSize: size, onPressed: onPressed),
    );
  }
}
