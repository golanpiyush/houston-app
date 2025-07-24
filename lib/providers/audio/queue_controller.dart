// // audio/queue_controller.dart
// import 'dart:async';

// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:houston/models/media_track.dart';
// import 'package:houston/providers/audio/player_controller.dart';
// import 'package:houston/providers/ytmusic_provider.dart';

// class QueueController extends ChangeNotifier {
//   final CorePlayerController _playerController;
//   final WidgetRef _ref;

//   List<MediaTrack> _playlist = [];
//   int _currentIndex = -1;
//   bool _isAutoLoadingRelated = false;

//   QueueController({
//     required CorePlayerController playerController,
//     required WidgetRef ref,
//   }) : _playerController = playerController,
//        _ref = ref;

//   // Getters
//   List<MediaTrack> get playlist => List.unmodifiable(_playlist);
//   int get currentIndex => _currentIndex;
//   bool get isAutoLoadingRelated => _isAutoLoadingRelated;

//   Future<void> _handleTrackCompleted() async {
//     if (hasNext()) {
//       await playNext();
//     } else if (_playerController.currentTrack != null &&
//         !_isAutoLoadingRelated) {
//       await _autoLoadRelatedSongs();
//     }
//   }

//   // Playlist management methods
//   void setPlaylist(List<MediaTrack> tracks) {
//     _playlist = List.from(tracks);
//     _currentIndex = tracks.isNotEmpty ? 0 : -1;
//     notifyListeners();
//   }

//   void addToPlaylist(List<MediaTrack> tracks) {
//     _playlist.addAll(tracks);
//     notifyListeners();
//   }

//   void insertNext(MediaTrack track) {
//     if (_currentIndex >= 0) {
//       _playlist.insert(_currentIndex + 1, track);
//     } else {
//       _playlist.add(track);
//     }
//     notifyListeners();
//   }

//   void removeFromPlaylist(int index) {
//     if (index >= 0 && index < _playlist.length) {
//       _playlist.removeAt(index);
//       if (index < _currentIndex) {
//         _currentIndex--;
//       } else if (index == _currentIndex) {
//         _currentIndex = -1;
//       }
//       notifyListeners();
//     }
//   }

//   bool hasNext() =>
//       _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
//   bool hasPrevious() => _playlist.isNotEmpty && _currentIndex > 0;

//   Future<void> playNext() async {
//     if (hasNext()) {
//       _currentIndex++;
//       await _playerController.loadTrack(_playlist[_currentIndex]);
//       await _playerController.play();
//     }
//   }

//   Future<void> playPrevious() async {
//     if (hasPrevious()) {
//       _currentIndex--;
//       await _playerController.loadTrack(_playlist[_currentIndex]);
//       await _playerController.play();
//     }
//   }

//   Future<void> playTrackAt(int index) async {
//     if (index >= 0 && index < _playlist.length) {
//       _currentIndex = index;
//       await _playerController.loadTrack(_playlist[index]);
//       await _playerController.play();
//     }
//   }

//   void shufflePlaylist() {
//     if (_playlist.length > 1) {
//       final currentTrack = _currentIndex >= 0 ? _playlist[_currentIndex] : null;
//       _playlist.shuffle();

//       if (currentTrack != null) {
//         _currentIndex = _playlist.indexOf(currentTrack);
//       }

//       notifyListeners();
//     }
//   }

//   // Search and related songs methods
//   Future<void> searchAndPlay(
//     String query, {
//     bool autoLoadRelated = true,
//   }) async {
//     try {
//       _ref.read(ytMusicProvider.notifier).clearSearch();

//       _ref
//           .read(ytMusicProvider.notifier)
//           .streamSearchResults(
//             query: query,
//             limit: 1,
//             audioQuality: 'very_high',
//             thumbnailQuality: 'high',
//             context: null,
//           );

//       final completer = Completer<void>();
//       bool isListening = true;

//       _ref.listen<YtMusicState>(ytMusicProvider, (previous, next) {
//         if (!isListening) return;

