import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradient_mini_music_visualizer/mini_music_visualizer.dart';
import 'package:houston/models/song.dart';
import 'package:houston/providers/audio_state_provider.dart';
import 'package:houston/providers/ytmusic_provider.dart';
import 'package:houston/screens/player_screen.dart';

class RelatedSongsQueueScreen extends ConsumerStatefulWidget {
  final Song? seedSong;

  const RelatedSongsQueueScreen({Key? key, this.seedSong}) : super(key: key);

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

  // Queue state
  bool _isShuffled = false;
  bool _isLoopEnabled = false;
  List<Song> _queueOrder = [];
  List<Song> _previousQueueOrder = [];
  bool _isManualPlay = false;
  bool _preserveCurrentQueue = false; // ✅ Flag to preserve queue

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
    if (_songAnimations.containsKey(songId) || !mounted) return;

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
    final index = _queueOrder.indexWhere((song) => song.videoId == songId);
    final delay = index >= 0 ? index * 100 : 0;

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted && _songAnimations.containsKey(songId)) {
        controller.forward().catchError((error) {
          // Handle animation errors silently
          debugPrint('Animation error for $songId: $error');
        });
      }
    });
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
    setState(() {
      _isShuffled = !_isShuffled;
      if (_isShuffled) {
        _queueOrder = List.from(_queueOrder)..shuffle();
      } else {
        // Reset to original order (you might want to store original order)
        final ytMusicState = ref.read(ytMusicProvider);
        _queueOrder = List.from(ytMusicState.relatedSongs);
      }
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isShuffled ? Icons.shuffle : Icons.shuffle_on,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isShuffled ? 'Shuffle enabled' : 'Shuffle disabled',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _isShuffled
            ? Colors.purple.shade600
            : Colors.grey.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleLoop() {
    setState(() {
      _isLoopEnabled = !_isLoopEnabled;
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isLoopEnabled ? Icons.repeat : Icons.repeat_on,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isLoopEnabled ? 'Loop enabled' : 'Loop disabled',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _isLoopEnabled
            ? Colors.blue.shade600
            : Colors.grey.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _reorderQueue(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final Song item = _queueOrder.removeAt(oldIndex);
      _queueOrder.insert(newIndex, item);
    });
  }

  void _playRelatedSong(Song song, int index) async {
    try {
      _isManualPlay = true; // ✅ Prevent auto-fetch
      _preserveCurrentQueue = true; // ✅ Preserve current queue

      final audioNotifier = ref.read(audioProvider.notifier);
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
      _preserveCurrentQueue = false; // ✅ Reset on error
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
    ref.listen<Song?>(audioProvider.select((s) => s.currentSong), (
      previous,
      current,
    ) {
      if (current != null) {
        if (_isManualPlay) {
          _isManualPlay = false; // ✅ Reset flag
          return; // 🔒 Skip auto-fetch if manual
        }

        // ✅ Check if the current song is from this screen's queue
        final isFromCurrentQueue = _queueOrder.any(
          (song) => song.videoId == current.videoId,
        );

        if (isFromCurrentQueue) {
          // 🔒 Don't refresh related songs if playing from current queue
          return;
        }

        // ✅ Only stream if it was an external change (e.g., autoplay from different source)
        ref
            .read(ytMusicProvider.notifier)
            .streamRelatedSongs(
              songName: current.title,
              artistName: current.artists,
            );
      }
    });

    final ytMusicState = ref.watch(ytMusicProvider);
    final audioState = ref.watch(audioProvider);
    final relatedSongs = ytMusicState.relatedSongs;
    final isLoading = ytMusicState.isLoading || ytMusicState.isStreaming;
    final currentSong = audioState.currentSong;

    // Update queue order when related songs change and handle animations
    if (_queueOrder.length != relatedSongs.length && !_preserveCurrentQueue) {
      // Detect new songs for animation
      final newSongs = relatedSongs
          .where(
            (song) => !_previousQueueOrder.any(
              (prev) => prev.videoId == song.videoId,
            ),
          )
          .toList();

      // Clean up animations for removed songs
      final removedSongs = _previousQueueOrder
          .where(
            (song) =>
                !relatedSongs.any((current) => current.videoId == song.videoId),
          )
          .toList();

      for (final removedSong in removedSongs) {
        if (removedSong.videoId != null) {
          _disposeSongAnimation(removedSong.videoId!);
        }
      }

      _previousQueueOrder = List.from(relatedSongs);
      _queueOrder = List.from(relatedSongs);

      if (_isShuffled) {
        _queueOrder.shuffle();
      }

      // Create animations for new songs
      for (final newSong in newSongs) {
        if (newSong.videoId != null) {
          _createSongAnimation(newSong.videoId!);
        }
      }
    } else if (_preserveCurrentQueue) {
      // Reset the flag after one build cycle
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
                  '${relatedSongs.length}',
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
            if (relatedSongs.isNotEmpty)
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
                        color: _isShuffled
                            ? Colors.purple.shade600.withOpacity(0.2)
                            : Colors.grey.shade900.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isShuffled
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
                                  Icons.shuffle,
                                  color: _isShuffled
                                      ? Colors.purple.shade300
                                      : Colors.grey.shade400,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Shuffle',
                                  style: GoogleFonts.nunito(
                                    color: _isShuffled
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
                        color: _isLoopEnabled
                            ? Colors.blue.shade600.withOpacity(0.2)
                            : Colors.grey.shade900.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isLoopEnabled
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
                                  Icons.repeat,
                                  color: _isLoopEnabled
                                      ? Colors.blue.shade300
                                      : Colors.grey.shade400,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Loop All',
                                  style: GoogleFonts.nunito(
                                    color: _isLoopEnabled
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
                    // Drag hint
                    if (relatedSongs.length > 1)
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
            if (relatedSongs.isNotEmpty)
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
              child: relatedSongs.isEmpty && !isLoading
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _queueOrder.length,
                      onReorder: _reorderQueue,
                      itemBuilder: (context, index) {
                        final song = _queueOrder[index];
                        final isCurrentlyPlaying =
                            currentSong?.videoId == song.videoId;

                        return _buildSongTile(song, index, isCurrentlyPlaying);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildSongTile(Song song, int index, bool isCurrentlyPlaying) {
    final songId = song.videoId ?? 'song_$index';
    final slideAnimation = _slideAnimations[songId];
    final scaleAnimation = _scaleAnimations[songId];

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
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
                            Icon(Icons.music_note, color: Colors.grey.shade600),
                      )
                    : Icon(Icons.music_note, color: Colors.grey.shade600),
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
        title: Text(
          song.title,
          style: GoogleFonts.nunito(
            color: isCurrentlyPlaying ? Colors.purple.shade300 : Colors.white,
            fontSize: 15,
            fontWeight: isCurrentlyPlaying ? FontWeight.w600 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (song.duration != null)
              Text(
                song.duration!,
                style: GoogleFonts.nunito(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#${index + 1}',
              style: GoogleFonts.nunito(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentlyPlaying
                    ? Colors.purple.shade600
                    : Colors.grey.shade800,
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
            const SizedBox(width: 8),
            // Drag handle
            Icon(Icons.drag_handle, color: Colors.grey.shade600, size: 20),
          ],
        ),
        onTap: () => _playRelatedSong(song, index),
      ),
    );

    // Apply animations if they exist and are valid
    if (slideAnimation != null && scaleAnimation != null && mounted) {
      return AnimatedBuilder(
        key: Key(songId),
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

    return Container(key: Key(songId), child: songTile);
  }
}
