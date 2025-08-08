import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song.dart';
import '../../screens/related_songs_queue.dart';

enum NavigationType { NEXT, PREVIOUS, INDEX, JUMP_TO }

enum NavigationSource { USER, QUEUE, AUTOPLAY, ERROR_RECOVERY, SYSTEM }

class PlaybackContext {
  final String playlistType;
  final String playbackSource;
  final List<Song> currentPlaylist;
  final bool isNetworkPlayback;
  final String? searchQuery;

  PlaybackContext({
    required this.playlistType,
    required this.playbackSource,
    required this.currentPlaylist,
    required this.isNetworkPlayback,
    this.searchQuery,
  });
}

class NavigationRequest {
  final NavigationType type;
  final NavigationSource source;
  final int? targetIndex;
  final bool force;
  final String reason;
  final DateTime createdAt;

  NavigationRequest({
    required this.type,
    required this.source,
    this.targetIndex,
    this.force = false,
    required this.reason,
  }) : createdAt = DateTime.now();
}

/// Centralized navigation controller - THE SINGLE AUTHORITY for all song transitions
class NavigationController {
  final dynamic _audioNotifier;
  final Ref _ref;

  // Callbacks to AudioNotifier
  late Function(dynamic) onStateUpdate;
  late Function(Song, PlaybackContext, int) onPlaySong;

  // Navigation state
  bool _isNavigating = false;
  NavigationRequest? _currentRequest;

  NavigationController(this._audioNotifier, this._ref);

  /// Master navigation method - ALL navigation goes through here
  Future<bool> navigateTo({
    required NavigationType type,
    int? targetIndex,
    NavigationSource source = NavigationSource.USER,
    bool force = false,
    required String reason,
  }) async {
    final request = NavigationRequest(
      type: type,
      source: source,
      targetIndex: targetIndex,
      force: force,
      reason: reason,
    );

    print('🧭 Navigation Request: ${type.name} from ${source.name} - $reason');

    // Priority check - user actions always win
    if (!_canProcessRequest(request)) {
      print('⚠️ Navigation request blocked by priority system');
      return false;
    }

    if (_isNavigating && !force) {
      print('⚠️ Navigation in progress, queuing request');
      return await _queueRequest(request);
    }

    return await _processNavigationRequest(request);
  }

  bool _canProcessRequest(NavigationRequest request) {
    // User actions always have highest priority
    if (request.source == NavigationSource.USER) return true;

    // Don't interrupt user navigation with system/autoplay requests
    if (_currentRequest?.source == NavigationSource.USER &&
        request.source != NavigationSource.USER) {
      return false;
    }

    // Allow forced requests
    if (request.force) return true;

    return true;
  }

  Future<bool> _queueRequest(NavigationRequest request) async {
    // For now, simple approach - just retry after delay
    await Future.delayed(Duration(milliseconds: 500));
    return await _processNavigationRequest(request);
  }

  Future<bool> _processNavigationRequest(NavigationRequest request) async {
    _isNavigating = true;
    _currentRequest = request;

    try {
      final currentState = _audioNotifier.state;

      switch (request.type) {
        case NavigationType.NEXT:
          return await _handleNext(currentState, request);

        case NavigationType.PREVIOUS:
          return await _handlePrevious(currentState, request);

        case NavigationType.INDEX:
          return await _handleIndex(currentState, request);

        case NavigationType.JUMP_TO:
          return await _handleJumpTo(currentState, request);
      }
    } catch (e) {
      print('❌ Navigation error: $e');
      return false;
    } finally {
      _isNavigating = false;
      _currentRequest = null;
    }
  }

  Future<bool> _handleNext(
    dynamic currentState,
    NavigationRequest request,
  ) async {
    print('⏭️ Processing NEXT navigation');

    // Priority 1: Next song in queue
    final nextFromQueue = await _tryNextInQueue();
    if (nextFromQueue) {
      print('✅ Next song found in queue');
      return true;
    }

    // Priority 2: Next song in current playlist
    if (currentState.currentIndex < currentState.playlist.length - 1) {
      print('✅ Next song found in playlist');
      return await _playNextInPlaylist(currentState);
    }

    // Priority 3: Handle autoplay/related songs
    if (request.source == NavigationSource.AUTOPLAY ||
        request.source == NavigationSource.USER) {
      return await _handleAutoplayNext(currentState);
    }

    print('⚠️ No next song available');
    return false;
  }

