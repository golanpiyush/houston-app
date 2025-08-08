import 'package:flutter/material.dart';

class GradientIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onPressed; // ✅ Make it nullable!
  final Gradient? gradient;

  const GradientIconButton({
    super.key,
    required this.icon,
    required this.size,
    this.onPressed, // ✅ now it's allowed to be null
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final defaultGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white, Color(0xFF0D0D0D)],
    );

    return IconButton(
      onPressed: onPressed,
      icon: ShaderMask(
        shaderCallback: (bounds) => (gradient ?? defaultGradient).createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        ),
        blendMode: BlendMode.srcIn,
        child: Icon(icon, size: size),
      ),
    );
  }
}
