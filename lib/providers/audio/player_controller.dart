// // audio/core_player_controller.dart
// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:houston/models/media_track.dart';
// import 'package:media_kit/media_kit.dart';
// import 'package:audio_service/audio_service.dart';

// import 'effects_controller.dart';

// class CorePlayerController extends ChangeNotifier {
//   late final Player _player;
//   final AudioHandler _audioHandler;
//   final EffectsController _effectsController;

//   MediaTrack? _currentTrack;
//   Duration _duration = Duration.zero;
//   bool _isPlaying = false;

//   StreamSubscription? _positionSubscription;
//   StreamSubscription? _playingSubscription;
//   StreamSubscription? _completedSubscription;

//   CorePlayerController({
//     required AudioHandler audioHandler,
//     required EffectsController effectsController,
//   }) : _audioHandler = audioHandler,
//        _effectsController = effectsController {
//     _initializePlayer();
//     _setupEffectsListener();
//     _setupPlaybackCompleteListener();
//   }

//   // Getters
//   MediaTrack? get currentTrack => _currentTrack;
//   Duration get duration => _duration;
//   Stream<Duration> get positionStream => _player.stream.position;
//   Stream<bool> get playingStream => _player.stream.playing;
//   bool get isPlaying => _isPlaying;

//   void _initializePlayer() {
//     _player = Player();

//     // Setup player event listeners
//     _positionSubscription = _player.stream.position.listen((position) {
//       if (_currentTrack != null) {
//         _updatePlaybackState(position: position);
//       }
//     });

//     _playingSubscription = _player.stream.playing.listen((playing) {
//       _isPlaying = playing;
//       if (_currentTrack != null) {
//         _updatePlaybackState(playing: playing);
//       }
//       notifyListeners();
//     });

//     // Setup duration listener
//     _player.stream.duration.listen((duration) {
//       _duration = duration;
//       notifyListeners();
//     });
//   }

//   void _updatePlaybackState({Duration? position, bool? playing}) {
//     final newState = PlaybackState(
//       controls: [
//         MediaControl.skipToPrevious,
//         if (playing == true) MediaControl.pause else MediaControl.play,
//         MediaControl.skipToNext,
//       ],
//       systemActions: const {
//         MediaAction.seek,
//         MediaAction.seekForward,
//         MediaAction.seekBackward,
//       },
//       androidCompactActionIndices: const [0, 1, 2],
//       processingState: AudioProcessingState.ready,
//       playing: playing ?? _audioHandler.playbackState.value.playing,
//       updatePosition: position ?? _audioHandler.playbackState.value.position,
//       bufferedPosition: Duration.zero,
//       speed: 1.0,
//       queueIndex: 0,
//     );

//     (_audioHandler.playbackState as ValueNotifier<PlaybackState>).value =
//         newState;
//   }

//   void _setupEffectsListener() {
//     // Initialize the player in effects controller first
//     _effectsController.setPlayer(_player);
//     // Use the public applyEffects method
//     _effectsController.addListener(() async {
//       await _effectsController.applyEffects();
//     });
//   }

//   void _setupPlaybackCompleteListener() {
//     _completedSubscription = _player.stream.completed.listen((completed) {
//       if (completed) {
//         notifyListeners();
//       }
//     });
//   }

//   Future<void> loadTrack(MediaTrack track) async {
//     try {
//       _currentTrack = track;

//       if (track.audioUrl != null) {
//         Media media;

//         if (track.audioUrl!.startsWith('http')) {
//           media = Media(track.audioUrl!);
//         } else if (File(track.audioUrl!).existsSync()) {
//           media = Media('file://${track.audioUrl!}');
//         } else {
//           media = Media(track.audioUrl!);
//         }

//         await _player.open(media);
//       }

//       await _updateMediaSession();
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error loading track: $e');
//     }
//   }

//   Future<void> loadLocalFile(
//     String filePath, {
//     String? title,
//     String? artist,
//   }) async {
//     try {
//       final file = File(filePath);
//       if (!file.existsSync()) {
//         throw Exception('File does not exist: $filePath');
//       }

//       final track = MediaTrack(
//         id: filePath.hashCode.toString(),
//         title: title ?? _getFileNameWithoutExtension(filePath),
//         artists: artist ?? 'Unknown Artist',
//         audioUrl: filePath,
//         isLocal: true,
//       );

//       await loadTrack(track);
//     } catch (e) {
//       debugPrint('Error loading local file: $e');
//     }
//   }

//   String _getFileNameWithoutExtension(String filePath) {
//     final fileName = filePath.split('/').last;
//     final lastDotIndex = fileName.lastIndexOf('.');
//     return lastDotIndex > 0 ? fileName.substring(0, lastDotIndex) : fileName;
//   }

//   Future<void> play() async {
//     await _player.play();
//   }

//   Future<void> pause() async {
//     await _player.pause();
//   }

//   Future<void> togglePlayPause() async {
//     if (_isPlaying) {
//       await pause();
//     } else {
//       await play();
//     }
//   }

//   Future<void> seekTo(Duration position) async {
//     await _player.seek(position);
//   }

//   Future<void> setVolume(double volume) async {
//     await _player.setVolume(volume * 100);
//   }

//   Future<void> _updateMediaSession() async {
//     if (_currentTrack == null) return;

//     Uri? artUri;
//     if (_currentTrack!.albumArt != null &&
//         _currentTrack!.albumArt!.isNotEmpty) {
//       if (_currentTrack!.albumArt!.startsWith('http')) {
//         artUri = Uri.parse(_currentTrack!.albumArt!);
//       } else if (File(_currentTrack!.albumArt!).existsSync()) {
//         artUri = Uri.file(_currentTrack!.albumArt!);
//       } else {
//         try {
//           artUri = Uri.parse(_currentTrack!.albumArt!);
//         } catch (e) {
//           debugPrint('Invalid artUri format: ${_currentTrack!.albumArt}');
//         }
//       }
//     }

//     final mediaItem = MediaItem(
//       id: _currentTrack!.id,
//       album: _currentTrack!.album ?? '',
//       title: _currentTrack!.title,
//       artist: _currentTrack!.artists,
//       duration: duration,
//       artUri: artUri,
//     );

//     await _audioHandler.updateMediaItem(mediaItem);
//   }

//   @override
//   void dispose() {
//     _positionSubscription?.cancel();
//     _playingSubscription?.cancel();
//     _completedSubscription?.cancel();
//     _player.dispose();
//     super.dispose();
//   }
// }
