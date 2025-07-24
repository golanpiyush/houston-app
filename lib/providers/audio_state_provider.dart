import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/models/lyrics_model.dart';
import 'package:houston/providers/managers/download_manager.dart';
import 'package:houston/providers/managers/relatedsongsmanager.dart';
import 'package:houston/providers/ytmusic_provider.dart';
import 'package:houston/services/storage_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song.dart';

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
  final bool autoplayEnabled;
  final List<Song> relatedSongs;
  final bool isFetchingRelated;
  final String playlistType; // 'saved', 'search', 'related'
  final String playbackSource; // 'search', 'saved', 'artist', 'related'
  final bool isNetworkPlayback;
  final String? lastSearchQuery; // Track the last search query
  final Song? seedSong; // The original song used to generate related songs

  // Add these new fields to AudioState class:
  final String? lastRelatedSongTitle;
  final String? lastRelatedSongArtist;

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
    this.autoplayEnabled = true,
    required this.relatedSongs,
    this.isFetchingRelated = false,
    this.playlistType = 'search',
    this.playbackSource = 'search',
    this.isNetworkPlayback = true,
    this.lastSearchQuery,
    this.seedSong,
    this.lastRelatedSongArtist,
    this.lastRelatedSongTitle,
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
    // Update the AudioState copyWith method to include:
    String? lastRelatedSongTitle,
    String? lastRelatedSongArtist,
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
      autoplayEnabled: autoplayEnabled ?? this.autoplayEnabled,
      relatedSongs: relatedSongs ?? this.relatedSongs,
      isFetchingRelated: isFetchingRelated ?? this.isFetchingRelated,
      playlistType: playlistType ?? this.playlistType,
      playbackSource: playbackSource ?? this.playbackSource,
      isNetworkPlayback: isNetworkPlayback ?? this.isNetworkPlayback,
      lastSearchQuery: lastSearchQuery ?? this.lastSearchQuery,
      seedSong: seedSong ?? this.seedSong,
      lastRelatedSongTitle: lastRelatedSongTitle ?? this.lastRelatedSongTitle,
      lastRelatedSongArtist:
          lastRelatedSongArtist ?? this.lastRelatedSongArtist,
    );
  }

  // Helper to check if we need to refetch related songs (smart logic)
  bool get shouldRefetchRelatedSongs {
    return relatedSongs.length <=
        3; // Refetch when only 3 or fewer songs remain
  }

  // Get the current position in related songs queue
  int get relatedSongsPosition {
    return 15 - relatedSongs.length; // Assuming we start with 15 related songs
  }
}

