import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:houston/models/lyrics_model.dart';
import 'package:houston/providers/audio/related_songs_service.dart';
import 'package:houston/providers/managers/download_manager.dart';

import 'package:houston/screens/related_songs_queue.dart';
import 'package:houston/services/storage_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../models/song.dart';

// ==================== STATE DEFINITION ====================
class OperationCancelledException implements Exception {
  final String message;
  OperationCancelledException(this.message);

  @override
  String toString() => 'OperationCancelledException: $message';
}

/// Represents the current state of audio playback
final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  return AudioNotifier(ref);
});

class AudioState {
  final Song? currentSong;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isLoading;
  final List<Song> playlist;
  final int currentIndex;
  final bool isFavorite;
  final int? audioSessionId;
  final bool isLooping;
  final bool isSaved;
  final List<LyricsLine> currentLyrics;

  final String playlistType; // 'saved', 'search', 'related'
  final String playbackSource; // 'search', 'saved', 'artist', 'related'
  final bool isNetworkPlayback;
  final String? lastSearchQuery;

  final DateTime? sleepTimerEndTime;

  AudioState({
    this.currentSong,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.isLoading,
    required this.playlist,
    required this.currentIndex,
    required this.isFavorite,
    required this.isLooping,
    required this.isSaved,
    this.audioSessionId,
    required this.currentLyrics,

    this.playlistType = 'search',
    this.playbackSource = 'search',
    this.isNetworkPlayback = true,
    this.lastSearchQuery,

    this.sleepTimerEndTime,
  });

  AudioState copyWith({
    Song? currentSong,
    bool? isPlaying,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isLoading,
    List<Song>? playlist,
    int? currentIndex,
    bool? isFavorite,
    bool? isLooping,
    bool? isSaved,
    int? audioSessionId,
    List<LyricsLine>? currentLyrics,
    bool? autoplayEnabled,
    List<Song>? relatedSongs,
    bool? isFetchingRelated,
    String? playlistType,
    String? playbackSource,
    bool? isNetworkPlayback,
    String? lastSearchQuery,
    Song? seedSong,
    String? lastRelatedSongTitle,
    String? lastRelatedSongArtist,
    bool? hasTriggeredRelatedFetch,
    DateTime? sleepTimerEndTime,
    bool clearSleepTimer = false,
  }) {
    return AudioState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isLoading: isLoading ?? this.isLoading,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isFavorite: isFavorite ?? this.isFavorite,
      isLooping: isLooping ?? this.isLooping,
      isSaved: isSaved ?? this.isSaved,
      audioSessionId: audioSessionId ?? this.audioSessionId,
      currentLyrics: currentLyrics ?? this.currentLyrics,

      playlistType: playlistType ?? this.playlistType,
      playbackSource: playbackSource ?? this.playbackSource,
      isNetworkPlayback: isNetworkPlayback ?? this.isNetworkPlayback,
      lastSearchQuery: lastSearchQuery ?? this.lastSearchQuery,

      sleepTimerEndTime: clearSleepTimer
          ? null
          : (sleepTimerEndTime ?? this.sleepTimerEndTime),
    );
  }
}

// ==================== AUDIO NOTIFIER ====================

/// Manages all audio playback and state
class AudioNotifier extends StateNotifier<AudioState> {
  // Dependencies
  final AudioPlayer _audioPlayer = AudioPlayer();
  final StorageService _storageService = StorageService();
  final DownloadManager _downloadManager = DownloadManager();
  final Set<String> _currentlyDownloading = {};
  final Ref _ref;
  late final RelatedSongsService _relatedSongsService;
  // Cache for saved status to avoid repeated checks
  final Map<String, bool> _savedStatusCache = {};
  // ignore: unused_field
  String? _lastCheckedSongKey;
  Timer? _sleepTimer;
  // Getters
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  @override
  bool get mounted => !super.mounted || super.hasListeners;
  String _getSongKey(Song song) => '${song.title}|${song.artists}';
  bool _isHandlingError = false;
  int _consecutiveErrors = 0;
  static const int MAX_CONSECUTIVE_ERRORS = 3;
  DateTime? _lastErrorTime;
  Completer<void>? _currentOperation;
  String _currentOperationId = '';
  bool _isTransitioning = false;
  int _operationCounter = 0;
  // ignore: unused_field
  bool _hasTriggeredAutoplayPrep = false;
  // ignore: unused_field
  String? _lastAutoplayPrepSong;

  // ==================== INITIALIZATION ====================

  AudioNotifier(this._ref)
    : super(
        AudioState(
          isPlaying: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          isLoading: false,
          playlist: [],
          currentIndex: 0,
          isFavorite: false,
          isLooping: false,
          isSaved: false,
          audioSessionId: null,
          currentLyrics: [],

          playlistType: 'search',
          playbackSource: 'search',
          isNetworkPlayback: true,
          lastSearchQuery: null,
        ),
      ) {
    _initializePlayer();
    _initializeRelatedSongsService();
    _setupQueueListener();
  }

  // FIXED: Position stream listener in _initializePlayer
  void _initializePlayer() {
    // Duration updates
    _audioPlayer.durationStream.listen(
      (duration) {
        if (duration != null && mounted) {
          state = state.copyWith(totalDuration: duration);
        }
      },
      onError: (error) {
        print('❌ Duration stream error: $error');
        // Don't show toast for duration errors
      },
    );

    // FIXED: Only handle successful events - NO error handling here
    _audioPlayer.playbackEventStream.listen((event) {
      // Only handle successful events - removed all error handling
      if (event.processingState == ProcessingState.ready) {
        print('✅ Audio ready to play');
        _consecutiveErrors = 0;
        _lastErrorTime = null;
        _isHandlingError = false; // Reset error handling flag
      } else if (event.processingState == ProcessingState.completed) {
        print('🏁 Audio playback completed');
        if (!state.isLooping) {
          _handleAutoplayOnCompletion();
        }
      }
    });

    // FIXED: Much more selective player state error handling
    _audioPlayer.playerStateStream.listen(
      (playerState) {
        if (!mounted) return;

        final isNowPlaying = playerState.playing;
        final processingState = playerState.processingState;

        // Handle different processing states
        switch (processingState) {
          case ProcessingState.idle:
            print('🔄 Player idle');
            break;
          case ProcessingState.loading:
            print('🔄 Loading audio...');
            break;
          case ProcessingState.buffering:
            print('🔄 Buffering...');
            break;
          case ProcessingState.ready:
            print('✅ Audio ready');
            _consecutiveErrors = 0;
            _lastErrorTime = null;
            _isHandlingError = false;
            break;
          case ProcessingState.completed:
            print('🏁 Audio completed');
            if (!state.isLooping) {
              _handleAutoplayOnCompletion();
            }
            break;
        }

        state = state.copyWith(
          isPlaying: isNowPlaying,
          isLoading:
              processingState == ProcessingState.loading ||
              processingState == ProcessingState.buffering,
        );
      },
      onError: (error) {
        print('❌ Player state error: $error');

        // FIXED: Completely ignore MediaCodec cleanup errors
        if (!mounted || _isHandlingError) return;

        final errorString = error.toString().toLowerCase();

        // FIXED: Ignore ALL MediaCodec buffer and connection aborted errors
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
          return;
        }

        // FIXED: Only handle REAL network/connection errors
        final isRealError =
            errorString.contains('unable to connect') ||
            errorString.contains('network error') ||
            errorString.contains('connection timeout') ||
            errorString.contains('http error 403') ||
            errorString.contains('http error 404') ||
            errorString.contains('source error') ||
            errorString.contains('format not supported');

        if (!isRealError) {
          print('⚠️ Ignoring non-critical error: $error');
          return;
        }

        // Rate limit error handling - prevent rapid retries
        final now = DateTime.now();
        if (_lastErrorTime != null &&
            now.difference(_lastErrorTime!).inSeconds < 10) {
          print('⚠️ Error rate limited - ignoring');
          return;
        }

        _lastErrorTime = now;
        state = state.copyWith(isPlaying: false, isLoading: false);

        _showErrorToast('Connection error. Trying to recover...');

        // Delay error handling to allow for natural recovery
        Future.delayed(Duration(milliseconds: 5000), () {
          if (mounted && !_isHandlingError) {
            _handlePlaybackError();
          }
        });
      },
    );

