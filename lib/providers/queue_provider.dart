// import 'dart:async';
// import 'dart:math';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:houston/models/song.dart';
// import 'package:houston/providers/ytmusic_provider.dart';

// // Enum for playback modes
// enum PlaybackMode { normal, repeatAll, repeatOne }

// // Enum for queue source types
// enum QueueSource { search, saved, artist, related, manual }

// // Queue Provider
// final queueProvider = StateNotifierProvider<QueueNotifier, QueueState>((ref) {
//   return QueueNotifier(ref);
// });

// class QueueState {
//   final List<Song> originalQueue;
//   final List<Song> currentQueue;
//   final List<Song> smartQueue;
//   final List<Song> upNext;
//   final Song? currentSong;
//   final int currentIndex;
//   final PlaybackMode playbackMode;
//   final bool isShuffled;
//   final List<int> shuffleIndices;
//   final int shuffleIndex;
//   final bool autoplayEnabled;
//   final bool crossfadeEnabled;
//   final int crossfadeDuration;
//   final QueueSource currentQueueSource;
//   final bool isLoadingRelated;
//   final int relatedSongsFetchCount;
//   final String? lastFetchedFor; // videoId of last song we fetched related for
//   final bool hasMoreRelated; // indicates if more related songs are available

//   QueueState({
//     required this.originalQueue,
//     required this.currentQueue,
//     required this.smartQueue,
//     required this.upNext,
//     this.currentSong,
//     required this.currentIndex,
//     required this.playbackMode,
//     required this.isShuffled,
//     required this.shuffleIndices,
//     required this.shuffleIndex,
//     required this.autoplayEnabled,
//     required this.crossfadeEnabled,
//     required this.crossfadeDuration,
//     required this.currentQueueSource,
//     required this.isLoadingRelated,
//     required this.relatedSongsFetchCount,
//     this.lastFetchedFor,
//     required this.hasMoreRelated,
//   });

//   QueueState copyWith({
//     List<Song>? originalQueue,
//     List<Song>? currentQueue,
//     List<Song>? smartQueue,
//     List<Song>? upNext,
//     Song? currentSong,
//     int? currentIndex,
//     PlaybackMode? playbackMode,
//     bool? isShuffled,
//     List<int>? shuffleIndices,
//     int? shuffleIndex,
//     bool? autoplayEnabled,
//     bool? crossfadeEnabled,
//     int? crossfadeDuration,
//     QueueSource? currentQueueSource,
//     bool? isLoadingRelated,
//     int? relatedSongsFetchCount,
//     String? lastFetchedFor,
//     bool? hasMoreRelated,
//   }) {
//     return QueueState(
//       originalQueue: originalQueue ?? this.originalQueue,
//       currentQueue: currentQueue ?? this.currentQueue,
//       smartQueue: smartQueue ?? this.smartQueue,
//       upNext: upNext ?? this.upNext,
//       currentSong: currentSong ?? this.currentSong,
//       currentIndex: currentIndex ?? this.currentIndex,
//       playbackMode: playbackMode ?? this.playbackMode,
//       isShuffled: isShuffled ?? this.isShuffled,
//       shuffleIndices: shuffleIndices ?? this.shuffleIndices,
//       shuffleIndex: shuffleIndex ?? this.shuffleIndex,
//       autoplayEnabled: autoplayEnabled ?? this.autoplayEnabled,
//       crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
//       crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
//       currentQueueSource: currentQueueSource ?? this.currentQueueSource,
//       isLoadingRelated: isLoadingRelated ?? this.isLoadingRelated,
//       relatedSongsFetchCount:
//           relatedSongsFetchCount ?? this.relatedSongsFetchCount,
//       lastFetchedFor: lastFetchedFor ?? this.lastFetchedFor,
//       hasMoreRelated: hasMoreRelated ?? this.hasMoreRelated,
//     );
//   }
// }

// class QueueNotifier extends StateNotifier<QueueState> {
//   final Ref _ref;
//   Timer? _relatedSongsTimer;

