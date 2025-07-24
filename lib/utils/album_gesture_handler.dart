import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/models/lyrics_model.dart';
import 'package:houston/providers/lyrics_provider.dart';
import '../providers/audio_state_provider.dart';

class AlbumArtGestureHandler {
  final BuildContext context;
  final WidgetRef ref;
  final AnimationController slideController;
  final AnimationController lyricsController;
  final VoidCallback onLyricsLoadingChanged;
  final VoidCallback onLyricsVisibilityChanged;

  bool _isDismissing = false;
  bool _isProcessingGesture = false;

  // Gesture sensitivity thresholds
  static const double _velocityThreshold =
      200.0; // Reduced for better sensitivity

  AlbumArtGestureHandler({
    required this.context,
    required this.ref,
    required this.slideController,
    required this.lyricsController,
    required this.onLyricsLoadingChanged,
    required this.onLyricsVisibilityChanged,
  });

  /// Handles vertical swipe gestures (up/down)
  void handleVerticalSwipe(DragEndDetails details, bool showLyrics) async {
    if (_isDismissing || _isProcessingGesture) return;

    final velocity = details.velocity.pixelsPerSecond.dy;
    final delta = details.velocity.pixelsPerSecond.dy;

    debugPrint('Vertical swipe - velocity: $velocity, delta: $delta');

    // Calculate swipe direction and strength
    final isSwipeUp = velocity < -_velocityThreshold;
    final isSwipeDown = velocity > _velocityThreshold;

    // Ensure significant swipe
    if (velocity.abs() < _velocityThreshold) {
      debugPrint(
        'Vertical swipe too weak: ${velocity.abs()} < $_velocityThreshold',
      );
      return;
    }

    _isProcessingGesture = true;

    try {
      if (isSwipeUp && !showLyrics) {
        debugPrint('Showing lyrics');
        // Swipe up: Show lyrics
        await _showLyrics();
      } else if (isSwipeDown) {
        if (showLyrics) {
          debugPrint('Hiding lyrics');
          // Swipe down: Hide lyrics
          await _hideLyrics();
        } else {
          debugPrint('Dismissing screen');
          // Swipe down: Dismiss screen
          await _dismissScreen();
        }
      }
    } finally {
      _isProcessingGesture = false;
    }
  }

  /// Handles horizontal swipe gestures (left/right)
  void handleHorizontalSwipe(DragEndDetails details) async {
    if (_isDismissing || _isProcessingGesture) return;

    final velocity = details.velocity.pixelsPerSecond.dx;
    final delta = details.velocity.pixelsPerSecond.dx;

    debugPrint('Horizontal swipe - velocity: $velocity, delta: $delta');

    // Calculate swipe direction and strength
    final isSwipeLeft = velocity < -_velocityThreshold;
    final isSwipeRight = velocity > _velocityThreshold;

    // Ensure significant swipe
    if (velocity.abs() < _velocityThreshold) {
      debugPrint(
        'Horizontal swipe too weak: ${velocity.abs()} < $_velocityThreshold',
      );
      return;
    }

    _isProcessingGesture = true;

    try {
      if (isSwipeLeft) {
        debugPrint('Next song');
        // Swipe left: Next song
        await _nextSong();
      } else if (isSwipeRight) {
        debugPrint('Previous song');
        // Swipe right: Previous song
        await _previousSong();
      }
    } finally {
      _isProcessingGesture = false;
    }
  }

  /// Handles double tap gesture
  void handleDoubleTap(bool showLyrics) async {
    if (_isDismissing || _isProcessingGesture) return;

    if (showLyrics) {
      _isProcessingGesture = true;
      try {
        await _hideLyrics();
      } finally {
        _isProcessingGesture = false;
      }
    }
  }

  /// Handles single tap gesture
  void handleSingleTap() {
    if (_isDismissing || _isProcessingGesture) return;

    // Toggle play/pause
    ref.read(audioProvider.notifier).pauseResume();
  }

