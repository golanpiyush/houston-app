import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/utils/album_gesture_handler.dart';
import 'package:houston/widgets/lyrics_overlay.dart';

class AnimatedAlbumArt extends ConsumerStatefulWidget {
  final String imageUrl;
  final bool isPlaying;
  final Color shadowColor;

  const AnimatedAlbumArt({
    super.key,
    required this.imageUrl,
    required this.isPlaying,
    required this.shadowColor,
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

  late final AlbumArtGestureHandler _gestureHandler;

  bool _showLyrics = false;
  bool _lyricsLoading = false;

  // Cache variables
  String? _cachedImageUrl;
  Widget? _cachedImageWidget;
  bool _isLoading = false;

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

    if (!widget.isPlaying) {
      _fadeController.value = 1.0;
    }
  }

  void _initializeGestureHandler() {
    _gestureHandler = AlbumArtGestureHandler(
      context: context,
      ref: ref,
      slideController: _slideController,
      lyricsController: _lyricsController,
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

    if (widget.imageUrl.startsWith('http')) {
      _cachedImageWidget = _buildNetworkImage();
    } else {
      _cachedImageWidget = await _buildLocalImage();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.cover,
      width: imageSize,
      height: imageSize,
      placeholder: (_, __) => _buildPlaceholderWidget(),
      errorWidget: (_, __, ___) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );
  }

  Future<Widget> _buildLocalImage() async {
    try {
      final exists = await File(widget.imageUrl).exists();
      return exists
          ? Image.file(
              File(widget.imageUrl),
              fit: BoxFit.cover,
              width: imageSize,
              height: imageSize,
              errorBuilder: (_, __, ___) => _buildErrorWidget(),
            )
          : _buildErrorWidget();
    } catch (e) {
      debugPrint('Error loading local image: $e');
      return _buildErrorWidget();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isPlaying && oldWidget.isPlaying) {
      _fadeController.forward();
    } else if (widget.isPlaying && !oldWidget.isPlaying) {
      _fadeController.reverse();
    }

    if (widget.imageUrl != oldWidget.imageUrl) {
      _cacheImageWidget();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _lyricsController.dispose();
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
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.all(shadowMargin),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Primary vibrant shadow
            BoxShadow(
              color: widget.shadowColor.withOpacity(0.7),
              blurRadius: 60,
              spreadRadius: 20,
              offset: const Offset(0, 25),
            ),
            // Secondary glow effect
            BoxShadow(
              color: widget.shadowColor.withOpacity(0.4),
              blurRadius: 40,
              spreadRadius: 10,
              offset: const Offset(0, 15),
            ),
            // Subtle inner glow
            BoxShadow(
              color: widget.shadowColor.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContainer() {
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
        child: _isLoading
            ? _buildPlaceholderWidget()
            : _cachedImageWidget ?? _buildErrorWidget(),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Single tap for play/pause
      onTap: () => _gestureHandler.handleSingleTap(),

      // Double tap to hide lyrics when showing
      onDoubleTap: () => _gestureHandler.handleDoubleTap(_showLyrics),

      // Separate handlers for better gesture detection
      onHorizontalDragEnd: (details) =>
          _gestureHandler.handleHorizontalSwipe(details),
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
              // Enhanced shadow container
              _buildShadowContainer(),

              // Image container
              _buildImageContainer(),

              // Overlay stack (fade overlay + lyrics)
              _buildOverlayStack(),
            ],
          ),
        ),
      ),
    );
  }
}
