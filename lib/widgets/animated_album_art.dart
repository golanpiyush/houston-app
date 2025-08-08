import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/providers/lyrics_provider_provider.dart';
import 'package:houston/providers/settings_provider.dart';
import 'package:houston/utils/album_gesture_handler.dart';
import 'package:houston/widgets/lyrics_overlay.dart';

class AnimatedAlbumArt extends ConsumerStatefulWidget {
  final String imageUrl;
  final bool isPlaying;
  final Color shadowColor;
  final VoidCallback? onPreviousSong;
  final VoidCallback? onNextSong;
  final Future<String?> Function()? getAlbumArtFallback; // Add this

  const AnimatedAlbumArt({
    super.key,
    required this.imageUrl,
    required this.isPlaying,
    required this.shadowColor,
    this.onPreviousSong,
    this.onNextSong,
    this.getAlbumArtFallback, // Add this
  });

  @override
  ConsumerState<AnimatedAlbumArt> createState() => _AnimatedAlbumArtState();
}

class _AnimatedAlbumArtState extends ConsumerState<AnimatedAlbumArt>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _lyricsController;
  late final Animation<double> _lyricsAnimation;

  late final AnimationController _shadowColorController;
  late final Animation<double> _shadowColorAnimation;

  // Song transition animations
  late final AnimationController _songTransitionController;
  late Animation<double> _currentImageOpacity;
  late Animation<double> _nextImageOpacity;
  late Animation<Offset> _currentImageSlide;
  late Animation<Offset> _nextImageSlide;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;
  late final AnimationController _breathingController;
  late final Animation<double> _breathingAnimation;
  late final AlbumArtGestureHandler _gestureHandler;

  // Audio visualizer properties (simulated)
  Timer? _visualizerTimer;
  double _currentSoundLevel = 0.0;
  double _smoothedSoundLevel = 0.0;
  List<double> _soundLevelHistory = [];
  static const int _historyLength = 10;
  final Random _random = Random();

  // Visualizer settings
  double _sensitivity = 1.0;
  double _smoothingFactor = 0.15;

  bool _showLyrics = false;
  bool _lyricsLoading = false;
  bool _isTransitioning = false;

  // Cache variables
  String? _cachedImageUrl;
  Widget? _cachedImageWidget;
  Widget? _nextImageWidget; // For transition
  bool _isLoading = false;
  String? _transitionDirection; // 'left', 'right', or null

  // Constants
  static const double containerSize = 345.0;
  static const double imageSize = 335.0;
  static const double shadowMargin = 25.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeGestureHandler();
    _cacheImageWidget();
    _initializeAudioVisualizer();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _shadowColorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _shadowColorAnimation = CurvedAnimation(
      parent: _shadowColorController,
      curve: Curves.easeInOut,
    );

    _shadowColorController.forward();
  }

  void _initializeAudioVisualizer() {
    print('AUDIO_VISUALIZER: Initializing simulated audio visualizer');
  }

  void _startAudioMonitoring() {
    // Simulate audio levels with realistic music-like patterns
    _visualizerTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (mounted && widget.isPlaying) {
        _generateSimulatedAudioLevel();
      }
    });
    print('AUDIO_VISUALIZER: Started simulated audio monitoring');
  }

  void _stopAudioMonitoring() {
    _visualizerTimer?.cancel();
    _visualizerTimer = null;
    _currentSoundLevel = 0.0;
    _smoothedSoundLevel = 0.0;
    _soundLevelHistory.clear();
    print('AUDIO_VISUALIZER: Stopped audio monitoring');
  }

  void _generateSimulatedAudioLevel() {
    if (!mounted) return;

    // Generate realistic music-like audio patterns
    final baseLevel = 0.3 + (_random.nextDouble() * 0.4); // Base level 0.3-0.7
    final spike = _random.nextDouble() < 0.1
        ? _random.nextDouble() * 0.3
        : 0.0; // Occasional spikes
    final beat =
        sin(DateTime.now().millisecondsSinceEpoch / 500) *
        0.15; // Rhythmic component

    _currentSoundLevel = (baseLevel + spike + beat).clamp(0.0, 1.0);

    setState(() {
      // Add to history for smoothing
      _soundLevelHistory.add(_currentSoundLevel);
      if (_soundLevelHistory.length > _historyLength) {
        _soundLevelHistory.removeAt(0);
      }

      // Apply smoothing
      final averageLevel =
          _soundLevelHistory.reduce((a, b) => a + b) /
          _soundLevelHistory.length;
      _smoothedSoundLevel =
          (_smoothedSoundLevel * (1 - _smoothingFactor)) +
          (averageLevel * _smoothingFactor);
    });
  }

  double _getNormalizedSoundLevel() {
    if (!widget.isPlaying) return 0.0;
    return (_smoothedSoundLevel * _sensitivity).clamp(0.0, 1.0);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1.2)).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );

    _lyricsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _lyricsAnimation = CurvedAnimation(
      parent: _lyricsController,
      curve: Curves.easeOutCubic,
    );

    _songTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _currentImageOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _songTransitionController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _nextImageOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _songTransitionController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _songTransitionController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(
        parent: _songTransitionController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _initializeSlideAnimations('left');

    if (!widget.isPlaying) {
      _fadeController.value = 1.0;
    }
  }

  void _initializeSlideAnimations(String direction) {
    if (direction == 'left') {
      _currentImageSlide =
          Tween<Offset>(begin: Offset.zero, end: const Offset(-1.2, 0)).animate(
            CurvedAnimation(
              parent: _songTransitionController,
              curve: Curves.easeInOut,
            ),
          );

      _nextImageSlide =
          Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _songTransitionController,
              curve: Curves.easeInOut,
            ),
          );
    } else {
      _currentImageSlide =
          Tween<Offset>(begin: Offset.zero, end: const Offset(1.2, 0)).animate(
            CurvedAnimation(
              parent: _songTransitionController,
              curve: Curves.easeInOut,
            ),
          );

      _nextImageSlide =
          Tween<Offset>(begin: const Offset(-1.2, 0), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _songTransitionController,
              curve: Curves.easeInOut,
            ),
          );
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shadowColor != oldWidget.shadowColor) {
      _animateShadowColorChange();
    }

    // Handle play/pause state changes
    if (!widget.isPlaying && oldWidget.isPlaying) {
      _fadeController.forward();
      _stopAudioMonitoring();
    } else if (widget.isPlaying && !oldWidget.isPlaying) {
      _fadeController.reverse();
      _startAudioMonitoring();
    }

    if (widget.imageUrl != oldWidget.imageUrl) {
      print(
        'ANIMATED_ALBUM_ART: Song changed from ${oldWidget.imageUrl} to ${widget.imageUrl}',
      );
      _handleSongChange(oldWidget.imageUrl);
    }

    final currentLyricsProvider = ref.read(lyricsProviderProvider);
    if (_gestureHandler.lyricsProvider.selectedSource !=
        currentLyricsProvider.selectedSource) {
      print(
        'ANIMATED_ALBUM_ART: Settings changed, reinitializing gesture handler',
      );
      _gestureHandler.dispose();
      _initializeGestureHandler();
    }
  }

  void _animateShadowColorChange() {
    _shadowColorController.animateTo(0.0).then((_) {
      if (mounted) {
        _shadowColorController.forward();
      }
    });
  }

  Future<void> _handleSongChange(String oldImageUrl) async {
    print(
      'ANIMATED_ALBUM_ART: _handleSongChange called, isTransitioning: $_isTransitioning',
    );

    if (_isTransitioning) {
      print('ANIMATED_ALBUM_ART: Already transitioning, skipping');
      return;
    }

    setState(() {
      _isTransitioning = true;
    });

    try {
      print('ANIMATED_ALBUM_ART: Starting song transition');
      _animateShadowColorChange();

      final direction = _transitionDirection ?? 'left';
      _initializeSlideAnimations(direction);

      await _cacheNextImage(widget.imageUrl);
      print('ANIMATED_ALBUM_ART: Next image cached');

      await _songTransitionController.forward();
      print('ANIMATED_ALBUM_ART: Transition animation completed');

      if (mounted) {
        setState(() {
          _cachedImageUrl = widget.imageUrl;
          _cachedImageWidget = _nextImageWidget;
          _nextImageWidget = null;
          _transitionDirection = null;
        });
        print('ANIMATED_ALBUM_ART: State updated after transition');
      }

      _songTransitionController.reset();
      print('ANIMATED_ALBUM_ART: Animation controller reset');
    } catch (e) {
      print('ANIMATED_ALBUM_ART: Error during song transition: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
        print(
          'ANIMATED_ALBUM_ART: Transition completed, isTransitioning: false',
        );
      }
    }
  }

  void _initializeGestureHandler() {
    final lyricsProvider = ref.read(lyricsProviderProvider);

    print(
      'ANIMATED_ALBUM_ART: Initializing with lyrics source: ${lyricsProvider.selectedSource}',
    );

    _gestureHandler = AlbumArtGestureHandler(
      context: context,
      ref: ref,
      slideController: _slideController,
      lyricsController: _lyricsController,
      lyricsProvider: lyricsProvider,
      onLyricsLoadingChanged: () {
        setState(() {
          _lyricsLoading = !_lyricsLoading;
        });
      },
      onLyricsVisibilityChanged: () {
        setState(() {
          _showLyrics = !_showLyrics;
        });
      },
    );
  }

  Future<void> _cacheImageWidget() async {
    if (_cachedImageUrl == widget.imageUrl && _cachedImageWidget != null) {
      return;
    }

    setState(() => _isLoading = true);
    _cachedImageUrl = widget.imageUrl;

    try {
      if (widget.imageUrl.startsWith('http')) {
        _cachedImageWidget = _buildNetworkImage(widget.imageUrl);
      } else {
        _cachedImageWidget = await _buildLocalImage(widget.imageUrl);
      }
    } catch (e) {
      print('ANIMATED_ALBUM_ART: Error caching image widget: $e');
      _cachedImageWidget = _buildErrorWidget();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cacheNextImage(String imageUrl) async {
    try {
      if (imageUrl.startsWith('http')) {
        _nextImageWidget = _buildNetworkImage(imageUrl);
      } else {
        _nextImageWidget = await _buildLocalImage(imageUrl);
      }
      print('ANIMATED_ALBUM_ART: Next image widget created successfully');
    } catch (e) {
      print('ANIMATED_ALBUM_ART: Error caching next image: $e');
      _nextImageWidget = _buildErrorWidget();
    }
  }

  Widget _buildNetworkImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: imageSize,
      height: imageSize,
      placeholder: (_, __) => _buildPlaceholderWidget(),
      errorWidget: (_, __, ___) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );
  }

  Future<String?> _getAlbumArtFallbackPath() async {
    // This would be provided from the parent widget
    if (widget.getAlbumArtFallback != null) {
      return await widget.getAlbumArtFallback!();
    }
    return null;
  }

  Future<Widget> _buildLocalImage(String imageUrl) async {
    try {
      final exists = await File(imageUrl.replaceFirst('file://', '')).exists();
      if (exists) {
        return Image.file(
          File(imageUrl.replaceFirst('file://', '')),
          fit: BoxFit.cover,
          width: imageSize,
          height: imageSize,
          errorBuilder: (_, __, ___) => _buildErrorWidget(),
        );
      }
      // If local file doesn't exist, try to get fallback path
      final fallbackPath = await _getAlbumArtFallbackPath();
      if (fallbackPath != null && fallbackPath != imageUrl) {
        return _buildLocalImage(fallbackPath);
      }
      return _buildErrorWidget();
    } catch (e) {
      debugPrint('Error loading local image: $e');
      return _buildErrorWidget();
    }
  }

  void _triggerSongTransition(String direction) {
    if (_isTransitioning) return;

    print('ANIMATED_ALBUM_ART: Triggering song transition: $direction');

    setState(() {
      _transitionDirection = direction;
    });

    _initializeSlideAnimations(direction);
  }

  @override
  void dispose() {
    _stopAudioMonitoring();
    _fadeController.dispose();
    _slideController.dispose();
    _shadowColorController.dispose();
    _breathingController.dispose();
    _lyricsController.dispose();
    _songTransitionController.dispose();
    _gestureHandler.dispose();
    super.dispose();
  }

  Widget _buildPlaceholderWidget() {
    return Container(
      color: Colors.grey[800],
      width: imageSize,
      height: imageSize,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.shadowColor.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[900],
      width: imageSize,
      height: imageSize,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
      ),
    );
  }

  Widget _buildShadowContainer() {
    final breathingEnabled = ref.watch(
      settingsProvider.select((s) => s.breathingAnimation),
    );

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _songTransitionController,
          _shadowColorController,
          if (breathingEnabled) _breathingController,
        ]),
        builder: (context, child) {
          // Get normalized sound level for visualizer
          final soundLevel = _getNormalizedSoundLevel();

          // Enhanced breathing effect with audio visualization
          double breathingScale = 1.0;
          double breathingShadowBlur = 25.0;
          double breathingShadowSpread = 3.0;
          double shadowOpacity = _shadowColorAnimation.value * 0.6;

          if (breathingEnabled && widget.isPlaying) {
            // Get sound level for visualization
            final soundLevel = _getNormalizedSoundLevel();

            if (soundLevel > 0) {
              // Audio-reactive visualization
              final audioScale =
                  0.05 + (soundLevel * 0.15); // 5-20% scale based on audio
              final audioBlur = 15.0 + (soundLevel * 25.0); // 15-40 blur
              final audioSpread = 1.0 + (soundLevel * 6.0); // 1-7 spread
              final audioOpacity = 0.4 + (soundLevel * 0.4); // 0.4-0.8 opacity

              breathingScale = 1.0 + audioScale;
              breathingShadowBlur = audioBlur;
              breathingShadowSpread = audioSpread;
              shadowOpacity = _shadowColorAnimation.value * audioOpacity;
            } else {
              // Fallback to regular breathing animation
              final breathingValue = _breathingAnimation.value;
              breathingScale = 1.0 + (breathingValue * 0.05);
              breathingShadowBlur = 20.0 + (breathingValue * 10.0);
              breathingShadowSpread = 2.0 + (breathingValue * 3.0);
              shadowOpacity =
                  _shadowColorAnimation.value * (0.6 + (breathingValue * 0.2));
            }
          }

          return Transform.scale(
            scale:
                (_isTransitioning ? _scaleAnimation.value : 1.0) *
                breathingScale,
            child: Transform.rotate(
              angle: _isTransitioning ? _rotationAnimation.value : 0.0,
              child: Container(
                margin: const EdgeInsets.all(shadowMargin),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    // Main colored shadow with audio reactive effect
                    BoxShadow(
                      color: widget.shadowColor.withOpacity(shadowOpacity),
                      blurRadius: breathingShadowBlur,
                      spreadRadius: breathingShadowSpread,
                      offset: const Offset(0, 8),
                    ),
                    // Secondary deeper shadow for depth
                    BoxShadow(
                      color: widget.shadowColor.withOpacity(
                        shadowOpacity * 0.5,
                      ),
                      blurRadius: breathingShadowBlur * 1.5,
                      spreadRadius: breathingShadowSpread * 0.5,
                      offset: const Offset(0, 12),
                    ),
                    // Subtle ambient shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        0.2 * _shadowColorAnimation.value,
                      ),
                      blurRadius: breathingShadowBlur * 0.5,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    // Extra glow for high audio levels
                    if (soundLevel > 0.7)
                      BoxShadow(
                        color: widget.shadowColor.withOpacity(
                          shadowOpacity * 0.8,
                        ),
                        blurRadius: breathingShadowBlur * 2.0,
                        spreadRadius: breathingShadowSpread * 1.5,
                        offset: const Offset(0, 0),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageContainer() {
    if (_isTransitioning && _nextImageWidget != null) {
      print('ANIMATED_ALBUM_ART: Building transition image container');
      return Stack(
        children: [
          // Current image sliding out
          AnimatedBuilder(
            animation: _songTransitionController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _currentImageSlide.value.dx * imageSize,
                  _currentImageSlide.value.dy * imageSize,
                ),
                child: Opacity(
                  opacity: _currentImageOpacity.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: _buildSingleImageContainer(_cachedImageWidget),
                    ),
                  ),
                ),
              );
            },
          ),
          // Next image sliding in
          AnimatedBuilder(
            animation: _songTransitionController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _nextImageSlide.value.dx * imageSize,
                  _nextImageSlide.value.dy * imageSize,
                ),
                child: Opacity(
                  opacity: _nextImageOpacity.value,
                  child: Transform.scale(
                    scale: 0.9 + (_nextImageOpacity.value * 0.1),
                    child: Transform.rotate(
                      angle: -_rotationAnimation.value * 0.5,
                      child: _buildSingleImageContainer(_nextImageWidget),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return _buildSingleImageContainer(
      _isLoading
          ? _buildPlaceholderWidget()
          : (_cachedImageWidget ?? _buildErrorWidget()),
    );
  }

  Widget _buildSingleImageContainer(Widget? imageWidget) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: imageSize,
      height: imageSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.shadowColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: imageWidget ?? _buildErrorWidget(),
      ),
    );
  }

  Widget _buildOverlayStack() {
    return Stack(
      children: [
        // Fade overlay when paused
        FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // Audio visualizer indicator (small dot showing audio activity)
        if (widget.isPlaying)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getNormalizedSoundLevel() > 0.1
                    ? Colors.green.withOpacity(
                        0.8 + (_getNormalizedSoundLevel() * 0.2),
                      )
                    : Colors.grey.withOpacity(0.5),
                shape: BoxShape.circle,
                boxShadow: _getNormalizedSoundLevel() > 0.5
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        // Lyrics overlay with fade transition
        if (_showLyrics)
          FadeTransition(
            opacity: _lyricsAnimation,
            child: const LyricsOverlay(),
          ),
        // Loading indicator for lyrics
        if (_lyricsLoading)
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.shadowColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading lyrics...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Transition indicator
        if (_isTransitioning)
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _gestureHandler.handleSingleTap(),
      onDoubleTap: () => _gestureHandler.handleDoubleTap(_showLyrics),
      onHorizontalDragEnd: (details) {
        const double swipeThreshold = 100;
        final double velocity = details.primaryVelocity ?? 0;

        if (velocity.abs() > swipeThreshold &&
            !_showLyrics &&
            !_isTransitioning) {
          if (velocity > 0) {
            if (widget.onPreviousSong != null) {
              _triggerSongTransition('right');
              widget.onPreviousSong!();
            }
          } else {
            if (widget.onNextSong != null) {
              _triggerSongTransition('left');
              widget.onNextSong!();
            }
          }
        } else {
          _gestureHandler.handleHorizontalSwipe(details);
        }
      },
      onVerticalDragEnd: (details) =>
          _gestureHandler.handleVerticalSwipe(details, _showLyrics),
      child: SlideTransition(
        position: _slideAnimation,
        child: SizedBox(
          width: containerSize,
          height: containerSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _buildShadowContainer(),
              _buildImageContainer(),
              _buildOverlayStack(),
            ],
          ),
        ),
      ),
    );
  }
}