//   QueueNotifier(this._ref)
//     : super(
//         QueueState(
//           originalQueue: [],
//           currentQueue: [],
//           smartQueue: [],
//           upNext: [],
//           currentSong: null,
//           currentIndex: 0,
//           playbackMode: PlaybackMode.normal,
//           isShuffled: false,
//           shuffleIndices: [],
//           shuffleIndex: 0,
//           autoplayEnabled: true,
//           crossfadeEnabled: false,
//           crossfadeDuration: 3,
//           currentQueueSource: QueueSource.manual,
//           isLoadingRelated: false,
//           relatedSongsFetchCount: 0,
//           lastFetchedFor: null,
//           hasMoreRelated: true,
//         ),
//       );

//   @override
//   void dispose() {
//     _relatedSongsTimer?.cancel();
//     super.dispose();
//   }

//   // Get the active queue based on current state
//   List<Song> get activeQueue {
//     if (state.upNext.isNotEmpty) {
//       return [...state.currentQueue, ...state.upNext];
//     }
//     if (state.smartQueue.isNotEmpty && _isAtEndOfQueue()) {
//       return [...state.currentQueue, ...state.smartQueue];
//     }
//     return state.currentQueue;
//   }

//   // Initialize the queue with a playlist and source type
//   void initializeQueue(
//     List<Song> songs, {
//     int startIndex = 0,
//     QueueSource source = QueueSource.manual,
//   }) {
//     if (songs.isEmpty) return;

//     final clampedIndex = startIndex.clamp(0, songs.length - 1);

//     state = state.copyWith(
//       originalQueue: List.from(songs),
//       currentQueue: List.from(songs),
//       currentIndex: clampedIndex,
//       currentSong: songs[clampedIndex],
//       smartQueue: [],
//       upNext: [],
//       currentQueueSource: source,
//       relatedSongsFetchCount: 0,
//       lastFetchedFor: null,
//       hasMoreRelated: true,
//     );

//     // Re-apply shuffle if it was enabled
//     if (state.isShuffled) {
//       _generateShuffleIndices();
//     }

//     // Start preloading related songs if autoplay is enabled
//     _checkAndPreloadRelatedSongs();
//   }

//   // Add songs to the "Up Next" queue
//   void addToUpNext(List<Song> songs) {
//     final updatedUpNext = [...state.upNext, ...songs];
//     state = state.copyWith(upNext: updatedUpNext);
//   }

//   // Add a single song to "Up Next"
//   void addSongToUpNext(Song song) {
//     addToUpNext([song]);
//   }

//   // Add songs to play immediately after current song
//   void playNext(List<Song> songs) {
//     if (songs.isEmpty) return;

//     final updatedUpNext = [...songs, ...state.upNext];
//     state = state.copyWith(upNext: updatedUpNext);
//   }

//   // Add a song to the current queue
//   void addToQueue(Song song) {
//     final updatedQueue = [...state.currentQueue, song];
//     state = state.copyWith(currentQueue: updatedQueue);

//     // If this is the first song being added, set it as current
//     if (state.currentSong == null) {
//       state = state.copyWith(currentSong: song, currentIndex: 0);
//     }
//   }

//   // Replace the entire current queue
//   void replaceQueue(List<Song> songs) {
//     if (songs.isEmpty) {
//       clearQueue();
//       return;
//     }

//     state = state.copyWith(
//       originalQueue: List.from(songs),
//       currentQueue: List.from(songs),
//       currentIndex: 0,
//       currentSong: songs.first,
//       smartQueue: [],
//       upNext: [],
//       currentQueueSource: QueueSource.manual,
//       relatedSongsFetchCount: 0,
//       lastFetchedFor: null,
//       hasMoreRelated: true,
//     );

//     // Re-apply shuffle if enabled
//     if (state.isShuffled) {
//       _generateShuffleIndices();
//     }
//   }

//   void checkAndPreloadRelatedSongs() {
//     if (!state.autoplayEnabled ||
//         state.isLoadingRelated ||
//         !_shouldAutoplayForSource(state.currentQueueSource)) {
//       return;
//     }

//     final totalQueue = [...state.currentQueue, ...state.smartQueue];
//     final totalLength = totalQueue.length;

//     // Only fetch if we're playing the second-to-last song
//     if (state.currentIndex >= totalLength - 2) {
//       final songToFetchFor = totalQueue[state.currentIndex];
//       _fetchRelatedSongsForSong(songToFetchFor);
//     }
//   }

