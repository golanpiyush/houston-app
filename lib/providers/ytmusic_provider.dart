// providers/ytmusic_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/models/song.dart';
import 'package:yt_flutter_musicapi/models/audioUrlresultsModel.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart' hide SystemStatus;

final ytMusicProvider = StateNotifierProvider<YtMusicNotifier, YtMusicState>((
  ref,
) {
  return YtMusicNotifier();
});

class YtMusicState {
  final bool isInitialized;
  final bool isLoading;
  final List<Song> searchResults;
  final List<Song> artistSongs;
  final List<Song> relatedSongs;
  final SystemStatus? systemStatus;
  final String? error;
  final bool isStreaming;

  YtMusicState({
    required this.isInitialized,
    required this.isLoading,
    required this.searchResults,
    required this.artistSongs,
    required this.relatedSongs,
    this.systemStatus,
    this.error,
    this.isStreaming = false,
  });

  YtMusicState copyWith({
    bool? isInitialized,
    bool? isLoading,
    List<Song>? searchResults,
    List<Song>? artistSongs,
    List<Song>? relatedSongs,
    SystemStatus? systemStatus,
    String? error,
    bool? isStreaming,
  }) {
    return YtMusicState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      searchResults: searchResults ?? this.searchResults,
      artistSongs: artistSongs ?? this.artistSongs,
      relatedSongs: relatedSongs ?? this.relatedSongs,
      systemStatus: systemStatus ?? this.systemStatus,
      error: error ?? this.error,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class YtMusicNotifier extends StateNotifier<YtMusicState> {
  final YtFlutterMusicapi _api = YtFlutterMusicapi();
  StreamSubscription? _searchSubscription;
  StreamSubscription? _artistSubscription;
  StreamSubscription? _relatedSubscription;

  // Add a flag to track if the notifier is disposed
  bool _isDisposed = false;

  YtMusicNotifier()
    : super(
        YtMusicState(
          isInitialized: false,
          isLoading: false,
          searchResults: [],
          artistSongs: [],
          relatedSongs: [],
        ),
      ) {
    _initializeApi();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelAllStreams();
    super.dispose();
  }

  void _cancelAllStreams() {
    _searchSubscription?.cancel();
    _artistSubscription?.cancel();
    _relatedSubscription?.cancel();

    // Clear the subscriptions to prevent any residual callbacks
    _searchSubscription = null;
    _artistSubscription = null;
    _relatedSubscription = null;

    // Only update streaming state if not disposed and state is still streaming
    if (!_isDisposed && state.isStreaming) {
      state = state.copyWith(isStreaming: false);
    }
  }

  // Helper method to check if we should update state
  bool _canUpdateState() {
    return !_isDisposed && mounted;
  }

  Future<void> _initializeApi() async {
    if (!_canUpdateState() || state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.initialize(country: 'US');

      if (!_canUpdateState()) return;

      if (response.success) {
        state = state.copyWith(
          isInitialized: true,
          isLoading: false,
          error: null,
        );
        await checkStatus();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to initialize API',
        );
      }
    } catch (e) {
      if (_canUpdateState()) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> checkStatus() async {
    if (!_canUpdateState()) return;

    state = state.copyWith(isLoading: true);
    try {
      final response = await _api.checkStatus();

      if (!_canUpdateState()) return;

      if (response.success && response.data != null) {
        // Convert the plugin's SystemStatus to our local model
        final pluginStatus = response.data!;
        final localStatus = SystemStatus(
          success: pluginStatus.success,
          message: pluginStatus.message,
          ytmusicReady: pluginStatus.ytmusicReady,
          ytmusicVersion: pluginStatus.ytmusicVersion,
          ytdlpReady: pluginStatus.ytdlpReady,
          ytdlpVersion: pluginStatus.ytdlpVersion,
        );

        state = state.copyWith(
          systemStatus: localStatus,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message ?? 'Failed to check system status',
        );
      }
    } catch (e) {
      if (_canUpdateState()) {
        state = state.copyWith(
          isLoading: false,
          error: 'Error checking system status: ${e.toString()}',
        );
      }
    }
  }

  // Search streaming with optional context
  void streamSearchResults({
    required String query,
    int limit = 25,
    String audioQuality = 'very_high',
    BuildContext? context,
  }) {
    if (!state.isInitialized || !_canUpdateState()) return;

    // Cancel existing streams first
    _cancelAllStreams();

    state = state.copyWith(
      isLoading: true,
      isStreaming: true,
      searchResults: [],
      error: null,
    );

    try {
      final stream = _api.streamSearchResults(
        query: query,
        limit: limit,
        audioQuality: _getAudioQuality(audioQuality),
        includeAudioUrl: true,
        includeAlbumArt: true,
      );

      _searchSubscription = stream.listen(
        (item) {
          // Check if this subscription is still active AND we can update state
          if (_searchSubscription != null && _canUpdateState()) {
            final song = Song.fromSearchResult(item);
            state = state.copyWith(
              searchResults: [...state.searchResults, song],
            );
          }
        },
        onError: (error) {
          // Only handle error if subscription is still active AND we can update state
          if (_searchSubscription != null && _canUpdateState()) {
            if (context != null && context.mounted) {
              _showErrorToast(context, 'Search error: $error');
            }
            debugPrint('Search error: $error');
            state = state.copyWith(
              isLoading: false,
              isStreaming: false,
              error: error.toString(),
            );
          }
        },
        onDone: () {
          // Only update state if subscription is still active AND we can update state
          if (_searchSubscription != null && _canUpdateState()) {
            state = state.copyWith(isLoading: false, isStreaming: false);
          }
        },
      );
    } catch (e) {
      if (context != null && context.mounted) {
        _showErrorToast(context, 'Error starting search: $e');
      }
      debugPrint('Error starting search: $e');
      if (_canUpdateState()) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          error: e.toString(),
        );
      }
    }
  }

  // Artist songs streaming with optional context
  void streamArtistSongs({
    required String artistName,
    int limit = 25,
    String audioQuality = 'very_high',
    String thumbnailQuality = 'very_high',
    BuildContext? context,
  }) {
    if (!state.isInitialized || !_canUpdateState()) return;

    _cancelAllStreams();

    state = state.copyWith(
      isLoading: true,
      isStreaming: true,
      artistSongs: [],
      error: null,
    );

    try {
      final stream = _api.streamArtistSongs(
        artistName: artistName,
        limit: limit,
        audioQuality: _getAudioQuality(audioQuality),
        thumbQuality: _getThumbnailQuality(thumbnailQuality),
        includeAudioUrl: true,
        includeAlbumArt: true,
      );

      _artistSubscription = stream.listen(
        (item) {
          if (_artistSubscription != null && _canUpdateState()) {
            final song = Song.fromArtistSong(item);
            state = state.copyWith(artistSongs: [...state.artistSongs, song]);
          }
        },
        onError: (error) {
          if (_artistSubscription != null && _canUpdateState()) {
            if (context != null && context.mounted) {
              _showErrorToast(context, 'Artist songs error: $error');
            }
            debugPrint('Artist songs error: $error');
            state = state.copyWith(
              isLoading: false,
              isStreaming: false,
              error: error.toString(),
            );
          }
        },
        onDone: () {
          if (_artistSubscription != null && _canUpdateState()) {
            state = state.copyWith(isLoading: false, isStreaming: false);
          }
        },
      );
    } catch (e) {
      if (context != null && context.mounted) {
        _showErrorToast(context, 'Error fetching artist songs: $e');
      }
      debugPrint('Error fetching artist songs: $e');
      if (_canUpdateState()) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          error: e.toString(),
        );
      }
    }
  }

  // Related songs streaming with optional context
  void streamRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 5,
    String audioQuality = 'high',
    String thumbnailQuality = 'very_high',
    BuildContext? context,
  }) {
    if (!state.isInitialized || !_canUpdateState()) return;

    _cancelAllStreams();

    state = state.copyWith(
      isLoading: true,
      isStreaming: true,
      relatedSongs: [],
      error: null,
    );

    try {
      final stream = _api.streamRelatedSongs(
        songName: songName,
        artistName: artistName,
        limit: limit,
        audioQuality: _getAudioQuality(audioQuality),
        thumbQuality: _getThumbnailQuality(thumbnailQuality),
        includeAudioUrl: true,
        includeAlbumArt: true,
      );

      _relatedSubscription = stream.listen(
        (item) {
          if (_relatedSubscription != null && _canUpdateState()) {
            final song = Song.fromRelatedSong(item);
            state = state.copyWith(relatedSongs: [...state.relatedSongs, song]);
          }
        },
        onError: (error) {
          if (_relatedSubscription != null && _canUpdateState()) {
            if (context != null && context.mounted) {
              _showErrorToast(context, 'Related songs error: $error');
            }
            debugPrint('Related songs error: $error');
            state = state.copyWith(
              isLoading: false,
              isStreaming: false,
              error: error.toString(),
            );
          }
        },
        onDone: () {
          if (_relatedSubscription != null && _canUpdateState()) {
            state = state.copyWith(isLoading: false, isStreaming: false);
          }
        },
      );
    } catch (e) {
      if (context != null && context.mounted) {
        _showErrorToast(context, 'Error fetching related songs: $e');
      }
      debugPrint('Error fetching related songs: $e');
      if (_canUpdateState()) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          error: e.toString(),
        );
      }
    }
  }

  Future<YTMusicResponse<AudioUrlResult>> getAudioUrlFlexible({
    String? title,
    String? artist,
    String? videoId,
    AudioQuality audioQuality = AudioQuality.high,
  }) async {
    try {
      // Validate input parameters
      if ((videoId?.isEmpty ?? true) &&
          (title?.isEmpty ?? true) &&
          (artist?.isEmpty ?? true)) {
        throw ArgumentError(
          'Either videoId OR (title and/or artist) must be provided',
        );
      }

      final response = await _api.getAudioUrlFlexible(
        title: title,
        artist: artist,
        videoId: videoId,
        audioQuality: audioQuality,
      );

      return response;
    } catch (e, stackTrace) {
      debugPrint('Error in getAudioUrlFlexible: $e\n$stackTrace');
      rethrow;
    }
  }

  void _showErrorToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  AudioQuality _getAudioQuality(String quality) {
    switch (quality) {
      case 'low':
        return AudioQuality.low;
      case 'medium':
        return AudioQuality.med;
      case 'high':
        return AudioQuality.high;
      case 'very_high':
        return AudioQuality.veryHigh;
      default:
        return AudioQuality.high;
    }
  }

  ThumbnailQuality _getThumbnailQuality(String quality) {
    switch (quality) {
      case 'low':
        return ThumbnailQuality.low;
      case 'medium':
        return ThumbnailQuality.med;
      case 'high':
        return ThumbnailQuality.high;
      case 'very_high':
        return ThumbnailQuality.veryHigh;
      default:
        return ThumbnailQuality.high;
    }
  }

  void clearSearch() {
    _cancelAllStreams();
    if (_canUpdateState()) {
      state = state.copyWith(searchResults: []);
    }
  }

  void clearArtistSongs() {
    _cancelAllStreams();
    if (_canUpdateState()) {
      state = state.copyWith(artistSongs: []);
    }
  }

  void clearRelatedSongs() {
    _cancelAllStreams();
    if (_canUpdateState()) {
      state = state.copyWith(relatedSongs: []);
    }
  }
}