    // FIXED: Position stream with proper autoplay trigger
    _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;

      state = state.copyWith(currentPosition: position);

      // FIXED: Better autoplay preparation logic with stricter conditions
      if (_consecutiveErrors == 0 &&
          state.totalDuration != Duration.zero &&
          position.inMilliseconds > 0 &&
          !state.isLooping &&
          state.currentSong != null) {
        final halfDuration = state.totalDuration.inMilliseconds ~/ 2;
        final remainingTime = state.totalDuration - position;

        // FIXED: 50% mark reached - check conditions before preparing autoplay
        if (position.inMilliseconds >= halfDuration &&
            remainingTime.inSeconds > 10) {
          // FIXED: Only prepare autoplay for specific conditions
          bool shouldPrepareAutoplay = false;

          if (state.playbackSource == 'search') {
            // Always prepare for search songs
            shouldPrepareAutoplay = true;
            print('🎯 50% mark reached - preparing autoplay for SEARCH song');
          } else if (state.playbackSource == 'saved') {
            // Only prepare for saved songs when queue is low
            final remainingSongs =
                state.playlist.length - state.currentIndex - 1;
            if (remainingSongs <= 2) {
              shouldPrepareAutoplay = true;
              print(
                '🎯 50% mark reached - preparing autoplay for SAVED song (queue low: $remainingSongs remaining)',
              );
            } else {
              print(
                '🚫 50% mark reached - SKIPPING autoplay for SAVED song (queue has $remainingSongs remaining)',
              );
            }
          } else if (state.playbackSource == 'artist') {
            // Only prepare for artist songs when queue is low
            final remainingSongs =
                state.playlist.length - state.currentIndex - 1;
            if (remainingSongs <= 2) {
              shouldPrepareAutoplay = true;
              print(
                '🎯 50% mark reached - preparing autoplay for ARTIST song (queue low: $remainingSongs remaining)',
              );
            } else {
              print(
                '🚫 50% mark reached - SKIPPING autoplay for ARTIST song (queue has $remainingSongs remaining)',
              );
            }
          } else {
            print(
              '🚫 50% mark reached - SKIPPING autoplay for ${state.playbackSource} source',
            );
          }

          // Only trigger autoplay if conditions are met
          if (shouldPrepareAutoplay) {
            _relatedSongsService.prepareForAutoplay(
              state.currentSong!,
              state.playbackSource,
              _relatedSongsService.hasTriggeredRelatedFetch,
            );
          }
        }

        // FIXED: Auto-switch to related songs near end (85% mark) - ONLY for search
        if (state.playbackSource == 'search') {
          final eightyFivePercent = (state.totalDuration.inMilliseconds * 0.85)
              .round();
          if (position.inMilliseconds >= eightyFivePercent &&
              remainingTime.inSeconds <= 15 &&
              remainingTime.inSeconds > 5) {
            print(
              '🔄 85% mark reached - attempting auto-switch to related (SEARCH only)',
            );
            _attemptAutoSwitchToRelated();
          }
        }
      }
    });
  }

  // NEW: Method to attempt auto-switch to related songs
  Future<void> _attemptAutoSwitchToRelated() async {
    if (state.currentSong == null || _isTransitioning) return;

    final queueState = _ref.read(queueStateProvider);

    // Check if we have related songs ready
    if (queueState.currentOrder.isNotEmpty) {
      print('🔄 Auto-switching to related songs queue');

      // Set the queue to start from the first related song
      final queueNotifier = _ref.read(queueStateProvider.notifier);
      queueNotifier.setCurrentIndex(0);

      // The queue listener will handle the actual song transition
    } else {
      print('⚠️ No related songs available for auto-switch');
      // Force fetch if we don't have related songs
      _relatedSongsService.fetchForSong(state.currentSong!);
    }
  }

  // REPLACE _initializeRelatedSongsManager WITH THIS:
  void _initializeRelatedSongsService() {
    _relatedSongsService = RelatedSongsService(
      _ref,
      _onRelatedSongsUpdate,
      _onQueueEmpty,
    );

    // Setup queue listener for playback sync
    _ref.listen<QueueState>(queueStateProvider, (previous, current) {
      print('🔔 === QUEUE STATE CHANGED (AudioNotifier) ===');
      print('   Previous index: ${previous?.currentIndex ?? 'null'}');
      print('   Current index: ${current.currentIndex}');
      print('   Queue length: ${current.currentOrder.length}');

      // Only process if index actually changed AND is valid
      if (previous?.currentIndex != current.currentIndex &&
          current.currentOrder.isNotEmpty &&
          current.currentIndex >= 0 &&
          current.currentIndex < current.currentOrder.length) {
        final targetSong = current.currentOrder[current.currentIndex];
        print('   Target song: ${targetSong.title}');
        print('   Current playing: ${state.currentSong?.title ?? 'none'}');

        // Only sync if it's actually a different song
        if (state.currentSong?.videoId != targetSong.videoId) {
          print('🔄 Syncing to new queue song');
          _syncWithQueueState(current);
        } else {
          print('⏭️ Same song, updating state only');
          // Update state without changing playback
          state = state.copyWith(
            playlist: current.currentOrder,
            currentIndex: current.currentIndex,
            playlistType: 'related',
            playbackSource: 'related',
          );
        }
      }
    });
  }

  // ADD THESE CALLBACK METHODS:
  void _onRelatedSongsUpdate(List<Song> songs, bool isFetching) {
    // Update local state if needed - for now just log
    print(
      '🔔 Related songs updated: ${songs.length} songs, fetching: $isFetching',
    );
  }

  void _onQueueEmpty() {
    print('🔔 Queue is empty - might need to handle fallback');
    // Handle empty queue scenario if needed
  }

  // Setup queue listener - COMPLETE FIXED
  void _setupQueueListener() {
    _ref.listen<QueueState>(queueStateProvider, (previous, current) {
      print('🔔 === QUEUE STATE CHANGED ===');
      print('   Previous index: ${previous?.currentIndex ?? 'null'}');
      print('   Current index: ${current.currentIndex}');
      print('   Queue length: ${current.currentOrder.length}');

      // Always update our state with current queue
      state = state.copyWith(relatedSongs: current.currentOrder);

      // FIXED: Only process if index actually changed AND is valid
      if (previous?.currentIndex != current.currentIndex &&
          current.currentOrder.isNotEmpty &&
          current.currentIndex >= 0 &&
          current.currentIndex < current.currentOrder.length) {
        final targetSong = current.currentOrder[current.currentIndex];
        print('   Target song: ${targetSong.title}');
        print('   Current playing: ${state.currentSong?.title ?? 'none'}');

        // FIXED: Only sync if it's actually a different song
        if (state.currentSong?.videoId != targetSong.videoId) {
          print('🔄 Syncing to new queue song');
          _syncWithQueueState(current);
        } else {
          print('⏭️ Same song, updating state only');
          // Update state without changing playback
          state = state.copyWith(
            playlist: current.currentOrder,
            currentIndex: current.currentIndex,
            playlistType: 'related',
            playbackSource: 'related',
          );
        }
      }
    });
  }

  Future<void> cancelCurrentOperation(String reason) async {
    await _cancelCurrentOperation(reason);
  }
  // ==================== PLAYBACK CONTROL ====================

  Future<void> playSong(
    Song song, {
    List<Song>? playlist,
    int? index,
    String? playlistType,
    String? playbackSource,
  }) async {
    if (!mounted) return;

    final operationId =
        'play_${++_operationCounter}_${DateTime.now().millisecondsSinceEpoch}';
    print('🎵 Playing song: ${song.title} [Operation: $operationId]');

    // FIXED: Better source determination logic with normalization
    String source;
    if (playbackSource != null) {
      source = _normalizePlaybackSource(playbackSource);
      print(
        '🎯 Using provided playback source: $playbackSource -> normalized: $source',
      );
    } else {
      source = _determinePlaybackSource(song, playlist);
      print('🎯 Determined playback source: $source');
    }

    // FIXED: Updated source recognition to include all variants
    final isUserInitiated =
        source == 'search' ||
        source == 'saved' ||
        source == 'artist' ||
        source == 'quickpicks' ||
        source == 'youtube_quick_picks' ||
        source == 'trending' ||
        source == 'playlist'; // ADD THIS LINE

    final isManualRelatedSelection = source == 'related' && index != null;

    // FIXED: Always allow user-initiated playback including playlist
    final shouldCancelPrevious = isUserInitiated || isManualRelatedSelection;

    if (shouldCancelPrevious) {
      await _cancelCurrentOperation('User selected new song from $source');
      await Future.delayed(Duration(milliseconds: 50));
    } else if (_currentOperation != null && !_currentOperation!.isCompleted) {
      // For automatic related song transitions, check if we should skip
      if (source == 'related') {
        if (state.currentSong?.videoId == song.videoId) {
          print('⚠️ Same song already playing, skipping: $operationId');
          return;
        }
        await _cancelCurrentOperation('Different related song selected');
        await Future.delayed(Duration(milliseconds: 50));
      } else {
        print('⚠️ Operation already in progress, skipping: $operationId');
        return;
      }
    }

    // Validate audio URL first
    if (song.audioUrl == null || song.audioUrl!.isEmpty) {
      print('❌ No audio URL available for: ${song.title}');
      _showErrorToast('No audio source available for this song');
      return;
    }

    // Create new operation
    final operation = Completer<void>();
    _currentOperation = operation;
    _currentOperationId = operationId;

    state = state.copyWith(isLoading: true);
    final isNetwork = song.audioUrl!.startsWith('http');

    try {
      print("🎵 AudioURL: ${song.audioUrl} [Operation: $operationId]");
      print("🎯 Final playback source: $source"); // Debug log

      // Check if operation was cancelled
      if (_isOperationCancelled(operationId)) {
        print('🚫 Operation cancelled before audio setup: $operationId');
        return;
      }

      // Stop current playback and wait for completion
      if (_audioPlayer.playing) {
        print('🛑 Stopping current playback... [Operation: $operationId]');
        await _audioPlayer.stop();
        await Future.delayed(Duration(milliseconds: 100));

        // Check cancellation after stop
        if (_isOperationCancelled(operationId)) {
          print('🚫 Operation cancelled after stop: $operationId');
          return;
        }
      }

      // Reset player state before setting new source
      await _audioPlayer.setVolume(1.0);

      // Create audio source
      final audioSource = AudioSource.uri(
        Uri.parse(song.audioUrl!),
        tag: MediaItem(
          id: song.videoId ?? song.audioUrl!,
          title: song.title,
          artist: song.artists,
          artUri: _parseArtUri(song.albumArt),
        ),
      );

      // Check cancellation before setting source
      if (_isOperationCancelled(operationId)) {
        print('🚫 Operation cancelled before setting source: $operationId');
        return;
      }

      // Set audio source with proper timeout
      print('🔄 Setting audio source... [Operation: $operationId]');
      if (isNetwork) {
        await _audioPlayer
            .setAudioSource(audioSource)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Audio loading timed out',
                  Duration(seconds: 15),
                );
              },
            );
      } else {
        await _audioPlayer.setAudioSource(audioSource);
      }

      // Final cancellation check before completing
      if (_isOperationCancelled(operationId)) {
        print('🚫 Operation cancelled after setting source: $operationId');
        return;
      }

      print('✅ Audio source set successfully [Operation: $operationId]');

      // Get session ID and saved status
      final sessionId = _audioPlayer.androidAudioSessionId;
      final isSaved = await _storageService.isSongSaved(song);

      // FIXED: Clear related songs only for new non-related songs (including all quickpicks variants)
      if (source != 'related') {
        final isDifferentSong =
            state.currentSong == null ||
            state.currentSong!.videoId != song.videoId;

        // FIXED: Include all quickpicks variants
        final isQuickpicksVariant =
            source == 'quickpicks' ||
            source == 'youtube_quick_picks' ||
            source == 'trending';

        if (source == 'search' ||
            isQuickpicksVariant ||
            (isDifferentSong && source != 'related')) {
          print(
            '🧹 Clearing related songs for new song or search/quickpicks: $source',
          );
          _relatedSongsService.clearRelatedData();

          // Also clear queue for search and quickpicks variants
          if (source == 'search' || isQuickpicksVariant) {
            final queueNotifier = _ref.read(queueStateProvider.notifier);
            queueNotifier.clearQueue();
          }
        }
      }

      // Determine correct index for queue-based playback
      final correctIndex = source == 'related' && index != null
          ? index
          : (index ?? 0);

      // Update state before playing - ENSURE SOURCE IS CORRECTLY SET
      state = state.copyWith(
        currentSong: song,
        playlist: playlist ?? [song],
        currentIndex: correctIndex,
        isLoading: false,
        audioSessionId: sessionId,
        isSaved: isSaved,
        playlistType: playlistType ?? source,
        playbackSource: source, // Use the normalized source
        isNetworkPlayback: isNetwork,
      );

      // Start playback
      print('▶️ Starting playback... [Operation: $operationId]');
      print('🎯 State updated with source: ${state.playbackSource}');

      // Reset autoplay preparation trigger for new song
      _hasTriggeredAutoplayPrep = false;
      _lastAutoplayPrepSong = null;

      await _audioPlayer.play();
      print(
        '✅ Song started playing - Source: ${state.playbackSource} [Operation: $operationId]',
      );

      // Complete operation successfully
      if (!operation.isCompleted && _currentOperationId == operationId) {
        operation.complete();
      }

      // FIXED: Auto-fetch related songs with proper conditions (including quickpicks variants)
      if (source != 'related') {
        print('🔍 === AUTO FETCH CHECK (AudioNotifier) ===');
        print('   Song: ${song.title} by ${song.artists}');
        print('   Source: $source');
        print('   Playlist length: ${state.playlist.length}');
        print('   Current index: ${state.currentIndex}');

        final isQuickpicksVariant =
            source == 'quickpicks' ||
            source == 'youtube_quick_picks' ||
            source == 'trending';

        // Don't fetch related songs for quickpicks variants or playlists
        if (isQuickpicksVariant || source == 'playlist') {
          print('   ❌ Skipping related songs fetch for ${source}');
        }
        // Only fetch for saved songs when queue is low (2 or fewer remaining)
        else if (source == 'saved') {
          final remainingSongs =
              (playlist?.length ?? state.playlist.length) -
              (index ?? state.currentIndex) -
              1;
          print('   Remaining saved songs: $remainingSongs');

          if (remainingSongs <= 2) {
            print('   ✅ Queue low, enabling auto-fetch for related songs');
            _relatedSongsService.autoFetchRelatedSongs(song, source);
          } else {
            print(
              '   ❌ Queue has enough songs ($remainingSongs remaining), skipping related fetch',
            );
          }
        }
        // Only fetch for artist songs when queue is low (2 or fewer remaining)
        else if (source == 'artist') {
          final remainingSongs =
              (playlist?.length ?? state.playlist.length) -
              (index ?? state.currentIndex) -
              1;
          print('   Remaining artist songs: $remainingSongs');

          if (remainingSongs <= 2) {
            print('   ✅ Queue low, enabling auto-fetch for related songs');
            _relatedSongsService.autoFetchRelatedSongs(song, source);
          } else {
            print(
              '   ❌ Queue has enough songs ($remainingSongs remaining), skipping related fetch',
            );
          }
        }
        // For search sources, continue normal behavior
        else if (source == 'search') {
          print('   ✅ Enabling auto-fetch for related songs (SEARCH)');
          _relatedSongsService.autoFetchRelatedSongs(song, source);
        } else {
          print('   ❌ Unknown source type, skipping related fetch');
        }
      }
    } catch (e) {
      print('❌ Error playing song [Operation: $operationId]: $e');

      // Complete operation with error only if it's the current operation
      if (!operation.isCompleted && _currentOperationId == operationId) {
        operation.complete(); // Complete normally to avoid unhandled exceptions
      }

      // Clear loading state
      if (mounted && _currentOperationId == operationId) {
        state = state.copyWith(isLoading: false);
      }

      // Only show error if this operation wasn't cancelled
      if (!_isOperationCancelled(operationId)) {
        final errorMessage = _getErrorMessage(e);
        _showErrorToast(errorMessage);
        await _handlePlaybackError();
      }
    } finally {
      // Clear current operation if it matches
      if (_currentOperationId == operationId) {
        _currentOperation = null;
        _currentOperationId = '';
      }
    }
  }

  // NEW: Method to normalize playback source names
  // Updated _normalizePlaybackSource method in AudioNotifier
  String _normalizePlaybackSource(String source) {
    switch (source.toLowerCase()) {
      case 'youtube_quick_picks':
      case 'quickpicks':
      case 'trending':
      case 'quick_picks':
        return 'quickpicks';
      case 'search':
      case 'youtube_search':
        return 'search';
      case 'artist':
      case 'artist_songs':
        return 'artist';
      case 'related':
      case 'related_songs':
        return 'related';
      case 'saved':
      case 'local':
      case 'downloaded':
        return 'saved';
      case 'playlist':
      case 'custom_playlist':
        return 'playlist'; // ADD THIS LINE
      default:
        return source; // Return as-is if no normalization needed
    }
  }

  // Helper method to get error message
  String _getErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (error.toString().contains('Unable to connect')) {
      return 'Unable to connect to audio source. Please try again.';
    } else if (error.toString().contains('Format not supported')) {
      return 'Audio format not supported.';
    } else if (error.toString().contains('403') ||
        error.toString().contains('Forbidden')) {
      return 'Audio source unavailable. Trying alternative source...';
    } else if (error.toString().contains('404') ||
        error.toString().contains('Not Found')) {
      return 'Audio file not found.';
    } else {
      return 'Playback failed. Please try again.';
    }
  }

  /// Show error toast notification
  void _showErrorToast(String message) {
    _logPlayerState();
    // Using fluttertoast package
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.red.shade700,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  Future<void> pauseResume({
    bool fadeOnPause = true,
    Duration fadeDuration = const Duration(milliseconds: 800),
  }) async {
    // Don't allow pause/resume during loading, error handling, or transitions
    if (state.isLoading || _isHandlingError || _isTransitioning) {
      print(
        '⚠️ Cannot pause/resume during loading, error handling, or transition',
      );
      return;
    }

    try {
      if (state.isPlaying) {
        print('⏸️ Pausing playback');
        if (fadeOnPause) {
          await _fadeOutAndPause(fadeDuration);
        } else {
          await _audioPlayer.pause();
        }
      } else {
        print('▶️ Resuming playback');

        // Check if we have a valid current song and audio source
        if (state.currentSong?.audioUrl == null) {
          print('⚠️ No valid audio source to resume');
          return;
        }

        // Check if audio player has a valid source
        if (_audioPlayer.audioSource == null) {
          print('🔄 No audio source set, attempting to reload...');
          if (state.currentSong != null) {
            await playSong(
              state.currentSong!,
              playlist: state.playlist,
              index: state.currentIndex,
              playlistType: state.playlistType,
              playbackSource: state.playbackSource,
            );
          }
          return;
        }

        // Simple resume logic
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play();

        // Update session ID if changed
        final currentSessionId = _audioPlayer.androidAudioSessionId;
        if (currentSessionId != state.audioSessionId) {
          state = state.copyWith(audioSessionId: currentSessionId);
        }
      }
    } catch (e) {
      print('❌ Error in pauseResume: $e');

      // Don't trigger full error handling for pause/resume errors
      try {
        await _audioPlayer.setVolume(1.0);
        if (mounted) {
          state = state.copyWith(isPlaying: false, isLoading: false);
        }
      } catch (e2) {
        print('❌ Error in pauseResume fallback: $e2');
      }
    }
  }

  // Add this method to AudioNotifier for better error diagnosis
  void _logPlayerState() {
    print('🔍 === PLAYER STATE DEBUG ===');
    print('   Player playing: ${_audioPlayer.playing}');
    print('   Player processing state: ${_audioPlayer.processingState}');
    print(
      '   Audio source: ${_audioPlayer.audioSource != null ? 'Present' : 'NULL'}',
    );
    print('   Current song: ${state.currentSong?.title ?? 'NULL'}');
    print('   Audio URL: ${state.currentSong?.audioUrl ?? 'NULL'}');
    print('   Is loading: ${state.isLoading}');
    print('   Is playing (state): ${state.isPlaying}');
    print('   Consecutive errors: $_consecutiveErrors');
    print('   Is handling error: $_isHandlingError');
    print('   Last error time: $_lastErrorTime');
    print('=========================');
  }

  /// Helper method for fade-out and pause
  Future<void> _fadeOutAndPause(Duration fadeDuration) async {
    const initialVolume = 1.0;
    const steps = 10;
    final stepDuration = Duration(
      milliseconds: fadeDuration.inMilliseconds ~/ steps,
    );

    for (int i = steps; i >= 0; i--) {
      if (!mounted || !state.isPlaying) break;

      final volume = (i / steps) * initialVolume;
      await _audioPlayer.setVolume(volume);

      if (i > 0) {
        await Future.delayed(stepDuration);
      }
    }

    await _audioPlayer.pause();
    print('🔇 Faded out and paused');
  }

  /// Seek to specific position in current track
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Simplified previous song
  Future<void> playPrevious() async {
    print('⏮️ Manual playPrevious called');

    final queueState = _ref.read(queueStateProvider);
    final queueNotifier = _ref.read(queueStateProvider.notifier);

    try {
      // Priority 1: Previous song in queue
      if (queueState.currentOrder.isNotEmpty && queueState.currentIndex > 0) {
        queueNotifier.setCurrentIndex(queueState.currentIndex - 1);
        return;
      }

      // Priority 2: Previous song in playlist
      if (state.currentIndex > 0) {
        await playSong(
          state.playlist[state.currentIndex - 1],
          playlist: state.playlist,
          index: state.currentIndex - 1,
          playlistType: state.playlistType,
          playbackSource: state.playbackSource,
        );
        return;
      }

      // Fallback: restart current
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (e) {
      print('❌ Error in playPrevious: $e');
      // Simple fallback - just continue
    }
  }

  // UPDATE playNext method to use service:
  Future<void> playNext() async {
    print('🎵 Manual playNext called');

    try {
      // Priority 1: Next song in current playlist
      if (state.currentIndex < state.playlist.length - 1) {
        print('📋 Playing next song in current playlist');
        await _playNextInPlaylist();
        return;
      }

      // Priority 2: Use related songs service for queue navigation
      if (_relatedSongsService.moveToNextInQueue()) {
        print('✅ Successfully moved to next song in queue');
        return;
      }

      // Priority 3: Force fetch more related songs
      if (state.currentSong != null) {
        print('🚀 Queue empty, fetching related songs');
        _relatedSongsService.fetchForSong(state.currentSong!);
        return;
      }

      // Fallback: restart current
      print('🔄 Fallback: restarting current song');
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (e) {
      print('❌ Error in playNext: $e');
    }
  }

  // FIXED: handleSearchResults method - properly clear related data
  Future<void> handleSearchResults(
    List<Song> searchResults,
    String query,
  ) async {
    if (searchResults.isEmpty) return;

    print('🔍 Handling search results for query: "$query"');
    final firstSong = searchResults.first;

    // Force clear all related data immediately for new search
    print('🧹 Clearing related data for new search');
    _relatedSongsService.clearRelatedData();

    // Also clear the queue state
    final queueNotifier = _ref.read(queueStateProvider.notifier);
    queueNotifier.clearQueue();

    // Use service to handle new search
    _relatedSongsService.handleNewSearchQuery(query);

    state = state.copyWith(lastSearchQuery: query);

    // EXPLICIT source setting
    await playSong(
      firstSong,
      playlist: searchResults,
      index: 0,
      playlistType: 'search',
      playbackSource: 'search', // EXPLICIT
    );
  }

  /// Play artist songs
  Future<void> playArtistSongs(
    List<Song> artistSongs, {
    int startIndex = 0,
  }) async {
    if (artistSongs.isEmpty) return;

    // EXPLICIT source setting
    await playSong(
      artistSongs[startIndex],
      playlist: artistSongs,
      index: startIndex,
      playlistType: 'artist',
      playbackSource: 'artist', // EXPLICIT
    );
  }

  /// Play saved songs
  Future<void> playSavedSongs(
    List<Song> savedSongs, {
    int startIndex = 0,
  }) async {
    if (savedSongs.isEmpty) return;

    // EXPLICIT source setting
    await playSong(
      savedSongs[startIndex],
      playlist: savedSongs,
      index: startIndex,
      playlistType: 'saved',
      playbackSource: 'saved', // EXPLICIT
    );
  }

  // UPDATE playSearchResults to use service:
  Future<void> playSearchResults(
    List<Song> searchResults, {
    int startIndex = 0,
    String? searchQuery,
  }) async {
    if (searchResults.isEmpty) return;

    print('🎵 Playing search results - startIndex: $startIndex');
    final targetSong = searchResults[startIndex];

    // Use service to clear related data
    _relatedSongsService.clearRelatedData();

    state = state.copyWith(lastSearchQuery: searchQuery);

    // EXPLICIT source setting
    await playSong(
      targetSong,
      playlist: searchResults,
      index: startIndex,
      playlistType: 'search',
      playbackSource: 'search', // EXPLICIT
    );
  }

  // ADD: Method to play related song using service
  Future<void> playRelated(Song song) async {
    try {
      print('🎵 playRelated called for: ${song.title}');

      if (_relatedSongsService.playRelatedSong(song)) {
        print('✅ Successfully set queue to play related song');
      } else {
        print('❌ Failed to play related song');
        await _handlePlaybackError();
      }
    } catch (e) {
      print('❌ Error in playRelated: $e');
      await _handlePlaybackError();
    }
  }

  // NEW: Direct transition method for related songs
  Future<void> _transitionToRelatedSong(
    Song song,
    QueueState queueState,
  ) async {
    print('🔄 Direct transition to related song: ${song.title}');

    try {
      state = state.copyWith(isLoading: true);

      // Stop current playback gently
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
        await Future.delayed(Duration(milliseconds: 200));
      }

      // Create new audio source
      final audioSource = AudioSource.uri(
        Uri.parse(song.audioUrl!),
        tag: MediaItem(
          id: song.videoId,
          title: song.title,
          artist: song.artists,
          artUri: _parseArtUri(song.albumArt),
        ),
      );

      // Set new source
      await _audioPlayer.setAudioSource(audioSource);

      // Update state
      final isSaved = await _storageService.isSongSaved(song);
      final sessionId = _audioPlayer.androidAudioSessionId;

      state = state.copyWith(
        currentSong: song,
        playlist: queueState.currentOrder,
        currentIndex: queueState.currentIndex,
        isLoading: false,
        audioSessionId: sessionId,
        isSaved: isSaved,
        playlistType: 'related',
        playbackSource: 'related',
        isNetworkPlayback: song.audioUrl!.startsWith('http'),
      );

      // Start playback
      await _audioPlayer.play();
      print('✅ Direct transition completed successfully');
    } catch (e) {
      print('❌ Direct transition failed: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
      // Don't call error handler immediately - let natural recovery happen
    }
  }

  // FIXED: Much more conservative error handling
  Future<void> _handlePlaybackError() async {
    if (_isHandlingError) {
      print('⚠️ Already handling error, skipping...');
      return;
    }

    _isHandlingError = true;
    _consecutiveErrors++;

    print('🔧 Handling playback error... (attempt $_consecutiveErrors)');

    try {
      // Reset loading state immediately
      if (mounted) {
        state = state.copyWith(isLoading: false, isPlaying: false);
      }

      // FIXED: Better detection of related song transitions
      final isRelatedTransition = _isCurrentlyHandlingRelatedTransition();
      final maxErrors = isRelatedTransition
          ? 8
          : MAX_CONSECUTIVE_ERRORS; // More lenient for related

      if (_consecutiveErrors >= maxErrors) {
        print('❌ Too many consecutive errors, stopping playback');
        await _audioPlayer.stop();
        state = state.copyWith(
          currentSong: null,
          isPlaying: false,
          isLoading: false,
        );
        _showErrorToast('Multiple playback errors occurred. Please try again.');
        return;
      }

      // FIXED: Special handling for related song transitions
      if (isRelatedTransition && state.currentSong != null) {
        print('🔄 Handling related song transition error...');

        // Give more time for related transitions
        await Future.delayed(Duration(seconds: 5));

        if (mounted &&
            state.currentSong != null &&
            state.currentSong!.audioUrl != null) {
          try {
            // Simple restart approach for related songs
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();

            print('✅ Successfully recovered related song');
            _consecutiveErrors = 0;
            return;
          } catch (e) {
            print('❌ Related song recovery failed: $e');
            // Don't immediately skip - let it try a few more times
            if (_consecutiveErrors < maxErrors - 2) {
              print('🔄 Will retry related song...');
              return;
            }
          }
        }
      }

      // For non-related songs or final retry attempts
      if (state.currentSong != null && state.currentSong!.audioUrl != null) {
        print('🔄 Attempting to restart current song...');

        await Future.delayed(Duration(seconds: 3));

        if (mounted && state.currentSong != null) {
          try {
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();
            print('✅ Successfully restarted current song');
            _consecutiveErrors = 0;
            return;
          } catch (e) {
            print('❌ Failed to restart current song: $e');
          }
        }
      }

      // Only skip if we've really exhausted options
      if (_consecutiveErrors >= maxErrors - 1) {
        print('⏭️ Final attempt - skipping to next song...');
        await skipCurrentSong();
      }
    } catch (e) {
      print('❌ Error in recovery attempt: $e');
      if (mounted) {
        state = state.copyWith(
          currentSong: null,
          isPlaying: false,
          isLoading: false,
        );
      }
    } finally {
      _isHandlingError = false;

      // FIXED: Longer reset timer based on actual transition type
      final resetDelay = _isCurrentlyHandlingRelatedTransition() ? 30 : 45;
      Timer(Duration(seconds: resetDelay), () {
        if (_consecutiveErrors > 0) {
          print('🔄 Resetting error counter after timeout');
          _consecutiveErrors = 0;
          _lastErrorTime = null;
        }
      });
    }
  }

  // NEW: Helper method to detect if we're handling a related song transition
  bool _isCurrentlyHandlingRelatedTransition() {
    // Check multiple indicators of related song transitions
    final queueState = _ref.read(queueStateProvider);

    // If queue has songs and we're playing from related source
    final hasRelatedQueue = queueState.currentOrder.isNotEmpty;
    final isRelatedSource = state.playbackSource == 'related';

    // If we're currently fetching related songs
    final isFetchingRelated = _relatedSongsService.isFetchingRelated;

    // If the current song is likely from related songs service
    final currentSongInQueue =
        state.currentSong != null &&
        queueState.currentOrder.any(
          (s) => s.videoId == state.currentSong!.videoId,
        );

    return hasRelatedQueue ||
        isRelatedSource ||
        isFetchingRelated ||
        currentSongInQueue;
  }

  // ==================== PLAYBACK HELPERS ====================

  Future<void> stopPlayback({
    bool fadeOut = true,
    Duration fadeDuration = const Duration(seconds: 2),
  }) async {
    try {
      if (fadeOut && state.isPlaying) {
        print('🔊 Starting fade-out over ${fadeDuration.inSeconds}s');

        // Get initial volume (default is usually 1.0)
        const initialVolume = 1.0;
        const steps = 20; // Number of fade steps
        final stepDuration = Duration(
          milliseconds: fadeDuration.inMilliseconds ~/ steps,
        );

        // Gradually reduce volume
        for (int i = steps; i >= 0; i--) {
          if (!mounted || !state.isPlaying) {
            break; // Stop if playback already stopped
          }

          final volume = (i / steps) * initialVolume;
          await _audioPlayer.setVolume(volume);

          if (i > 0) {
            await Future.delayed(stepDuration);
          }
        }

        print('🔇 Fade-out completed');
      }

      // Stop the player
      await _audioPlayer.stop();

      // Reset volume back to normal for next playback
      await _audioPlayer.setVolume(1.0);

      // Update state
      state = state.copyWith(
        isPlaying: false,
        currentSong: null,
        currentPosition: Duration.zero,
      );

      print('⏹️ Playback stopped');
    } catch (e) {
      print('❌ Error stopping playback: $e');
      // Ensure player is stopped even if fade-out failed
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(1.0);
        state = state.copyWith(isPlaying: false, currentSong: null);
      } catch (e2) {
        print('❌ Error in fallback stop: $e2');
      }
    }
  }

  /// Play next song in current playlist
  Future<void> _playNextInPlaylist() async {
    final nextIndex = state.currentIndex + 1;
    final nextSong = state.playlist[nextIndex];

    print('Playing next song in playlist: ${nextSong.title}');

    await playSong(
      nextSong,
      playlist: state.playlist,
      index: nextIndex,
      playlistType: state.playlistType,
      playbackSource: state.playbackSource,
    );
  }

  // FIXED: _syncWithQueueState method
  Future<void> _syncWithQueueState(QueueState queueState) async {
    if (!mounted ||
        queueState.currentOrder.isEmpty ||
        queueState.currentIndex >= queueState.currentOrder.length ||
        queueState.currentIndex < 0) {
      return;
    }

    final songToPlay = queueState.currentOrder[queueState.currentIndex];

    // Skip if already playing this song
    if (state.currentSong?.videoId == songToPlay.videoId) {
      print('⏭️ Already playing this song, just updating state');
      state = state.copyWith(
        playlist: queueState.currentOrder,
        currentIndex: queueState.currentIndex,
        playlistType: 'related',
        playbackSource: 'related',
      );
      return;
    }

    // Skip if no audio URL
    if (songToPlay.audioUrl == null || songToPlay.audioUrl!.isEmpty) {
      print('⚠️ No audio URL for queue song: ${songToPlay.title}');
      return;
    }

    // PRIORITY: Cancel any ongoing operations before queue sync
    await _cancelCurrentOperation('Queue sync priority');

    // Add delay to ensure cancellation is processed
    await Future.delayed(Duration(milliseconds: 100));

    // Set transition lock
    _isTransitioning = true;

    try {
      print('🔄 Syncing with queue: ${songToPlay.title}');

      // Use playSong with related source to ensure proper handling
      await playSong(
        songToPlay,
        playlist: queueState.currentOrder,
        index: queueState.currentIndex,
        playlistType: 'related',
        playbackSource: 'related',
      );
    } catch (e) {
      print('❌ Error syncing with queue: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          playlist: queueState.currentOrder,
          currentIndex: queueState.currentIndex,
          playlistType: 'related',
          playbackSource: 'related',
        );
      }
    } finally {
      _isTransitioning = false;
    }
  }

  /// Cancel current operation with reason
  Future<void> _cancelCurrentOperation(String reason) async {
    if (_currentOperation != null && !_currentOperation!.isCompleted) {
      print('🚫 Cancelling current operation: $reason');

      try {
        // Stop audio player immediately but gently
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        }

        // Mark operation as cancelled without throwing
        if (!_currentOperation!.isCompleted) {
          _currentOperation!.complete(); // Complete normally instead of error
        }
      } catch (e) {
        print('⚠️ Error during operation cancellation: $e');
        // Silently handle cancellation errors
      }

      _currentOperation = null;
      _currentOperationId = '';
    }
  }

  /// Check if operation was cancelled
  bool _isOperationCancelled(String operationId) {
    return _currentOperationId != operationId || _currentOperation == null;
  }

  Future<void> setSleepTimer(int minutes) async {
    print('setSleepTimer called with $minutes minutes');

    // Cancel existing timer first
    _sleepTimer?.cancel();
    _sleepTimer = null;

    // Calculate end time
    final endTime = DateTime.now().add(Duration(minutes: minutes));

    // Update state FIRST before starting timer
    state = state.copyWith(sleepTimerEndTime: endTime);
    print('State updated with endTime: $endTime');

    // Start new timer
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      print('Sleep timer expired - stopping playback');
      try {
        await stopPlayback();
        // Clear the timer state after stopping
        if (mounted) {
          state = state.copyWith(sleepTimerEndTime: null);
        }
      } catch (e) {
        print('Error during timer expiration: $e');
      }
    });

    print('Sleep timer set for $minutes minutes, endTime: $endTime');
  }

  Future<void> cancelSleepTimer() async {
    print('cancelSleepTimer called');

    // Cancel any existing timer
    _sleepTimer?.cancel();
    _sleepTimer = null;

    // Update the state using the clear flag
    state = state.copyWith(clearSleepTimer: true);

    print('Sleep timer cancelled - endTime set to null');
  }

  // ==================== AUTOPLAY LOGIC ====================

  Future<void> _handleAutoplayOnCompletion() async {
    print('🎵 Handling autoplay on completion');
    print('   Current source: ${state.playbackSource}');
    print('   Current index: ${state.currentIndex}');
    print('   Playlist length: ${state.playlist.length}');

    try {
      if (state.isLooping) {
        print('🔄 Looping enabled - restarting current song');
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        return;
      }

      // PRIORITY 1: Try next in current playlist
      if (state.currentIndex < state.playlist.length - 1) {
        print('📋 Playing next song in current playlist');
        await _playNextInPlaylist();
        return;
      }

      // PRIORITY 2: For search songs, always try queue
      if (state.playbackSource == 'search') {
        print('🔍 Search song completed - checking queue');
        if (_relatedSongsService.moveToNextInQueue()) {
          print('✅ Moved to next song in related queue');
          return;
        }
      }

      // PRIORITY 3: For saved/artist songs, only use queue if originally enabled
      if (state.playbackSource == 'saved' || state.playbackSource == 'artist') {
        // Check if we had enabled related songs fetch (queue is low)
        final queueState = _ref.read(queueStateProvider);
        if (queueState.currentOrder.isNotEmpty) {
          print(
            '📋 ${state.playbackSource} song completed - using available queue',
          );
          if (_relatedSongsService.moveToNextInQueue()) {
            print('✅ Moved to next song in related queue');
            return;
          }
        } else {
          print(
            '🛑 ${state.playbackSource} playlist completed - stopping playback',
          );
          await _audioPlayer.stop();
          state = state.copyWith(isPlaying: false);
          return;
        }
      }

      // PRIORITY 4: Last resort - fetch related songs (only for search)
      if (state.playbackSource == 'search' && state.currentSong != null) {
        print('🚀 No queue available - fetching related songs for search');
        _relatedSongsService.fetchForSong(state.currentSong!);
        return;
      }

      // FALLBACK: Stop playback
      print('🛑 No more songs available - stopping playback');
      await _audioPlayer.stop();
      state = state.copyWith(isPlaying: false);
    } catch (e) {
      print('❌ Error in autoplay completion: $e');
      // Simple fallback - restart current song if available
      if (state.currentSong != null) {
        try {
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play();
        } catch (e2) {
          print('❌ Fallback restart failed: $e2');
          state = state.copyWith(isPlaying: false);
        }
      }
    }
  }

  // ==================== ERROR HANDLING ====================

  // FIXED: Improved skipCurrenSong method
  Future<void> skipCurrentSong() async {
    print('⏭️ Skipping current song due to errors');

    // Prevent excessive skipping
    if (_isHandlingError && _consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
      print('⚠️ Too many errors, not skipping');
      return;
    }

    try {
      // FIXED: Reset error state when manually skipping
      _isHandlingError = false;

      final queueState = _ref.read(queueStateProvider);
      final queueNotifier = _ref.read(queueStateProvider.notifier);

      // Priority 1: Next song in queue
      if (queueState.currentOrder.isNotEmpty &&
          queueState.currentIndex < queueState.currentOrder.length - 1) {
        print('📋 Moving to next song in queue');
        queueNotifier.setCurrentIndex(queueState.currentIndex + 1);
        return;
      }

      // Priority 2: Next song in current playlist
      if (state.playlist.isNotEmpty &&
          state.currentIndex < state.playlist.length - 1) {
        print('📋 Playing next song in playlist');
        await _playNextInPlaylist();
        return;
      }

      // Priority 3: Try to fetch related songs (only if not too many errors)
      if (state.currentSong != null && _consecutiveErrors < 3) {
        print('🚀 Fetching related songs as fallback');
        _relatedSongsService.fetchForSong(state.currentSong!);
        return;
      }

      // Last resort: stop playback
      print('🛑 No more songs available, stopping playback');
      await _audioPlayer.stop();
      state = state.copyWith(isPlaying: false, isLoading: false);
    } catch (e) {
      print('❌ Error in skipCurrentSong: $e');
      if (mounted) {
        state = state.copyWith(isPlaying: false, isLoading: false);
      }
    }
  }
  // ==================== UTILITY METHODS ====================

  // UPDATED: _determinePlaybackSource method with better logic
  String _determinePlaybackSource(Song song, List<Song>? playlist) {
    print('🔍 Determining playback source...');
    print('   Song: ${song.title}');
    print('   Has playlist: ${playlist != null}');
    print('   Playlist length: ${playlist?.length ?? 0}');
    print('   Current state source: ${state.playbackSource}');

    // Priority 1: Check if song has local audio (saved songs)
    if (song.audioUrl != null && !song.audioUrl!.startsWith('http')) {
      print('   🎯 Detected LOCAL audio URL -> saved');
      return 'saved';
    }

    // Priority 2: Check if playlist contains local songs (saved playlist)
    if (playlist != null && playlist.isNotEmpty) {
      final hasLocalSongs = playlist.any(
        (s) => s.audioUrl != null && !s.audioUrl!.startsWith('http'),
      );
      if (hasLocalSongs) {
        print('   🎯 Detected playlist with LOCAL songs -> saved');
        return 'saved';
      }
    }

    // Priority 3: If current state is already a specific source, maintain it
    // unless we're switching to a completely different context
    if (state.playbackSource == 'related') {
      print('   🎯 Currently playing related songs -> related');
      return 'related';
    }

    // Priority 4: Default fallback - if no specific indicators, use search
    // This handles cases where source isn't explicitly provided
    print('   🎯 No specific indicators found -> search (default)');
    return 'search';
  }

  /// Play quickpicks/trending songs - NEW METHOD
  Future<void> playQuickpicks(
    List<Song> quickpickSongs, {
    int startIndex = 0,
  }) async {
    if (quickpickSongs.isEmpty) return;

    print('🔥 Playing quickpicks - startIndex: $startIndex');

    // Clear related songs for new quickpicks session
    _relatedSongsService.clearRelatedData();

    // Clear queue state
    final queueNotifier = _ref.read(queueStateProvider.notifier);
    queueNotifier.clearQueue();

    // EXPLICIT source setting
    await playSong(
      quickpickSongs[startIndex],
      playlist: quickpickSongs,
      index: startIndex,
      playlistType: 'quickpicks',
      playbackSource: 'quickpicks', // EXPLICIT
    );
  }

  /// Parse album art URI safely
  Uri? _parseArtUri(String? albumArt) {
    if (albumArt == null || albumArt.isEmpty) {
      return null;
    }

    try {
      if (albumArt.startsWith('http://') || albumArt.startsWith('https://')) {
        return Uri.parse(albumArt);
      }

      if (albumArt.startsWith('/') || albumArt.startsWith('file://')) {
        final cleanPath = albumArt.startsWith('file://')
            ? albumArt.substring(7)
            : albumArt;
        return Uri.file(cleanPath);
      }

      return null;
    } catch (e) {
      print('Error parsing artUri: $e');
      return null;
    }
  }

  // ==================== STATE MANAGEMENT ====================

  /// Update playlist order from external source
  void updatePlaylistOrder(List<Song> reorderedQueue, int newCurrentIndex) {
    print('🔄 Updating audio playlist with reordered queue');
    print('   - New queue length: ${reorderedQueue.length}');
    print('   - New current index: $newCurrentIndex');
    print('   - Current playing: ${state.currentSong?.title}');

    if (reorderedQueue.isEmpty) {
      print('⚠️ Empty reordered queue provided');
      return;
    }

    if (newCurrentIndex < 0 || newCurrentIndex >= reorderedQueue.length) {
      print(
        '❌ Invalid current index: $newCurrentIndex (queue length: ${reorderedQueue.length})',
      );
      return;
    }

    try {
      final expectedCurrentSong = reorderedQueue[newCurrentIndex];
      if (state.currentSong?.videoId != expectedCurrentSong.videoId) {
        print('⚠️ Current song mismatch - updating current song reference');
        print('   Expected: ${expectedCurrentSong.title}');
        print('   Current: ${state.currentSong?.title}');
      }

      state = state.copyWith(
        playlist: List.from(reorderedQueue),
        currentIndex: newCurrentIndex,
        currentSong: expectedCurrentSong,
      );

      print('✅ Audio playlist updated successfully');
      print(
        '   - Next song: ${newCurrentIndex < reorderedQueue.length - 1 ? reorderedQueue[newCurrentIndex + 1].title : 'None'}',
      );
      print(
        '   - Previous song: ${newCurrentIndex > 0 ? reorderedQueue[newCurrentIndex - 1].title : 'None'}',
      );
    } catch (e) {
      print('❌ Error updating playlist order: $e');
    }
  }

  /// Set autoplay enabled/disabled
  void setAutoplayEnabled(bool enabled) {
    state = state.copyWith(autoplayEnabled: enabled);
    print('Autoplay ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Set playlist type
  void setPlaylistType(String type) {
    state = state.copyWith(playlistType: type);
  }

  /// Update lyrics
  void setLyrics(List<LyricsLine> lyrics) {
    state = state.copyWith(currentLyrics: lyrics);
  }

  /// Update lyrics (alternative method name for compatibility)
  void updateLyrics(List<LyricsLine> lyrics) {
    state = state.copyWith(currentLyrics: lyrics);
  }

  /// Set looping mode - UPDATED
  void setLooping(bool shouldLoop) {
    try {
      state = state.copyWith(isLooping: shouldLoop);

      if (shouldLoop) {
        _audioPlayer.setLoopMode(LoopMode.one); // Loop single song
      } else {
        _audioPlayer.setLoopMode(LoopMode.off);
      }

      print(
        '🔄 Loop mode ${shouldLoop ? 'enabled (single song)' : 'disabled'}',
      );
    } catch (e) {
      print('❌ Error setting loop mode: $e');
      // Revert state on error
      state = state.copyWith(isLooping: !shouldLoop);
    }
  }

  /// Toggle looping mode
  void toggleLooping() {
    final newLooping = !state.isLooping;
    setLooping(newLooping);
    print('Looping ${newLooping ? 'enabled' : 'disabled'}');
  }

  /// Toggle favorite status
  void toggleFavorite() {
    state = state.copyWith(isFavorite: !state.isFavorite);
  }

  // ==================== DOWNLOAD/SAVE MANAGEMENT ====================

  /// Toggle saved status of current song
  Future<void> toggleSaved() async {
    if (state.currentSong == null) return;

    final song = state.currentSong!;
    final songKey = _getSongKey(song);
    final isSaved = await _isSongSavedOrDownloading(song);

    if (isSaved) {
      await _removeSong(song, songKey);
    } else {
      await _saveSong(song, songKey);
    }
  }

  Future<void> download(Song song) async {
    final songKey = '${song.audioUrl}';

    // Prevent duplicate downloads
    if (_currentlyDownloading.contains(songKey)) {
      print('⚠️ Download already in progress for: ${song.title}');
      return;
    }

    try {
      print('⬇️ Starting download for: ${song.title}');
      final audioPath = await _downloadManager.downloadAudio(song);

      if (audioPath == null) {
        throw Exception('Failed to download audio');
      }

      final artPath = song.albumArt != null
          ? await _downloadManager.downloadAlbumArt(song)
          : null;

      await _storageService.saveSong(
        title: song.title,
        artist: song.artists,
        audioUrl: song.audioUrl!,
        audioPath: audioPath,
        albumArtUrl: song.albumArt,
        albumArtPath: artPath,
      );

      print('✅ Song downloaded successfully: ${song.title}');
      _savedStatusCache[songKey] = true;
      state = state.copyWith(isSaved: true);
    } catch (e) {
      print('❌ Failed to download song: $e');
      _savedStatusCache[songKey] = false;
      state = state.copyWith(isSaved: false);
    } finally {
      _currentlyDownloading.remove(songKey);
    }
  }

  // Save song to storage (Updated to work with download state provider)
  Future<void> _saveSong(Song song, String songKey) async {
    _currentlyDownloading.add(songKey);
    _savedStatusCache[songKey] = true;
    state = state.copyWith(isSaved: true);

    try {
      print('⬇️ Starting download for: ${song.title}');
      final audioPath = await _downloadManager.downloadAudio(song);

      if (audioPath == null) {
        throw Exception('Failed to download audio');
      }

      final artPath = song.albumArt != null
          ? await _downloadManager.downloadAlbumArt(song)
          : null;

      await _storageService.saveSong(
        title: song.title,
        artist: song.artists,
        audioUrl: song.audioUrl!,
        audioPath: audioPath,
        albumArtUrl: song.albumArt,
        albumArtPath: artPath,
      );

      print('✅ Song saved successfully: ${song.title}');
      _savedStatusCache[songKey] = true;
    } catch (e) {
      print('❌ Failed to save song: $e');
      _savedStatusCache[songKey] = false;
      state = state.copyWith(isSaved: false);
    } finally {
      _currentlyDownloading.remove(songKey);
    }
  }

  /// Remove song from storage (Updated to work with download state provider)
  Future<void> _removeSong(Song song, String songKey) async {
    await _storageService.removeSong(song);
    _currentlyDownloading.remove(songKey);
    _savedStatusCache[songKey] = false;
    state = state.copyWith(isSaved: false);

    print('✅ Song removed from storage: ${song.title}');
  }

  /// Check if current song is saved
  Future<bool> isCurrentSongSaved() async {
    if (state.currentSong == null) return false;

    final song = state.currentSong!;
    final songKey = _getSongKey(song);

    // Always check storage service to ensure accuracy
    print('🔍 Checking saved status for: ${song.title}');
    final isSaved = await _storageService.isSongSaved(song);

    // Update cache and state
    _savedStatusCache[songKey] = isSaved;
    _lastCheckedSongKey = songKey;

    // Update state if different
    if (state.isSaved != isSaved) {
      state = state.copyWith(isSaved: isSaved);
    }

    return isSaved;
  }

  // ignore: unused_element
  Future<void> _handleDownloadToggle() async {
    if (state.currentSong == null) return;

    final song = state.currentSong!;
    final songKey = _getSongKey(song);

    if (_currentlyDownloading.contains(songKey)) {
      return; // Already downloading
    }

    final isSaved = await _storageService.isSongSaved(song);

    if (isSaved) {
      // Remove song
      await _storageService.removeSong(song);
      state = state.copyWith(isSaved: false);
    } else {
      // Download song
      _currentlyDownloading.add(songKey);
      state = state.copyWith(isSaved: true); // Optimistic update

      try {
        final artPath = await _downloadManager.downloadAlbumArt(song);
        final audioPath = await _downloadManager.downloadAudio(song);
        if (audioPath == null) {
          throw Exception('Failed to download audio');
        }

        await _storageService.saveSong(
          title: song.title,
          artist: song.artists,
          audioUrl: song.audioUrl!,
          audioPath: audioPath, // Now guaranteed non-null
          albumArtUrl: song.albumArt,
          albumArtPath: artPath,
        );
      } catch (e) {
        state = state.copyWith(isSaved: false);
      } finally {
        _currentlyDownloading.remove(songKey);
      }
    }
  }

  /// Check if song is saved or currently downloading (with caching)
  Future<bool> _isSongSavedOrDownloading(Song song) async {
    final songKey = _getSongKey(song);

    // Check if currently downloading
    if (_currentlyDownloading.contains(songKey)) {
      return true;
    }

    // Check storage service
    return await _storageService.isSongSaved(song);
  }

  /// Clear saved status cache (call when needed to refresh)
  void clearSavedStatusCache() {
    _savedStatusCache.clear();
    _lastCheckedSongKey = null;
    print('🧹 Cleared saved status cache');
  }

  /// Update cache when external changes occur
  void updateSavedStatusCache(Song song, bool isSaved) {
    final songKey = _getSongKey(song);
    _savedStatusCache[songKey] = isSaved;
    print('📝 Updated cache for ${song.title}: $isSaved');
  }

  /// Preload saved status for a list of songs (batch optimization)
  Future<void> preloadSavedStatus(List<Song> songs) async {
    print('🚀 Preloading saved status for ${songs.length} songs');

    for (final song in songs) {
      final songKey = _getSongKey(song);
      if (!_savedStatusCache.containsKey(songKey)) {
        try {
          final isSaved = await _storageService.isSongSaved(song);
          _savedStatusCache[songKey] = isSaved;
        } catch (e) {
          print('❌ Error preloading saved status for ${song.title}: $e');
          _savedStatusCache[songKey] = false;
        }
      }
    }

    print('✅ Preloading complete');
  }

  // ==================== CLEANUP ====================

  @override
  void dispose() {
    _cancelCurrentOperation('AudioNotifier dispose');
    _sleepTimer?.cancel();
    _savedStatusCache.clear();
    _audioPlayer.dispose();
    _relatedSongsService.dispose(); // UPDATED: Use service dispose

    super.dispose();
  }
}