//   // Add a single song to play next
//   void playSongNext(Song song) {
//     // If currently playing, insert right after current song
//     if (state.currentSong != null) {
//       final updatedUpNext = [song, ...state.upNext];
//       state = state.copyWith(upNext: updatedUpNext);

//       // If we're at the end of current queue, play immediately
//       if (state.currentIndex == state.currentQueue.length - 1) {
//         jumpToSong(state.currentIndex + 1);
//       }
//     } else {
//       // If nothing is playing, just add to up next
//       addSongToUpNext(song);
//     }
//   }

//   // Clear the entire queue
//   void clearQueue() {
//     _relatedSongsTimer?.cancel();
//     state = state.copyWith(
//       originalQueue: [],
//       currentQueue: [],
//       smartQueue: [],
//       upNext: [],
//       currentSong: null,
//       currentIndex: 0,
//       shuffleIndices: [],
//       shuffleIndex: 0,
//       currentQueueSource: QueueSource.manual,
//       relatedSongsFetchCount: 0,
//       lastFetchedFor: null,
//       hasMoreRelated: true,
//       isLoadingRelated: false,
//     );
//   }

//   // Clear only "Up Next" queue
//   void clearUpNext() {
//     state = state.copyWith(upNext: []);
//   }

//   // Remove a song from "Up Next"
//   void removeFromUpNext(int index) {
//     if (index < 0 || index >= state.upNext.length) return;

//     final updatedUpNext = List<Song>.from(state.upNext);
//     updatedUpNext.removeAt(index);
//     state = state.copyWith(upNext: updatedUpNext);
//   }

//   // Jump to a specific song in the queue
//   void jumpToSong(int index) {
//     final queue = activeQueue;
//     if (index < 0 || index >= queue.length) return;

//     // Handle jumping within current queue vs up next
//     if (index < state.currentQueue.length) {
//       state = state.copyWith(
//         currentIndex: index,
//         currentSong: state.currentQueue[index],
//       );

//       if (state.isShuffled) {
//         _updateShuffleIndexForJump(index);
//       }
//     } else {
//       // Jumping to up next - move songs to current queue
//       final upNextIndex = index - state.currentQueue.length;
//       final songsToMove = state.upNext.take(upNextIndex + 1).toList();
//       final remainingUpNext = state.upNext.skip(upNextIndex + 1).toList();

//       final newCurrentQueue = [...state.currentQueue, ...songsToMove];
//       final newIndex = newCurrentQueue.length - 1;

//       state = state.copyWith(
//         currentQueue: newCurrentQueue,
//         upNext: remainingUpNext,
//         currentIndex: newIndex,
//         currentSong: songsToMove.last,
//       );
//     }

//     // Check if we need to preload more related songs
//     _checkAndPreloadRelatedSongs();
//   }

//   // Enhanced getNextSong with autoplay logic
//   Song? getNextSong() {
//     final queue = activeQueue;
//     if (queue.isEmpty) return null;

//     int nextIndex;

//     if (state.isShuffled) {
//       nextIndex = _getNextShuffleIndex();
//       if (nextIndex == -1) {
//         return _handleEndOfQueue();
//       }
//     } else {
//       nextIndex = state.currentIndex + 1;

//       // Check if we've reached the end
//       if (nextIndex >= queue.length) {
//         if (state.playbackMode == PlaybackMode.repeatAll) {
//           nextIndex = 0;
//         } else {
//           return _handleEndOfQueue();
//         }
//       }
//     }

//     // Move to next song
//     _moveToIndex(nextIndex);

//     // Check if we need to preload more related songs
//     _checkAndPreloadRelatedSongs();

//     return queue[nextIndex];
//   }

//   // Handle what happens when we reach the end of the current queue
//   Song? _handleEndOfQueue() {
//     if (!state.autoplayEnabled) return null;

//     // Check if autoplay should work for this source
//     if (!_shouldAutoplayForSource(state.currentQueueSource)) return null;

//     // If we have smart queue, transition to it
//     if (state.smartQueue.isNotEmpty) {
//       final firstSmartSong = state.smartQueue.first;