  Future<bool> _handlePrevious(
    dynamic currentState,
    NavigationRequest request,
  ) async {
    print('⏮️ Processing PREVIOUS navigation');

    // Priority 1: Previous song in queue
    final prevFromQueue = await _tryPreviousInQueue();
    if (prevFromQueue) {
      print('✅ Previous song found in queue');
      return true;
    }

    // Priority 2: Previous song in current playlist
    if (currentState.currentIndex > 0) {
      print('✅ Previous song found in playlist');
      return await _playPreviousInPlaylist(currentState);
    }

    // Priority 3: Restart current song (user navigation only)
    if (request.source == NavigationSource.USER) {
      print('🔄 Restarting current song');
      return await _restartCurrentSong();
    }

    print('⚠️ No previous song available');
    return false;
  }

  Future<bool> _handleIndex(
    dynamic currentState,
    NavigationRequest request,
  ) async {
    if (request.targetIndex == null) return false;

    final targetIndex = request.targetIndex!;
    print('🎯 Processing INDEX navigation to: $targetIndex');

    // Validate index
    if (!canNavigateToIndex(targetIndex)) {
      print('❌ Invalid target index: $targetIndex');
      return false;
    }

    // Navigate to specific index in current playlist
    if (targetIndex >= 0 && targetIndex < currentState.playlist.length) {
      return await _playAtIndex(currentState, targetIndex);
    }

    return false;
  }

  Future<bool> _handleJumpTo(
    dynamic currentState,
    NavigationRequest request,
  ) async {
    if (request.targetIndex == null) return false;

    print('🚀 Processing JUMP_TO navigation');

    // Similar to INDEX but may involve cross-playlist jumps
    return await _handleIndex(currentState, request);
  }

  // ==================== QUEUE OPERATIONS ====================

