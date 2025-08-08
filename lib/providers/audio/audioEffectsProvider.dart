import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/providers/managers/audioeffectsmethodchannel.dart';

// Provider instance
final audioEffectsProvider =
    StateNotifierProvider<AudioEffectsNotifier, AudioEffectsState>((ref) {
      return AudioEffectsNotifier();
    });

// State class to hold all audio effects data
class AudioEffectsState {
  final bool isEnabled;
  final bool isInitialized;
  final int sessionId;
  final String currentPreset;
  final List<String> availablePresets;

  // Individual effect values
  final int bassBoost;
  final double audioBalance;
  final int loudnessEnhancer;
  final int presetReverb;

  // Equalizer data
  final int bandCount;
  final List<double> equalizerBands;
  final List<int> bandFrequencies;

  // Support flags
  final Map<String, bool> effectSupport;

  const AudioEffectsState({
    this.isEnabled = false,
    this.isInitialized = false,
    this.sessionId = 0,
    this.currentPreset = 'Normal',
    this.availablePresets = const ['Normal'],
    this.bassBoost = 0,
    this.audioBalance = 0.5,
    this.loudnessEnhancer = 0,
    this.presetReverb = 0,
    this.bandCount = 0,
    this.equalizerBands = const [],
    this.bandFrequencies = const [],
    this.effectSupport = const {},
  });

  AudioEffectsState copyWith({
    bool? isEnabled,
    bool? isInitialized,
    int? sessionId,
    String? currentPreset,
    List<String>? availablePresets,
    int? bassBoost,
    double? audioBalance,
    int? loudnessEnhancer,
    int? presetReverb,
    int? bandCount,
    List<double>? equalizerBands,
    List<int>? bandFrequencies,
    Map<String, bool>? effectSupport,
  }) {
    return AudioEffectsState(
      isEnabled: isEnabled ?? this.isEnabled,
      isInitialized: isInitialized ?? this.isInitialized,
      sessionId: sessionId ?? this.sessionId,
      currentPreset: currentPreset ?? this.currentPreset,
      availablePresets: availablePresets ?? this.availablePresets,
      bassBoost: bassBoost ?? this.bassBoost,
      audioBalance: audioBalance ?? this.audioBalance,
      loudnessEnhancer: loudnessEnhancer ?? this.loudnessEnhancer,
      presetReverb: presetReverb ?? this.presetReverb,
      bandCount: bandCount ?? this.bandCount,
      equalizerBands: equalizerBands ?? this.equalizerBands,
      bandFrequencies: bandFrequencies ?? this.bandFrequencies,
      effectSupport: effectSupport ?? this.effectSupport,
    );
  }
}

// Notifier class to manage state and communicate with method channel
class AudioEffectsNotifier extends StateNotifier<AudioEffectsState> {
  final AudioEffectsMethodChannel _methodChannel;

  AudioEffectsNotifier()
    : _methodChannel = AudioEffectsMethodChannel(),
      super(const AudioEffectsState()) {
    _checkEffectSupport();
  }

  // Initialize audio effects with session ID but keep effects disabled
  Future<bool> initialize(int sessionId) async {
    // Always set session ID for consistency, but don't actually initialize effects
    state = state.copyWith(
      isInitialized: false, // Keep disabled
      sessionId: sessionId, // Maintain session ID consistency
      isEnabled: false, // Ensure effects are disabled
    );

    // Don't call method channel initialization to avoid MediaCodec conflicts
    // await _loadInitialData(); // DISABLED - this was causing the issues

    print('AudioEffects: Session ID set to $sessionId (effects disabled)');
    return true; // Always return success since we're just tracking session ID
  }

  // Check which effects are supported on the device
  Future<void> _checkEffectSupport() async {
    final Map<String, bool> support = {};
    final effectTypes = [
      'bass_boost',
      'equalizer',
      'loudness_enhancer',
      'environmental_reverb',
    ];

    for (final effect in effectTypes) {
      support[effect] = await _methodChannel.isEffectSupported(effect);
    }

    state = state.copyWith(effectSupport: support);
  }