//       // Move first smart song to current queue
//       final updatedCurrentQueue = [...state.currentQueue, firstSmartSong];
//       final updatedSmartQueue = state.smartQueue.skip(1).toList();

//       state = state.copyWith(
//         currentQueue: updatedCurrentQueue,
//         smartQueue: updatedSmartQueue,
//         currentIndex: updatedCurrentQueue.length - 1,
//         currentSong: firstSmartSong,
//       );

//       // Check if we need more related songs
//       _checkAndPreloadRelatedSongs();

//       return firstSmartSong;
//     }

//     // If no smart queue, try to fetch related songs immediately
//     if (state.currentSong != null && !state.isLoadingRelated) {
//       _fetchRelatedSongsImmediate();

//       // Return null while we're fetching
//       return null;
//     }

//     return null;
//   }

//   // Check if autoplay should work for the given source
//   bool _shouldAutoplayForSource(QueueSource source) {
//     switch (source) {
//       case QueueSource.search:
//       case QueueSource.saved:
//       case QueueSource.artist:
//       case QueueSource.related:
//         return true;
//       case QueueSource.manual:
//         return false;
//     }
//   }

//   // Get the previous song in the queue
//   Song? getPreviousSong() {
//     final queue = activeQueue;
//     if (queue.isEmpty) return null;

//     int previousIndex;

//     if (state.isShuffled) {
//       previousIndex = _getPreviousShuffleIndex();
//       if (previousIndex == -1) return null;
//     } else {
//       previousIndex = state.currentIndex - 1;

//       // Check if we've reached the beginning
//       if (previousIndex < 0) {
//         if (state.playbackMode == PlaybackMode.repeatAll) {
//           previousIndex = queue.length - 1;
//         } else {
//           return null;
//         }
//       }
//     }

//     // Move to previous song
//     _moveToIndex(previousIndex);
//     return queue[previousIndex];
//   }

//   // Check if we need to preload related songs - UPDATED LOGIC
//   void _checkAndPreloadRelatedSongs() {
//     if (!state.autoplayEnabled ||
//         state.isLoadingRelated ||
//         !_shouldAutoplayForSource(state.currentQueueSource))
//       return;

//     final totalQueue = [...state.currentQueue, ...state.smartQueue];
//     final totalLength = totalQueue.length;

//     // Only fetch if we're playing the second-to-last song
//     if (state.currentIndex == totalLength - 2) {
//       final songToFetchFor = totalQueue[state.currentIndex];
//       _fetchRelatedSongsForSong(songToFetchFor);
//     }
//   }

//   // Fetch related songs for a specific song
//   void _fetchRelatedSongsForSong(Song song) {
//     if (state.isLoadingRelated) return;

//     // Don't fetch again for the same song unless we need more
//     if (state.lastFetchedFor == song.videoId && state.smartQueue.length >= 10) {
//       return;
//     }

//     _relatedSongsTimer?.cancel();
//     _relatedSongsTimer = Timer(Duration(milliseconds: 500), () {
//       _fetchRelatedSongs(song: song, isImmediate: false);
//     });
//   }

//   // Fetch related songs immediately (for when queue ends)
//   void _fetchRelatedSongsImmediate() {
//     if (state.currentSong == null) return;

//     _relatedSongsTimer?.cancel();
//     _fetchRelatedSongs(song: state.currentSong!, isImmediate: true);
//   }

//   // Enhanced fetchRelatedSongs with better performance and failsafes
//   void _fetchRelatedSongs({
//     required Song song,
//     bool isImmediate = false,
//   }) async {
//     if (state.isLoadingRelated) return;

//     state = state.copyWith(isLoadingRelated: true);

//     try {
//       // Determine how many songs to fetch based on current situation
//       int limit = 45; // Always fetch 45 as requested
//       bool shouldAppend = false;

//       // If we're fetching more songs for the same track (pagination)
//       if (state.lastFetchedFor == song.videoId && state.smartQueue.isNotEmpty) {
//         shouldAppend = true;
//       }

//       final relatedSongs = await _fetchRelatedSongsFromService(
//         song,
//         limit: limit,
//         offset: shouldAppend ? state.relatedSongsFetchCount * 45 : 0,
//       );

