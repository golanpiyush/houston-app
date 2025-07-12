import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/models/lyrics_model.dart';
import 'package:houston/providers/managers/download_manager.dart';
import 'package:houston/services/storage_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song.dart';

final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  return AudioNotifier();
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
    required this.currentLyrics, // new
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
    );
  }
}

class AudioNotifier extends StateNotifier<AudioState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final StorageService _storageService = StorageService();
  final DownloadManager _downloadManager = DownloadManager();
  final Set<String> _currentlyDownloading = {}; // Track downloading songs

  // getter
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  AudioNotifier()
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
          currentLyrics: [], // <- Add this
        ),
      ) {
    _initializePlayer();
  }

  void _initializePlayer() {
    _audioPlayer.positionStream.listen((position) {
      state = state.copyWith(currentPosition: position);
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(totalDuration: duration);
      }
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
        isLoading: playerState.processingState == ProcessingState.loading,
      );
    });
  }

  void setLyrics(List<LyricsLine> lyrics) {
    state = state.copyWith(currentLyrics: lyrics);
  }

  Future<void> playSong(Song song, {List<Song>? playlist, int? index}) async {
    try {
      state = state.copyWith(isLoading: true);

      if (song.audioUrl != null) {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(song.audioUrl!),
            tag: MediaItem(
              id: song.audioUrl!,
              title: song.title,
              artist: song.artists,
              artUri: song.albumArt != null ? Uri.parse(song.albumArt!) : null,
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
        );

        await _audioPlayer.play();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print('Error playing song: $e');
    }
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

  Future<void> playNext() async {
    if (state.currentIndex < state.playlist.length - 1) {
      await playSong(
        state.playlist[state.currentIndex + 1],
        playlist: state.playlist,
        index: state.currentIndex + 1,
      );
    }
  }

  Future<void> playPrevious() async {
    if (state.currentIndex > 0) {
      await playSong(
        state.playlist[state.currentIndex - 1],
        playlist: state.playlist,
        index: state.currentIndex - 1,
      );
    }
  }

  void toggleFavorite() {
    state = state.copyWith(isFavorite: !state.isFavorite);
  }

  Future<void> toggleSaved() async {
    if (state.currentSong == null) return;

    final song = state.currentSong!;
    final songKey = '${song.title}|${song.artists}';
    // Check if already saved/downloading
    final isSaved = await _isSongSavedOrDownloading(song);

    if (isSaved) {
      // Remove from saved/downloading
      await _storageService.removeSong(song);
      _currentlyDownloading.remove(songKey);
      state = state.copyWith(isSaved: false);
      return;
    }
    // Start download process
    _currentlyDownloading.add(songKey);
    state = state.copyWith(isSaved: true);
    try {
      // Download both audio and artwork
      final audioPath = await _downloadManager.downloadAudio(song);

      // Check if download was successful
      if (audioPath == null) {
        throw Exception('Failed to download audio');
      }

      final artPath = song.albumArt != null
          ? await _downloadManager.downloadAlbumArt(song)
          : null;
      // Save to storage
      await _storageService.saveSong(
        title: song.title,
        artist: song.artists,
        audioUrl: song.audioUrl!,
        audioPath: audioPath, // Now guaranteed to be non-null
        albumArtUrl: song.albumArt,
        albumArtPath: artPath,
      );
    } catch (e) {
      state = state.copyWith(isSaved: false);
      // Handle error
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
