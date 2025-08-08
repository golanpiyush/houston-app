import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/models/lyrics_model.dart';
import 'package:houston/providers/lyrics_provider.dart';
import 'package:houston/providers/lyrics_provider_provider.dart';
import 'package:houston/providers/settings_provider.dart';
import '../providers/audio/audio_state_provider.dart';

class AlbumArtGestureHandler {
  final BuildContext context;
  final WidgetRef ref;
  final AnimationController slideController;
  final AnimationController lyricsController;
  final VoidCallback onLyricsLoadingChanged;
  final VoidCallback onLyricsVisibilityChanged;
  final LyricsProvider lyricsProvider;

  // ADDED: Callback to force UI rebuild
  final VoidCallback? onSongChanged;

  bool _isDismissing = false;
  bool _isProcessingGesture = false;

  // Gesture sensitivity thresholds
  static const double _velocityThreshold = 200.0;

  AlbumArtGestureHandler({
    required this.context,
    required this.ref,
    required this.slideController,
    required this.lyricsController,
    required this.onLyricsLoadingChanged,
    required this.onLyricsVisibilityChanged,
    this.onSongChanged, // ADDED: Optional callback for song changes
    required this.lyricsProvider,
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
        await _showLyrics();
      } else if (isSwipeDown) {
        if (showLyrics) {
          debugPrint('Hiding lyrics');
          await _hideLyrics();
        } else {
          debugPrint('Dismissing screen');
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
        debugPrint('Next song gesture detected');
        await _nextSong();
      } else if (isSwipeRight) {
        debugPrint('Previous song gesture detected');
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

    debugPrint('Single tap - toggling play/pause');
    // Toggle play/pause
    ref.read(audioProvider.notifier).pauseResume();
  }

  Future<void> _showLyricsAlternative() async {
    onLyricsVisibilityChanged();
    onLyricsLoadingChanged();

    // Start lyrics animation
    await lyricsController.forward();

    // Fetch lyrics using direct approach
    final song = ref.read(audioProvider).currentSong;
    if (song != null) {
      // Get current settings and create fresh provider
      final settings = ref.read(settingsProvider);

      print(
        'GESTURE_HANDLER: Current settings source: ${settings.lyricsProvider}',
      );

      final freshLyricsProvider = LyricsProvider();
      freshLyricsProvider.selectedSource = settings.lyricsProvider;

      print(
        'GESTURE_HANDLER: Created provider with source: ${freshLyricsProvider.selectedSource}',
      );

      try {
        final result = await freshLyricsProvider.fetchLyrics(
          song.title,
          song.artists,
        );

        print('GESTURE_HANDLER: Lyrics fetch result: ${result['success']}');

        if (result['success']) {
          final parsed = (result['lines'] as List)
              .map((e) => LyricsLine.fromMap(e))
              .toList();
          ref.read(audioProvider.notifier).setLyrics(parsed);
          print(
            'GESTURE_HANDLER: Successfully set ${parsed.length} lyrics lines',
          );
        } else {
          print('GESTURE_HANDLER: Failed to fetch lyrics: ${result['error']}');
        }
      } catch (e) {
        debugPrint('Error loading lyrics: $e');
      } finally {
        freshLyricsProvider.dispose(); // Important: Clean up
      }
    } else {
      print('GESTURE_HANDLER: No current song available');
    }

    onLyricsLoadingChanged();
  }

  static Future<Map<String, dynamic>> fetchLyricsWithFreshProvider(
    WidgetRef ref,
    String title,
    String artist, {
    int duration = -1,
  }) async {
    // Invalidate and get fresh provider
    ref.invalidate(lyricsProviderProvider);
    final lyricsProvider = ref.read(lyricsProviderProvider);

    print(
      'GESTURE_HANDLER: Using FRESH provider with source: ${lyricsProvider.selectedSource}',
    );

    // Use the fresh provider to fetch lyrics
    return await lyricsProvider.fetchLyrics(title, artist, duration: duration);
  }

  // Alternative: Create a completely fresh provider instance
  static Future<Map<String, dynamic>> fetchLyricsAlternative(
    WidgetRef ref,
    String title,
    String artist, {
    int duration = -1,
  }) async {
    // Create a completely new provider instance that reads current settings
    final settings = ref.read(settingsProvider);
    final freshProvider = LyricsProvider();
    freshProvider.selectedSource = settings.lyricsProvider;

    print(
      'GESTURE_HANDLER: Created FRESH provider with source: ${freshProvider.selectedSource}',
    );

    try {
      final result = await freshProvider.fetchLyrics(
        title,
        artist,
        duration: duration,
      );
      return result;
    } finally {
      freshProvider.dispose(); // Clean up
    }
  }

  /// Shows lyrics with loading state
  Future<void> _showLyrics() async {
    onLyricsVisibilityChanged();
    onLyricsLoadingChanged();

    // Start lyrics animation
    await lyricsController.forward();

    // Fetch lyrics using the fresh provider
    final song = ref.read(audioProvider).currentSong;
    if (song != null) {
      try {
        print(
          'GESTURE_HANDLER: Starting lyrics fetch for: ${song.title} by ${song.artists}',
        );

        // Use the static method with fresh provider
        final result = await fetchLyricsAlternative(
          ref,
          song.title,
          song.artists,
        );

        print('GESTURE_HANDLER: Lyrics fetch result: ${result['success']}');

        if (result['success']) {
          final parsed = (result['lines'] as List)
              .map((e) => LyricsLine.fromMap(e))
              .toList();
          ref.read(audioProvider.notifier).setLyrics(parsed);
          print(
            'GESTURE_HANDLER: Successfully set ${parsed.length} lyrics lines',
          );
        } else {
          print('GESTURE_HANDLER: Failed to fetch lyrics: ${result['error']}');
        }
      } catch (e) {
        debugPrint('Error loading lyrics: $e');
      }
    } else {
      print('GESTURE_HANDLER: No current song available');
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

  /// Plays next song - FIXED
  Future<void> _nextSong() async {
    try {
      debugPrint('🎵 Gesture handler: Calling playNext()');

      // Get current song before the change
      final currentSong = ref.read(audioProvider).currentSong;
      debugPrint('🎵 Current song before next: ${currentSong?.title}');

      // Call the audio provider method
      await ref.read(audioProvider.notifier).playNext();

      // Wait a moment for state to update
      await Future.delayed(Duration(milliseconds: 100));

      // Get the new current song
      final newSong = ref.read(audioProvider).currentSong;
      debugPrint('🎵 New song after next: ${newSong?.title}');

      // FIXED: Force UI update by triggering callback
      if (onSongChanged != null) {
        debugPrint('🎵 Triggering onSongChanged callback');
        onSongChanged!();
      }

      // FIXED: Additional state refresh to ensure UI updates
      if (context.mounted) {
        // Force a rebuild by invalidating the provider temporarily
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref.invalidate(audioProvider);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error in gesture handler playNext: $e');
    }
  }

  /// Plays previous song - FIXED
  Future<void> _previousSong() async {
    try {
      debugPrint('🎵 Gesture handler: Calling playPrevious()');

      // Get current song before the change
      final currentSong = ref.read(audioProvider).currentSong;
      debugPrint('🎵 Current song before previous: ${currentSong?.title}');

      // Call the audio provider method
      await ref.read(audioProvider.notifier).playPrevious();

      // Wait a moment for state to update
      await Future.delayed(Duration(milliseconds: 100));

      // Get the new current song
      final newSong = ref.read(audioProvider).currentSong;
      debugPrint('🎵 New song after previous: ${newSong?.title}');

      // FIXED: Force UI update by triggering callback
      if (onSongChanged != null) {
        debugPrint('🎵 Triggering onSongChanged callback');
        onSongChanged!();
      }

      // FIXED: Additional state refresh to ensure UI updates
      if (context.mounted) {
        // Force a rebuild by invalidating the provider temporarily
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref.invalidate(audioProvider);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error in gesture handler playPrevious: $e');
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
