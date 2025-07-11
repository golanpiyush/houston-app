import 'package:flutter/material.dart';

class AnimatedNavItem extends StatefulWidget {
  final bool isSelected;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const AnimatedNavItem({
    super.key,
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<AnimatedNavItem>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    // Separate controllers for better performance
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Smooth background animation with custom curve
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Subtle slide animation for icon
    _slideAnimation =
        Tween<double>(
          begin: 0.0,
          end: -0.05, // Reduced slide distance for smoother effect
        ).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutQuart,
          ),
        );

    // Text fade and scale animation
    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Initialize state
    if (widget.isSelected) {
      _backgroundController.value = 1.0;
      _contentController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _backgroundController.forward();
        _contentController.forward();
      } else {
        _backgroundController.reverse();
        _contentController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _backgroundController,
          _contentController,
        ]),
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: Color.lerp(
                Colors.transparent,
                colorScheme.primary.withOpacity(0.15),
                _backgroundAnimation.value,
              ),
              borderRadius: BorderRadius.circular(25),
              // Add subtle shadow for depth
              boxShadow: _backgroundAnimation.value > 0.5
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated icon with slide effect
                  Transform.translate(
                    offset: Offset(_slideAnimation.value * 10, 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 24,
                      width: 24,
                      child: IconTheme(
                        data: IconThemeData(
                          color: Color.lerp(
                            colorScheme.onSurface.withOpacity(0.7),
                            colorScheme.primary,
                            _backgroundAnimation.value,
                          ),
                          size: 24,
                        ),
                        child: widget.icon,
                      ),
                    ),
                  ),

                  // Animated text with smooth width transition
                  ClipRect(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width:
                          _textAnimation.value *
                          (_getTextWidth(context) + 16), // Added padding space
                      child: Opacity(
                        opacity: _textAnimation.value,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _getTextWidth(BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.label,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width;
  }
}
