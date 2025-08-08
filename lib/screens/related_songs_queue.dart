import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradient_mini_music_visualizer/mini_music_visualizer.dart';
import 'package:houston/models/song.dart';
import 'package:houston/providers/audio/audio_state_provider.dart';
import 'package:houston/providers/ytmusic_provider.dart';
import 'package:houston/screens/player_screen.dart';

// Global queue state provider to persist across rebuilds
final queueStateProvider =
    StateNotifierProvider<QueueStateNotifier, QueueState>((ref) {
      return QueueStateNotifier();
    });

class QueueState {
  final List<Song> originalOrder;
  final List<Song> currentOrder;
  final bool isShuffled;
  final bool isLooping;
  final int currentIndex;
  final String? seedSongId;
  final bool hasUserReordered;

  const QueueState({
    this.originalOrder = const [],
    this.currentOrder = const [],
    this.isShuffled = false,
    this.isLooping = false,
    this.currentIndex = 0,
    this.seedSongId,
    this.hasUserReordered = false,
  });

  QueueState copyWith({
    List<Song>? originalOrder,
    List<Song>? currentOrder,
    bool? isShuffled,
    bool? isLooping,
    int? currentIndex,
    String? seedSongId,
    bool? hasUserReordered,
  }) {
    return QueueState(
      originalOrder: originalOrder ?? this.originalOrder,
      currentOrder: currentOrder ?? this.currentOrder,
      isShuffled: isShuffled ?? this.isShuffled,
      isLooping: isLooping ?? this.isLooping,
      currentIndex: currentIndex ?? this.currentIndex,
      seedSongId: seedSongId ?? this.seedSongId,
      hasUserReordered: hasUserReordered ?? this.hasUserReordered,
    );
  }
}

class QueueStateNotifier extends StateNotifier<QueueState> {
  QueueStateNotifier() : super(const QueueState());

  void updateQueue(List<Song> songs, String? seedSongId) {
    // Ensure we're not updating during build
    if (mounted) {
      // Only update if it's a different seed song or first time
      if (state.seedSongId != seedSongId || state.originalOrder.isEmpty) {
        print(
          '🔄 Updating queue with ${songs.length} songs for seed: $seedSongId',
        );
        state = QueueState(
          originalOrder: List.from(songs),
          currentOrder: List.from(songs),
          seedSongId: seedSongId,
          isShuffled: false,
          isLooping: state.isLooping, // Preserve loop state
          currentIndex: 0,
          hasUserReordered: false,
        );
      } else if (!state.hasUserReordered) {
        // Add new songs to existing queue if user hasn't reordered
        final existingIds = state.originalOrder.map((s) => s.videoId).toSet();
        final newSongs = songs
            .where((s) => !existingIds.contains(s.videoId))
            .toList();

        if (newSongs.isNotEmpty) {
          print('➕ Adding ${newSongs.length} new songs to existing queue');
          final updatedOriginal = [...state.originalOrder, ...newSongs];
          final updatedCurrent = state.isShuffled
              ? [...state.currentOrder, ...newSongs..shuffle()]
              : [...state.currentOrder, ...newSongs];

          state = state.copyWith(
            originalOrder: updatedOriginal,
            currentOrder: updatedCurrent,
          );
        }
      }
    }
  }

