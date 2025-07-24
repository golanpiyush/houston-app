import 'package:flutter/widgets.dart';
import 'package:houston/utils/album_gesture_handler.dart';

/// Gesture detector wrapper for better handling
class SmartGestureDetector extends StatelessWidget {
  final Widget child;
  final AlbumArtGestureHandler gestureHandler;
  final bool showLyrics;

  const SmartGestureDetector({
    super.key,
    required this.child,
    required this.gestureHandler,
    required this.showLyrics,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Single tap for play/pause
      onTap: () => gestureHandler.handleSingleTap(),

      // Double tap to hide lyrics
      onDoubleTap: () => gestureHandler.handleDoubleTap(showLyrics),

      // Pan end for all directional gestures
      onPanEnd: (details) => gestureHandler.handlePanEnd(details, showLyrics),

      // Prevent conflicts
      behavior: HitTestBehavior.opaque,

      child: child,
    );
  }
}
