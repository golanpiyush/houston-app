// // audio/effects_controller.dart
// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:media_kit/media_kit.dart';

// class EffectsController extends ChangeNotifier {
//   // MPV player instance for applying effects
//   Player? _player;

//   // Equalizer bands (10-band EQ with frequencies optimized for music)
//   static const List<double> _defaultFrequencies = [
//     31.25, // Sub-bass
//     62.5, // Bass
//     125, // Lower midrange
//     250, // Midrange
//     500, // Upper midrange
//     1000, // Presence
//     2000, // Presence
//     4000, // Brilliance
//     8000, // High frequency
//     16000, // Ultra high frequency
//   ];

//   final Map<int, double> _equalizerBands = {};
//   double _bassBoost = 0.0;
//   double _trebleBoost = 0.0;
//   double _virtualSurround = 0.0;
//   double _compressor = 0.0;
//   double _loudness = 0.0;
//   double _reverb = 0.0;
//   double _chorus = 0.0;
//   double _tempo = 1.0;
//   double _pitch = 1.0;
//   bool _enabled = true;
//   bool _autoGain = false;
//   bool _noiseReduction = false;
//   bool _crossfeed = false;

//   // Advanced settings
//   double _dynamicRange = 0.0;
//   double _stereoWidth = 1.0;
//   bool _bassEnhancement = false;
//   bool _trebleEnhancement = false;

//   // Getters
//   List<double> get frequencies => _defaultFrequencies;
//   Map<int, double> get equalizerBands => Map.unmodifiable(_equalizerBands);
//   double get bassBoost => _bassBoost;
//   double get trebleBoost => _trebleBoost;
//   double get virtualSurround => _virtualSurround;
//   double get compressor => _compressor;
//   double get loudness => _loudness;
//   double get reverb => _reverb;
//   double get chorus => _chorus;
//   double get tempo => _tempo;
//   double get pitch => _pitch;
//   double get dynamicRange => _dynamicRange;
//   double get stereoWidth => _stereoWidth;
//   bool get enabled => _enabled;
//   bool get autoGain => _autoGain;
//   bool get noiseReduction => _noiseReduction;
//   bool get crossfeed => _crossfeed;
//   bool get bassEnhancement => _bassEnhancement;
//   bool get trebleEnhancement => _trebleEnhancement;

//   EffectsController() {
//     _initializeEqualizer();
//   }

//   // Connect to media_kit player
//   void setPlayer(Player player) {
//     _player = player;
//   }

//   void _initializeEqualizer() {
//     for (int i = 0; i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = 0.0;
//     }
//   }

//   // Equalizer methods
//   void setEqualizerBand(int band, double gain) {
//     if (band >= 0 && band < _defaultFrequencies.length) {
//       gain = gain.clamp(-20.0, 20.0);
//       _equalizerBands[band] = gain;
//       _applyEffects();
//       notifyListeners();
//     }
//   }

//   double getEqualizerBand(int band) {
//     return _equalizerBands[band] ?? 0.0;
//   }

//   // Audio enhancement methods
//   void setBassBoost(double gain) {
//     _bassBoost = gain.clamp(0.0, 20.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setTrebleBoost(double gain) {
//     _trebleBoost = gain.clamp(0.0, 20.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setVirtualSurround(double intensity) {
//     _virtualSurround = intensity.clamp(0.0, 1.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setCompressor(double ratio) {
//     _compressor = ratio.clamp(0.0, 1.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setLoudness(double gain) {
//     _loudness = gain.clamp(0.0, 15.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setReverb(double intensity) {
//     _reverb = intensity.clamp(0.0, 1.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setChorus(double intensity) {
//     _chorus = intensity.clamp(0.0, 1.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setTempo(double tempo) {
//     _tempo = tempo.clamp(0.5, 2.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setPitch(double pitch) {
//     _pitch = pitch.clamp(0.5, 2.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setDynamicRange(double range) {
//     _dynamicRange = range.clamp(0.0, 1.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setStereoWidth(double width) {
//     _stereoWidth = width.clamp(0.0, 2.0);
//     _applyEffects();
//     notifyListeners();
//   }

