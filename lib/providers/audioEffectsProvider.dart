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

  // Initialize audio effects with session ID
  Future<bool> initialize(int sessionId) async {
    final success = await _methodChannel.initialize(sessionId);
    if (success) {
      state = state.copyWith(isInitialized: true, sessionId: sessionId);
      await _loadInitialData();
      return true;
    }
    return false;
  }

  // Alias for initialize - for compatibility with existing code
  // Handles nullable session ID
  Future<bool> initializeEffects(int? sessionId) async {
    if (sessionId == null) {
      print('Error: Audio session ID is null');
      return false;
    }
    return await initialize(sessionId);
  }

  // Load initial data after initialization
  Future<void> _loadInitialData() async {
    try {
      // Load available presets
      final presets = await _methodChannel.getAvailablePresets();

      // Load equalizer info
      final bandCount = await _methodChannel.getEqualizerBandCount();
      final List<double> bands = [];
      final List<int> frequencies = [];

      for (int i = 0; i < bandCount; i++) {
        final band = await _methodChannel.getEqualizerBand(i);
        final freq = await _methodChannel.getEqualizerBandFreq(i);
        bands.add(band.toDouble());
        frequencies.add(freq);
      }

      // Load current values
      final bassBoost = await _methodChannel.getBassBoost();
      final balance = await _methodChannel.getAudioBalance();
      final loudness = await _methodChannel.getLoudnessEnhancer();
      final reverb = await _methodChannel.getEnvironmentalReverb();

      state = state.copyWith(
        availablePresets: presets.isNotEmpty ? presets : ['Normal'],
        bandCount: bandCount,
        equalizerBands: bands,
        bandFrequencies: frequencies,
        bassBoost: bassBoost,
        audioBalance: balance,
        loudnessEnhancer: loudness,
        presetReverb: reverb,
        isEnabled: true,
      );
    } catch (e) {
      print('Error loading initial audio effects data: $e');
    }
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

  // Set bass boost (0-2000 mB)
  Future<void> setBassBoost(double value) async {
    final intValue = value.toInt().clamp(0, 2000);
    final success = await _methodChannel.setBassBoost(intValue);
    if (success) {
      state = state.copyWith(bassBoost: intValue, currentPreset: 'Custom');
    }
  }

  // Set audio balance (0.0 = left, 0.5 = center, 1.0 = right)
  Future<void> setAudioBalance(double balance) async {
    final clampedBalance = balance.clamp(0.0, 1.0);
    final success = await _methodChannel.setAudioBalance(clampedBalance);
    if (success) {
      state = state.copyWith(
        audioBalance: clampedBalance,
        currentPreset: 'Custom',
      );
    }
  }

  // Reset audio balance to center
  Future<void> resetAudioBalance() async {
    final success = await _methodChannel.resetAudioBalance();
    if (success) {
      state = state.copyWith(audioBalance: 0.5);
    }
  }

  // Set loudness enhancer (0-2000 mB)
  Future<void> setLoudnessEnhancer(double value) async {
    final intValue = value.toInt().clamp(0, 2000);
    final success = await _methodChannel.setLoudnessEnhancer(intValue);
    if (success) {
      state = state.copyWith(
        loudnessEnhancer: intValue,
        currentPreset: 'Custom',
      );
    }
  }

  // Set environmental reverb/preset reverb (0-100%)
  Future<void> setPresetReverb(double value) async {
    final intValue = value.toInt().clamp(0, 100);
    final success = await _methodChannel.setEnvironmentalReverb(intValue);
    if (success) {
      state = state.copyWith(presetReverb: intValue, currentPreset: 'Custom');
    }
  }

  // Set equalizer band level (-2400 to +2400 mB)
  Future<void> setEqualizerBand(int band, double level) async {
    if (band >= 0 && band < state.bandCount) {
      final intLevel = level.toInt().clamp(-2400, 2400);
      final success = await _methodChannel.setEqualizerBand(band, intLevel);
      if (success) {
        final newBands = List<double>.from(state.equalizerBands);
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
