import 'dart:math';

import 'package:flutter/material.dart';

// Custom widget for random glow animation
class RandomGlowLikedAnimation extends StatefulWidget {
  final VoidCallback? onTap;
  final double size;
  final int delay;

  const RandomGlowLikedAnimation({
    Key? key,
    this.onTap,
    this.size = 24.0,
    required this.delay,
  }) : super(key: key);

  @override
  State<RandomGlowLikedAnimation> createState() =>
      _RandomGlowLikedAnimationState();
}

class _RandomGlowLikedAnimationState extends State<RandomGlowLikedAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Glow animation controller
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Pulse animation (scale effect) - reduced intensity
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animation (opacity effect) - reduced intensity
    _glowAnimation = Tween<double>(begin: 0.5, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start animations with random delay
    _startAnimationsWithDelay();
  }

  void _startAnimationsWithDelay() {
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _pulseController.repeat(reverse: true);

        // Glow animation with additional random delay
        Future.delayed(Duration(milliseconds: Random().nextInt(500) + 200), () {
          if (mounted) {
            _glowController.repeat(reverse: true);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: widget.size + 16,
              height: widget.size + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(
                      _glowAnimation.value * 0.3,
                    ), // Reduced glow intensity
                    blurRadius: 4.0, // Reduced blur radius
                    spreadRadius: 1.0, // Reduced spread radius
                  ),
                ],
              ),
              child: Icon(
                Icons.favorite,
                size: widget.size,
                color: Colors.red.withOpacity(_glowAnimation.value),
              ),
            ),
          );
        },
      ),
    );
  }
}
