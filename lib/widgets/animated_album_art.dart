import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/models/lyrics_model.dart';
import 'package:houston/providers/lyrics_provider.dart';
import 'package:houston/widgets/lyrics_overlay.dart';
import '../providers/audio_provider.dart';

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
  bool _isDismissing = false;
  bool _showLyrics = false;
  // ignore: unused_field
  bool _lyricsLoading = false;

  // Cache variables
  String? _cachedImageUrl;
  Widget? _cachedImageWidget;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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

    if (!widget.isPlaying) {
      _fadeController.value = 1.0;
    }
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
      width: 350,
      height: 350,
      placeholder: (_, __) => _buildPlaceholderWidget(),
      errorWidget: (_, __, ___) => _buildErrorWidget(),
    );
  }

  Future<Widget> _buildLocalImage() async {
    try {
      final exists = await File(widget.imageUrl).exists();
      return exists
          ? Image.file(
              File(widget.imageUrl),
              fit: BoxFit.cover,
              width: 350,
              height: 350,
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
    super.dispose();
  }

  void _handleSwipe(DragEndDetails details) async {
    final velocity = details.primaryVelocity ?? 0;
    if (_isDismissing) return;

    if (velocity < -300) {
      // Swipe up: Show lyrics
      if (!_showLyrics) {
        setState(() {
          _lyricsLoading = true;
          _showLyrics = true;
        });

        final song = ref.read(audioProvider).currentSong;
        if (song != null) {
          try {
            final result = await LyricsProvider().fetchLyrics(
              song.title,
              song.artists,
            );
            if (result['success']) {
              final parsed = (result['lines'] as List)
                  .map((e) => LyricsLine.fromMap(e))
                  .toList();
              ref.read(audioProvider.notifier).setLyrics(parsed);
            }
          } catch (e) {
            print('Error loading lyrics: $e');
          }
        }

        setState(() {
          _lyricsLoading = false;
        });

        _fadeController.forward(); // fade in lyrics
      }
    } else if (velocity > 300) {
      // Swipe down: Hide lyrics / dismiss
      if (_showLyrics) {
        setState(() => _showLyrics = false);
        _fadeController.reverse(); // fade out lyrics
      } else {
        _isDismissing = true;
        _slideController.forward().then((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  Widget _buildPlaceholderWidget() {
    return Container(
      color: Colors.grey[800],
      width: 350,
      height: 350,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[900],
      width: 350,
      height: 350,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ref.read(audioProvider.notifier).pauseResume(),
      onHorizontalDragEnd: _handleSwipe,
      onVerticalDragEnd: _handleSwipe,
      child: SlideTransition(
        position: _slideAnimation,
        child: SizedBox(
          width: 345,
          height: 345,
          child: Stack(
            clipBehavior: Clip.none, // Important for shadow visibility
            alignment: Alignment.center,
            children: [
              // Enhanced shadow container with multiple layers
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(25), // More space for shadow
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
              ),
              // Image container
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: 335, // Smaller than container to show shadow
                height: 335,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  // Add a subtle border to enhance the effect
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
              ),
              // Fade overlay when paused
              Stack(
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 335,
                      height: 335,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  if (_showLyrics) const LyricsOverlay(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