//       if (relatedSongs.isNotEmpty) {
//         // Filter out duplicates from current queue and existing smart queue
//         final existingVideoIds = {
//           ...state.currentQueue.map((s) => s.videoId),
//           ...state.smartQueue.map((s) => s.videoId),
//           ...state.upNext.map((s) => s.videoId),
//         };

//         final filteredSongs = relatedSongs
//             .where((song) => !existingVideoIds.contains(song.videoId))
//             .toList();

//         if (filteredSongs.isNotEmpty) {
//           final updatedSmartQueue = shouldAppend
//               ? [...state.smartQueue, ...filteredSongs]
//               : filteredSongs;

//           state = state.copyWith(
//             smartQueue: updatedSmartQueue,
//             lastFetchedFor: song.videoId,
//             relatedSongsFetchCount: shouldAppend
//                 ? state.relatedSongsFetchCount + 1
//                 : 1,
//             hasMoreRelated: filteredSongs.length >= (limit * 0.8),
//           );

//           print(
//             'Added ${filteredSongs.length} related songs to smart queue based on: ${song.title} by ${song.artists}',
//           );
//         }
//       }
//     } catch (e) {
//       print('Error fetching related songs: $e');

//       // Failsafe: If fetching fails, try with a different approach
//       if (isImmediate) {
//         _attemptFallbackAutoplay();
//       }
//     } finally {
//       state = state.copyWith(isLoadingRelated: false);
//     }
//   }

//   // Fallback autoplay when related songs fail
//   void _attemptFallbackAutoplay() {
//     // Try to use songs from the original queue as fallback
//     if (state.currentQueueSource != QueueSource.related &&
//         state.originalQueue.isNotEmpty) {
//       final fallbackSongs = state.originalQueue
//           .where((song) => song.videoId != state.currentSong?.videoId)
//           .take(10)
//           .toList();

//       if (fallbackSongs.isNotEmpty) {
//         state = state.copyWith(smartQueue: fallbackSongs);
//         print('Using fallback songs from original queue');
//       }
//     }
//   }

//   // Enable shuffle mode
//   void enableShuffle() {
//     if (state.isShuffled) return;

//     _generateShuffleIndices();
//     state = state.copyWith(isShuffled: true);
//   }

//   // Disable shuffle mode
//   void disableShuffle() {
//     if (!state.isShuffled) return;

//     state = state.copyWith(
//       isShuffled: false,
//       shuffleIndices: [],
//       shuffleIndex: 0,
//     );
//   }

//   // Toggle shuffle mode
//   void toggleShuffle() {
//     if (state.isShuffled) {
//       disableShuffle();
//     } else {
//       enableShuffle();
//     }
//   }

//   // Toggle between playback modes
//   void togglePlaybackMode() {
//     PlaybackMode nextMode;
//     switch (state.playbackMode) {
//       case PlaybackMode.normal:
//         nextMode = PlaybackMode.repeatAll;
//         break;
//       case PlaybackMode.repeatAll:
//         nextMode = PlaybackMode.repeatOne;
//         break;
//       case PlaybackMode.repeatOne:
//         nextMode = PlaybackMode.normal;
//         break;
//     }

//     state = state.copyWith(playbackMode: nextMode);
//   }

//   // Set specific playback mode
//   void setPlaybackMode(PlaybackMode mode) {
//     state = state.copyWith(playbackMode: mode);
//   }

//   // Toggle autoplay with smart preloading
//   void toggleAutoplay() {
//     final newAutoplayState = !state.autoplayEnabled;
//     state = state.copyWith(autoplayEnabled: newAutoplayState);

//     // If autoplay was enabled, start preloading
//     if (newAutoplayState) {
//       _checkAndPreloadRelatedSongs();
//     } else {
//       // Cancel any pending fetches
//       _relatedSongsTimer?.cancel();
//     }
//   }

//   // Toggle crossfade
//   void toggleCrossfade() {
//     state = state.copyWith(crossfadeEnabled: !state.crossfadeEnabled);
//   }

//   // Set crossfade duration
//   void setCrossfadeDuration(int seconds) {
//     final clampedDuration = seconds.clamp(1, 10);
//     state = state.copyWith(crossfadeDuration: clampedDuration);
//   }

