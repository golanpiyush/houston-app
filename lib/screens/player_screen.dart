import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/providers/audio/audioEffectsProvider.dart';
import 'package:houston/providers/managers/download_manager.dart';
import 'package:houston/screens/artist_info_page.dart';
import 'package:houston/screens/related_songs_queue.dart';
import 'package:houston/services/storage_service.dart';
import 'package:houston/utils/add_to_playlist_bottom_sheet.dart';
import 'package:houston/utils/album_art_utils.dart';
import 'package:houston/widgets/gradient_icons.dart';
import 'package:icons_plus/icons_plus.dart';
import '../providers/audio/audio_state_provider.dart';
import '../widgets/animated_album_art.dart';
import '../utils/vibrant_color_extractor.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  Color shadowColor = Colors.black;
  String? lastAlbumArt;
  bool _isSaved = false;
  final albumArtService = AlbumArtService(StorageService());

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isDismissing = false;
  bool isLooping = false;
  bool _isDownloading = false;
  String _lastCheckedSongId = '';

  // ADDED: Gesture handling variables
  bool _isProcessingGesture = false;
  static const double _velocityThreshold = 300.0;
  String? _lastSongVideoId; // Track song changes

  @override
  void initState() {
    super.initState();

    // Defer provider mutations until after the first frame to avoid Riverpod's
    // "modifying a provider while the widget tree is building" error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Read the current audio session ID from the audioProvider.
      final audioSessionId = ref.read(audioProvider).audioSessionId;
      print('Initializing effects with sessionId: $audioSessionId');

      // Initialize audio effects now that the widget tree has finished building.
      ref.read(audioEffectsProvider.notifier).initializeEffects(audioSessionId);

      // Check saved status (if it modifies providers/state, it must be here too).
      _checkSavedStatus();
    });

    // Animation setup can run immediately; it doesn't mutate providers.
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1.1),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check saved status when song changes
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    final isSaved = await ref.read(audioProvider.notifier).isCurrentSongSaved();
    if (mounted) {
      setState(() {
        _isSaved = isSaved;
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  // UPDATED: Handle both vertical and horizontal swipes
  void _handlePanEnd(DragEndDetails details) {
    if (_isProcessingGesture || _isDismissing) return;

    final horizontalVelocity = details.velocity.pixelsPerSecond.dx;
    final verticalVelocity = details.velocity.pixelsPerSecond.dy;

    debugPrint(
      'Pan end - horizontal: $horizontalVelocity, vertical: $verticalVelocity',
    );

    // Check if gesture meets minimum velocity threshold
    final horizontalMagnitude = horizontalVelocity.abs();
    final verticalMagnitude = verticalVelocity.abs();

    if (horizontalMagnitude < _velocityThreshold &&
        verticalMagnitude < _velocityThreshold) {
      debugPrint(
        'Gesture too weak - H: $horizontalMagnitude, V: $verticalMagnitude',
      );
      return;
    }

    // Determine dominant direction
    if (horizontalMagnitude > verticalMagnitude &&
        horizontalMagnitude > _velocityThreshold) {
      debugPrint('Handling as horizontal gesture');
      _handleHorizontalSwipe(details);
    } else if (verticalMagnitude > horizontalMagnitude &&
        verticalMagnitude > _velocityThreshold) {
      debugPrint('Handling as vertical gesture');
      _handleVerticalSwipe(details);
    }
  }

  // ADDED: Handle horizontal swipes for song navigation
  void _handleHorizontalSwipe(DragEndDetails details) async {
    if (_isProcessingGesture || _isDismissing) return;

    final velocity = details.velocity.pixelsPerSecond.dx;
    final isSwipeLeft = velocity < -_velocityThreshold;
    final isSwipeRight = velocity > _velocityThreshold;

    if (!isSwipeLeft && !isSwipeRight) return;

    _isProcessingGesture = true;

    try {
      if (isSwipeLeft) {
        debugPrint('🎵 Next song gesture detected');
        await _playNext();
      } else if (isSwipeRight) {
        debugPrint('🎵 Previous song gesture detected');
        await _playPrevious();
      }
    } finally {
      _isProcessingGesture = false;
    }
  }

  // UPDATED: Handle vertical swipes for dismissal
  void _handleVerticalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > _velocityThreshold && !_isDismissing) {
      _isDismissing = true;
      _slideController.forward().then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  // ADDED: Play next song with proper state handling
  Future<void> _playNext() async {
    try {
      debugPrint('🎵 PlayerScreen: Calling playNext()');

      final currentSong = ref.read(audioProvider).currentSong;
      debugPrint('🎵 Current song before next: ${currentSong?.title}');

      await ref.read(audioProvider.notifier).playNext();

      // Wait for state to update
      await Future.delayed(Duration(milliseconds: 200));

      final newSong = ref.read(audioProvider).currentSong;
      debugPrint('🎵 New song after next: ${newSong?.title}');

      // Force UI update
      if (mounted) {
        setState(() {
          _lastSongVideoId = newSong?.videoId;
        });

        // Trigger saved status check for new song
        _checkSavedStatus();
      }
    } catch (e) {
      debugPrint('❌ Error in PlayerScreen playNext: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Unable to play next song",
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  // ADDED: Play previous song with proper state handling
  Future<void> _playPrevious() async {
    try {
      debugPrint('🎵 PlayerScreen: Calling playPrevious()');

      final currentSong = ref.read(audioProvider).currentSong;
      debugPrint('🎵 Current song before previous: ${currentSong?.title}');

      await ref.read(audioProvider.notifier).playPrevious();

      // Wait for state to update
      await Future.delayed(Duration(milliseconds: 200));

      final newSong = ref.read(audioProvider).currentSong;
      debugPrint('🎵 New song after previous: ${newSong?.title}');

      // Force UI update
      if (mounted) {
        setState(() {
          _lastSongVideoId = newSong?.videoId;
        });

        // Trigger saved status check for new song
        _checkSavedStatus();
      }
    } catch (e) {
      debugPrint('❌ Error in PlayerScreen playPrevious: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Unable to play previous song",
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  // ADDED: Handle tap to play/pause
  void _handleTap() {
    if (_isProcessingGesture || _isDismissing) return;

    debugPrint('🎵 PlayerScreen: Toggle play/pause');
    ref.read(audioProvider.notifier).pauseResume();
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Add mounted check at the very start
    if (!mounted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("Loading...", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final audioState = ref.watch(audioProvider);
    final downloadStates = ref.watch(downloadStateProvider);

    final song = audioState.currentSong;

    // FIXED: Better song change detection with mounted checks
    if (song?.videoId != _lastSongVideoId && song != null && mounted) {
      _lastSongVideoId = song.videoId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check mounted again in callback
          _checkSavedStatus();
          if (song.albumArt != lastAlbumArt) {
            _updateColor(song.albumArt);
          }
        }
      });
    }

    // Get current song's download state
    final songKey = song != null ? '${song.title}|${song.artists}' : '';
    final downloadState = downloadStates[songKey];

    final isDownloading = downloadState?.isDownloading ?? false;

    // Check if current song is actually saved (not just cached)
    final isSaved = song != null ? audioState.isSaved : false;

    // Check if song changed and update saved status
    final currentSongId = song != null ? '${song.title}|${song.artists}' : '';
    if (currentSongId != _lastCheckedSongId && mounted) {
      _lastCheckedSongId = currentSongId;
      if (song != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Check mounted in callback
            try {
              ref.read(audioProvider.notifier).isCurrentSongSaved();
            } catch (e) {
              print('⚠️ Error checking saved status: $e');
            }
          }
        });
      }
    }

    // ⛳ Detect album art change and update shadow
    final currentArt = song?.albumArt;
    if (currentArt != null && currentArt != lastAlbumArt) {
      lastAlbumArt = currentArt;
      _updateColor(currentArt);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Now Playing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.fireplace, color: Colors.orange, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RelatedSongsQueueScreen(),
                ),
              );
            },
            tooltip: 'Audio Effects',
          ),
        ],
      ),
      body: song == null
          ? const Center(
              child: Text(
                "No song playing",
                style: TextStyle(color: Colors.white),
              ),
            )
          : GestureDetector(
              // UPDATED: Handle both vertical and horizontal gestures
              onPanEnd: _handlePanEnd,
              onTap: _handleTap, // ADDED: Tap to play/pause
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // In your build method:
                      Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.all(20),
                        child: AnimatedAlbumArt(
                          key: ValueKey(song.videoId),
                          imageUrl: song.albumArt ?? '',
                          isPlaying: audioState.isPlaying,
                          shadowColor: shadowColor,
                          getAlbumArtFallback: () async {
                            final songData = {
                              'title': song.title,
                              'artist': song.artists,
                              'albumart': song.albumArt,
                              'videoid': song.videoId,
                              'id': song.videoId,
                              'duration': song.duration,
                            };
                            return albumArtService.getAlbumArtPath(songData);
                          },
                          onPreviousSong: () async => await _playPrevious(),
                          onNextSong: () async => await _playNext(),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Song title + artist
                      Center(
                        child: Column(
                          key: ValueKey(
                            '${song.videoId}_info',
                          ), // ADDED: Force rebuild on song change
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song.title,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                final artists = _parseArtists(song.artists);
                                if (artists.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ArtistInfoPage(
                                        artistName: artists.first,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                song.artists,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Slider
                      Column(
                        key: ValueKey(
                          '${song.videoId}_controls',
                        ), // ADDED: Force rebuild on song change
                        children: [
                          Slider(
                            value: audioState.currentPosition.inMilliseconds
                                .clamp(
                                  0,
                                  audioState.totalDuration.inMilliseconds,
                                )
                                .toDouble(),
                            max: audioState.totalDuration.inMilliseconds > 0
                                ? audioState.totalDuration.inMilliseconds
                                      .toDouble()
                                : 1.0,
                            onChanged: (value) {
                              ref
                                  .read(audioProvider.notifier)
                                  .seekTo(
                                    Duration(milliseconds: value.toInt()),
                                  );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(audioState.currentPosition),
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _formatDuration(audioState.totalDuration),
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Controls - UPDATED with navigation buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ADDED: Previous button
                          GradientIconButton(
                            icon: Bootstrap.skip_backward,
                            size: 26,
                            onPressed: _playPrevious,
                          ),

                          const SizedBox(width: 20),

                          GradientIconButton(
                            icon: isLooping
                                ? Bootstrap.repeat_1
                                : Bootstrap.repeat,
                            size: 26,
                            onPressed: () {
                              final notifier = ref.read(audioProvider.notifier);
                              final wasLooping = ref
                                  .read(audioProvider)
                                  .isLooping;

                              notifier.toggleLooping();

                              final nowLooping = !wasLooping;
                              Fluttertoast.showToast(
                                msg: nowLooping
                                    ? "Looping Enabled"
                                    : "Looping Disabled",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                              );
                            },
                          ),

                          const SizedBox(width: 20),
                          GradientIconButton(
                            icon: audioState.isPlaying
                                ? Bootstrap.pause
                                : Bootstrap.play,
                            size: 58,
                            onPressed: () {
                              ref.read(audioProvider.notifier).pauseResume();
                            },
                          ),
                          const SizedBox(width: 20),
                          GradientIconButton(
                            icon: isDownloading
                                ? Icons.downloading
                                : isSaved
                                ? Bootstrap
                                      .heart_fill // Filled heart when saved
                                : Bootstrap.heart, // Empty heart when not saved
                            size: 26,
                            onPressed: isDownloading
                                ? null
                                : () async {
                                    await ref
                                        .read(audioProvider.notifier)
                                        .toggleSaved();
                                    // Refresh saved status after toggle
                                    _checkSavedStatus();
                                  },
                          ),

                          const SizedBox(width: 20),

                          // ADDED: Next button
                          GradientIconButton(
                            icon: Bootstrap.skip_forward,
                            size: 26,
                            onPressed: _playNext,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Center(
                        child: GradientIconButton(
                          icon: EvaIcons.plus_square,
                          size: 32,
                          onPressed: () {
                            // Add to playlist
                            PlaylistBottomSheetHelper.showAddToPlaylistBottomSheet(
                              context,
                              song,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _updateColor(String? imageUrl) async {
    print('Updating color for: $imageUrl');
    if (imageUrl == null) {
      if (mounted) {
        setState(() {
          shadowColor = Colors.black;
        });
      }
      print('New shadow color: $shadowColor');
      return;
    }

    try {
      // Remove the incorrect casting - pass the imageUrl directly
      final color = await VibrantColorExtractor.extract(imageUrl);

      if (mounted) {
        setState(() {
          shadowColor = color;
        });
      }
      print('New shadow color: $shadowColor');
    } catch (e) {
      print('Error extracting color: $e');
      if (mounted) {
        setState(() {
          shadowColor = Colors.black;
        });
      }
    }
  }

  Future<void> _handleDownloadToggle() async {
    setState(() {
      _isDownloading = true;
    });

    await ref.read(audioProvider.notifier).toggleSaved();

    setState(() {
      _isDownloading = false;
    });

    _checkSavedStatus(); // recheck saved status

    Fluttertoast.showToast(
      msg: _isSaved ? "Removed from Downloads" : "Saved to Downloads",
      gravity: ToastGravity.BOTTOM,
    );
  }

  List<String> _parseArtists(String artistsString) {
    // Handle common separators and variations
    return artistsString
        .split(
          RegExp(
            r'\s*,\s*|\s*&\s*|\s+and\s+|\s+feat\.?\s+',
            caseSensitive: false,
          ),
        )
        .where((artist) => artist.trim().isNotEmpty)
        .map((artist) => artist.trim())
        .toList();
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