//   void setEnabled(bool enabled) {
//     _enabled = enabled;
//     _applyEffects();
//     notifyListeners();
//   }

//   void setAutoGain(bool enabled) {
//     _autoGain = enabled;
//     _applyEffects();
//     notifyListeners();
//   }

//   void setNoiseReduction(bool enabled) {
//     _noiseReduction = enabled;
//     _applyEffects();
//     notifyListeners();
//   }

//   void setCrossfeed(bool enabled) {
//     _crossfeed = enabled;
//     _applyEffects();
//     notifyListeners();
//   }

//   void setBassEnhancement(bool enabled) {
//     _bassEnhancement = enabled;
//     _applyEffects();
//     notifyListeners();
//   }

//   void setTrebleEnhancement(bool enabled) {
//     _trebleEnhancement = enabled;
//     _applyEffects();
//     notifyListeners();
//   }

//   // Apply all effects to the player - Fixed method
//   Future<void> _applyEffects() async {
//     if (_player == null || !_enabled) {
//       // Clear all filters if disabled
//       await _clearFilters();
//       return;
//     }

//     final filterString = _buildCompleteFilterString();

//     try {
//       if (kIsWeb) {
//         debugPrint('Audio effects not supported on web platform');
//         return;
//       }

//       // Check if platform is available and use the correct method
//       final platform = _player!.platform;
//       if (platform != null) {
//         // Use the platform-specific setProperty method
//         await platform.setProperty('af', filterString);
//         debugPrint('Applied audio filters: $filterString');
//       } else {
//         debugPrint('Platform not available for applying audio effects');
//       }
//     } catch (e) {
//       debugPrint('Error applying audio effects: $e');
//     }
//   }

//   // Public method for external use - cleaned up
//   Future<void> applyEffects() async {
//     await _applyEffects();
//   }

//   Future<void> _clearFilters() async {
//     try {
//       if (kIsWeb) {
//         return;
//       }

//       final platform = _player?.platform;
//       if (platform != null) {
//         await platform.setProperty('af', '');
//         debugPrint('Cleared audio filters');
//       }
//     } catch (e) {
//       debugPrint('Error clearing filters: $e');
//     }
//   }

//   // Build complete MPV audio filter string
//   String _buildCompleteFilterString() {
//     if (!_enabled) return '';

//     List<String> filters = [];

//     // Auto gain control (first in chain for optimal processing)
//     if (_autoGain) {
//       filters.add('dynaudnorm=f=75:g=25:p=0.95');
//     }

//     // Noise reduction
//     if (_noiseReduction) {
//       filters.add('highpass=f=20,lowpass=f=20000');
//       filters.add('afftdn=nr=12:nf=-25');
//     }

//     // Equalizer (core frequency shaping)
//     if (_equalizerBands.values.any((gain) => gain != 0.0)) {
//       List<String> eqFilters = [];
//       for (int i = 0; i < _defaultFrequencies.length; i++) {
//         final freq = _defaultFrequencies[i];
//         final gain = _equalizerBands[i] ?? 0.0;
//         if (gain.abs() > 0.1) {
//           eqFilters.add('equalizer=f=$freq:width_type=h:width=1:g=$gain');
//         }
//       }
//       if (eqFilters.isNotEmpty) {
//         filters.addAll(eqFilters);
//       }
//     }

//     // Bass enhancement with multiple techniques
//     if (_bassBoost > 0 || _bassEnhancement) {
//       if (_bassEnhancement) {
//         // Advanced bass enhancement using multiple filters
//         filters.add('lowshelf=f=100:g=${_bassBoost + 3}:width=0.8');
//         filters.add('bass=g=${_bassBoost}:f=60:w=1');
//         filters.add(
//           'equalizer=f=40:width_type=h:width=2:g=${_bassBoost * 0.7}',
//         );
//       } else {
//         filters.add('bass=g=${_bassBoost}:f=80:w=1');
//       }
//     }

