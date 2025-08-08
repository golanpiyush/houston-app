import 'package:flutter/services.dart';

class AudioEffectsMethodChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.example.houston/audio_effects',
  );

  AudioEffectsMethodChannel();

  // Initialize effects with audio session ID
  Future<bool> initialize(int sessionId) async {
    try {
      print("[AudioEffects] Initializing with sessionId: $sessionId");
      final result = await _channel.invokeMethod('initializeEffects', {
        'sessionId': sessionId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error initializing audio effects: ${e.message}');
      return false;
    }
  }

  // Apply preset
  Future<bool> applyPreset(String presetName) async {
    try {
      print("[AudioEffects] Applying preset: $presetName");
      final result = await _channel.invokeMethod('applyPreset', {
        'presetName': presetName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error applying preset: ${e.message}');
      return false;
    }
  }

  // Bass Boost controls
  Future<bool> setBassBoost(int strength) async {
    try {
      print("[AudioEffects] Setting bass boost: $strength");
      final result = await _channel.invokeMethod('setBassBoost', {
        'strength': strength,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error setting bass boost: ${e.message}');
      return false;
    }
  }

  Future<int> getBassBoost() async {
    try {
      print("[AudioEffects] Getting bass boost");
      final result = await _channel.invokeMethod('getBassBoost');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Error getting bass boost: ${e.message}');
      return 0;
    }
  }

  // Audio Balance controls
  Future<bool> setAudioBalance(double balance) async {
    try {
      print("[AudioEffects] Setting audio balance: $balance");
      final result = await _channel.invokeMethod('setAudioBalance', {
        'balance': balance,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error setting audio balance: ${e.message}');
      return false;
    }
  }

  Future<double> getAudioBalance() async {
    try {
      print("[AudioEffects] Getting audio balance");
      final result = await _channel.invokeMethod('getAudioBalance');
      return result?.toDouble() ?? 0.5;
    } on PlatformException catch (e) {
      print('Error getting audio balance: ${e.message}');
      return 0.5;
    }
  }

  Future<bool> resetAudioBalance() async {
    try {
      print("[AudioEffects] Resetting audio balance");
      final result = await _channel.invokeMethod('resetAudioBalance');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error resetting audio balance: ${e.message}');
      return false;
    }
  }

  // Equalizer controls
  Future<bool> setEqualizerBand(int band, int level) async {
    try {
      print("[AudioEffects] Setting EQ band $band to $level");
      final result = await _channel.invokeMethod('setEqualizerBand', {
        'band': band,
        'level': level,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error setting equalizer band: ${e.message}');
      return false;
    }
  }

  Future<int> getEqualizerBand(int band) async {
    try {
      print("[AudioEffects] Getting EQ band $band");
      final result = await _channel.invokeMethod('getEqualizerBand', {
        'band': band,
      });
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Error getting equalizer band: ${e.message}');
      return 0;
    }
  }

  Future<int> getEqualizerBandCount() async {
    try {
      print("[AudioEffects] Getting EQ band count");
      final result = await _channel.invokeMethod('getEqualizerBandCount');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Error getting equalizer band count: ${e.message}');
      return 0;
    }
  }

  Future<int> getEqualizerBandFreq(int band) async {
    try {
      print("[AudioEffects] Getting EQ band $band frequency");
      final result = await _channel.invokeMethod('getEqualizerBandFreq', {
        'band': band,
      });
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Error getting equalizer band frequency: ${e.message}');
      return 0;
    }
  }

  // Loudness Enhancer controls
  Future<bool> setLoudnessEnhancer(int gainmB) async {
    try {
      print("[AudioEffects] Setting loudness enhancer: $gainmB");
      final result = await _channel.invokeMethod('setLoudnessEnhancer', {
        'gainmB': gainmB,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error setting loudness enhancer: ${e.message}');
      return false;
    }
  }

  Future<int> getLoudnessEnhancer() async {
    try {
      print("[AudioEffects] Getting loudness enhancer");
      final result = await _channel.invokeMethod('getLoudnessEnhancer');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Error getting loudness enhancer: ${e.message}');
      return 0;
    }
  }

  // Environmental Reverb controls (0-100%)
  Future<bool> setEnvironmentalReverb(int level) async {
    try {
      print("[AudioEffects] Setting environmental reverb: $level%");
      final result = await _channel.invokeMethod(
        'setEnvironmentalReverbLevel',
        {'level': level},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error setting environmental reverb: ${e.message}');
      return false;
    }
  }

  Future<int> getEnvironmentalReverb() async {
    try {
      print("[AudioEffects] Getting environmental reverb");
      final result = await _channel.invokeMethod('getEnvironmentalReverbLevel');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Error getting environmental reverb: ${e.message}');
      return 0;
    }
  }

  // Master controls
  Future<bool> enableAllEffects() async {
    try {
      print("[AudioEffects] Enabling all effects");
      final result = await _channel.invokeMethod('enableAllEffects');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error enabling all effects: ${e.message}');
      return false;
    }
  }

  Future<bool> disableAllEffects() async {
    try {
      print("[AudioEffects] Disabling all effects");
      final result = await _channel.invokeMethod('disableAllEffects');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error disabling all effects: ${e.message}');
      return false;
    }
  }

  Future<bool> resetAllEffects() async {
    try {
      print("[AudioEffects] Resetting all effects");
      final result = await _channel.invokeMethod('resetAllEffects');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error resetting all effects: ${e.message}');
      return false;
    }
  }

  // Get available presets
  Future<List<String>> getAvailablePresets() async {
    try {
      print("[AudioEffects] Getting available presets");
      final result = await _channel.invokeMethod('getAvailablePresets');
      return List<String>.from(result ?? []);
    } on PlatformException catch (e) {
      print('Error getting available presets: ${e.message}');
      return [];
    }
  }

  // Check if effects are supported
  Future<bool> isEffectSupported(String effectType) async {
    try {
      print("[AudioEffects] Checking support for $effectType");
      final result = await _channel.invokeMethod('isEffectSupported', {
        'effectType': effectType,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking effect support: ${e.message}');
      return false;
    }
  }

  // Release effects
  Future<void> release() async {
    try {
      print("[AudioEffects] Releasing effects");
      await _channel.invokeMethod('release');
    } on PlatformException catch (e) {
      print('Error releasing effects: ${e.message}');
    }
  }
}