  // Toggle all effects on/off
  Future<void> toggleEffects() async {
    if (state.isEnabled) {
      final success = await _methodChannel.disableAllEffects();
      if (success) {
        state = state.copyWith(isEnabled: false);
      }
    } else {
      final success = await _methodChannel.enableAllEffects();
      if (success) {
        state = state.copyWith(isEnabled: true);
      }
    }
  }

  // Apply a preset
  Future<void> applyPreset(String presetName) async {
    final success = await _methodChannel.applyPreset(presetName);
    if (success) {
      state = state.copyWith(currentPreset: presetName);
      // Reload current values after applying preset
      await _refreshCurrentValues();
    }
  }

  // Refresh current effect values from the native side
  Future<void> _refreshCurrentValues() async {
    try {
      final bassBoost = await _methodChannel.getBassBoost();
      final balance = await _methodChannel.getAudioBalance();
      final loudness = await _methodChannel.getLoudnessEnhancer();
      final reverb = await _methodChannel.getEnvironmentalReverb();

      final List<double> bands = [];
      for (int i = 0; i < state.bandCount; i++) {
        final band = await _methodChannel.getEqualizerBand(i);
        bands.add(band.toDouble());
      }

      state = state.copyWith(
        bassBoost: bassBoost,
        audioBalance: balance,
        loudnessEnhancer: loudness,
        presetReverb: reverb,
        equalizerBands: bands,
      );
    } catch (e) {
      print('Error refreshing audio effects values: $e');
    }
  }

  // Updated alias method
  Future<bool> initializeEffects(int? sessionId) async {
    if (sessionId == null) {
      print('Warning: Audio session ID is null, using default');
      return await initialize(0); // Use default session ID
    }
    return await initialize(sessionId);
  }

  Future<void> setBassBoost(double value) async {
    // NO-OP - just update state for UI consistency
    final intValue = value.toInt().clamp(0, 2000);
    state = state.copyWith(bassBoost: intValue, currentPreset: 'Custom');
  }

  Future<void> setAudioBalance(double balance) async {
    // NO-OP - just update state for UI consistency
    final clampedBalance = balance.clamp(0.0, 1.0);
    state = state.copyWith(
      audioBalance: clampedBalance,
      currentPreset: 'Custom',
    );
  }

  Future<void> setLoudnessEnhancer(double value) async {
    // NO-OP - just update state for UI consistency
    final intValue = value.toInt().clamp(0, 2000);
    state = state.copyWith(loudnessEnhancer: intValue, currentPreset: 'Custom');
  }

  Future<void> setPresetReverb(double value) async {
    // NO-OP - just update state for UI consistency
    final intValue = value.toInt().clamp(0, 100);
    state = state.copyWith(presetReverb: intValue, currentPreset: 'Custom');
  }

  Future<void> setEqualizerBand(int band, double level) async {
    // NO-OP - just update state for UI consistency
    if (band >= 0 && band < state.bandCount) {
      final intLevel = level.toInt().clamp(-2400, 2400);
      final newBands = List<double>.from(state.equalizerBands);
      if (newBands.length > band) {
        newBands[band] = intLevel.toDouble();
        state = state.copyWith(
          equalizerBands: newBands,
          currentPreset: 'Custom',
        );
      }
    }
  }

  // Reset all effects to default values
  Future<void> resetAllEffects() async {
    final success = await _methodChannel.resetAllEffects();
    if (success) {
      final resetBands = List<double>.filled(state.bandCount, 0.0);
      state = state.copyWith(
        bassBoost: 0,
        audioBalance: 0.5,
        loudnessEnhancer: 0,
        presetReverb: 0,
        equalizerBands: resetBands,
        currentPreset: 'Normal',
      );
    }
  }

  // Format frequency for display (e.g., 1000 Hz -> "1.0 kHz")
  String formatFrequency(int frequency) {
    if (frequency >= 1000) {
      final kHz = frequency / 1000.0;
      if (kHz == kHz.toInt()) {
        return '${kHz.toInt()} kHz';
      } else {
        return '${kHz.toStringAsFixed(1)} kHz';
      }
    } else {
      return '$frequency Hz';
    }
  }

  // Check if a specific effect is supported
  bool isEffectSupported(String effectType) {
    return state.effectSupport[effectType] ?? false;
  }

  // Release resources
  Future<void> release() async {
    await _methodChannel.release();
    state = const AudioEffectsState();
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }
}
