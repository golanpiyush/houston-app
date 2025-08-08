import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/models/song.dart';
import 'package:houston/providers/ytmusic_provider.dart';

// Animation Controller Class
class StatusAnimations {
  static const Duration fastDuration = Duration(milliseconds: 300);
  static const Duration mediumDuration = Duration(milliseconds: 500);
  static const Duration slowDuration = Duration(milliseconds: 800);

  static const Curve elasticCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
  static const Curve bounceCurve = Curves.bounceOut;

  // Stagger animation delays
  static Duration getStaggerDelay(int index) {
    return Duration(milliseconds: 100 * index);
  }

  // Custom animation curves
  static Animation<double> createFadeAnimation(
    AnimationController controller,
    double begin,
    double end, {
    Duration delay = Duration.zero,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(
          delay.inMilliseconds / controller.duration!.inMilliseconds,
          1.0,
          curve: smoothCurve,
        ),
      ),
    );
  }

  static Animation<Offset> createSlideAnimation(
    AnimationController controller,
    Offset begin,
    Offset end, {
    Duration delay = Duration.zero,
  }) {
    return Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(
          delay.inMilliseconds / controller.duration!.inMilliseconds,
          1.0,
          curve: elasticCurve,
        ),
      ),
    );
  }

  static Animation<double> createScaleAnimation(
    AnimationController controller,
    double begin,
    double end, {
    Duration delay = Duration.zero,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(
          delay.inMilliseconds / controller.duration!.inMilliseconds,
          1.0,
          curve: bounceCurve,
        ),
      ),
    );
  }
}

// Animation Controller Class

class ApiStatusScreen extends ConsumerStatefulWidget {
  const ApiStatusScreen({super.key});

  @override
  ConsumerState<ApiStatusScreen> createState() => _ApiStatusScreenState();
}

class _ApiStatusScreenState extends ConsumerState<ApiStatusScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _refreshController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startInitialAnimation();
  }

  void _setupAnimations() {
    _mainController = AnimationController(
      duration: StatusAnimations.slowDuration,
      vsync: this,
      lowerBound: 0.8, // Prevent going below this value
      upperBound: 1.0, // Prevent going above this value
    );

    _refreshController = AnimationController(
      duration: StatusAnimations.mediumDuration,
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
      lowerBound: 0.9,
      upperBound: 1.1,
    );

    _fadeAnimation = StatusAnimations.createFadeAnimation(
      _mainController,
      0.0,
      1.0,
    );
    _slideAnimation = StatusAnimations.createSlideAnimation(
      _mainController,
      const Offset(0, 0.3),
      Offset.zero,
    );
    _scaleAnimation = StatusAnimations.createScaleAnimation(
      _mainController,
      0.8,
      1.0,
    );

    _pulseController.repeat(reverse: true);
  }

  void _startInitialAnimation() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _mainController.forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _refreshController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    try {
      // Reset the controller before starting
      _refreshController.reset();
      // Forward the animation
      await _refreshController.forward();
      // Check status
      await ref.read(ytMusicProvider.notifier).checkStatus();
    } finally {
      // Always reverse the animation when done
      if (mounted) {
        await _refreshController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ytMusicProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAnimatedAppBar(theme),
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SizeTransition(
              sizeFactor: _scaleAnimation,
              axis: Axis.vertical,
              axisAlignment: -1,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildBody(state, theme),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAnimatedAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.8),
                  theme.colorScheme.secondary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.api,
              color: theme.colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'System Status',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        RotationTransition(
          turns: Tween(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _refreshController,
              curve: Curves.easeInOut,
            ),
          ),
          child: IconButton(
            key: const ValueKey('refresh_button'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.refresh, color: theme.colorScheme.primary),
            ),
            onPressed: _handleRefresh,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(YtMusicState state, ThemeData theme) {
    // Get the app bar height from the theme instead of Scaffold
    final appBarHeight = AppBar().preferredSize.height;

    return Container(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height - appBarHeight,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.colorScheme.surface, theme.colorScheme.surface],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.isLoading) _buildLoadingIndicator(theme),
              if (state.error != null)
                _buildErrorCard(context, state.error!, theme),
              if (state.systemStatus != null)
                _buildStatusOverview(state.systemStatus!, theme),
              if (state.systemStatus != null) const SizedBox(height: 32),
              if (state.systemStatus != null)
                _buildComponentCards(state.systemStatus!, theme),
              const SizedBox(height: 32),
              _buildActionButton(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Checking Engine Status...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      duration: StatusAnimations.mediumDuration,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: StatusAnimations.elasticCurve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value.clamp(0.0, 1.0),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.errorContainer,
                  theme.colorScheme.errorContainer.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.error.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Engine Failed',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer.withOpacity(
                            0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOverview(SystemStatus status, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      duration: StatusAnimations.mediumDuration,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: StatusAnimations.smoothCurve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engine Overview',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStatusColor(
                          status.isFullyOperational,
                          theme,
                        ).withOpacity(0.1),
                        _getStatusColor(
                          status.isFullyOperational,
                          theme,
                        ).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(
                        status.isFullyOperational,
                        theme,
                      ).withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(
                          status.isFullyOperational,
                          theme,
                        ).withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: status.isFullyOperational
                                ? 1.0 + (_pulseController.value * 0.1)
                                : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  status.isFullyOperational,
                                  theme,
                                ).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                status.isFullyOperational
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: _getStatusColor(
                                  status.isFullyOperational,
                                  theme,
                                ),
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.statusSummary,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(
                                  status.isFullyOperational,
                                  theme,
                                ),
                              ),
                            ),
                            if (status.message.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                status.message,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComponentCards(SystemStatus status, ThemeData theme) {
    return Column(
      children: [
        Text(
          'Components',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildAnimatedComponentCard(
          icon: Icons.music_note,
          title: 'YouTube Music',
          version: status.ytmusicVersion,
          isReady: status.ytmusicReady,
          delay: StatusAnimations.getStaggerDelay(0),
          theme: theme,
        ),
        const SizedBox(height: 16),
        _buildAnimatedComponentCard(
          icon: Icons.download,
          title: 'yt-dlp',
          version: status.ytdlpVersion,
          isReady: status.ytdlpReady,
          delay: StatusAnimations.getStaggerDelay(1),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildAnimatedComponentCard({
    required IconData icon,
    required String title,
    required String version,
    required bool isReady,
    required Duration delay,
    required ThemeData theme,
  }) {
    return TweenAnimationBuilder<double>(
      duration: StatusAnimations.mediumDuration + delay,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: StatusAnimations.elasticCurve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getStatusColor(isReady, theme).withOpacity(0.2),
                          _getStatusColor(isReady, theme).withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: _getStatusColor(isReady, theme),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version: $version',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(isReady, theme).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(isReady, theme),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isReady ? 'Operational' : 'Offline',
                          style: TextStyle(
                            color: _getStatusColor(isReady, theme),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, ThemeData theme) {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: StatusAnimations.slowDuration,
        tween: Tween(begin: 0.0, end: 1.0),
        curve: StatusAnimations.bounceCurve,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value.clamp(0.1, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 24),
                label: const Text(
                  'refresh Engine',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _handleRefresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(bool isReady, ThemeData theme) {
    return isReady
        ? const Color(0xFF10B981) // Green
        : const Color(0xFFF59E0B); // Orange
  }
}
