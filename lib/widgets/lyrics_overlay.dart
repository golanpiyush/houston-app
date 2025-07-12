import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/models/lyrics_model.dart';
import 'package:houston/providers/audio_provider.dart';

class LyricsOverlay extends ConsumerStatefulWidget {
  const LyricsOverlay({super.key});

  @override
  ConsumerState<LyricsOverlay> createState() => _LyricsOverlayState();
}

class _LyricsOverlayState extends ConsumerState<LyricsOverlay>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _glowController;
  late AnimationController _scaleController;

  int _currentIndex = 0;
  int _currentWordIndex = 0;
  StreamSubscription<Duration>? _positionSub;
  Duration _currentPosition = Duration.zero;

  // Constants for layout
  static const double itemHeight = 70.0;
  static const double albumArtSize = 335.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize position subscription after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSub = ref
          .read(audioProvider.notifier)
          .positionStream
          .listen(_onPositionChanged);
    });
  }

  void _calculateLayout() {
    // No longer needed - using fixed album art size
  }

  void _onPositionChanged(Duration position) {
    final audioState = ref.read(audioProvider);
    final lyrics = audioState.currentLyrics;

    if (lyrics.isEmpty) return;

    _currentPosition = position;
    final millis = position.inMilliseconds;
    final index = _getCurrentIndex(millis, lyrics);
    final wordIndex = _getCurrentWordIndex(millis, index, lyrics);

    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      _scrollToIndex(index);
      _scaleController.reset();
      _scaleController.forward();
    }

    if (wordIndex != _currentWordIndex) {
      setState(() => _currentWordIndex = wordIndex);
    }
  }

  int _getCurrentIndex(int position, List<LyricsLine> lyrics) {
    if (lyrics.isEmpty) return 0;

    for (int i = 0; i < lyrics.length; i++) {
      if (position < lyrics[i].timestamp) {
        return i == 0 ? 0 : i - 1;
      }
    }
    return lyrics.length - 1;
  }

  int _getCurrentWordIndex(
    int position,
    int lineIndex,
    List<LyricsLine> lyrics,
  ) {
    if (lyrics.isEmpty || lineIndex < 0 || lineIndex >= lyrics.length) {
      return 0;
    }

    final line = lyrics[lineIndex];
    final words = line.text.split(' ');

    if (words.isEmpty) return 0;

    // Only calculate word timing if we're at or past the current line's timestamp
    if (position < line.timestamp) {
      return 0;
    }

    // Calculate word timing based on line duration
    final nextLineTimestamp = lineIndex + 1 < lyrics.length
        ? lyrics[lineIndex + 1].timestamp
        : line.timestamp + 4000; // Default 4 seconds if last line

    final lineDuration = nextLineTimestamp - line.timestamp;
    if (lineDuration <= 0) return 0;

    final wordDuration = lineDuration / words.length;
    final timeInLine = position - line.timestamp;
    final wordIndex = (timeInLine / wordDuration).floor();

    return wordIndex.clamp(0, words.length - 1);
  }

  void _scrollToIndex(int index) {
    final audioState = ref.read(audioProvider);
    final lyrics = audioState.currentLyrics;

    if (lyrics.isEmpty || !_scrollController.hasClients) return;

    // Calculate center offset based on album art size
    final centerOffset = (albumArtSize / 2) - (itemHeight / 2);
    final targetOffset = (index * itemHeight) - centerOffset;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  void _onLineTap(int index) {
    final audioState = ref.read(audioProvider);
    final lyrics = audioState.currentLyrics;

    if (index < lyrics.length) {
      final timestamp = lyrics[index].timestamp;
      ref
          .read(audioProvider.notifier)
          .seekTo(Duration(milliseconds: timestamp));
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _scrollController.dispose();
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Widget _buildWordByWordText(
    String text,
    int currentWordIndex,
    bool isActive,
  ) {
    if (text.isEmpty) return const SizedBox.shrink();

    final words = text.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          width: albumArtSize - 40, // Account for padding within album art
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: words.asMap().entries.map((entry) {
              final wordIndex = entry.key;
              final word = entry.value;
              final isCurrentWord = isActive && wordIndex <= currentWordIndex;
              final isActiveWord = isActive && wordIndex == currentWordIndex;

              // Enhanced opacity logic
              Color textColor;
              if (isActive) {
                if (isCurrentWord) {
                  textColor = Colors.white;
                } else {
                  textColor = Colors.white.withOpacity(
                    0.4,
                  ); // Lower opacity for inactive words in active line
                }
              } else {
                textColor = Colors.white.withOpacity(
                  0.25,
                ); // Much lower opacity for inactive lines
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.poppins(
                    fontSize: isActive ? 20 : 16,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: textColor,
                    shadows: isActiveWord
                        ? [
                            Shadow(
                              blurRadius: 15 + (_glowController.value * 10),
                              color: Colors.cyan.withOpacity(0.8),
                              offset: const Offset(0, 0),
                            ),
                            Shadow(
                              blurRadius: 8 + (_glowController.value * 5),
                              color: Colors.white.withOpacity(0.6),
                              offset: const Offset(0, 0),
                            ),
                          ]
                        : isCurrentWord
                        ? [
                            const Shadow(
                              blurRadius: 8,
                              color: Colors.white,
                              offset: Offset(0, 0),
                            ),
                          ]
                        : [],
                  ),
                  child: Text('$word '),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final lyrics = audioState.currentLyrics;

    // Since this overlay is positioned within the 335x335 album art container,
    // we'll set fixed dimensions to match the album art exactly
    const double albumArtSize = 335.0;

    // Calculate center offset based on the album art size
    final centerOffset = (albumArtSize / 2) - (itemHeight / 2);

    if (lyrics.isEmpty) {
      return Container(
        width: albumArtSize,
        height: albumArtSize,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Text(
            'No lyrics available',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      width: albumArtSize,
      height: albumArtSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.4),
            Colors.black.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Stack(
        children: [
          // Gradient overlays for fade effect
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          // Center highlight line - positioned at the exact center of the album art
          Positioned(
            top: centerOffset + (itemHeight / 2) - 1,
            left: 20,
            right: 20,
            height: 2,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.cyan.withOpacity(
                          0.3 + (_glowController.value * 0.4),
                        ),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              },
            ),
          ),
          // Lyrics list with precise centering for album art
          ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: centerOffset),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final line = lyrics[index];
              final isActive = index == _currentIndex;

              return AnimatedBuilder(
                animation: _scaleController,
                builder: (context, child) {
                  final scale = isActive
                      ? 1.0 + (_scaleController.value * 0.05)
                      : 1.0;

                  return Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: () => _onLineTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: itemHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isActive
                              ? Border.all(
                                  color: Colors.cyan.withOpacity(0.3),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Center(
                          child: _buildWordByWordText(
                            line.text,
                            _currentWordIndex,
                            isActive,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
