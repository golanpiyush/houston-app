// providers/ytmusic_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';
import '../models/song.dart';

final ytMusicProvider = StateNotifierProvider<YtMusicNotifier, YtMusicState>((
  ref,
) {
  return YtMusicNotifier();
});

class YtMusicState {
  final bool isInitialized;
  final bool isLoading;
  final List<Song> searchResults;
  final String? error;

  YtMusicState({
    required this.isInitialized,
    required this.isLoading,
    required this.searchResults,
    this.error,
  });

  YtMusicState copyWith({
    bool? isInitialized,
    bool? isLoading,
    List<Song>? searchResults,
    String? error,
  }) {
    return YtMusicState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      searchResults: searchResults ?? this.searchResults,
      error: error ?? this.error,
    );
  }
}

class YtMusicNotifier extends StateNotifier<YtMusicState> {
  final YtFlutterMusicapi _api =
      YtFlutterMusicapi(); // Fixed: lowercase 'a' in 'api'

  YtMusicNotifier()
    : super(
        YtMusicState(isInitialized: false, isLoading: false, searchResults: []),
      ) {
    _initializeApi();
  }

  Future<void> _initializeApi() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.initialize(country: 'US');

      if (response.success) {
        state = state.copyWith(
          isInitialized: true,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to initialize API',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> searchMusic(
    String query, {
    int limit = 25,
    String audioQuality = 'high',
    String thumbnailQuality = 'high',
  }) async {
    if (state.isLoading || !state.isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.searchMusic(
        query: query,
        limit: limit,
        audioQuality: _getAudioQuality(audioQuality),
        thumbQuality: _getThumbnailQuality(thumbnailQuality),
        includeAudioUrl: true,
        includeAlbumArt: true,
      );

      if (response.success && response.data != null) {
        final songs = response.data!
            .map(
              (item) => Song(
                title: item.title,
                artists: item.artists,
                duration: item.duration,
                year: item.year,
                videoId: item.videoId,
                albumArt: item.albumArt,
                audioUrl: item.audioUrl,
                // isOriginal: item.isOriginal,
              ),
            )
            .toList();

        state = state.copyWith(
          searchResults: songs,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Search failed',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<Song>> getRelatedSongs(
    String songName,
    String artistName, {
    int limit = 25,
    String audioQuality = 'high',
    String thumbnailQuality = 'high',
  }) async {
    try {
      final response = await _api.getRelatedSongs(
        songName: songName,
        artistName: artistName,
        limit: limit,
        audioQuality: _getAudioQuality(audioQuality),
        thumbQuality: _getThumbnailQuality(thumbnailQuality),
        includeAudioUrl: true,
        includeAlbumArt: true,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map(
              (item) => Song(
                title: item.title,
                artists: item.artists,
                duration: item.duration,
                // year: item.year,
                videoId: item.videoId,
                albumArt: item.albumArt,
                audioUrl: item.audioUrl,
                isOriginal: item.isOriginal,
              ),
            )
            .toList();
      }
    } catch (e) {
      print('Error getting related songs: $e');
    }
    return [];
  }

  AudioQuality _getAudioQuality(String quality) {
    switch (quality) {
      case 'low':
        return AudioQuality.low;
      case 'medium':
        return AudioQuality.med;
      case 'high':
        return AudioQuality.high;
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
      default:
        return ThumbnailQuality.high;
    }
  }

  void clearSearch() {
    state = state.copyWith(searchResults: []);
  }
}
