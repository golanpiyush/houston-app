import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:houston/providers/audio/navigation_controller.dart';
import 'package:just_audio/just_audio.dart';
import 'operation_manager.dart';

enum RecoveryStrategy {
  RETRY_CURRENT, // Retry current song
  SKIP_TO_NEXT, // Skip to next song
  RELOAD_SOURCE, // Reload audio source
  FALLBACK_TO_NETWORK, // Use network fallback for local files
  USER_INTERVENTION_REQUIRED, // Show error to user
  IGNORE_ERROR, // Ignore non-critical errors
}

class AudioError {
  final String message;
  final dynamic originalError;
  final DateTime timestamp;
  final String? songTitle;
  final String? audioUrl;
  final String errorType;

  AudioError({
    required this.message,
    required this.originalError,
    required this.errorType,
    this.songTitle,
    this.audioUrl,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'AudioError($errorType): $message at ${timestamp.toIso8601String()}';
  }
}

/// Handles playback errors without disrupting user navigation
class AudioErrorHandler {
  final dynamic _audioNotifier;
  final AudioPlayer _audioPlayer;
  final OperationManager _operationManager;

  // Error tracking
  int _consecutiveErrors = 0;
  DateTime? _lastErrorTime;
  bool _isHandlingError = false;
  final List<AudioError> _recentErrors = [];
  final Map<String, int> _errorCounts = {};

  // Recovery settings
  static const int MAX_CONSECUTIVE_ERRORS = 3;
  static const int MAX_RETRIES_PER_SONG = 2;
  static const Duration ERROR_RATE_LIMIT = Duration(seconds: 10);

  AudioErrorHandler(
    this._audioNotifier,
    this._audioPlayer,
    this._operationManager,
  );

  /// Handle player state errors with intelligent filtering
  void handlePlayerStateError(dynamic error) {
    if (!_shouldHandleError(error)) {
      return;
    }

    final audioError = _categorizeError(error);
    _recordError(audioError);

    // Rate limit error handling
    if (_isRateLimited()) {
      print('⚠️ Error handling rate limited');
      return;
    }

    final strategy = _determineRecoveryStrategy(audioError);
    _executeRecoveryStrategy(strategy, audioError);
  }

  /// Main error handling entry point
  Future<void> handlePlaybackError() async {
    if (_isHandlingError) {
      print('⚠️ Already handling error, skipping');
      return;
    }

    _isHandlingError = true;
    _consecutiveErrors++;

    try {
      final currentState = _audioNotifier.state;

      print('🔧 Handling playback error (attempt $_consecutiveErrors)');

      // Reset loading state immediately
      if (currentState.isLoading) {
        _audioNotifier.state = currentState.copyWith(
          isLoading: false,
          isPlaying: false,
        );
      }

      // Determine if this is a critical error sequence
      if (_consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
        await _handleCriticalErrorSequence();
        return;
      }

      // Handle based on current context
      if (_isRelatedSongTransition()) {
        await _handleRelatedSongError();
      } else {
        await _handleGeneralPlaybackError();
      }
    } catch (e) {
      print('❌ Error in error handling: $e');
      await _handleFallbackRecovery();
    } finally {
      _isHandlingError = false;
      _scheduleErrorReset();
    }
  }

  // ==================== ERROR CATEGORIZATION ====================

  bool _shouldHandleError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Ignore MediaCodec cleanup errors (these are harmless)
    final isMediaCodecError =
        errorString.contains('connection aborted') ||
        errorString.contains('bufferqueue') ||
        errorString.contains('detachbuffer') ||
        errorString.contains('cancelbuffer') ||
        errorString.contains('mediacodec') ||
        errorString.contains('surface') ||
        errorString.contains('disconnect');

    if (isMediaCodecError) {
      print('⚠️ Ignoring MediaCodec cleanup error: $error');
      return false;
    }

    // Only handle real playback errors
    final isRealError =
        errorString.contains('unable to connect') ||
        errorString.contains('network error') ||
        errorString.contains('connection timeout') ||
        errorString.contains('http error') ||
        errorString.contains('source error') ||
        errorString.contains('format not supported') ||
        errorString.contains('file not found');

