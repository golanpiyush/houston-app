import 'package:flutter/material.dart';
import 'shimmer.dart';

class ShimmerListPlaceholder extends StatelessWidget {
  final int itemCount;
  final bool showBackground;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  const ShimmerListPlaceholder({
    super.key,
    this.itemCount = 8,
    this.showBackground = false,
    this.padding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        physics: physics,
        child: Column(
          children: List.generate(
            itemCount,
            (index) => const MusicItemShimmer(),
          ),
        ),
      ),
    );
  }
}

class MusicItemShimmer extends StatelessWidget {
  const MusicItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Album art shimmer
          const AlbumArtShimmer(size: 56, borderRadius: 8),
          const SizedBox(width: 16),
          // Text content shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title shimmer (varies in width)
                TextShimmer(
                  width: _getRandomTitleWidth(),
                  height: 16,
                  margin: const EdgeInsets.only(bottom: 8),
                ),
                // Artist shimmer (varies in width)
                TextShimmer(
                  width: _getRandomArtistWidth(),
                  height: 14,
                  margin: const EdgeInsets.only(bottom: 4),
                ),
                // Album/Duration shimmer
                TextShimmer(width: _getRandomAlbumWidth(), height: 12),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Options button shimmer
          const CircularShimmer(size: 24),
        ],
      ),
    );
  }

  double _getRandomTitleWidth() {
    final widths = [120.0, 180.0, 200.0, 160.0, 220.0];
    return widths[DateTime.now().millisecondsSinceEpoch % widths.length];
  }

  double _getRandomArtistWidth() {
    final widths = [80.0, 120.0, 140.0, 100.0, 160.0];
    return widths[DateTime.now().millisecondsSinceEpoch % widths.length];
  }

  double _getRandomAlbumWidth() {
    final widths = [60.0, 90.0, 110.0, 80.0, 130.0];
    return widths[DateTime.now().millisecondsSinceEpoch % widths.length];
  }
}

// Specialized shimmer for search results
class SearchResultShimmer extends StatefulWidget {
  const SearchResultShimmer({super.key});

  @override
  State<SearchResultShimmer> createState() => _SearchResultShimmerState();
}

class _SearchResultShimmerState extends State<SearchResultShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Album art shimmer
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(_animation.value),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),

                // Text content shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 18,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(_animation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: MediaQuery.of(context).size.width * 0.6,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(_animation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 12,
                        width: MediaQuery.of(context).size.width * 0.3,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(_animation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration shimmer
                Container(
                  width: 40,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(_animation.value),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getSearchTitleWidth() {
    final widths = [140.0, 180.0, 160.0, 200.0];
    return widths[DateTime.now().millisecondsSinceEpoch % widths.length];
  }

  double _getSearchArtistWidth() {
    final widths = [90.0, 110.0, 130.0, 100.0];
    return widths[DateTime.now().millisecondsSinceEpoch % widths.length];
  }
}

// Grid shimmer for albums/playlists
class GridShimmerPlaceholder extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final EdgeInsetsGeometry? padding;

  const GridShimmerPlaceholder({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: padding ?? const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: List.generate(
          itemCount,
          (index) => SizedBox(
            width: (MediaQuery.of(context).size.width - 48) / crossAxisCount,
            child: const GridItemShimmer(),
          ),
        ),
      ),
    );
  }
}

class GridItemShimmer extends StatelessWidget {
  const GridItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    // Calculate item width based on screen size and cross axis count
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 48) / 2; // 48 = padding + spacing
    final aspectRatio = 1.0; // Square aspect ratio for album art
    final imageHeight = itemWidth * aspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Square album art with fixed height instead of Expanded
        SizedBox(
          width: itemWidth,
          height: imageHeight,
          child: const AlbumArtShimmer(size: double.infinity, borderRadius: 12),
        ),
        const SizedBox(height: 8),
        // Title
        const TextShimmer(
          width: double.infinity,
          height: 14,
          margin: EdgeInsets.only(bottom: 4),
        ),
        // Artist
        TextShimmer(width: _getGridArtistWidth(), height: 12),
      ],
    );
  }

  double _getGridArtistWidth() {
    final widths = [80.0, 100.0, 120.0, 90.0];
    return widths[DateTime.now().millisecondsSinceEpoch % widths.length];
  }
}
