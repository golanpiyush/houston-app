import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/providers/audio/audio_state_provider.dart';

class SleepTimerCard extends ConsumerStatefulWidget {
  const SleepTimerCard({super.key});

  @override
  ConsumerState<SleepTimerCard> createState() => _SleepTimerCardState();
}

class _SleepTimerCardState extends ConsumerState<SleepTimerCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeIn));

    _slideController.forward();
  }

  // Fix 3: Add a listener in the build method to watch for state changes
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioState = ref.watch(audioProvider);
    final isActive = audioState.sleepTimerEndTime != null;
    final isPlaying = audioState.isPlaying;
    final notifier = ref.read(audioProvider.notifier);

    // Debug print to verify state
    // print(
    //   'SleepTimer UI - isActive: $isActive, endTime: ${audioState.sleepTimerEndTime}',
    // );

    // Prevent state conflicts - if we just set a timer, don't immediately cancel it
    if (isActive && audioState.sleepTimerEndTime != null) {
      final remaining = audioState.sleepTimerEndTime!.difference(
        DateTime.now(),
      );
      if (remaining.isNegative) {
        // Timer has expired, let it handle itself
        print('Timer expired naturally');
      }
    }

    // Listen for timer cancellation state changes
    ref.listen<AudioState>(audioProvider, (previous, next) {
      final wasActive = previous?.sleepTimerEndTime != null;
      final isNowActive = next.sleepTimerEndTime != null;

      // Timer state changed
      if (wasActive != isNowActive) {
        if (!isNowActive && _pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }

        // Force UI update
        if (mounted) {
          setState(() {});
        }
      }
    });

    // Control pulse animation based on active state
    if (isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isActive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.1),
                      theme.colorScheme.secondary.withOpacity(0.05),
                    ],
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
                blurRadius: isActive ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isActive
                  ? BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    )
                  : BorderSide.none,
            ),
            elevation: 0,
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme, isActive),
                  const SizedBox(height: 16),
                  _buildContent(theme, isActive, isPlaying, notifier),
                  if (isActive) _buildActiveTimer(theme, audioState, notifier),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isActive) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.2)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isActive ? _pulseAnimation.value : 1.0,
                child: Icon(
                  Icons.bedtime,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sleep Timer',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              AnimatedOpacity(
                opacity: isActive ? 1.0 : 0.6,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  isActive ? 'Timer is running' : 'Set automatic pause',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    ThemeData theme,
    bool isActive,
    bool isPlaying,
    notifier,
  ) {
    if (!isPlaying && !isActive) {
      return _buildInactiveState(theme);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose duration:',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          _buildTimerOptions(theme, isActive, isPlaying, notifier),
        ],
      ),
    );
  }

  Widget _buildInactiveState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Start playback to set sleep timer',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fix 1: Update the _buildTimerOptions method to properly handle state changes
  Widget _buildTimerOptions(
    ThemeData theme,
    bool isActive,
    bool isPlaying,
    notifier,
  ) {
    final audioState = ref.watch(audioProvider);
    final currentEndTime = audioState.sleepTimerEndTime;

    final options = [
      TimerOptionData('Off', null, isSelected: currentEndTime == null),
      if (isPlaying) ...[
        TimerOptionData('1 min', 1),
        TimerOptionData('15 min', 15),
        TimerOptionData('30 min', 30),
        TimerOptionData('1 hr', 60),
        TimerOptionData('2 hr', 120),
        TimerOptionData('3 hr', 180),
        TimerOptionData('5 hr', 300),
      ],
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 200 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: _TimerOption(
                label: option.label,
                isSelected: option.isSelected,
                isEnabled: isActive || isPlaying,
                onTap: option.minutes == null
                    ? () async {
                        print('Cancelling timer from Off button');
                        await notifier.cancelSleepTimer();
                        // Don't call setState here - let the listener handle it
                      }
                    : () async {
                        print('Setting timer to ${option.minutes} minutes');
                        await notifier.setSleepTimer(option.minutes!);
                        // Don't call setState here - let the listener handle it
                      },
              ),
            );
          },
        );
      }).toList(),
    );
  }

  // Fix 2: Update the _buildActiveTimer method to handle timer cancellation properly
  Widget _buildActiveTimer(ThemeData theme, audioState, notifier) {
    final endTime = audioState.sleepTimerEndTime;

    if (endTime == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            // Always get fresh state
            final currentState = ref.read(audioProvider);
            final currentEndTime = currentState.sleepTimerEndTime;

            if (currentEndTime == null) {
              return const SizedBox.shrink();
            }

            final remaining = currentEndTime.difference(DateTime.now());

            if (remaining.isNegative) {
              // Timer should have expired
              return const SizedBox.shrink();
            }

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time remaining',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(remaining),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await notifier.cancelSleepTimer();
                    if (mounted) setState(() {});
                  },
                  icon: Icon(Icons.close, color: theme.colorScheme.error),
                  tooltip: 'Cancel timer',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }
}

class TimerOptionData {
  final String label;
  final int? minutes;
  final bool isSelected;

  TimerOptionData(this.label, this.minutes, {this.isSelected = false});
}

class _TimerOption extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isEnabled;

  const _TimerOption({
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.isEnabled = true,
  });

  @override
  State<_TimerOption> createState() => _TimerOptionState();
}

class _TimerOptionState extends State<_TimerOption>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: widget.isEnabled ? widget.onTap : null,
                onTapDown: widget.isEnabled
                    ? (_) {
                        setState(() => _isPressed = true);
                        _controller.forward();
                      }
                    : null,
                onTapUp: widget.isEnabled
                    ? (_) {
                        setState(() => _isPressed = false);
                        _controller.reverse();
                      }
                    : null,
                onTapCancel: widget.isEnabled
                    ? () {
                        setState(() => _isPressed = false);
                        _controller.reverse();
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: widget.isSelected
                        ? LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.8),
                            ],
                          )
                        : null,
                    color: widget.isSelected
                        ? null
                        : _isPressed
                        ? theme.colorScheme.surfaceContainerHighest.withOpacity(
                            0.8,
                          )
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: widget.isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.2),
                      width: widget.isSelected ? 2 : 1,
                    ),
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style:
                        theme.textTheme.bodyMedium?.copyWith(
                          color: widget.isSelected
                              ? theme.colorScheme.onPrimary
                              : widget.isEnabled
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurfaceVariant.withOpacity(
                                  0.5,
                                ),
                          fontWeight: widget.isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ) ??
                        const TextStyle(),
                    child: Text(widget.label),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