//     // Treble enhancement
//     if (_trebleBoost > 0 || _trebleEnhancement) {
//       if (_trebleEnhancement) {
//         // Advanced treble enhancement
//         filters.add('highshelf=f=8000:g=${_trebleBoost + 2}:width=0.8');
//         filters.add('treble=g=${_trebleBoost}:f=10000:w=1');
//         filters.add(
//           'equalizer=f=12000:width_type=h:width=2:g=${_trebleBoost * 0.8}',
//         );
//       } else {
//         filters.add('treble=g=${_trebleBoost}:f=8000:w=1');
//       }
//     }

//     // Dynamic range compression
//     if (_compressor > 0) {
//       final ratio = 2 + (_compressor * 8); // 2:1 to 10:1 ratio
//       final threshold = -20 + (_compressor * 15); // -20dB to -5dB
//       filters.add(
//         'acompressor=threshold=${threshold}dB:ratio=$ratio:attack=5:release=50',
//       );
//     }

//     // Loudness normalization
//     if (_loudness > 0) {
//       filters.add('loudnorm=I=-16:TP=-1.5:LRA=11:linear=true');
//       if (_loudness > 5) {
//         filters.add('volume=${(_loudness - 5) * 0.5}dB');
//       }
//     }

//     // Stereo processing
//     if (_stereoWidth != 1.0 || _virtualSurround > 0) {
//       if (_virtualSurround > 0) {
//         // Virtual surround using multiple techniques
//         final intensity = _virtualSurround;
//         filters.add('extrastereo=m=${intensity * 0.8}:c=false');
//         filters.add(
//           'stereowiden=delay=20:feedback=${intensity * 0.6}:crossfeed=${intensity * 0.4}:drymix=${1.0 - intensity * 0.3}',
//         );

//         // Add some reverb for spatial effect
//         if (_reverb == 0) {
//           filters.add(
//             'aecho=0.8:0.9:${40 + (intensity * 20)}:${0.3 * intensity}',
//           );
//         }
//       }

//       if (_stereoWidth != 1.0) {
//         filters.add(
//           'stereowiden=delay=${(2.0 - _stereoWidth) * 10}:feedback=${_stereoWidth * 0.7}',
//         );
//       }
//     }

//     // Crossfeed for headphones
//     if (_crossfeed) {
//       filters.add('crossfeed=strength=0.4:range=0.5');
//     }

//     // Reverb
//     if (_reverb > 0) {
//       final roomSize = 0.1 + (_reverb * 0.7);
//       final damping = 0.5 + (_reverb * 0.4);
//       filters.add('aecho=0.8:0.88:${60 + (_reverb * 40)}:${_reverb * 0.6}');
//       filters.add(
//         'equalizer=f=400:width_type=h:width=1:g=${-2 * _reverb}',
//       ); // Slight mid cut for natural reverb
//     }

//     // Chorus
//     if (_chorus > 0) {
//       final speed = 0.5 + (_chorus * 1.5);
//       final depth = _chorus * 2.5;
//       filters.add(
//         'chorus=0.5:0.9:${20 + (_chorus * 30)}:0.4:${speed}:${depth}',
//       );
//     }

//     // Time stretching (tempo without pitch change)
//     if (_tempo != 1.0) {
//       filters.add('atempo=${_tempo}');
//     }

//     // Pitch shifting (without tempo change)
//     if (_pitch != 1.0) {
//       // Use scaletempo2 for better quality pitch shifting
//       final semitones = ((_pitch - 1.0) * 12).round();
//       if (semitones != 0) {
//         filters.add(
//           'asetrate=${44100 * _pitch},aresample=44100,atempo=${1.0 / _pitch}',
//         );
//       }
//     }

//     // Dynamic range expansion (for compressed music)
//     if (_dynamicRange > 0) {
//       final ratio = 1.0 + (_dynamicRange * 2.0); // 1:1 to 3:1 expansion
//       filters.add(
//         'acompressor=threshold=-25dB:ratio=1/${ratio}:attack=1:release=100:makeup=0dB',
//       );
//     }