  void updateQueueSafely(List<Song> songs, String? seedSongId) {
    // Schedule the update for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateQueue(songs, seedSongId);
    });
  }

  void toggleShuffle() {
    print('🔀 Toggling shuffle: ${!state.isShuffled}');

    Song? currentSong;
    if (state.currentIndex < state.currentOrder.length) {
      currentSong = state.currentOrder[state.currentIndex];
    }

    List<Song> newOrder;
    int newIndex = 0;

    if (!state.isShuffled) {
      // Enable shuffle
      newOrder = List.from(state.currentOrder)..shuffle();
      if (currentSong != null) {
        newIndex = newOrder.indexWhere(
          (s) => s.videoId == currentSong!.videoId,
        );
        if (newIndex == -1) newIndex = 0;
      }
    } else {
      // Disable shuffle - restore original order
      newOrder = List.from(state.originalOrder);
      if (currentSong != null) {
        newIndex = newOrder.indexWhere(
          (s) => s.videoId == currentSong!.videoId,
        );
        if (newIndex == -1) newIndex = 0;
      }
    }

    state = state.copyWith(
      currentOrder: newOrder,
      isShuffled: !state.isShuffled,
      currentIndex: newIndex,
    );
  }

  void toggleLoop() {
    print('🔁 Toggling loop: ${!state.isLooping}');
    state = state.copyWith(isLooping: !state.isLooping);
  }

  void reorderSongs(int oldIndex, int newIndex) {
    print('🔄 Reordering: $oldIndex -> $newIndex');
    print('📋 Current queue length: ${state.currentOrder.length}');

    // Enhanced validation
    if (state.currentOrder.isEmpty) {
      print('❌ Cannot reorder: queue is empty');
      return;
    }

    if (oldIndex < 0 || oldIndex >= state.currentOrder.length) {
      print(
        '❌ Invalid oldIndex: $oldIndex (valid range: 0-${state.currentOrder.length - 1})',
      );
      return;
    }

    if (newIndex < 0 || newIndex >= state.currentOrder.length) {
      print(
        '❌ Invalid newIndex: $newIndex (valid range: 0-${state.currentOrder.length - 1})',
      );
      return;
    }

    if (oldIndex == newIndex) {
      print('⚠️ Same index, no reorder needed');
      return;
    }

    print('🎵 Current playing index: ${state.currentIndex}');
    print(
      '📋 Before reorder: ${state.currentOrder.map((s) => '${s.title.length > 10 ? s.title.substring(0, 10) : s.title}...').toList()}',
    );

    try {
      final newOrder = List<Song>.from(state.currentOrder);

      // Remove the song from old position
      final song = newOrder.removeAt(oldIndex);

      // Insert at new position
      newOrder.insert(newIndex, song);

      // Update current index tracking
      int newCurrentIndex = state.currentIndex;

      if (oldIndex == state.currentIndex) {
        // The currently playing song was moved
        newCurrentIndex = newIndex;
      } else if (oldIndex < state.currentIndex &&
          newIndex >= state.currentIndex) {
        // Song moved from before current to after current
        newCurrentIndex -= 1;
      } else if (oldIndex > state.currentIndex &&
          newIndex <= state.currentIndex) {
        // Song moved from after current to before current
        newCurrentIndex += 1;
      }

      // Final bounds check for new current index
      if (newCurrentIndex < 0) {
        newCurrentIndex = 0;
      } else if (newCurrentIndex >= newOrder.length) {
        newCurrentIndex = newOrder.length - 1;
      }

      print(
        '📋 After reorder: ${newOrder.map((s) => '${s.title.length > 10 ? s.title.substring(0, 10) : s.title}...').toList()}',
      );
      print(
        '🎵 Current index updated: ${state.currentIndex} -> $newCurrentIndex',
      );

      state = state.copyWith(
        currentOrder: newOrder,
        currentIndex: newCurrentIndex,
        hasUserReordered: true,
      );

      print('✅ Reorder completed successfully');
      print('   - New queue length: ${state.currentOrder.length}');
      print('   - New current index: ${state.currentIndex}');
    } catch (e) {
      print('❌ Error during reorder operation: $e');
      print('   - Stack trace: ${StackTrace.current}');
      rethrow; // Re-throw to let UI handle the error
    }
  }

  void syncWithAudioPlayer(WidgetRef ref) {
    try {
      final audioNotifier = ref.read(audioProvider.notifier);

      print('🔗 Syncing queue state with audio player');
      print('   - Queue length: ${state.currentOrder.length}');
      print('   - Current index: ${state.currentIndex}');

      if (state.currentOrder.isEmpty) {
        print('⚠️ Cannot sync - queue is empty');
        return;
      }

      if (state.currentIndex < 0 ||
          state.currentIndex >= state.currentOrder.length) {
        print('❌ Cannot sync - invalid current index: ${state.currentIndex}');
        return;
      }

      // Update the audio player's playlist with the reordered queue
      audioNotifier.updatePlaylistOrder(state.currentOrder, state.currentIndex);

      print('✅ Successfully synced queue with audio player');
    } catch (e) {
      print('❌ Error syncing with audio player: $e');
    }
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < state.currentOrder.length) {
      state = state.copyWith(currentIndex: index);
    }
  }

  void clearQueue() {
    print('🧹 Clearing queue state');
    state = const QueueState();
  }
}