  /// Shows lyrics with loading state
  Future<void> _showLyrics() async {
    onLyricsVisibilityChanged();
    onLyricsLoadingChanged();

    // Start lyrics animation
    await lyricsController.forward();

    // Fetch lyrics
    final song = ref.read(audioProvider).currentSong;
    if (song != null) {
      try {
        final result = await LyricsProvider().fetchLyrics(
          song.title,
          song.artists,
        );

        if (result['success']) {
          final parsed = (result['lines'] as List)
              .map((e) => LyricsLine.fromMap(e))
              .toList();
          ref.read(audioProvider.notifier).setLyrics(parsed);
        }
      } catch (e) {
        debugPrint('Error loading lyrics: $e');
        // Show error message or fallback
      }
    }

    onLyricsLoadingChanged();
  }

  /// Hides lyrics with animation
  Future<void> _hideLyrics() async {
    await lyricsController.reverse();
    onLyricsVisibilityChanged();
  }

  /// Dismisses the screen with slide animation
  Future<void> _dismissScreen() async {
    if (_isDismissing) return;

    _isDismissing = true;

    try {
      await slideController.forward();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error dismissing screen: $e');
      _isDismissing = false;
    }
  }

  /// Plays next song
  Future<void> _nextSong() async {
    try {
      await ref.read(audioProvider.notifier).playNext();
    } catch (e) {
      debugPrint('Error playing next song: $e');
    }
  }

  /// Plays previous song
  Future<void> _previousSong() async {
    try {
      await ref.read(audioProvider.notifier).playPrevious();
    } catch (e) {
      debugPrint('Error playing previous song: $e');
    }
  }

  /// Universal gesture handler that intelligently routes gestures
  void handlePanEnd(DragEndDetails details, bool showLyrics) {
    if (_isDismissing || _isProcessingGesture) return;

    final horizontalVelocity = details.velocity.pixelsPerSecond.dx;
    final verticalVelocity = details.velocity.pixelsPerSecond.dy;

    debugPrint(
      'Pan end - horizontal: $horizontalVelocity, vertical: $verticalVelocity',
    );

    // Check if gesture meets minimum velocity threshold
    final horizontalMagnitude = horizontalVelocity.abs();
    final verticalMagnitude = verticalVelocity.abs();

    if (horizontalMagnitude < _velocityThreshold &&
        verticalMagnitude < _velocityThreshold) {
      debugPrint(
        'Gesture too weak - H: $horizontalMagnitude, V: $verticalMagnitude',
      );
      return;
    }

    // Determine dominant direction with lower threshold for better sensitivity
    if (horizontalMagnitude > verticalMagnitude &&
        horizontalMagnitude > _velocityThreshold) {
      debugPrint('Handling as horizontal gesture');
      handleHorizontalSwipe(details);
    } else if (verticalMagnitude > horizontalMagnitude &&
        verticalMagnitude > _velocityThreshold) {
      debugPrint('Handling as vertical gesture');
      handleVerticalSwipe(details, showLyrics);
    } else {
      debugPrint('Ambiguous gesture - defaulting to vertical');
      // For ambiguous gestures, default to vertical
      handleVerticalSwipe(details, showLyrics);
    }
  }

  /// Dispose method for cleanup
  void dispose() {
    _isDismissing = false;
    _isProcessingGesture = false;
  }
}

enum GestureDirection { horizontal, vertical, ambiguous }

/// Extension for better gesture detection
extension GestureDetailsExtension on DragEndDetails {
  bool get isSignificantGesture {
    final velocity = primaryVelocity?.abs() ?? 0;
    final distance = velocity * 0.016; // Approximate distance based on velocity
    return velocity > 300 && distance > 100;
  }

  bool get isHorizontalDominant {
    final horizontal = velocity.pixelsPerSecond.dx.abs();
    final vertical = velocity.pixelsPerSecond.dy.abs();
    return horizontal > vertical * 1.5;
  }

  bool get isVerticalDominant {
    final horizontal = velocity.pixelsPerSecond.dx.abs();
    final vertical = velocity.pixelsPerSecond.dy.abs();
    return vertical > horizontal * 1.5;
  }
}
