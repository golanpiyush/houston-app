import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/widgets/gradient_icons.dart';
import 'package:icons_plus/icons_plus.dart';
import '../providers/audio_provider.dart';
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

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1.1),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Check saved status when screen initializes
    _checkSavedStatus();
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

  void _handleVerticalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 300 && !_isDismissing) {
      _isDismissing = true;
      _slideController.forward().then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final song = audioState.currentSong;

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
      ),
      body: song == null
          ? const Center(
              child: Text(
                "No song playing",
                style: TextStyle(color: Colors.white),
              ),
            )
          : GestureDetector(
              onVerticalDragEnd: _handleVerticalSwipe,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.all(
                          20,
                        ), // Give space for shadow
                        child: AnimatedAlbumArt(
                          imageUrl: song.albumArt ?? '',
                          isPlaying: audioState.isPlaying,
                          shadowColor: shadowColor,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Song title + artist
                      Center(
                        child: Column(
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
                            const SizedBox(height: 4),
                            Text(
                              song.artists,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Slider
                      Column(
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

                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GradientIcon(
                            icon: Bootstrap.repeat,
                            size: 26,
                            onPressed: () {},
                          ),
                          const SizedBox(width: 20),
                          GradientIcon(
                            icon: audioState.isPlaying
                                ? Bootstrap.pause
                                : Bootstrap.play,
                            size: 58,
                            onPressed: () {
                              ref.read(audioProvider.notifier).pauseResume();
                            },
                          ),
                          const SizedBox(width: 20),
                          GradientIcon(
                            icon: _isSaved
                                ? Bootstrap
                                      .heart_fill // filled heart when saved
                                : Bootstrap.heart,
                            size: 26,
                            onPressed: () async {
                              await ref
                                  .read(audioProvider.notifier)
                                  .toggleSaved();
                              // Update local state after toggling
                              _checkSavedStatus();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Center(
                        child: GradientIcon(
                          icon: EvaIcons.plus_square,
                          size: 32,
                          onPressed: () {
                            // Add to playlist
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

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
