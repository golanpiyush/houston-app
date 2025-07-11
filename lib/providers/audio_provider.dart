// providers/audio_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
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

  AudioState({
    this.currentSong,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.isLoading,
    required this.playlist,
    required this.currentIndex,
    required this.isFavorite,
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
    );
  }
}

class AudioNotifier extends StateNotifier<AudioState> {
  final AudioPlayer _audioPlayer = AudioPlayer();

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

  Future<void> playSong(Song song, {List<Song>? playlist, int? index}) async {
    try {
      state = state.copyWith(isLoading: true);

      if (song.audioUrl != null) {
        await _audioPlayer.setUrl(song.audioUrl!);

        state = state.copyWith(
          currentSong: song,
          playlist: playlist ?? [song],
          currentIndex: index ?? 0,
          isLoading: false,
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