//     // Final limiter to prevent clipping
//     if (filters.isNotEmpty) {
//       filters.add(
//         'alimiter=level_in=1:level_out=0.95:limit=1.0:attack=5:release=50',
//       );
//     }

//     return filters.join(',');
//   }

//   // Preset methods with enhanced settings
//   void applyPreset(EqualizerPreset preset) {
//     switch (preset) {
//       case EqualizerPreset.flat:
//         _applyFlat();
//         break;
//       case EqualizerPreset.rock:
//         _applyRock();
//         break;
//       case EqualizerPreset.pop:
//         _applyPop();
//         break;
//       case EqualizerPreset.jazz:
//         _applyJazz();
//         break;
//       case EqualizerPreset.classical:
//         _applyClassical();
//         break;
//       case EqualizerPreset.electronic:
//         _applyElectronic();
//         break;
//       case EqualizerPreset.bass:
//         _applyBass();
//         break;
//       case EqualizerPreset.vocal:
//         _applyVocal();
//         break;
//       case EqualizerPreset.acoustic:
//         _applyAcoustic();
//         break;
//       case EqualizerPreset.hiphop:
//         _applyHipHop();
//         break;
//     }
//     _applyEffects();
//     notifyListeners();
//   }

//   void _applyFlat() {
//     for (int i = 0; i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = 0.0;
//     }
//     _bassBoost = 0.0;
//     _trebleBoost = 0.0;
//     _compressor = 0.0;
//     _virtualSurround = 0.0;
//     _reverb = 0.0;
//     _chorus = 0.0;
//     _bassEnhancement = false;
//     _trebleEnhancement = false;
//   }

//   void _applyRock() {
//     final gains = [6.0, 4.0, 2.0, -1.0, -2.0, 0.0, 3.0, 5.0, 6.0, 7.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 4.0;
//     _trebleBoost = 5.0;
//     _compressor = 0.3;
//     _bassEnhancement = true;
//     _trebleEnhancement = true;
//   }

//   void _applyPop() {
//     final gains = [3.0, 2.0, 0.0, 3.0, 5.0, 5.0, 3.0, 1.0, -1.0, -2.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 2.0;
//     _trebleBoost = 2.0;
//     _compressor = 0.4;
//     _virtualSurround = 0.2;
//   }

//   void _applyJazz() {
//     final gains = [4.0, 3.0, 2.0, 3.0, -1.0, -1.0, 1.0, 2.0, 3.0, 4.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 2.0;
//     _trebleBoost = 3.0;
//     _virtualSurround = 0.3;
//     _reverb = 0.2;
//   }

//   void _applyClassical() {
//     final gains = [5.0, 4.0, 3.0, 2.0, -1.0, -1.0, 1.0, 3.0, 4.0, 5.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 1.0;
//     _trebleBoost = 4.0;
//     _virtualSurround = 0.4;
//     _reverb = 0.3;
//     _dynamicRange = 0.5;
//   }

//   void _applyElectronic() {
//     final gains = [8.0, 6.0, 2.0, 0.0, -3.0, 2.0, 2.0, 4.0, 7.0, 8.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 6.0;
//     _trebleBoost = 6.0;
//     _compressor = 0.2;
//     _virtualSurround = 0.5;
//     _bassEnhancement = true;
//   }

//   void _applyBass() {
//     final gains = [10.0, 8.0, 6.0, 4.0, 2.0, 0.0, -1.0, -1.0, 0.0, 1.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 8.0;
//     _trebleBoost = 0.0;
//     _bassEnhancement = true;
//     _compressor = 0.1;
//   }

//   void _applyVocal() {
//     final gains = [-3.0, -2.0, 2.0, 4.0, 6.0, 6.0, 5.0, 3.0, 2.0, 1.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 0.0;
//     _trebleBoost = 3.0;
//     _compressor = 0.3;
//     _noiseReduction = true;
//   }