class AudioNotifier extends StateNotifier<AudioState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final StorageService _storageService = StorageService();
  final DownloadManager _downloadManager = DownloadManager();
  final Set<String> _currentlyDownloading = {};
  final Ref _ref;
  late final RelatedSongsManager _relatedSongsManager;

  // getter
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

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
          autoplayEnabled: true,
          relatedSongs: [],
          isFetchingRelated: false,
          playlistType: 'search',
          playbackSource: 'search',
          isNetworkPlayback: true,
          lastSearchQuery: null,
          seedSong: null,
        ),
      ) {
    _initializePlayer();
    _relatedSongsManager = RelatedSongsManager(_ref, (songs, isFetching) {
      state = state.copyWith(
        relatedSongs: songs,
        isFetchingRelated: isFetching,
      );
    });
  }
  void _initializePlayer() {
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(totalDuration: duration);
      }
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      final wasPlaying = state.isPlaying;
      final isNowPlaying = playerState.playing;
      final processingState = playerState.processingState;

      state = state.copyWith(
        isPlaying: isNowPlaying,
        isLoading:
            processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering,
      );

      // Handle song completion for autoplay
      if (state.autoplayEnabled && !state.isLooping) {
        if (wasPlaying &&
            !isNowPlaying &&
            (processingState == ProcessingState.completed ||
                processingState == ProcessingState.idle)) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleAutoplay();
          });
        }
      }
    });

    _audioPlayer.positionStream.listen((position) {
      state = state.copyWith(currentPosition: position);

      // Check if we're near the end of the song for proactive autoplay
      if (state.totalDuration != Duration.zero &&
          position.inMilliseconds > 0 &&
          state.autoplayEnabled &&
          !state.isLooping) {
        final remainingTime = state.totalDuration - position;

        // Trigger autoplay preparation when 5 seconds left
        if (remainingTime.inSeconds <= 5 && remainingTime.inSeconds > 0) {
          _prepareNextSong();
        }

        // Fallback: Force next song when very close to end
        if (remainingTime.inSeconds <= 1 && state.isPlaying) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (state.isPlaying && _isNearEnd()) {
              _handleAutoplay();
            }
          });
        }
      }
    });
  }

  void _onRelatedSongsUpdate(List<Song> songs, bool isFetching) {
    state = state.copyWith(relatedSongs: songs, isFetchingRelated: isFetching);

    // Auto-start playback if needed
    if (state.autoplayEnabled && !state.isPlaying && songs.isNotEmpty) {
      _playFromRelatedSongs();
    }
  }

  Future<void> handleSearchResults(
    List<Song> searchResults,
    String query,
  ) async {
    if (searchResults.isEmpty) return;
    final firstSong = searchResults.first;

    await playSong(
      firstSong,
      playlist: searchResults,
      index: 0,
      playlistType: 'search',
      playbackSource: 'search',
    );

    // Set last search query but don't manually fetch - playSong will handle it
    state = state.copyWith(lastSearchQuery: query);
  }

  // Helper methods for autoplay detection
  bool _isNearEnd() {
    if (state.totalDuration == Duration.zero) return false;
    final remainingTime = state.totalDuration - state.currentPosition;
    return remainingTime.inSeconds <= 1;
  }

  void _prepareNextSong() {
    print('Preparing next song for autoplay...');
  }

  Future<void> _handleAutoplay() async {
    if (!state.autoplayEnabled) {
      print('Autoplay disabled, stopping');
      return;
    }

    print('_handleAutoplay called - current song: ${state.currentSong?.title}');
    print(
      'Current index: ${state.currentIndex}, playlist length: ${state.playlist.length}',
    );
    print('Related songs available: ${state.relatedSongs.length}');

    try {
      if (state.isLooping) {
        print('Looping enabled, restarting current song');
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        return;
      }

      // Check if there's a next song in the current playlist
      if (state.currentIndex < state.playlist.length - 1) {
        print('Playing next song in playlist');
        await _playNextInPlaylist();
        return;
      }

      // Handle end of playlist
      print('End of playlist, handling autoplay');

      // If we have related songs, play them immediately
      if (state.relatedSongs.isNotEmpty) {
        print('Related songs available, playing from queue');
        await _playFromRelatedSongs();
        return;
      }

      // If we're already fetching, just wait
      if (state.isFetchingRelated) {
        print('Already fetching related songs, waiting...');
        return;
      }

      // Last resort: try to fetch related songs
      print('No related songs available, attempting to fetch...');
      if (state.currentSong != null) {
        _relatedSongsManager.fetchForSong(state.currentSong!);
      }
    } catch (e) {
      print('Error in autoplay: $e');
    }
  }

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
    // playSong will automatically handle related songs fetching
  }

  Future<void> _playFromRelatedSongs() async {
    if (state.relatedSongs.isEmpty) {
      print('No related songs available to play');
      await _handlePlaybackError();
      return;
    }

    try {
      final relatedSong = state.relatedSongs.first;
      print('Playing related song: ${relatedSong.title}');

      // Create new playlist with current song + related songs
      final updatedPlaylist = [
        if (state.currentSong != null) state.currentSong!,
        ...state.relatedSongs,
      ];

      await playSong(
        relatedSong,
        playlist: updatedPlaylist,
        index: state.currentSong != null ? 1 : 0,
        playlistType: 'related',
        playbackSource: 'related',
      );

      // Remove the played song from related songs queue
      _relatedSongsManager.removeFirst();
    } catch (e) {
      print('Error playing from related songs: $e');
      await _handlePlaybackError();
    }
  }

  Future<void> _handlePlaybackError() async {
    // First try to play from related songs if available
    if (state.relatedSongs.isNotEmpty) {
      await _playFromRelatedSongs();
      return;
    }

    // If no related songs, try to restart current song
    if (state.currentSong != null) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    }

    // If still failing, show error to user
    state = state.copyWith(isLoading: false);
  }

  // ========== KEEP ALL EXISTING METHODS BELOW UNCHANGED ==========

  void setAutoplayEnabled(bool enabled) {
    state = state.copyWith(autoplayEnabled: enabled);
    print('Autoplay ${enabled ? 'enabled' : 'disabled'}');
  }

  void setPlaylistType(String type) {
    state = state.copyWith(playlistType: type);
  }

  void setLyrics(List<LyricsLine> lyrics) {
    state = state.copyWith(currentLyrics: lyrics);
  }

  // Update the playSong method in AudioNotifier:
  Future<void> playSong(
    Song song, {
    List<Song>? playlist,
    int? index,
    String? playlistType,
    String? playbackSource,
  }) async {
    try {
      print('Playing song: ${song.title} by ${song.artists}');
      state = state.copyWith(isLoading: true);

      // Determine if this is network playback
      final isNetwork =
          song.audioUrl != null && song.audioUrl!.startsWith('http');
      final source = playbackSource ?? _determinePlaybackSource(song, playlist);
      final effectivePlaylist = playlist ?? [song];
      final effectiveIndex = index ?? 0;

      if (song.audioUrl != null) {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(song.audioUrl!),
            tag: MediaItem(
              id: song.audioUrl!,
              title: song.title,
              artist: song.artists,
              artUri: _parseArtUri(song.albumArt),
            ),
          ),
        );

        final sessionId = _audioPlayer.androidAudioSessionId;

        state = state.copyWith(
          currentSong: song,
          playlist: playlist ?? [song],
          currentIndex: index ?? 0,
          isLoading: false,
          audioSessionId: sessionId,
          isSaved: await isCurrentSongSaved(),
          playlistType: playlistType ?? state.playlistType,
          playbackSource: source,
          isNetworkPlayback: isNetwork,
        );

        await _audioPlayer.play();
        print('Song started playing - Source: $source, Network: $isNetwork');

        // Auto-fetch related songs based on playback source and conditions
        _autoFetchRelatedSongs(song, source);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print('Error playing song: $e');
    }
  }

  void _autoFetchRelatedSongs(Song song, String source) {
    bool shouldFetch = false;
    String reason = '';

    switch (source) {
      case 'search':
      case 'artist':
        shouldFetch = _shouldRefreshRelatedSongs(song);
        reason = 'New $source playback or song changed';
        break;
      case 'saved':
        final remainingSongs = state.playlist.length - state.currentIndex - 1;
        shouldFetch = remainingSongs <= 1 && _shouldRefreshRelatedSongs(song);
        reason = 'Saved queue low ($remainingSongs songs left) or song changed';
        break;
      case 'related':
        shouldFetch =
            state.relatedSongs.length <= 5 && _shouldRefreshRelatedSongs(song);
        reason =
            'Related queue low (${state.relatedSongs.length} songs) or song changed';
        break;
      default:
        print('Unknown playback source: $source');
        break;
    }

    print('Auto-fetch check: source=$source, shouldFetch=$shouldFetch');

    if (shouldFetch) {
      print(
        '🚀 Auto-fetching related songs: $reason for "${song.title}" by ${song.artists}',
      );

      state = state.copyWith(
        lastRelatedSongTitle: song.title,
        lastRelatedSongArtist: song.artists,
        seedSong: song,
      );

      _relatedSongsManager.fetchForSong(song);
    } else {
      print(
        '⏭️ Skipping related songs fetch: Source=$source, ShouldFetch=$shouldFetch',
      );
    }
  }

  // Add this helper method to determine if related songs should be refreshed:
  bool _shouldRefreshRelatedSongs(Song song) {
    // Always fetch if we haven't tracked any song yet
    if (state.lastRelatedSongTitle == null ||
        state.lastRelatedSongArtist == null) {
      print('🆕 First song, fetching related songs');
      return true;
    }

    // Fetch if title or artist has changed
    final titleChanged = state.lastRelatedSongTitle != song.title;
    final artistChanged = state.lastRelatedSongArtist != song.artists;

    if (titleChanged || artistChanged) {
      print('🔄 Song changed - Title: $titleChanged, Artist: $artistChanged');
      print(
        '   Previous: ${state.lastRelatedSongTitle} by ${state.lastRelatedSongArtist}',
      );
      print('   Current: ${song.title} by ${song.artists}');
      return true;
    }

    return false;
  }

  String _determinePlaybackSource(Song song, List<Song>? playlist) {
    if (playlist != null) {
      final hasNetworkSongs = playlist.any(
        (s) => s.audioUrl != null && s.audioUrl!.startsWith('http'),
      );
      if (!hasNetworkSongs) return 'saved';
    }
    return state.playbackSource;
  }

  Future<void> pauseResume() async {
    if (state.isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void updateLyrics(List<LyricsLine> lyrics) {
    state = state.copyWith(currentLyrics: lyrics);
  }

  Future<void> playPrevious() async {
    if (state.currentIndex > 0) {
      await playSong(
        state.playlist[state.currentIndex - 1],
        playlist: state.playlist,
        index: state.currentIndex - 1,
        playlistType: state.playlistType,
      );
    }
  }

  Future<void> playNext() async {
    print(
      'playNext called manually - current index: ${state.currentIndex}, playlist length: ${state.playlist.length}',
    );
    print('Related songs available: ${state.relatedSongs.length}');
    print('Currently fetching related: ${state.isFetchingRelated}');
    print('Current song: ${state.currentSong?.title}');
    print('Seed song: ${state.seedSong?.title}');

    if (state.playlist.length <= 1) {
      print('Single song in playlist - allowing skip');

      // First check if we have related songs ready
      if (state.relatedSongs.isNotEmpty) {
        print(
          '✅ Found ${state.relatedSongs.length} related songs, playing from queue',
        );
        await _playFromRelatedSongs();
        return;
      }

      // If we're already fetching, wait a bit and check again
      if (state.isFetchingRelated) {
        print('⏳ Already fetching related songs, waiting...');
        state = state.copyWith(isLoading: true);

        // Wait up to 3 seconds for related songs
        for (int i = 0; i < 6; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (state.relatedSongs.isNotEmpty) {
            print('✅ Related songs arrived while waiting, playing now');
            await _playFromRelatedSongs();
            return;
          }
        }
        print('⏰ Timeout waiting for related songs');
      }

      // If no related songs and not fetching, try to trigger fetch
      if (state.currentSong != null && !state.isFetchingRelated) {
        print(
          '🚀 No related songs available, triggering fetch for: ${state.currentSong!.title}',
        );
        state = state.copyWith(isLoading: true);

        // Trigger related songs fetch
        _relatedSongsManager.fetchForSong(state.currentSong!);

        // Wait for initial results
        await Future.delayed(const Duration(milliseconds: 1500));

        if (state.relatedSongs.isNotEmpty) {
          print('✅ Got related songs after manual fetch, playing now');
          await _playFromRelatedSongs();
          return;
        }
      }

      // Fallback: restart current song
      print('🔄 Fallback: restarting current song');
      state = state.copyWith(isLoading: false);
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }

    // Handle normal playlist navigation
    try {
      if (state.currentIndex < state.playlist.length - 1) {
        await _playNextInPlaylist();
      } else {
        await _handleAutoplay();
      }
    } catch (e) {
      print('Error in playNext: $e');
      _handlePlaybackError();
    }
  }

  void toggleLooping() {
    final newLooping = !state.isLooping;
    state = state.copyWith(isLooping: newLooping);
    print('Looping ${newLooping ? 'enabled' : 'disabled'}');
  }

  void toggleFavorite() {
    state = state.copyWith(isFavorite: !state.isFavorite);
  }

  Future<void> toggleSaved() async {
    if (state.currentSong == null) return;

    final song = state.currentSong!;
    final songKey = '${song.title}|${song.artists}';
    final isSaved = await _isSongSavedOrDownloading(song);

    if (isSaved) {
      await _storageService.removeSong(song);
      _currentlyDownloading.remove(songKey);
      state = state.copyWith(isSaved: false);
      return;
    }

    _currentlyDownloading.add(songKey);
    state = state.copyWith(isSaved: true);
    try {
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
    } catch (e) {
      state = state.copyWith(isSaved: false);
    } finally {
      _currentlyDownloading.remove(songKey);
    }
  }

  Future<bool> isCurrentSongSaved() async {
    if (state.currentSong == null) return false;
    return await _isSongSavedOrDownloading(state.currentSong!);
  }

  Future<bool> _isSongSavedOrDownloading(Song song) async {
    final songKey = '${song.title}|${song.artists}';
    return _currentlyDownloading.contains(songKey) ||
        await _storageService.isSongSaved(song);
  }

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

  Future<void> playRelated(Song song) async {
    try {
      print('🎵 playRelated called for: ${song.title}');
      print('🔍 Current related songs count: ${state.relatedSongs.length}');

      // Check if the song exists in related songs
      final relatedIndex = state.relatedSongs.indexWhere(
        (s) => s.videoId == song.videoId,
      );
      if (relatedIndex == -1) {
        print('⚠️ Song not found in related songs');
        return;
      }

      // Create new playlist with current song + remaining related songs
      final updatedPlaylist = [
        if (state.currentSong != null) state.currentSong!,
        ...state.relatedSongs.skip(relatedIndex),
      ];

      print('📋 Updated playlist length: ${updatedPlaylist.length}');
      print('   First song: ${updatedPlaylist.firstOrNull?.title}');
      print('   Last song: ${updatedPlaylist.lastOrNull?.title}');

      // Calculate the index in the combined playlist
      final playIndex = state.currentSong != null
          ? relatedIndex + 1
          : relatedIndex;

      await playSong(
        song,
        playlist: updatedPlaylist,
        index: playIndex,
        playlistType: 'related',
        playbackSource: 'related',
      );

      // Remove all songs before the played one from related songs queue
      if (relatedIndex > 0) {
        print('🗑️ Removing $relatedIndex songs from related queue');
        _relatedSongsManager.removeFirstN(relatedIndex);
      }

      print('✅ Successfully played related song');
    } catch (e) {
      print('❌ Error in playRelated: $e');
      await _handlePlaybackError();
    }
  }

  Future<void> playArtistSongs(
    List<Song> artistSongs, {
    int startIndex = 0,
  }) async {
    if (artistSongs.isEmpty) return;

    await playSong(
      artistSongs[startIndex],
      playlist: artistSongs,
      index: startIndex,
      playlistType: 'artist',
      playbackSource: 'artist',
    );
    // playSong will automatically handle related songs fetching
  }

  Future<void> playSavedSongs(
    List<Song> savedSongs, {
    int startIndex = 0,
  }) async {
    if (savedSongs.isEmpty) return;

    await playSong(
      savedSongs[startIndex],
      playlist: savedSongs,
      index: startIndex,
      playlistType: 'saved',
      playbackSource: 'saved',
    );
    // playSong will automatically handle related songs fetching based on queue size
  }

  Future<void> playSearchResults(
    List<Song> searchResults, {
    int startIndex = 0,
    String? searchQuery,
  }) async {
    if (searchResults.isEmpty) return;

    if (startIndex == 0 && searchQuery != null) {
      await handleSearchResults(searchResults, searchQuery);
    } else {
      await playSong(
        searchResults[startIndex],
        playlist: searchResults,
        index: startIndex,
        playlistType: 'search',
        playbackSource: 'search',
      );

      if (state.lastSearchQuery == searchQuery) {
        // Don't manually set seedSong - playSong will handle tracking
        state = state.copyWith(lastSearchQuery: searchQuery);
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _relatedSongsManager.dispose();
    super.dispose();
  }
}