//         if (!next.isStreaming &&
//             next.searchResults.isNotEmpty &&
//             !completer.isCompleted) {
//           isListening = false;
//           completer.complete();
//         } else if (!next.isStreaming &&
//             next.searchResults.isEmpty &&
//             next.error != null &&
//             !completer.isCompleted) {
//           isListening = false;
//           completer.completeError(next.error!);
//         }
//       });

//       await completer.future.timeout(
//         const Duration(seconds: 30),
//         onTimeout: () {
//           isListening = false;
//           throw TimeoutException('Search timeout', const Duration(seconds: 30));
//         },
//       );

//       final results = _ref.read(ytMusicProvider).searchResults;
//       if (results.isNotEmpty) {
//         final track = MediaTrack.fromSong(results.first);
//         await _playerController.loadTrack(track);
//         await _playerController.play();

//         if (autoLoadRelated) {
//           _autoLoadRelatedSongs();
//         }
//       }
//     } catch (e) {
//       debugPrint('Error searching and playing: $e');
//     }
//   }

//   Future<void> _autoLoadRelatedSongs() async {
//     if (_playerController.currentTrack == null || _isAutoLoadingRelated) return;

//     _isAutoLoadingRelated = true;
//     notifyListeners();

//     try {
//       _ref.read(ytMusicProvider.notifier).clearRelatedSongs();

//       _ref
//           .read(ytMusicProvider.notifier)
//           .streamRelatedSongs(
//             songName: _playerController.currentTrack!.title,
//             artistName: _playerController.currentTrack!.artists,
//             limit: 20,
//             audioQuality: 'high',
//             thumbnailQuality: 'medium',
//           );

//       final completer = Completer<void>();
//       bool isListening = true;

//       _ref.listen<YtMusicState>(ytMusicProvider, (previous, next) {
//         if (!isListening) return;

//         if (!next.isStreaming &&
//             next.relatedSongs.isNotEmpty &&
//             !completer.isCompleted) {
//           isListening = false;
//           completer.complete();
//         }
//       });

//       await completer.future.timeout(
//         const Duration(seconds: 30),
//         onTimeout: () {
//           isListening = false;
//           debugPrint('Related songs loading timed out');
//         },
//       );

//       final relatedSongs = _ref.read(ytMusicProvider).relatedSongs;
//       if (relatedSongs.isNotEmpty) {
//         final relatedTracks = relatedSongs
//             .map((song) => MediaTrack.fromSong(song))
//             .toList();
//         addToPlaylist(relatedTracks);
//       }
//     } catch (e) {
//       debugPrint('Error loading related songs: $e');
//     } finally {
//       _isAutoLoadingRelated = false;
//       notifyListeners();
//     }
//   }

//   Future<void> loadArtistSongs(String artistName) async {
//     try {
//       _ref.read(ytMusicProvider.notifier).clearArtistSongs();

//       _ref
//           .read(ytMusicProvider.notifier)
//           .streamArtistSongs(
//             artistName: artistName,
//             limit: 50,
//             audioQuality: 'high',
//             thumbnailQuality: 'medium',
//             context: null,
//           );

//       final completer = Completer<void>();
//       bool isListening = true;

//       _ref.listen<YtMusicState>(ytMusicProvider, (previous, next) {
//         if (!isListening) return;

//         if (!next.isStreaming &&
//             next.artistSongs.isNotEmpty &&
//             !completer.isCompleted) {
//           isListening = false;
//           completer.complete();
//         }
//       });

//       await completer.future.timeout(
//         const Duration(seconds: 30),
//         onTimeout: () {
//           isListening = false;
//           debugPrint('Artist songs loading timed out');
//         },
//       );

//       final artistSongs = _ref.read(ytMusicProvider).artistSongs;
//       if (artistSongs.isNotEmpty) {
//         final tracks = artistSongs
//             .map((song) => MediaTrack.fromSong(song))
//             .toList();
//         setPlaylist(tracks);
//       }
//     } catch (e) {
//       debugPrint('Error loading artist songs: $e');
//     }
//   }
// }