    return isRealError;
  }

  AudioError _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    final currentState = _audioNotifier.state;

    String errorType;
    String message;

    if (errorString.contains('network') || errorString.contains('connect')) {
      errorType = 'NETWORK';
      message = 'Network connection error';
    } else if (errorString.contains('timeout')) {
      errorType = 'TIMEOUT';
      message = 'Connection timeout';
    } else if (errorString.contains('403') ||
        errorString.contains('forbidden')) {
      errorType = 'UNAUTHORIZED';
      message = 'Audio source unavailable';
    } else if (errorString.contains('404') ||
        errorString.contains('not found')) {
      errorType = 'NOT_FOUND';
      message = 'Audio file not found';
    } else if (errorString.contains('format') ||
        errorString.contains('codec')) {
      errorType = 'FORMAT';
      message = 'Unsupported audio format';
    } else if (errorString.contains('file')) {
      errorType = 'FILE';
      message = 'Local file error';
    } else {
      errorType = 'UNKNOWN';
      message = 'Playback error';
    }

    return AudioError(
      message: message,
      originalError: error,
      errorType: errorType,
      songTitle: currentState.currentSong?.title,
      audioUrl: currentState.currentSong?.audioUrl,
    );
  }

  RecoveryStrategy _determineRecoveryStrategy(AudioError error) {
    final currentState = _audioNotifier.state;

    // Don't interrupt user navigation
    if (_isUserNavigating()) {
      print('👤 User is navigating, ignoring error');
      return RecoveryStrategy.IGNORE_ERROR;
    }

    switch (error.errorType) {
      case 'NETWORK':
      case 'TIMEOUT':
        if (_consecutiveErrors < 2) {
          return RecoveryStrategy.RETRY_CURRENT;
        } else {
          return RecoveryStrategy.SKIP_TO_NEXT;
        }

      case 'UNAUTHORIZED':
      case 'NOT_FOUND':
        return RecoveryStrategy.SKIP_TO_NEXT;

      case 'FILE':
        // Local file error - try network fallback if available
        if (currentState.currentSong?.audioUrl?.startsWith('http') == true) {
          return RecoveryStrategy.FALLBACK_TO_NETWORK;
        } else {
          return RecoveryStrategy.SKIP_TO_NEXT;
        }

      case 'FORMAT':
        return RecoveryStrategy.SKIP_TO_NEXT;

      default:
        if (_consecutiveErrors < 2) {
          return RecoveryStrategy.RETRY_CURRENT;
        } else {
          return RecoveryStrategy.USER_INTERVENTION_REQUIRED;
        }
    }
  }

  // ==================== RECOVERY EXECUTION ====================

  Future<void> _executeRecoveryStrategy(
    RecoveryStrategy strategy,
    AudioError error,
  ) async {
    print('🔧 Executing recovery strategy: ${strategy.name}');

    switch (strategy) {
      case RecoveryStrategy.RETRY_CURRENT:
        await _retryCurrentSong(error);
        break;

      case RecoveryStrategy.SKIP_TO_NEXT:
        await _skipToNextSong();
        break;

      case RecoveryStrategy.RELOAD_SOURCE:
        await _reloadAudioSource();
        break;

      case RecoveryStrategy.FALLBACK_TO_NETWORK:
        await _fallbackToNetwork();
        break;

      case RecoveryStrategy.USER_INTERVENTION_REQUIRED:
        _showUserError(error);
        break;

      case RecoveryStrategy.IGNORE_ERROR:
        print('⏭️ Ignoring error as requested');
        break;
    }
  }

  Future<void> _retryCurrentSong(AudioError error) async {
    final currentState = _audioNotifier.state;

    if (currentState.currentSong == null) {
      print('⚠️ No current song to retry');
      return;
    }

    print('🔄 Retrying current song: ${currentState.currentSong!.title}');

    try {
      // Wait before retry to avoid rapid failures
      await Future.delayed(Duration(seconds: 2));

      // Simple restart approach
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();

      print('✅ Successfully retried current song');
      _consecutiveErrors = 0;
      _lastErrorTime = null;
    } catch (e) {
      print('❌ Retry failed: $e');
      // Will be handled by next error handling cycle
    }
  }

  Future<void> _skipToNextSong() async {
    print('⏭️ Skipping to next song due to error');

    try {
      // Use operation manager to queue skip operation
      final operation = AudioOperation(
        type: OperationType.ERROR_RECOVERY,
        priority: 2,
        operationId: 'error_skip_${DateTime.now().millisecondsSinceEpoch}',
      );

      await _operationManager.queueOperation(operation);

      // Trigger navigation controller for next song
      final navigationController = _audioNotifier._navigationController;
      await navigationController.navigateTo(
        type: NavigationType.NEXT,
        source: NavigationSource.ERROR_RECOVERY,
        reason: 'Error recovery skip',
      );
    } catch (e) {
      print('❌ Error skipping song: $e');
      await _handleFallbackRecovery();
    }
  }

  Future<void> _reloadAudioSource() async {
    final currentState = _audioNotifier.state;

    if (currentState.currentSong == null) return;

    print('🔄 Reloading audio source');

    try {
      final song = currentState.currentSong!;

      // Use audio source manager to create new source
      final audioSourceManager = _audioNotifier._audioSourceManager;
      final optimalSource = await audioSourceManager.createOptimalAudioSource(
        song,
      );

      await _audioPlayer.setAudioSource(optimalSource.source);
      await _audioPlayer.play();

      print('✅ Successfully reloaded audio source');
      _consecutiveErrors = 0;
    } catch (e) {
      print('❌ Failed to reload audio source: $e');
      await _skipToNextSong();
    }
  }

  Future<void> _fallbackToNetwork() async {
    final currentState = _audioNotifier.state;

    if (currentState.currentSong?.audioUrl?.startsWith('http') != true) {
      print('⚠️ No network fallback available');
      await _skipToNextSong();
      return;
    }

    print('🌐 Falling back to network source');

    try {
      final song = currentState.currentSong!;

      // Create network audio source directly
      final audioSource = AudioSource.uri(
        Uri.parse(song.audioUrl!),
        tag: MediaItem(
          id: song.videoId ?? song.audioUrl!,
          title: song.title,
          artist: song.artists,
        ),
      );

      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();

      print('✅ Successfully switched to network source');
      _consecutiveErrors = 0;
    } catch (e) {
      print('❌ Network fallback failed: $e');
      await _skipToNextSong();
    }
  }

  // ==================== SPECIALIZED ERROR HANDLING ====================

  Future<void> _handleCriticalErrorSequence() async {
    print('❌ Critical error sequence detected - stopping playback');

    try {
      await _audioPlayer.stop();

      final currentState = _audioNotifier.state;
      _audioNotifier.state = currentState.copyWith(
        currentSong: null,
        isPlaying: false,
        isLoading: false,
      );

      _showUserError(
        AudioError(
          message: 'Multiple playback errors occurred. Please try again.',
          originalError: 'Critical error sequence',
          errorType: 'CRITICAL',
        ),
      );
    } catch (e) {
      print('❌ Error in critical error handling: $e');
    }
  }

  Future<void> _handleRelatedSongError() async {
    print('🔄 Handling related song transition error');

    // Give more time for related song transitions
    await Future.delayed(Duration(seconds: 5));

    final currentState = _audioNotifier.state;
    if (currentState.currentSong?.audioUrl != null) {
      try {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();

        print('✅ Successfully recovered related song');
        _consecutiveErrors = 0;
        return;
      } catch (e) {
        print('❌ Related song recovery failed: $e');
      }
    }

    // If recovery failed, try to continue with queue
    if (_consecutiveErrors < MAX_CONSECUTIVE_ERRORS) {
      print('🔄 Will retry related song transition...');
      return;
    }

    await _skipToNextSong();
  }

  Future<void> _handleGeneralPlaybackError() async {
    final currentState = _audioNotifier.state;

    if (currentState.currentSong?.audioUrl == null) {
      print('⚠️ No valid audio source to recover');
      await _skipToNextSong();
      return;
    }

    print('🔄 Attempting general playback recovery');

    // Wait before attempting recovery
    await Future.delayed(Duration(seconds: 3));

    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();

      print('✅ Successfully recovered playback');
      _consecutiveErrors = 0;
    } catch (e) {
      print('❌ General recovery failed: $e');

      if (_consecutiveErrors >= MAX_CONSECUTIVE_ERRORS - 1) {
        await _skipToNextSong();
      }
    }
  }

  Future<void> _handleFallbackRecovery() async {
    print('🆘 Executing fallback recovery');

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);

      final currentState = _audioNotifier.state;
      _audioNotifier.state = currentState.copyWith(
        isPlaying: false,
        isLoading: false,
      );
    } catch (e) {
      print('❌ Fallback recovery failed: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  bool _isUserNavigating() {
    // Check if user is currently performing navigation
    final navigationStatus = _audioNotifier._navigationController
        .getNavigationStatus();
    return navigationStatus['isNavigating'] == true &&
        navigationStatus['currentRequest']?['source'] == 'USER';
  }

  bool _isRelatedSongTransition() {
    final currentState = _audioNotifier.state;
    return currentState.playbackSource == 'related' ||
        _audioNotifier._relatedSongsService.isFetchingRelated;
  }

  bool _isRateLimited() {
    if (_lastErrorTime == null) return false;

    final timeSinceLastError = DateTime.now().difference(_lastErrorTime!);
    return timeSinceLastError < ERROR_RATE_LIMIT;
  }

  void _recordError(AudioError error) {
    _recentErrors.add(error);
    _lastErrorTime = error.timestamp;

    // Update error counts
    _errorCounts[error.errorType] = (_errorCounts[error.errorType] ?? 0) + 1;

    // Keep only recent errors
    if (_recentErrors.length > 20) {
      _recentErrors.removeAt(0);
    }

    print('📝 Recorded error: ${error.errorType} - ${error.message}');
  }

  void _scheduleErrorReset() {
    final resetDelay = _isRelatedSongTransition() ? 30 : 45;

    Timer(Duration(seconds: resetDelay), () {
      if (_consecutiveErrors > 0) {
        print('🔄 Resetting error counter after timeout');
        _consecutiveErrors = 0;
        _lastErrorTime = null;
      }
    });
  }

  void _showUserError(AudioError error) {
    // In a real implementation, this would show a toast or dialog
    print('🚨 User Error: ${error.message}');

    // For now, just log - the actual implementation would use Fluttertoast
    // or your app's error display mechanism
  }

  // ==================== DIAGNOSTICS ====================

  Map<String, dynamic> getErrorReport() {
    return {
      'isHandlingError': _isHandlingError,
      'consecutiveErrors': _consecutiveErrors,
      'lastErrorTime': _lastErrorTime?.toIso8601String(),
      'recentErrors': _recentErrors
          .map(
            (e) => {
              'type': e.errorType,
              'message': e.message,
              'timestamp': e.timestamp.toIso8601String(),
              'song': e.songTitle,
            },
          )
          .toList(),
      'errorCounts': _errorCounts,
      'isRateLimited': _isRateLimited(),
    };
  }

  void printErrorReport() {
    final report = getErrorReport();

    print('🔧 === ERROR HANDLER REPORT ===');
    print('   Currently Handling: ${report['isHandlingError']}');
    print('   Consecutive Errors: ${report['consecutiveErrors']}');
    print('   Last Error: ${report['lastErrorTime'] ?? 'None'}');
    print('   Rate Limited: ${report['isRateLimited']}');

    print('   Error Counts:');
    final counts = report['errorCounts'] as Map<String, dynamic>;
    counts.forEach((type, count) {
      print('     $type: $count');
    });

    print('   Recent Errors:');
    final recentErrors = report['recentErrors'] as List;
    for (final error in recentErrors.take(5)) {
      print(
        '     ${error['type']}: ${error['message']} (${error['song'] ?? 'Unknown'})',
      );
    }

    print('==============================');
  }

  void clearErrorHistory() {
    _recentErrors.clear();
    _errorCounts.clear();
    _consecutiveErrors = 0;
    _lastErrorTime = null;
    _isHandlingError = false;

    print('🧹 Error history cleared');
  }

  void dispose() {
    clearErrorHistory();
    print('🧹 Error Handler disposed');
  }
}