class RelatedSongsQueueScreen extends ConsumerStatefulWidget {
  final Song? seedSong;

  const RelatedSongsQueueScreen({super.key, this.seedSong});

  @override
  ConsumerState<RelatedSongsQueueScreen> createState() =>
      _RelatedSongsQueueScreenState();
}

class _RelatedSongsQueueScreenState
    extends ConsumerState<RelatedSongsQueueScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _songAnimationController;

  bool _isManualPlay = false;
  bool _preserveCurrentQueue = false;
  bool _isReordering = false;
  List<Song> _previousRelatedSongs = [];

  // Animation tracking
  final Map<String, AnimationController> _songAnimations = {};
  final Map<String, Animation<double>> _slideAnimations = {};
  final Map<String, Animation<double>> _scaleAnimations = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _songAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _songAnimationController.dispose();

    // Safely dispose all song animations
    final controllers = List<AnimationController>.from(_songAnimations.values);
    for (final controller in controllers) {
      controller.stop();
      controller.dispose();
    }
    _songAnimations.clear();
    _slideAnimations.clear();
    _scaleAnimations.clear();

    super.dispose();
  }

  void _createSongAnimation(String songId) {
    if (_songAnimations.containsKey(songId) || !mounted || songId.isEmpty) {
      return;
    }

    try {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );

      final slideAnimation = Tween<double>(
        begin: 50.0,
        end: 0.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut));

      final scaleAnimation = Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut));

      _songAnimations[songId] = controller;
      _slideAnimations[songId] = slideAnimation;
      _scaleAnimations[songId] = scaleAnimation;

      // Start animation with delay based on index
      final queueState = ref.read(queueStateProvider);
      final index = queueState.currentOrder.indexWhere(
        (song) => song.videoId == songId,
      );
      final delay = index >= 0 ? (index * 100).clamp(0, 2000) : 0;

      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted && _songAnimations.containsKey(songId)) {
          controller.forward().catchError((error) {
            debugPrint('Animation error for $songId: $error');
            _disposeSongAnimation(songId);
          });
        }
      });
    } catch (e) {
      debugPrint('Error creating animation for $songId: $e');
    }
  }

  void _disposeSongAnimation(String songId) {
    final controller = _songAnimations.remove(songId);
    if (controller != null) {
      controller.stop();
      controller.dispose();
    }
    _slideAnimations.remove(songId);
    _scaleAnimations.remove(songId);
  }

  void _toggleShuffle() {
    final queueNotifier = ref.read(queueStateProvider.notifier);
    queueNotifier.toggleShuffle();

    final isShuffled = ref.read(queueStateProvider).isShuffled;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isShuffled ? Icons.shuffle_on : Icons.shuffle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isShuffled ? 'Shuffle enabled' : 'Shuffle disabled',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
            ],
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isShuffled
              ? Colors.purple.shade600
              : Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _toggleLoop() {
    final queueNotifier = ref.read(queueStateProvider.notifier);
    queueNotifier.toggleLoop();

    final isLooping = ref.read(queueStateProvider).isLooping;

    // Update audio provider loop state
    try {
      final audioNotifier = ref.read(audioProvider.notifier);
      audioNotifier.setLooping(isLooping);
    } catch (e) {
      debugPrint('Error setting loop state: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isLooping ? Icons.repeat_on : Icons.repeat,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isLooping ? 'Loop enabled' : 'Loop disabled',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
            ],
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isLooping
              ? Colors.blue.shade600
              : Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Replace your existing _reorderSongs method in the UI with this:

  void _reorderSongs(int oldIndex, int newIndex) {
    print('🔄 UI Reorder requested: $oldIndex -> $newIndex');

    if (_isReordering) {
      print('⚠️ Reordering already in progress, ignoring request');
      return;
    }

    // Get fresh queue state
    final queueState = ref.read(queueStateProvider);
    print(
      '📊 Current queue state: ${queueState.currentOrder.length} songs, current index: ${queueState.currentIndex}',
    );

    // Enhanced validation
    if (queueState.currentOrder.isEmpty) {
      print('❌ Cannot reorder: queue is empty');
      return;
    }

    if (oldIndex < 0 || oldIndex >= queueState.currentOrder.length) {
      print(
        '❌ Invalid oldIndex: $oldIndex (queue length: ${queueState.currentOrder.length})',
      );
      return;
    }

    if (newIndex < 0 || newIndex > queueState.currentOrder.length) {
      print(
        '❌ Invalid newIndex: $newIndex (queue length: ${queueState.currentOrder.length})',
      );
      return;
    }

    // Adjust newIndex for ReorderableListView behavior
    int adjustedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedNewIndex = newIndex - 1;
    }

    if (oldIndex == adjustedNewIndex) {
      print('⚠️ Same index after adjustment, no reorder needed');
      return;
    }

    setState(() {
      _isReordering = true;
    });

    try {
      final queueNotifier = ref.read(queueStateProvider.notifier);

      // Perform the reorder - pass the adjusted index
      queueNotifier.reorderSongs(oldIndex, adjustedNewIndex);

      // Sync with audio player
      queueNotifier.syncWithAudioPlayer(ref);

      print('✅ Reorder and audio sync completed successfully');

      // Show success feedback with haptic feedback
      HapticFeedback.lightImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.swap_vert, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Moved "${queueState.currentOrder[oldIndex].title}" to position ${adjustedNewIndex + 1}',
                  style: GoogleFonts.nunito(fontSize: 14),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error during reorder: $e');
      print('❌ Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to reorder: ${e.toString()}',
                    style: GoogleFonts.nunito(fontSize: 14),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      // Reset flag after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isReordering = false;
          });
        }
      });
    }
  }

  void _playRelatedSong(Song song, int index) async {
    try {
      _isManualPlay = true;
      _preserveCurrentQueue = true;

      final audioNotifier = ref.read(audioProvider.notifier);
      final queueNotifier = ref.read(queueStateProvider.notifier);
      final queueState = ref.read(queueStateProvider);

      // Update current index in queue state
      queueNotifier.setCurrentIndex(index);

      // Create playlist from current index onwards
      final queueFromIndex = queueState.currentOrder.skip(index).toList();
      print('🎵 Playing song at index $index: ${song.title}');
      print(
        '📋 Queue from this point: ${queueFromIndex.map((s) => s.title).take(3).join(", ")}...',
      );

      await audioNotifier.playRelated(song);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Playing: ${song.title} by ${song.artists}',
                    style: GoogleFonts.nunito(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
      }
    } catch (e) {
      _preserveCurrentQueue = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error playing song: ${e.toString()}',
                    style: GoogleFonts.nunito(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(queueStateProvider);

    // Move the YtMusic state listener here
    ref.listen<YtMusicState>(ytMusicProvider, (previous, current) {
      if (!_preserveCurrentQueue && !_isReordering && mounted) {
        final relatedSongs = current.relatedSongs;
        final songsChanged =
            _previousRelatedSongs.length != relatedSongs.length ||
            !_listsEqual(_previousRelatedSongs, relatedSongs);

        if (songsChanged && relatedSongs.isNotEmpty) {
          print('🔄 Related songs updated: ${relatedSongs.length} songs');
          _updateQueueWithNewSongs(relatedSongs);
        }
      }
    });

    // Listen for current song changes
    ref.listen<Song?>(audioProvider.select((s) => s.currentSong), (
      previous,
      current,
    ) {
      if (current != null && !_isManualPlay) {
        final isFromCurrentQueue = queueState.currentOrder.any(
          (song) => song.videoId == current.videoId,
        );

        if (!isFromCurrentQueue) {
          // Fetch related songs for new song
          Future.microtask(() {
            if (mounted) {
              ref
                  .read(ytMusicProvider.notifier)
                  .streamRelatedSongs(
                    songName: current.title,
                    artistName: current.artists,
                  );
            }
          });
        }
      }
      if (_isManualPlay) {
        _isManualPlay = false;
      }
    });

    final ytMusicState = ref.watch(ytMusicProvider);
    final audioState = ref.watch(audioProvider);
    final isLoading = ytMusicState.isLoading || ytMusicState.isStreaming;
    final currentSong = audioState.currentSong;

    // Handle preserve queue flag reset
    if (_preserveCurrentQueue) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _preserveCurrentQueue = false;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Related Songs Queue',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.seedSong != null)
              Text(
                'Based on: ${widget.seedSong!.title}',
                style: GoogleFonts.nunito(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLoading ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${queueState.currentOrder.length}',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Shuffle and Loop buttons
            if (queueState.currentOrder.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Shuffle button
                    Container(
                      decoration: BoxDecoration(
                        color: queueState.isShuffled
                            ? Colors.purple.shade600.withOpacity(0.2)
                            : Colors.grey.shade900.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: queueState.isShuffled
                              ? Colors.purple.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _toggleShuffle,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  queueState.isShuffled
                                      ? Icons.shuffle_on
                                      : Icons.shuffle,
                                  color: queueState.isShuffled
                                      ? Colors.purple.shade300
                                      : Colors.grey.shade400,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Shuffle',
                                  style: GoogleFonts.nunito(
                                    color: queueState.isShuffled
                                        ? Colors.purple.shade300
                                        : Colors.grey.shade400,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Loop button
                    Container(
                      decoration: BoxDecoration(
                        color: queueState.isLooping
                            ? Colors.blue.shade600.withOpacity(0.2)
                            : Colors.grey.shade900.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: queueState.isLooping
                              ? Colors.blue.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _toggleLoop,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  queueState.isLooping
                                      ? Icons.repeat_on
                                      : Icons.repeat,
                                  color: queueState.isLooping
                                      ? Colors.blue.shade300
                                      : Colors.grey.shade400,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Loop All',
                                  style: GoogleFonts.nunito(
                                    color: queueState.isLooping
                                        ? Colors.blue.shade300
                                        : Colors.grey.shade400,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Status indicators
                    if (queueState.isShuffled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade600),
                        ),
                        child: Text(
                          'Shuffled',
                          style: GoogleFonts.nunito(
                            color: Colors.purple.shade300,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (queueState.isShuffled) const SizedBox(width: 4),
                    // Drag hint
                    if (queueState.currentOrder.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.drag_handle,
                              color: Colors.grey.shade500,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Drag to reorder',
                              style: GoogleFonts.nunito(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // Loading indicator section
            if (isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ytMusicState.isStreaming
                            ? 'Streaming related songs...'
                            : 'Searching for related songs...',
                        style: GoogleFonts.nunito(
                          color: Colors.orange.shade300,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Queue header
            if (queueState.currentOrder.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.queue_music,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Up Next',
                      style: GoogleFonts.nunito(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (!isLoading)
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade400,
                        size: 16,
                      ),
                  ],
                ),
              ),

            // Songs list with drag and drop
            Expanded(
              child: queueState.currentOrder.isEmpty && !isLoading
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: queueState.currentOrder.length,
                      onReorder: _reorderSongs,
                      buildDefaultDragHandles:
                          false, // We'll use custom drag handles
                      proxyDecorator: (child, index, animation) {
                        // Custom appearance while dragging
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (BuildContext context, Widget? child) {
                            final double animValue = Curves.easeInOut.transform(
                              animation.value,
                            );
                            final double elevation = lerpDouble(
                              0,
                              6,
                              animValue,
                            )!;
                            final double scale = lerpDouble(
                              1,
                              1.02,
                              animValue,
                            )!;
                            return Transform.scale(
                              scale: scale,
                              child: Material(
                                elevation: elevation,
                                color: Colors.transparent,
                                shadowColor: Colors.purple.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                child: child,
                              ),
                            );
                          },
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final song = queueState.currentOrder[index];
                        final isCurrentlyPlaying =
                            currentSong?.videoId == song.videoId;

                        // Use a stable key based on videoId
                        return _buildDraggableSongTile(
                          song,
                          index,
                          isCurrentlyPlaying,
                          key: ValueKey(
                            '${song.videoId}_$index',
                          ), // More unique key
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateQueueWithNewSongs(List<Song> relatedSongs) {
    // Detect new songs for animation
    final newSongs = relatedSongs
        .where(
          (song) => !_previousRelatedSongs.any(
            (prev) => prev.videoId == song.videoId,
          ),
        )
        .toList();

    // Clean up animations for removed songs
    final removedSongs = _previousRelatedSongs
        .where(
          (song) =>
              !relatedSongs.any((current) => current.videoId == song.videoId),
        )
        .toList();

    for (final removedSong in removedSongs) {
      _disposeSongAnimation(removedSong.videoId!);
    }

    _previousRelatedSongs = List.from(relatedSongs);

    // Update queue state safely
    final queueNotifier = ref.read(queueStateProvider.notifier);
    queueNotifier.updateQueueSafely(relatedSongs, widget.seedSong?.videoId);

    // Create animations for new songs
    for (final newSong in newSongs) {
      _createSongAnimation(newSong.videoId!);
    }
  }

  // Helper method to compare lists
  bool _listsEqual(List<Song> list1, List<Song> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].videoId != list2[i].videoId) return false;
    }
    return true;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade900,
              border: Border.all(color: Colors.grey.shade800, width: 2),
            ),
            child: Icon(
              Icons.queue_music_outlined,
              size: 40,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Related Songs Yet',
            style: GoogleFonts.nunito(
              color: Colors.grey.shade400,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Related songs will appear here as they\'re discovered',
            style: GoogleFonts.nunito(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Updated _buildDraggableSongTile method (replaces your _buildSongTile)
  Widget _buildDraggableSongTile(
    Song song,
    int index,
    bool isCurrentlyPlaying, {
    Key? key,
  }) {
    final slideAnimation = _slideAnimations[song.videoId];
    final scaleAnimation = _scaleAnimations[song.videoId];

    Widget songTile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentlyPlaying
            ? Colors.purple.shade900.withOpacity(0.3)
            : Colors.grey.shade900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentlyPlaying
              ? Colors.purple.shade400.withOpacity(0.5)
              : Colors.grey.shade800,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _playRelatedSong(song, index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Album art with play indicator
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade800,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: song.albumArt != null
                            ? Image.network(
                                song.albumArt!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.music_note,
                                      color: Colors.grey.shade600,
                                    ),
                              )
                            : Icon(
                                Icons.music_note,
                                color: Colors.grey.shade600,
                              ),
                      ),
                    ),
                    if (isCurrentlyPlaying)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withOpacity(0.4),
                          ),
                          child: const Center(
                            child: MiniMusicVisualizer(
                              color: Colors.red,
                              width: 4,
                              height: 15,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: GoogleFonts.nunito(
                          color: isCurrentlyPlaying
                              ? Colors.purple.shade300
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: isCurrentlyPlaying
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artists,
                        style: GoogleFonts.nunito(
                          color: isCurrentlyPlaying
                              ? Colors.purple.shade400
                              : Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song.duration != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          song.duration!,
                          style: GoogleFonts.nunito(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Queue position
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentlyPlaying
                        ? Colors.purple.shade700.withOpacity(0.3)
                        : Colors.grey.shade800.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: GoogleFonts.nunito(
                      color: isCurrentlyPlaying
                          ? Colors.purple.shade300
                          : Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Play button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentlyPlaying
                        ? Colors.purple.shade600
                        : Colors.grey.shade700,
                  ),
                  child: IconButton(
                    onPressed: () => _playRelatedSong(song, index),
                    icon: Icon(
                      isCurrentlyPlaying ? Icons.graphic_eq : Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),

                // Drag handle - this is the key for drag and drop
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.drag_handle,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Apply animations if they exist and are valid
    if (slideAnimation != null && scaleAnimation != null && mounted) {
      return AnimatedBuilder(
        key: key, // Key goes on the root widget returned from builder
        animation: Listenable.merge([slideAnimation, scaleAnimation]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, slideAnimation.value),
            child: Transform.scale(
              scale: scaleAnimation.value,
              child: Opacity(
                opacity: scaleAnimation.value.clamp(0.0, 1.0),
                child: songTile,
              ),
            ),
          );
        },
      );
    }

    // Key goes on the root widget when no animations
    return Container(key: key, child: songTile);
  }
}