//   // Reorder songs in the current queue
//   void reorderQueue(int oldIndex, int newIndex) {
//     if (oldIndex == newIndex) return;

//     final updatedQueue = List<Song>.from(state.currentQueue);
//     final song = updatedQueue.removeAt(oldIndex);
//     updatedQueue.insert(newIndex, song);

//     // Update current index if needed
//     int updatedCurrentIndex = state.currentIndex;
//     if (oldIndex == state.currentIndex) {
//       updatedCurrentIndex = newIndex;
//     } else if (oldIndex < state.currentIndex &&
//         newIndex >= state.currentIndex) {
//       updatedCurrentIndex--;
//     } else if (oldIndex > state.currentIndex &&
//         newIndex <= state.currentIndex) {
//       updatedCurrentIndex++;
//     }

//     state = state.copyWith(
//       currentQueue: updatedQueue,
//       currentIndex: updatedCurrentIndex,
//     );
//   }

//   // Remove a song from the current queue
//   void removeSongFromQueue(int index) {
//     if (index < 0 || index >= state.currentQueue.length) return;

//     final updatedQueue = List<Song>.from(state.currentQueue);
//     updatedQueue.removeAt(index);

//     // Update current index if needed
//     int updatedCurrentIndex = state.currentIndex;
//     if (index < state.currentIndex) {
//       updatedCurrentIndex--;
//     } else if (index == state.currentIndex) {
//       // Current song was removed
//       if (updatedCurrentIndex >= updatedQueue.length) {
//         updatedCurrentIndex = updatedQueue.length - 1;
//       }
//     }

//     final updatedCurrentSong =
//         updatedQueue.isNotEmpty && updatedCurrentIndex >= 0
//         ? updatedQueue[updatedCurrentIndex]
//         : null;

//     state = state.copyWith(
//       currentQueue: updatedQueue,
//       currentIndex: updatedCurrentIndex.clamp(0, updatedQueue.length - 1),
//       currentSong: updatedCurrentSong,
//     );

//     // Check if we need to preload more songs after removal
//     _checkAndPreloadRelatedSongs();
//   }

//   // Private helper methods
//   void _moveToIndex(int index) {
//     final queue = activeQueue;
//     if (index < 0 || index >= queue.length) return;

//     // Handle moving within different queue sections
//     if (index < state.currentQueue.length) {
//       state = state.copyWith(
//         currentIndex: index,
//         currentSong: state.currentQueue[index],
//       );
//     } else {
//       // Moving to up next or smart queue
//       final upNextIndex = index - state.currentQueue.length;

//       if (upNextIndex < state.upNext.length) {
//         // Moving to up next
//         final songsToMove = state.upNext.take(upNextIndex + 1).toList();
//         final remainingUpNext = state.upNext.skip(upNextIndex + 1).toList();

//         final newCurrentQueue = [...state.currentQueue, ...songsToMove];
//         final newIndex = newCurrentQueue.length - 1;

//         state = state.copyWith(
//           currentQueue: newCurrentQueue,
//           upNext: remainingUpNext,
//           currentIndex: newIndex,
//           currentSong: songsToMove.last,
//         );
//       } else {
//         // Moving to smart queue
//         final smartIndex = upNextIndex - state.upNext.length;
//         if (smartIndex < state.smartQueue.length) {
//           final songsToMove = [
//             ...state.upNext,
//             ...state.smartQueue.take(smartIndex + 1),
//           ];
//           final remainingSmartQueue = state.smartQueue
//               .skip(smartIndex + 1)
//               .toList();

//           final newCurrentQueue = [...state.currentQueue, ...songsToMove];
//           final newIndex = newCurrentQueue.length - 1;

//           state = state.copyWith(
//             currentQueue: newCurrentQueue,
//             upNext: [],
//             smartQueue: remainingSmartQueue,
//             currentIndex: newIndex,
//             currentSong: songsToMove.last,
//           );
//         }
//       }
//     }
//   }

//   void _generateShuffleIndices() {
//     final queue = activeQueue;
//     if (queue.isEmpty) return;

