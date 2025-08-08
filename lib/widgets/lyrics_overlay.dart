// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/models/lyrics_model.dart';
import 'package:houston/providers/audio/audio_state_provider.dart';
import 'package:houston/providers/lyrics_provider.dart' as lyrics_provider;
import 'package:houston/providers/lyrics_provider.dart';

import 'package:houston/providers/settings_provider.dart';

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
  late AnimationController _appearController;
  late AnimationController _wordGlowController;

  int _currentIndex = 0;
  int _currentWordIndex = 0;
  StreamSubscription<Duration>? _positionSub;
  Duration _currentPosition = Duration.zero;

  // Enhanced constants for better layout
  static const double itemHeight = 120.0;
  static const double overlaySize = 335.0;
  static const double horizontalPadding = 20.0;
  static const double verticalItemPadding = 12.0;
  static const double borderRadius = 24.0;
  static const double gradientHeight = 90.0;

  // Animation constants
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Duration _glowDuration = Duration(milliseconds: 2000);
  static const Duration _wordGlowDuration = Duration(milliseconds: 1500);
  static const Duration _scaleDuration = Duration(milliseconds: 400);
  static const Duration _scrollDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _startPositionListener();
    _fetchLyricsIfNeeded();
  }

  void _initializeControllers() {
    _scrollController = ScrollController();

    _glowController = AnimationController(duration: _glowDuration, vsync: this)
      ..repeat(reverse: true);

    _wordGlowController = AnimationController(
      duration: _wordGlowDuration,
      vsync: this,
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      duration: _scaleDuration,
      vsync: this,
    );

    _appearController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _appearController.forward();
  }

  void _startPositionListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSub = ref
          .read(audioProvider.notifier)
          .positionStream
          .listen(_onPositionChanged);
    });
  }

  Future<void> _fetchLyricsIfNeeded() async {
    final audioState = ref.read(audioProvider);
    final settings = ref.read(settingsProvider);

    print('LYRICS_PROVIDER: _fetchLyricsIfNeeded called');
    print(
      'LYRICS_PROVIDER: currentLyrics.isEmpty: ${audioState.currentLyrics.isEmpty}',
    );
    print(
      'LYRICS_PROVIDER: currentSong != null: ${audioState.currentSong != null}',
    );

    // Only fetch if we don't have lyrics and we have a current track
    if (audioState.currentLyrics.isEmpty && audioState.currentSong != null) {
      print('LYRICS_PROVIDER: Proceeding with lyrics fetch...');

      // Create a new instance of LyricsProvider
      final lyricsProvider = lyrics_provider.LyricsProvider();

      print('LYRICS_PROVIDER: Settings value is: ${settings.lyricsProvider}');
      print(
        'LYRICS_PROVIDER: Before assignment, selectedSource is: ${lyricsProvider.selectedSource}',
      );

      // Force the assignment explicitly - this is working correctly
      if (settings.lyricsProvider == LyricsSource.someRandomApi) {
        lyricsProvider.selectedSource = LyricsSource.someRandomApi;
      } else {
        lyricsProvider.selectedSource = LyricsSource.kugou;
      }

      print(
        'LYRICS_PROVIDER: After explicit assignment, selectedSource is: ${lyricsProvider.selectedSource}',
      );

      int? durationInSeconds;

      // Handle different duration types
      if (audioState.currentSong!.duration is Duration) {
        durationInSeconds =
            (audioState.currentSong!.duration as Duration).inSeconds;
      } else if (audioState.currentSong!.duration is int) {
        durationInSeconds = audioState.currentSong!.duration as int?;
      } else if (audioState.currentSong!.duration is String) {
        try {
          durationInSeconds = int.tryParse(
            audioState.currentSong!.duration as String,
          );
        } catch (e) {
          durationInSeconds = null;
        }
      }

      final result = await lyricsProvider.fetchLyrics(
        audioState.currentSong!.title,
        audioState.currentSong!.artists,
        duration: durationInSeconds ?? -1,
      );

      // Don't forget to dispose the provider
      lyricsProvider.dispose();

      if (result['success'] == true) {
        ref
            .read(audioProvider.notifier)
            .updateLyrics(
              result['lines']
                  .map<PlainLyricsLine>((e) => PlainLyricsLine.fromJson(e))
                  .toList(),
            );
      }
    }
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
      _triggerScaleAnimation();
    }

    if (wordIndex != _currentWordIndex) {
      setState(() => _currentWordIndex = wordIndex);
    }
  }

  void _triggerScaleAnimation() {
    _scaleController.reset();
    _scaleController.forward();
  }

  int _getCurrentIndex(int position, List<LyricsLine> lyrics) {
    if (lyrics.isEmpty) return 0;

    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (position >= lyrics[i].timestamp) {
        return i;
      }
    }
    return 0;
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
    final words = _splitTextIntoWords(line.text);

    if (words.isEmpty) return 0;

    if (position < line.timestamp) return 0;

    final nextLineTimestamp = lineIndex + 1 < lyrics.length
        ? lyrics[lineIndex + 1].timestamp
        : line.timestamp + 4000;

    final lineDuration = nextLineTimestamp - line.timestamp;
    if (lineDuration <= 0) return words.length - 1;

    final timeInLine = position - line.timestamp;
    final progress = (timeInLine / lineDuration).clamp(0.0, 1.0);

    // Smooth word progression with easing
    final easedProgress = _easeInOutCubic(progress);
    final wordIndex = (easedProgress * words.length).floor();

    return wordIndex.clamp(0, words.length - 1);
  }

  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  List<String> _splitTextIntoWords(String text) {
    return text.trim().split(RegExp(r'\s+'));
  }

  void _scrollToIndex(int index) {
    final audioState = ref.read(audioProvider);
    final lyrics = audioState.currentLyrics;

    if (lyrics.isEmpty || !_scrollController.hasClients) return;

    final centerOfOverlay = overlaySize / 40;
    final itemCenter = (index * itemHeight) + (itemHeight / 8);
    final targetOffset = itemCenter - centerOfOverlay;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final minScrollExtent = _scrollController.position.minScrollExtent;
    final clampedOffset = targetOffset.clamp(minScrollExtent, maxScrollExtent);

    _scrollController.animateTo(
      clampedOffset,
      duration: _scrollDuration,
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
    _appearController.dispose();
    _wordGlowController.dispose();
    super.dispose();
  }

  // 3. Update LyricsOverlay _getBaseTextStyle method
  TextStyle _getBaseTextStyle() {
    final settings = ref.watch(settingsProvider);

    // Map font names to Google Fonts
    getFontStyle() {
      switch (settings.lyricsFont) {
        case 'Poppins':
          return GoogleFonts.poppins();
        case 'Roboto':
          return GoogleFonts.roboto();
        case 'Open Sans':
          return GoogleFonts.openSans();
        case 'Montserrat':
          return GoogleFonts.montserrat();
        case 'Lato':
          return GoogleFonts.lato();
        case 'Nunito':
          return GoogleFonts.nunito();
        case 'Inter':
          return GoogleFonts.inter();
        case 'Raleway':
          return GoogleFonts.raleway();
        case 'Playfair Display':
          return GoogleFonts.playfairDisplay();
        case 'Luckiest Guy':
          return GoogleFonts.luckiestGuy();
        case 'Oswald':
          return GoogleFonts.oswald();
        case 'Merriweather':
          return GoogleFonts.merriweather();
        case 'Ubuntu':
          return GoogleFonts.ubuntu();
        case 'Fira Sans':
          return GoogleFonts.firaSans();
        case 'Crimson Text':
          return GoogleFonts.crimsonText();
        case 'Libre Baskerville':
          return GoogleFonts.libreBaskerville();
        case 'PT Sans':
          return GoogleFonts.ptSans();
        case 'Quicksand':
          return GoogleFonts.quicksand();
        case 'Caveat':
          return GoogleFonts.caveat();
        case 'Dancing Script':
          return GoogleFonts.dancingScript();
        case 'Comfortaa':
          return GoogleFonts.comfortaa();
        case 'Pacifico':
          return GoogleFonts.pacifico();
        case 'Satisfy':
          return GoogleFonts.satisfy();
        case 'Great Vibes':
          return GoogleFonts.greatVibes();
        default:
          return GoogleFonts.poppins();
      }
    }

    return getFontStyle().copyWith(height: 1.4, letterSpacing: 0.5);
  }

  Widget _buildWordByWordText(
    String text,
    int currentWordIndex,
    bool isActive,
    bool isPlainLyrics, // Add this parameter
  ) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final words = _splitTextIntoWords(text);
    if (words.isEmpty) return const SizedBox.shrink();

    // For plain lyrics, just show all words normally
    if (isPlainLyrics) {
      return Container(
        width: overlaySize - (horizontalPadding * 2),
        constraints: const BoxConstraints(minHeight: 50),
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: words.map((word) {
            return Text(
              word,
              style: _getBaseTextStyle().copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.8),
              ),
            );
          }).toList(),
        ),
      );
    }

    // Original animated version for timed lyrics
    return AnimatedBuilder(
      animation: Listenable.merge([_wordGlowController, _scaleController]),
      builder: (context, child) {
        return Container(
          width: overlaySize - (horizontalPadding * 2),
          constraints: const BoxConstraints(minHeight: 50),
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: words.asMap().entries.map((entry) {
              final wordIndex = entry.key;
              final word = entry.value;
              final isCurrentWord = isActive && wordIndex <= currentWordIndex;
              final isActiveWord = isActive && wordIndex == currentWordIndex;

              return _buildAnimatedWord(
                word,
                isCurrentWord,
                isActiveWord,
                isActive,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedWord(
    String word,
    bool isCurrentWord,
    bool isActiveWord,
    bool isActive,
  ) {
    Color textColor;
    double fontSize;
    FontWeight fontWeight;
    List<Shadow> shadows = [];

    if (isActive) {
      fontSize = 22;
      fontWeight = FontWeight.w600;
      if (isCurrentWord) {
        textColor = Colors.white;
        if (isActiveWord) {
          shadows = _buildActiveWordShadows();
        } else {
          shadows = _buildCurrentWordShadows();
        }
      } else {
        textColor = Colors.white.withOpacity(0.45);
      }
    } else {
      fontSize = 18;
      fontWeight = FontWeight.w400;
      textColor = Colors.white.withOpacity(0.35);
    }

    return AnimatedContainer(
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..scale(isActiveWord ? 1.0 + (_scaleController.value * 0.08) : 1.0),
      child: AnimatedDefaultTextStyle(
        duration: _animationDuration,
        curve: Curves.easeOutCubic,
        style: _getBaseTextStyle().copyWith(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
          shadows: shadows,
        ),
        child: Text(word),
      ),
    );
  }

  List<Shadow> _buildActiveWordShadows() {
    final glowIntensity = 0.5 + (_wordGlowController.value * 0.5);
    return [
      Shadow(
        blurRadius: 25 * glowIntensity,
        color: Colors.cyan.withOpacity(0.9 * glowIntensity),
        offset: Offset.zero,
      ),
      Shadow(
        blurRadius: 15 * glowIntensity,
        color: Colors.white.withOpacity(0.8 * glowIntensity),
        offset: Offset.zero,
      ),
      Shadow(
        blurRadius: 8 * glowIntensity,
        color: Colors.blue.withOpacity(0.6 * glowIntensity),
        offset: Offset.zero,
      ),
    ];
  }

  List<Shadow> _buildCurrentWordShadows() {
    return [
      Shadow(
        blurRadius: 12,
        color: Colors.white.withOpacity(0.7),
        offset: Offset.zero,
      ),
      Shadow(
        blurRadius: 6,
        color: Colors.white.withOpacity(0.5),
        offset: Offset.zero,
      ),
    ];
  }

  // Update the _buildLineByLineText method to use auto-scaling single line
  Widget _buildLineByLineText(
    String text,
    bool isActive,
    bool isPlainLyrics, // Add this parameter
  ) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    // For plain lyrics, simple static text
    if (isPlainLyrics) {
      return Container(
        width: overlaySize - (horizontalPadding * 2),
        constraints: const BoxConstraints(minHeight: 50),
        alignment: Alignment.center,
        child: Text(
          text,
          style: _getBaseTextStyle().copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Original animated version for timed lyrics
    return AnimatedBuilder(
      animation: Listenable.merge([_glowController, _scaleController]),
      builder: (context, child) {
        final glowIntensity = 0.6 + (_glowController.value * 0.4);
        final scale = isActive ? 1.0 + (_scaleController.value * 0.05) : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: overlaySize - (horizontalPadding * 2),
            constraints: const BoxConstraints(minHeight: 50),
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: _animationDuration,
              curve: Curves.easeOutCubic,
              style: _getBaseTextStyle().copyWith(
                fontSize: isActive ? 22 : 18,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? Colors.white : Colors.white.withOpacity(0.35),
                shadows: isActive ? _buildLineGlowShadows(glowIntensity) : [],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Shadow> _buildLineGlowShadows(double glowIntensity) {
    return [
      Shadow(
        blurRadius: 25 * glowIntensity,
        color: Colors.cyan.withOpacity(0.8 * glowIntensity),
        offset: Offset.zero,
      ),
      Shadow(
        blurRadius: 15 * glowIntensity,
        color: Colors.white.withOpacity(0.7 * glowIntensity),
        offset: Offset.zero,
      ),
      Shadow(
        blurRadius: 8 * glowIntensity,
        color: Colors.blue.withOpacity(0.5 * glowIntensity),
        offset: Offset.zero,
      ),
    ];
  }

  Widget _buildGradientOverlay(
    AlignmentGeometry begin,
    AlignmentGeometry end,
    BorderRadius borderRadius,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: borderRadius,
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _appearController,
      child: Container(
        width: overlaySize,
        height: overlaySize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.5),
              Colors.black.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note_outlined,
                color: Colors.white.withOpacity(0.5),
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(
                'No lyrics available',
                style: _getBaseTextStyle().copyWith(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final lyrics = audioState.currentLyrics;

    if (lyrics.isEmpty) {
      return _buildEmptyState();
    }

    final verticalPadding = (overlaySize / 2) - (itemHeight / 2);

    return FadeTransition(
      opacity: _appearController,
      child: Container(
        width: overlaySize,
        height: overlaySize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.5),
              Colors.black.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              // Main lyrics list
              ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  vertical: verticalPadding,
                  horizontal: 8,
                ),
                itemCount: lyrics.length,
                physics: const BouncingScrollPhysics(),
                // Update the build method's itemBuilder
                itemBuilder: (context, index) {
                  final line = lyrics[index];
                  final isActive = index == _currentIndex;
                  final isPlainLyrics =
                      line is PlainLyricsLine; // Check if plain lyrics

                  return GestureDetector(
                    onTap: isPlainLyrics
                        ? null
                        : () =>
                              _onLineTap(index), // Disable tap for plain lyrics
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: itemHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: EdgeInsets.symmetric(
                        vertical: verticalItemPadding,
                        horizontal: horizontalPadding,
                      ),
                      child: Center(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final settings = ref.watch(settingsProvider);
                            return settings.wordByWordLyrics &&
                                    !isPlainLyrics // Disable word-by-word for plain lyrics
                                ? _buildWordByWordText(
                                    line.text,
                                    _currentWordIndex,
                                    isActive,
                                    isPlainLyrics, // Pass the flag
                                  )
                                : _buildLineByLineText(
                                    line.text,
                                    isActive,
                                    isPlainLyrics, // Pass the flag
                                  );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Enhanced gradient overlays
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: gradientHeight,
                child: _buildGradientOverlay(
                  Alignment.topCenter,
                  Alignment.bottomCenter,
                  const BorderRadius.only(
                    topLeft: Radius.circular(borderRadius),
                    topRight: Radius.circular(borderRadius),
                  ),
                ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: gradientHeight,
                child: _buildGradientOverlay(
                  Alignment.bottomCenter,
                  Alignment.topCenter,
                  const BorderRadius.only(
                    bottomLeft: Radius.circular(borderRadius),
                    bottomRight: Radius.circular(borderRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
