// // audio/bg_handler.dart
// import 'dart:async';
// import 'package:audio_service/audio_service.dart';
// import 'package:flutter/foundation.dart';

// class HoustonAudioHandler extends BaseAudioHandler
//     with QueueHandler, SeekHandler {
//   static const String _playAction = 'play';
//   static const String _pauseAction = 'pause';
//   static const String _nextAction = 'next';
//   static const String _previousAction = 'previous';
//   static const String _seekToAction = 'seekTo';

//   HoustonAudioHandler() {
//     _initializeHandler();
//   }

//   void _initializeHandler() {
//     // Initialize playback state
//     playbackState.add(
//       const PlaybackState(
//         controls: [
//           MediaControl.skipToPrevious,
//           MediaControl.play,
//           MediaControl.skipToNext,
//         ],
//         systemActions: {
//           MediaAction.seek,
//           MediaAction.seekForward,
//           MediaAction.seekBackward,
//         },
//         androidCompactActionIndices: [0, 1, 2],
//         processingState: AudioProcessingState.idle,
//         playing: false,
//         updatePosition: Duration.zero,
//         bufferedPosition: Duration.zero,
//         speed: 1.0,
//       ),
//     );
//   }

//   // Media control handlers
//   @override
//   Future<void> play() async {
//     debugPrint('AudioHandler: play() called');

//     // Update playback state
//     playbackState.add(
//       playbackState.value.copyWith(
//         controls: [
//           MediaControl.skipToPrevious,
//           MediaControl.pause,
//           MediaControl.skipToNext,
//         ],
//         systemActions: {
//           MediaAction.seek,
//           MediaAction.seekForward,
//           MediaAction.seekBackward,
//         },
//         androidCompactActionIndices: [0, 1, 2],
//         processingState: AudioProcessingState.ready,
//         playing: true,
//       ),
//     );
//   }

//   @override
//   Future<void> pause() async {
//     debugPrint('AudioHandler: pause() called');

//     playbackState.add(
//       playbackState.value.copyWith(
//         controls: [
//           MediaControl.skipToPrevious,
//           MediaControl.play,
//           MediaControl.skipToNext,
//         ],
//         systemActions: {
//           MediaAction.seek,
//           MediaAction.seekForward,
//           MediaAction.seekBackward,
//         },
//         androidCompactActionIndices: [0, 1, 2],
//         processingState: AudioProcessingState.ready,
//         playing: false,
//       ),
//     );
//   }

//   @override
//   Future<void> skipToNext() async {
//     debugPrint('AudioHandler: skipToNext() called');
//     // The actual implementation will be handled by PlayerController
//     // This just updates the UI state
//   }

//   @override
//   Future<void> skipToPrevious() async {
//     debugPrint('AudioHandler: skipToPrevious() called');
//     // The actual implementation will be handled by PlayerController
//   }

//   @override
//   Future<void> seek(Duration position) async {
//     debugPrint('AudioHandler: seek() called - ${position.toString()}');

//     playbackState.add(playbackState.value.copyWith(updatePosition: position));
//   }

//   @override
//   Future<void> stop() async {
//     debugPrint('AudioHandler: stop() called');

//     playbackState.add(
//       playbackState.value.copyWith(
//         controls: [],
//         processingState: AudioProcessingState.idle,
//         playing: false,
//         updatePosition: Duration.zero,
//       ),
//     );

//     // Clear current media item
//     mediaItem.add(null);
//   }

//   // Custom methods for Houston-specific functionality
//   Future<void> updateMediaItem(MediaItem item) async {
//     mediaItem.add(item);
//   }

//   Future<void> updatePlaybackPosition(Duration position) async {
//     playbackState.add(playbackState.value.copyWith(updatePosition: position));
//   }

//   Future<void> updateBufferedPosition(Duration position) async {
//     playbackState.add(playbackState.value.copyWith(bufferedPosition: position));
//   }

//   Future<void> updatePlayingState(bool playing) async {
//     final controls = playing
//         ? [
//             MediaControl.skipToPrevious,
//             MediaControl.pause,
//             MediaControl.skipToNext,
//           ]
//         : [
//             MediaControl.skipToPrevious,
//             MediaControl.play,
//             MediaControl.skipToNext,
//           ];

//     playbackState.add(
//       playbackState.value.copyWith(
//         controls: controls,
//         playing: playing,
//         processingState: AudioProcessingState.ready,
//       ),
//     );
//   }

//   // Handle custom actions
//   @override
//   Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
//     switch (name) {
//       case 'toggleShuffle':
//         // Handle shuffle toggle
//         debugPrint('AudioHandler: toggleShuffle() called');
//         break;
//       case 'toggleRepeat':
//         // Handle repeat toggle
//         debugPrint('AudioHandler: toggleRepeat() called');
//         break;
//       case 'setRating':
//         // Handle rating (like/dislike)
//         debugPrint('AudioHandler: setRating() called');
//         break;
//       default:
//         debugPrint('AudioHandler: Unknown custom action: $name');
//     }
//   }

//   // Queue management
//   @override
//   Future<void> addQueueItem(MediaItem mediaItem) async {
//     final newQueue = [...queue.value, mediaItem];
//     queue.add(newQueue);
//   }

//   @override
//   Future<void> addQueueItems(List<MediaItem> mediaItems) async {
//     final newQueue = [...queue.value, ...mediaItems];
//     queue.add(newQueue);
//   }

//   @override
//   Future<void> removeQueueItem(MediaItem mediaItem) async {
//     final newQueue = queue.value
//         .where((item) => item.id != mediaItem.id)
//         .toList();
//     queue.add(newQueue);
//   }

//   @override
//   Future<void> skipToQueueItem(int index) async {
//     if (index >= 0 && index < queue.value.length) {
//       debugPrint('AudioHandler: skipToQueueItem() called - index: $index');
//       mediaItem.add(queue.value[index]);
//     }
//   }

//   @override
//   Future<void> updateQueue(List<MediaItem> newQueue) async {
//     queue.add(newQueue);
//   }

//   // Error handling
//   void notifyError(String code, String message) {
//     playbackState.add(
//       playbackState.value.copyWith(processingState: AudioProcessingState.error),
//     );

//     debugPrint('AudioHandler Error - Code: $code, Message: $message');
//   }

//   // Cleanup
//   Future<void> dispose() async {
//     await stop();
//   }
// }