//     final indices = List.generate(queue.length, (index) => index);
//     indices.remove(state.currentIndex); // Don't shuffle current song
//     indices.shuffle(Random());

//     // Put current song at the beginning of shuffle
//     final shuffleIndices = [state.currentIndex, ...indices];

//     state = state.copyWith(shuffleIndices: shuffleIndices, shuffleIndex: 0);
//   }

//   int _getNextShuffleIndex() {
//     if (state.shuffleIndices.isEmpty) return -1;

//     int nextShuffleIndex = state.shuffleIndex + 1;

//     if (nextShuffleIndex >= state.shuffleIndices.length) {
//       if (state.playbackMode == PlaybackMode.repeatAll) {
//         _generateShuffleIndices(); // Re-shuffle
//         return state.shuffleIndices.first;
//       }
//       return -1;
//     }

//     state = state.copyWith(shuffleIndex: nextShuffleIndex);
//     return state.shuffleIndices[nextShuffleIndex];
//   }

//   int _getPreviousShuffleIndex() {
//     if (state.shuffleIndices.isEmpty) return -1;

//     int previousShuffleIndex = state.shuffleIndex - 1;

//     if (previousShuffleIndex < 0) {
//       if (state.playbackMode == PlaybackMode.repeatAll) {
//         previousShuffleIndex = state.shuffleIndices.length - 1;
//       } else {
//         return -1;
//       }
//     }

//     state = state.copyWith(shuffleIndex: previousShuffleIndex);
//     return state.shuffleIndices[previousShuffleIndex];
//   }

//   void _updateShuffleIndexForJump(int targetIndex) {
//     final shuffleIndexPosition = state.shuffleIndices.indexOf(targetIndex);
//     if (shuffleIndexPosition != -1) {
//       state = state.copyWith(shuffleIndex: shuffleIndexPosition);
//     }
//   }

//   bool _isAtEndOfQueue() {
//     return state.currentIndex >= state.currentQueue.length - 1;
//   }

//   // Enhanced method with pagination support and better error handling
//   Future<List<Song>> _fetchRelatedSongsFromService(
//     Song song, {
//     int limit = 45,
//     int offset = 0,
//   }) async {
//     try {
//       final ytMusicNotifier = _ref.read(ytMusicProvider.notifier);
//       final ytMusicState = _ref.read(ytMusicProvider);

//       // Check if YT Music is initialized
//       if (!ytMusicState.isInitialized) {
//         print('YT Music not initialized, cannot fetch related songs');
//         return [];
//       }

//       // Clear previous related songs only if this is a fresh fetch (offset = 0)
//       if (offset == 0) {
//         ytMusicNotifier.clearRelatedSongs();
//       }

//       // Create a completer to handle the streaming response
//       final completer = Completer<List<Song>>();
//       late ProviderSubscription<YtMusicState> subscription;

//       // Listen to the ytMusicProvider state changes
//       subscription = _ref.listen(ytMusicProvider, (previous, next) {
//         // Check if streaming is done and we have results
//         if (previous?.isStreaming == true &&
//             next.isStreaming == false &&
//             !next.isLoading &&
//             next.relatedSongs.isNotEmpty) {
//           subscription.close();
//           completer.complete(next.relatedSongs);
//         }
//         // Handle error case or empty results
//         else if (previous?.isStreaming == true &&
//             next.isStreaming == false &&
//             !next.isLoading) {
//           subscription.close();
//           if (next.error != null) {
//             completer.completeError(next.error!);
//           } else {
//             completer.complete(next.relatedSongs);
//           }
//         }
//       });

//       // Start streaming related songs
//       ytMusicNotifier.streamRelatedSongs(
//         songName: song.title,
//         artistName: song.artists,
//         limit: limit,
//         audioQuality: 'high',
//         thumbnailQuality: 'very_high',
//         context: null,
//       );

//       // Wait for completion with timeout
//       return await completer.future.timeout(
//         Duration(seconds: 30),
//         onTimeout: () {
//           subscription.close();
//           print('Timeout fetching related songs for: ${song.title}');
//           return [];
//         },
//       );
//     } catch (e) {
//       print('Error fetching related songs: $e');
//       return [];
//     }
//   }
// }