  Future<bool> _tryNextInQueue() async {
    try {
      final queueState = _ref.read(queueStateProvider);
      final queueNotifier = _ref.read(queueStateProvider.notifier);

      if (queueState.currentOrder.isNotEmpty &&
          queueState.currentIndex < queueState.currentOrder.length - 1) {
        queueNotifier.setCurrentIndex(queueState.currentIndex + 1);
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error trying next in queue: $e');
      return false;
    }
  }

  Future<bool> _tryPreviousInQueue() async {
    try {
      final queueState = _ref.read(queueStateProvider);
      final queueNotifier = _ref.read(queueStateProvider.notifier);

      if (queueState.currentOrder.isNotEmpty && queueState.currentIndex > 0) {
        queueNotifier.setCurrentIndex(queueState.currentIndex - 1);
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error trying previous in queue: $e');
      return false;
    }
  }

  // ==================== PLAYLIST OPERATIONS ====================

  Future<bool> _playNextInPlaylist(dynamic currentState) async {
    try {
      final nextIndex = currentState.currentIndex + 1;
      final nextSong = currentState.playlist[nextIndex];

      await onPlaySong(
        nextSong,
        PlaybackContext(
          playlistType: currentState.playlistType,
          playbackSource: currentState.playbackSource,
          currentPlaylist: currentState.playlist,
          isNetworkPlayback: currentState.isNetworkPlayback,
          searchQuery: currentState.lastSearchQuery,
        ),
        nextIndex,
      );

      return true;
    } catch (e) {
      print('❌ Error playing next in playlist: $e');
      return false;
    }
  }

  Future<bool> _playPreviousInPlaylist(dynamic currentState) async {
    try {
      final prevIndex = currentState.currentIndex - 1;
      final prevSong = currentState.playlist[prevIndex];

      await onPlaySong(
        prevSong,
        PlaybackContext(
          playlistType: currentState.playlistType,
          playbackSource: currentState.playbackSource,
          currentPlaylist: currentState.playlist,
          isNetworkPlayback: currentState.isNetworkPlayback,
          searchQuery: currentState.lastSearchQuery,
        ),
        prevIndex,
      );

      return true;
    } catch (e) {
      print('❌ Error playing previous in playlist: $e');
      return false;
    }
  }

  Future<bool> _playAtIndex(dynamic currentState, int targetIndex) async {
    try {
      final targetSong = currentState.playlist[targetIndex];

      await onPlaySong(
        targetSong,
        PlaybackContext(
          playlistType: currentState.playlistType,
          playbackSource: currentState.playbackSource,
          currentPlaylist: currentState.playlist,
          isNetworkPlayback: currentState.isNetworkPlayback,
          searchQuery: currentState.lastSearchQuery,
        ),
        targetIndex,
      );

      return true;
    } catch (e) {
      print('❌ Error playing at index: $e');
      return false;
    }
  }

  Future<bool> _restartCurrentSong() async {
    try {
      // Use the audio player directly to restart
      await _audioNotifier._audioPlayer.seek(Duration.zero);
      await _audioNotifier._audioPlayer.play();
      return true;
    } catch (e) {
      print('❌ Error restarting current song: $e');
      return false;
    }
  }

  // ==================== AUTOPLAY LOGIC ====================

  Future<bool> _handleAutoplayNext(dynamic currentState) async {
    print('🎵 Handling autoplay next');

    try {
      // Check if we have related songs service available
      final relatedService = _audioNotifier._relatedSongsService;

      // Try to move to next in queue
      if (relatedService.moveToNextInQueue()) {
        print('✅ Moved to next in related queue');
        return true;
      }

      // Force fetch more related songs if current song available
      if (currentState.currentSong != null) {
        print('🚀 Fetching related songs for autoplay');
        relatedService.fetchForSong(currentState.currentSong);
        // This is async, so we return true but playback continues with current
        return false; // No immediate next song, but fetch initiated
      }

      return false;
    } catch (e) {
      print('❌ Error in autoplay next: $e');
      return false;
    }
  }

  // ==================== VALIDATION ====================

  bool canNavigateToIndex(int index) {
    final currentState = _audioNotifier.state;

    if (currentState.playlist.isEmpty) {
      print('⚠️ Cannot navigate: empty playlist');
      return false;
    }

    if (index < 0 || index >= currentState.playlist.length) {
      print(
        '⚠️ Cannot navigate: index $index out of bounds (0-${currentState.playlist.length - 1})',
      );
      return false;
    }

    final targetSong = currentState.playlist[index];
    if (targetSong.audioUrl == null || targetSong.audioUrl!.isEmpty) {
      print('⚠️ Cannot navigate: no audio URL for song at index $index');
      return false;
    }

    return true;
  }

  void validatePlaylistConsistency() {
    final currentState = _audioNotifier.state;

    print('🔍 === PLAYLIST CONSISTENCY CHECK ===');
    print('   Playlist length: ${currentState.playlist.length}');
    print('   Current index: ${currentState.currentIndex}');
    print('   Current song: ${currentState.currentSong?.title ?? 'null'}');

    // Check index bounds
    if (currentState.currentIndex < 0 ||
        currentState.currentIndex >= currentState.playlist.length) {
      print('❌ Index out of bounds!');
    }

    // Check current song matches playlist
    if (currentState.playlist.isNotEmpty &&
        currentState.currentIndex < currentState.playlist.length) {
      final expectedSong = currentState.playlist[currentState.currentIndex];
      if (currentState.currentSong?.videoId != expectedSong.videoId) {
        print('❌ Current song mismatch!');
        print('   Expected: ${expectedSong.title}');
        print('   Actual: ${currentState.currentSong?.title}');
      }
    }

    // Check for songs without audio URLs
    int invalidSongs = 0;
    for (int i = 0; i < currentState.playlist.length; i++) {
      final song = currentState.playlist[i];
      if (song.audioUrl == null || song.audioUrl!.isEmpty) {
        invalidSongs++;
      }
    }

    if (invalidSongs > 0) {
      print('⚠️ Found $invalidSongs songs without audio URLs');
    }

    print('================================');
  }

  // ==================== UTILITY ====================

  /// Get navigation priority for request source
  int _getNavigationPriority(NavigationSource source) {
    switch (source) {
      case NavigationSource.USER:
        return 1; // Highest priority
      case NavigationSource.ERROR_RECOVERY:
        return 2;
      case NavigationSource.QUEUE:
        return 3;
      case NavigationSource.AUTOPLAY:
        return 4;
      case NavigationSource.SYSTEM:
        return 5; // Lowest priority
    }
  }

  /// Check if we should interrupt current navigation
  bool shouldInterruptNavigation(NavigationSource newSource) {
    if (_currentRequest == null) return true;

    final currentPriority = _getNavigationPriority(_currentRequest!.source);
    final newPriority = _getNavigationPriority(newSource);

    return newPriority < currentPriority; // Lower number = higher priority
  }

  /// Get current navigation status
  Map<String, dynamic> getNavigationStatus() {
    return {
      'isNavigating': _isNavigating,
      'currentRequest': _currentRequest != null
          ? {
              'type': _currentRequest!.type.name,
              'source': _currentRequest!.source.name,
              'reason': _currentRequest!.reason,
              'createdAt': _currentRequest!.createdAt.toIso8601String(),
            }
          : null,
    };
  }

  void dispose() {
    _currentRequest = null;
    _isNavigating = false;
  }
}