//   void _applyAcoustic() {
//     final gains = [4.0, 3.0, 2.0, 1.0, 2.0, 3.0, 4.0, 3.0, 2.0, 1.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 2.0;
//     _trebleBoost = 3.0;
//     _reverb = 0.1;
//     _dynamicRange = 0.3;
//   }

//   void _applyHipHop() {
//     final gains = [7.0, 6.0, 4.0, 2.0, -1.0, -2.0, 1.0, 3.0, 4.0, 3.0];
//     for (int i = 0; i < gains.length && i < _defaultFrequencies.length; i++) {
//       _equalizerBands[i] = gains[i];
//     }
//     _bassBoost = 6.0;
//     _trebleBoost = 4.0;
//     _compressor = 0.4;
//     _bassEnhancement = true;
//   }

//   void resetAll() {
//     _applyFlat();
//     _tempo = 1.0;
//     _pitch = 1.0;
//     _dynamicRange = 0.0;
//     _stereoWidth = 1.0;
//     _loudness = 0.0;
//     _autoGain = false;
//     _noiseReduction = false;
//     _crossfeed = false;
//     _applyEffects();
//     notifyListeners();
//   }

//   // Get current filter string for debugging
//   String getFilterString() => _buildCompleteFilterString();

//   // Persistence methods
//   Map<String, dynamic> toJson() {
//     return {
//       'equalizerBands': _equalizerBands,
//       'bassBoost': _bassBoost,
//       'trebleBoost': _trebleBoost,
//       'virtualSurround': _virtualSurround,
//       'compressor': _compressor,
//       'loudness': _loudness,
//       'reverb': _reverb,
//       'chorus': _chorus,
//       'tempo': _tempo,
//       'pitch': _pitch,
//       'dynamicRange': _dynamicRange,
//       'stereoWidth': _stereoWidth,
//       'enabled': _enabled,
//       'autoGain': _autoGain,
//       'noiseReduction': _noiseReduction,
//       'crossfeed': _crossfeed,
//       'bassEnhancement': _bassEnhancement,
//       'trebleEnhancement': _trebleEnhancement,
//     };
//   }

//   void fromJson(Map<String, dynamic> json) {
//     if (json['equalizerBands'] != null) {
//       final bands = Map<String, dynamic>.from(json['equalizerBands']);
//       _equalizerBands.clear();
//       bands.forEach((key, value) {
//         _equalizerBands[int.parse(key)] = value.toDouble();
//       });
//     }

//     _bassBoost = (json['bassBoost'] ?? 0.0).toDouble();
//     _trebleBoost = (json['trebleBoost'] ?? 0.0).toDouble();
//     _virtualSurround = (json['virtualSurround'] ?? 0.0).toDouble();
//     _compressor = (json['compressor'] ?? 0.0).toDouble();
//     _loudness = (json['loudness'] ?? 0.0).toDouble();
//     _reverb = (json['reverb'] ?? 0.0).toDouble();
//     _chorus = (json['chorus'] ?? 0.0).toDouble();
//     _tempo = (json['tempo'] ?? 1.0).toDouble();
//     _pitch = (json['pitch'] ?? 1.0).toDouble();
//     _dynamicRange = (json['dynamicRange'] ?? 0.0).toDouble();
//     _stereoWidth = (json['stereoWidth'] ?? 1.0).toDouble();
//     _enabled = json['enabled'] ?? true;
//     _autoGain = json['autoGain'] ?? false;
//     _noiseReduction = json['noiseReduction'] ?? false;
//     _crossfeed = json['crossfeed'] ?? false;
//     _bassEnhancement = json['bassEnhancement'] ?? false;
//     _trebleEnhancement = json['trebleEnhancement'] ?? false;

//     _applyEffects();
//     notifyListeners();
//   }
// }

// enum EqualizerPreset {
//   flat,
//   rock,
//   pop,
//   jazz,
//   classical,
//   electronic,
//   bass,
//   vocal,
//   acoustic,
//   hiphop,
// }
