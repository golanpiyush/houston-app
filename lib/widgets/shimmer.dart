import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppShimmer extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AppShimmer({
    super.key,
    required this.child,
    this.isLoading = true,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Professional shimmer colors with transparency
    final defaultBaseColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.grey.shade300.withOpacity(0.6);
    final defaultHighlightColor = isDark
        ? Colors.white.withOpacity(0.16)
        : Colors.grey.shade100.withOpacity(0.8);

    if (!isLoading) return child;

    return Container(
      margin: margin,
      padding: padding,
      child: Shimmer.fromColors(
        baseColor: baseColor ?? defaultBaseColor,
        highlightColor: highlightColor ?? defaultHighlightColor,
        period: const Duration(milliseconds: 1200),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: baseColor ?? defaultBaseColor,
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

// Specialized shimmer for text with dynamic width
class TextShimmer extends StatelessWidget {
  final double? width;
  final double height;
  final bool isLoading;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  const TextShimmer({
    super.key,
    this.width,
    this.height = 14,
    this.isLoading = true,
    this.borderRadius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      isLoading: isLoading,
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
      margin: margin,
      child: const SizedBox.shrink(),
    );
  }
}

// Specialized shimmer for circular elements like album art
class CircularShimmer extends StatelessWidget {
  final double size;
  final bool isLoading;
  final EdgeInsetsGeometry? margin;

  const CircularShimmer({
    super.key,
    this.size = 56,
    this.isLoading = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      isLoading: isLoading,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      margin: margin,
      child: const SizedBox.shrink(),
    );
  }
}

// Specialized shimmer for album art (square with rounded corners)
class AlbumArtShimmer extends StatelessWidget {
  final double size;
  final bool isLoading;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const AlbumArtShimmer({
    super.key,
    this.size = 56,
    this.isLoading = true,
    this.margin,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      isLoading: isLoading,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(borderRadius),
      margin: margin,
      child: const SizedBox.shrink(),
    );
  }
}
