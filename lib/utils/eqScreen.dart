import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/providers/audio/audioEffectsProvider.dart';

class EQScreen extends ConsumerStatefulWidget {
  const EQScreen({super.key});

  @override
  ConsumerState<EQScreen> createState() => _EQScreenState();
}

class _EQScreenState extends ConsumerState<EQScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;
  final Set<String> _warningsShown = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _shouldShowWarning(AudioEffectsState state) {
    const double warningThreshold = 0.95;

    if (state.bassBoost > 1900) {
      final key = 'bassBoost_${(state.bassBoost / 100).floor()}';
      if (!_warningsShown.contains(key)) {
        _warningsShown.add(key);
        return true;
      }
    }

    if (state.loudnessEnhancer > 1900) {
      final key = 'loudness_${(state.loudnessEnhancer / 100).floor()}';
      if (!_warningsShown.contains(key)) {
        _warningsShown.add(key);
        return true;
      }
    }

    for (int i = 0; i < state.equalizerBands.length; i++) {
      if (state.equalizerBands[i].abs() > 2280) {
        final key = 'eq_${i}_${(state.equalizerBands[i].abs() / 100).floor()}';
        if (!_warningsShown.contains(key)) {
          _warningsShown.add(key);
          return true;
        }
      }
    }

    return false;
  }

  String _getWarningMessage(AudioEffectsState state) {
    List<String> highEffects = [];

    if (state.bassBoost > 1900) highEffects.add('Bass Boost');
    if (state.loudnessEnhancer > 1900) highEffects.add('Loudness');

    for (int i = 0; i < state.equalizerBands.length; i++) {
      if (state.equalizerBands[i].abs() > 2280) {
        highEffects.add('EQ Band ${i + 1}');
      }
    }

    if (highEffects.length == 1) {
      return '${highEffects.first} is above 95%. High levels may cause audio distortion.';
    } else if (highEffects.length > 1) {
      return 'Multiple effects above 95%. High levels may cause distortion.';
    }

    return 'Audio effects at high levels may cause distortion.';
  }

  @override
  Widget build(BuildContext context) {
    final effectsState = ref.watch(audioEffectsProvider);
    final effectsNotifier = ref.read(audioEffectsProvider.notifier);

    final showWarning = _shouldShowWarning(effectsState);
    final warningMessage = showWarning ? _getWarningMessage(effectsState) : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: showWarning ? null : 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: showWarning ? 56 : 0,
                child: showWarning
                    ? _buildWarningBanner(warningMessage)
                    : const SizedBox(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Audio Effects',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  _buildMasterControls(effectsState, effectsNotifier),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildPresetSelector(effectsState, effectsNotifier),
                    const SizedBox(height: 24),
                    _buildEffectKnobs(effectsState, effectsNotifier),
                    const SizedBox(height: 24),
                    _buildEqualizerBands(effectsState, effectsNotifier),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.orange[900]?.withOpacity(0.8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => _warningsShown.clear(),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterControls(
    AudioEffectsState state,
    AudioEffectsNotifier notifier,
  ) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            state.isEnabled ? Icons.toggle_on : Icons.toggle_off,
            color: state.isEnabled ? Colors.green : Colors.grey,
            size: 36,
          ),
          onPressed: () {
            notifier.toggleEffects();
            _warningsShown.clear();
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.restart_alt, color: Colors.white),
          onPressed: () {
            notifier.resetAllEffects();
            _warningsShown.clear();
          },
        ),
      ],
    );
  }

  Widget _buildPresetSelector(
    AudioEffectsState state,
    AudioEffectsNotifier notifier,
  ) {
    final allPresets = <String>[
      ...state.availablePresets,
      if (!state.availablePresets.contains('Custom')) 'Custom',
    ];

    String currentPreset = state.currentPreset;
    if (!allPresets.contains(currentPreset)) {
      currentPreset = allPresets.isNotEmpty ? allPresets.first : 'Normal';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.list, color: Colors.blue[300]),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: currentPreset,
              isExpanded: true,
              dropdownColor: Colors.grey[850],
              style: GoogleFonts.poppins(color: Colors.white),
              underline: const SizedBox(),
              items: allPresets
                  .map(
                    (preset) => DropdownMenuItem(
                      value: preset,
                      child: Row(
                        children: [
                          Text(preset),
                          if (preset == 'Custom')
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.tune,
                                size: 16,
                                color: Colors.orange[300],
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null && value != 'Custom') {
                  notifier.applyPreset(value);
                  _warningsShown.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectKnobs(
    AudioEffectsState state,
    AudioEffectsNotifier notifier,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 0.85, // Adjusted to accommodate labels
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildEffectKnob(
          value: state.bassBoost.toDouble(), // Fixed: Convert to double
          maxValue: 2000,
          label: 'Bass Boost',
          unit: 'mB',
          onChanged: notifier.setBassBoost,
          baseColor: Colors.red[800]!,
          highlightColor: Colors.red[300]!,
          warningThreshold: 1900,
        ),
        _buildBalanceKnob(state, notifier),
        _buildEffectKnob(
          value: state.loudnessEnhancer.toDouble(), // Fixed: Convert to double
          maxValue: 2000,
          label: 'Loudness',
          unit: 'mB',
          onChanged: notifier.setLoudnessEnhancer,
          baseColor: Colors.purple[800]!,
          highlightColor: Colors.purple[300]!,
          warningThreshold: 1900,
        ),
        _buildEffectKnob(
          value: state.presetReverb.toDouble(), // Fixed: Convert to double
          maxValue: 10,
          label: 'Reverb',
          unit: '%',
          onChanged: notifier.setPresetReverb,
          baseColor: Colors.orange[800]!,
          highlightColor: Colors.orange[300]!,
        ),
      ],
    );
  }

  Widget _buildBalanceKnob(
    AudioEffectsState state,
    AudioEffectsNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Label at the top
          Text(
            'Balance',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          KnobWidget(
            min: 0,
            max: 1,
            value: state.audioBalance,
            onChanged: notifier.setAudioBalance,
            label: 'Balance',
            unit: '',
            size: 100,
            baseColor: Colors.blue[800]!,
            highlightColor: Colors.blue[300]!,
          ),
          const SizedBox(height: 8),
          Text(
            _getBalanceText(state.audioBalance),
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getBalanceText(double balance) {
    final percentage = ((balance - 0.5).abs() * 200).toInt();
    final direction = balance < 0.5 ? 'Left' : 'Right';
    return balance == 0.5 ? 'Center' : '$percentage% $direction';
  }

  Widget _buildEffectKnob({
    required double value,
    required double maxValue,
    required String label,
    required String unit,
    required Function(double) onChanged,
    required Color baseColor,
    required Color highlightColor,
    double? warningThreshold,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Label at the top
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          KnobWidget(
            min: 0,
            max: maxValue,
            value: value,
            onChanged: onChanged,
            label: label,
            unit: unit,
            size: 100,
            baseColor: baseColor,
            highlightColor: highlightColor,
            warningThreshold: warningThreshold,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(value / maxValue * 100).toInt()}%',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
              if (warningThreshold != null && value > warningThreshold) ...[
                const SizedBox(width: 4),
                Icon(Icons.warning, color: Colors.orange, size: 14),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizerBands(
    AudioEffectsState state,
    AudioEffectsNotifier notifier,
  ) {
    if (state.bandCount == 0) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Equalizer',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.bandCount,
              itemBuilder: (context, index) {
                final freq = state.bandFrequencies[index];
                final level = state.equalizerBands[index];
                return _buildBandControl(
                  index: index,
                  frequency: freq,
                  level: level,
                  notifier: notifier,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandControl({
    required int index,
    required int frequency,
    required double level,
    required AudioEffectsNotifier notifier,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Text(
            notifier.formatFrequency(frequency),
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          KnobWidget(
            min: -2400,
            max: 2400,
            value: level,
            onChanged: (value) => notifier.setEqualizerBand(index, value),
            label: 'Band ${index + 1}',
            unit: 'mB',
            size: 70,
            baseColor: Colors.blueGrey[800]!,
            highlightColor: Colors.tealAccent[400]!,
            warningThreshold: 2280.0,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(level / 2400 * 100).toInt()}%',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
              ),
              if (level.abs() > 2280) ...[
                const SizedBox(width: 2),
                Icon(Icons.warning, color: Colors.orange, size: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class KnobWidget extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  final Function(double) onChanged;
  final String label;
  final String unit;
  final double size;
  final Color baseColor;
  final Color highlightColor;
  final double? warningThreshold;

  const KnobWidget({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.unit,
    required this.size,
    required this.baseColor,
    required this.highlightColor,
    this.warningThreshold,
  });

  @override
  _KnobWidgetState createState() => _KnobWidgetState();
}

class _KnobWidgetState extends State<KnobWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _currentValue;
  bool _isActive = false;
  double _lastAngle = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(covariant KnobWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _currentValue) {
      setState(() => _currentValue = widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getAngleFromPosition(Offset position) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;
    angle = angle - 90;
    if (angle > 135) angle = angle - 360;
    return angle.clamp(-135.0, 135.0);
  }

  double _angleToValue(double angle) {
    final normalizedAngle = (angle + 135) / 270;
    return widget.min + (normalizedAngle * (widget.max - widget.min));
  }

  double _valueToAngle(double value) {
    final normalizedValue = (value - widget.min) / (widget.max - widget.min);
    return (normalizedValue * 270) - 135;
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() => _isActive = true);
    _controller.forward();
    _lastAngle = _getAngleFromPosition(details.localPosition);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final newAngle = _getAngleFromPosition(details.localPosition);
    final newValue = _angleToValue(newAngle).clamp(widget.min, widget.max);
    setState(() => _currentValue = newValue);
    widget.onChanged(_currentValue);
    _lastAngle = newAngle;
  }

  void _handlePanEnd(DragEndDetails details) {
    _controller.reverse();
    setState(() => _isActive = false);
  }

  void _handleTap(TapDownDetails details) {
    final angle = _getAngleFromPosition(details.localPosition);
    final newValue = _angleToValue(angle).clamp(widget.min, widget.max);
    setState(() => _currentValue = newValue);
    widget.onChanged(_currentValue);
  }

  @override
  Widget build(BuildContext context) {
    final isWarning =
        widget.warningThreshold != null &&
        _currentValue.abs() > widget.warningThreshold!;
    final currentAngle = _valueToAngle(_currentValue);

    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTapDown: _handleTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _isActive
                    ? widget.highlightColor.withOpacity(0.8)
                    : widget.baseColor,
                Colors.black87,
              ],
              stops: const [0.3, 1.0],
            ),
            border: Border.all(
              color: _isActive ? widget.highlightColor : Colors.white24,
              width: _isActive ? 2 : 1,
            ),
            boxShadow: [
              if (_isActive || isWarning) ...[
                BoxShadow(
                  color: isWarning
                      ? Colors.orange.withOpacity(0.6)
                      : widget.highlightColor.withOpacity(0.4),
                  blurRadius: _isActive ? 20 : 10,
                  spreadRadius: _isActive ? 3 : 1,
                ),
              ],
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size - 8,
                height: widget.size - 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12, width: 1),
                ),
              ),
              ..._buildScaleMarkings(),
              if (_currentValue > widget.min)
                CustomPaint(
                  size: Size(widget.size - 20, widget.size - 20),
                  painter: KnobArcPainter(
                    startAngle: -135,
                    endAngle: currentAngle,
                    color: widget.highlightColor,
                    strokeWidth: 3,
                  ),
                ),
              Transform.rotate(
                angle: currentAngle * (math.pi / 180),
                child: Container(
                  width: 3,
                  height: widget.size * 0.35,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: widget.size * 0.25,
                height: widget.size * 0.25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _isActive
                          ? widget.highlightColor.withOpacity(0.3)
                          : Colors.grey[800]!,
                      Colors.black,
                    ],
                  ),
                  border: Border.all(
                    color: _isActive ? widget.highlightColor : Colors.white38,
                    width: 1.5,
                  ),
                ),
                child: _isActive
                    ? Icon(
                        Icons.radio_button_checked,
                        color: widget.highlightColor,
                        size: widget.size * 0.08,
                      )
                    : Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white54,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScaleMarkings() {
    final markings = <Widget>[];
    for (var i = 0; i < 11; i++) {
      final angle = -135 + (i * 27);
      final isMajor = i % 2 == 0;
      final isExtreme = i == 0 || i == 10;

      markings.add(
        Transform.rotate(
          angle: angle * (math.pi / 180),
          child: Container(
            width: isExtreme ? 3 : (isMajor ? 2 : 1),
            height: isExtreme
                ? widget.size * 0.2
                : (isMajor ? widget.size * 0.15 : widget.size * 0.1),
            decoration: BoxDecoration(
              color: isExtreme
                  ? widget.highlightColor.withOpacity(0.8)
                  : (isMajor ? Colors.white70 : Colors.white38),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    }
    return markings;
  }
}

class KnobArcPainter extends CustomPainter {
  final double startAngle;
  final double endAngle;
  final Color color;
  final double strokeWidth;

  KnobArcPainter({
    required this.startAngle,
    required this.endAngle,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final startRad = startAngle * math.pi / 180;
    final sweepRad = (endAngle - startAngle) * math.pi / 180;

    if (sweepRad.abs() > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startRad,
        sweepRad,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
