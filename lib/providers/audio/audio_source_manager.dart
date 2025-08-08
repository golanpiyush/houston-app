// import 'dart:io';
// import 'dart:async';
// import 'package:just_audio/just_audio.dart';
// import 'package:just_audio_background/just_audio_background.dart';
// import '../../models/song.dart';
// import '../../services/storage_service.dart';

// enum AudioSourceType { NETWORK_STREAM, LOCAL_FILE, CACHED_FILE, UNAVAILABLE }

// class AudioSourceInfo {
//   final AudioSourceType type;
//   final String actualPath;
//   final bool isAvailable;
//   final Duration? estimatedLoadTime;
//   final String? fallbackUrl;

//   AudioSourceInfo({
//     required this.type,
//     required this.actualPath,
//     required this.isAvailable,
//     this.estimatedLoadTime,
//     this.fallbackUrl,
//   });
// }

// class OptimalAudioSource {
//   final AudioSource source;
//   final AudioSourceInfo info;
//   final MediaItem mediaItem;

//   OptimalAudioSource({
//     required this.source,
//     required this.info,
//     required this.mediaItem,
//   });
// }

// /// Intelligent audio source management for local vs network songs
// class AudioSourceManager {
//   final StorageService _storageService;
//   final Map<String, AudioSourceInfo> _sourceCache = {};

//   AudioSourceManager(this._storageService);

//   /// Analyze and detect the best audio source for a song
//   Future<AudioSourceInfo> analyzeAudioSource(Song song) async {
//     final cacheKey = '${song.videoId}';

//     // Check cache first
//     if (_sourceCache.containsKey(cacheKey)) {
//       final cached = _sourceCache[cacheKey]!;
//       print('📦 Using cached source info for: ${song.title}');
//       return cached;
//     }

//     print('🔍 Analyzing audio source for: ${song.title}');

//     AudioSourceInfo sourceInfo;

//     // Check if song is saved locally first
//     final isSaved = await _storageService.isSongSaved(song, song.artists);
//     final savedSongs = await _storageService.getAllSavedSongs();
//     final savedSong = savedSongs.firstWhere(
//       (s) => s.title == song.title && s.artist == song.artists,
//     );

//     if (isSaved && savedSong != null && savedSong.localAudioPath != null) {
//       // Local file exists
//       sourceInfo = await _analyzeLocalFile(savedSong.localAudioPath!, song);
//     } else {
//       // Network source
//       sourceInfo = await _analyzeNetworkSource(song);
//     }

//     // Cache the result
//     _sourceCache[cacheKey] = sourceInfo;

//     print(
//       '✅ Source analysis complete: ${sourceInfo.type.name} - Available: ${sourceInfo.isAvailable}',
//     );
//     return sourceInfo;
//   }

//   /// Create the optimal audio source for a song
//   Future<OptimalAudioSource> createOptimalAudioSource(Song song) async {
//     final sourceInfo = await analyzeAudioSource(song);

//     if (!sourceInfo.isAvailable) {
//       throw Exception('No available audio source for: ${song.title}');
//     }

//     final mediaItem = _createMediaItem(song);
//     final audioSource = _createAudioSourceFromInfo(sourceInfo, mediaItem);

//     return OptimalAudioSource(
//       source: audioSource,
//       info: sourceInfo,
//       mediaItem: mediaItem,
//     );
//   }

//   /// Validate a list of saved songs for availability
//   Future<List<Song>> validateSavedSongs(List<Song> savedSongs) async {
//     print('🔍 Validating ${savedSongs.length} saved songs...');

//     final validSongs = <Song>[];
//     int validCount = 0;
//     int invalidCount = 0;

//     for (final song in savedSongs) {
//       try {
//         final sourceInfo = await analyzeAudioSource(song);

//         if (sourceInfo.isAvailable) {
//           validSongs.add(song);
//           validCount++;
//         } else {
//           print(
//             '⚠️ Invalid saved song: ${song.title} - ${sourceInfo.type.name}',
//           );
//           invalidCount++;
//         }
//       } catch (e) {
//         print('❌ Error validating ${song.title}: $e');
//         invalidCount++;
//       }
//     }

//     print('✅ Validation complete: $validCount valid, $invalidCount invalid');
//     return validSongs;
//   }

//   // ==================== PRIVATE ANALYSIS METHODS ====================

//   Future<AudioSourceInfo> _analyzeLocalFile(String audioPath, Song song) async {
//     print('📁 Analyzing local file: $audioPath');

//     try {
//       // Handle different path formats
//       final normalizedPath = _normalizePath(audioPath);
//       final file = File(normalizedPath);

//       if (!await file.exists()) {
//         print('❌ Local file not found: $normalizedPath');

//         // Try fallback to network if available
//         if (song.audioUrl != null && song.audioUrl!.startsWith('http')) {
//           print('🔄 Falling back to network source');
//           return await _analyzeNetworkSource(song);
//         }

//         return AudioSourceInfo(
//           type: AudioSourceType.UNAVAILABLE,
//           actualPath: normalizedPath,
//           isAvailable: false,
//         );
//       }

//       // Check file size and validity
//       final fileStat = await file.stat();
//       if (fileStat.size < 1024) {
//         // Less than 1KB is suspicious
//         print('⚠️ Local file too small: ${fileStat.size} bytes');

//         // Try fallback to network
//         if (song.audioUrl != null && song.audioUrl!.startsWith('http')) {
//           return await _analyzeNetworkSource(song);
//         }

//         return AudioSourceInfo(
//           type: AudioSourceType.UNAVAILABLE,
//           actualPath: normalizedPath,
//           isAvailable: false,
//         );
//       }

//       print('✅ Valid local file found: ${fileStat.size} bytes');

//       return AudioSourceInfo(
//         type: AudioSourceType.LOCAL_FILE,
//         actualPath: normalizedPath,
//         isAvailable: true,
//         estimatedLoadTime: Duration(
//           milliseconds: 100,
//         ), // Local files load quickly
//         fallbackUrl: song.audioUrl,
//       );
//     } catch (e) {
//       print('❌ Error analyzing local file: $e');

//       // Fallback to network if error with local file
//       if (song.audioUrl != null && song.audioUrl!.startsWith('http')) {
//         return await _analyzeNetworkSource(song);
//       }

//       return AudioSourceInfo(
//         type: AudioSourceType.UNAVAILABLE,
//         actualPath: audioPath,
//         isAvailable: false,
//       );
//     }
//   }

//   Future<AudioSourceInfo> _analyzeNetworkSource(Song song) async {
//     if (song.audioUrl == null || song.audioUrl!.isEmpty) {
//       return AudioSourceInfo(
//         type: AudioSourceType.UNAVAILABLE,
//         actualPath: '',
//         isAvailable: false,
//       );
//     }

//     print('🌐 Analyzing network source: ${song.audioUrl}');

//     // Validate URL format
//     if (!_isValidNetworkUrl(song.audioUrl!)) {
//       print('❌ Invalid network URL format');
//       return AudioSourceInfo(
//         type: AudioSourceType.UNAVAILABLE,
//         actualPath: song.audioUrl!,
//         isAvailable: false,
//       );
//     }

//     // For network sources, we assume availability (will be validated during playback)
//     return AudioSourceInfo(
//       type: AudioSourceType.NETWORK_STREAM,
//       actualPath: song.audioUrl!,
//       isAvailable: true,
//       estimatedLoadTime: Duration(seconds: 3), // Network sources take longer
//     );
//   }

//   // ==================== AUDIO SOURCE CREATION ====================

//   AudioSource _createAudioSourceFromInfo(
//     AudioSourceInfo info,
//     MediaItem mediaItem,
//   ) {
//     switch (info.type) {
//       case AudioSourceType.LOCAL_FILE:
//         return _createLocalAudioSource(info.actualPath, mediaItem);

//       case AudioSourceType.NETWORK_STREAM:
//         return _createNetworkAudioSource(info.actualPath, mediaItem);

//       case AudioSourceType.CACHED_FILE:
//         return _createLocalAudioSource(info.actualPath, mediaItem);

//       case AudioSourceType.UNAVAILABLE:
//         throw Exception('Cannot create audio source for unavailable source');
//     }
//   }

//   AudioSource _createLocalAudioSource(String path, MediaItem mediaItem) {
//     print('📁 Creating local audio source: $path');

//     // Ensure proper file:// URI format
//     final uri = path.startsWith('file://') ? Uri.parse(path) : Uri.file(path);

//     return AudioSource.uri(uri, tag: mediaItem);
//   }

//   AudioSource _createNetworkAudioSource(String url, MediaItem mediaItem) {
//     print('🌐 Creating network audio source: $url');

//     return AudioSource.uri(Uri.parse(url), tag: mediaItem);
//   }

//   MediaItem _createMediaItem(Song song) {
//     return MediaItem(
//       id: song.videoId ?? song.audioUrl ?? song.title,
//       title: song.title,
//       artist: song.artists,
//       artUri: _parseArtUri(song.albumArt),
//     );
//   }

//   // ==================== UTILITY METHODS ====================

//   String _normalizePath(String path) {
//     // Remove file:// prefix if present
//     if (path.startsWith('file://')) {
//       path = path.substring(7);
//     }

//     // Ensure absolute path
//     if (!path.startsWith('/')) {
//       // This might need adjustment based on your app's storage structure
//       path = '/storage/emulated/0/$path';
//     }

//     return path;
//   }

//   bool _isValidNetworkUrl(String url) {
//     try {
//       final uri = Uri.parse(url);
//       return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
//     } catch (e) {
//       return false;
//     }
//   }

//   Uri? _parseArtUri(String? albumArt) {
//     if (albumArt == null || albumArt.isEmpty) return null;

//     try {
//       if (albumArt.startsWith('http://') || albumArt.startsWith('https://')) {
//         return Uri.parse(albumArt);
//       }

//       if (albumArt.startsWith('/') || albumArt.startsWith('file://')) {
//         final cleanPath = albumArt.startsWith('file://')
//             ? albumArt.substring(7)
//             : albumArt;
//         return Uri.file(cleanPath);
//       }

//       return null;
//     } catch (e) {
//       print('❌ Error parsing album art URI: $e');
//       return null;
//     }
//   }

//   bool isLocalFile(String audioUrl) {
//     return audioUrl.startsWith('file://') ||
//         audioUrl.startsWith('/') ||
//         !audioUrl.startsWith('http');
//   }

//   Future<bool> validateLocalFile(String path) async {
//     try {
//       final normalizedPath = _normalizePath(path);
//       final file = File(normalizedPath);

//       if (!await file.exists()) return false;

//       final stat = await file.stat();
//       return stat.size > 1024; // Must be larger than 1KB
//     } catch (e) {
//       print('❌ Error validating local file: $e');
//       return false;
//     }
//   }

//   // ==================== CACHE MANAGEMENT ====================

//   void clearCache() {
//     _sourceCache.clear();
//     print('🧹 Audio source cache cleared');
//   }

//   void removeCacheEntry(Song song) {
//     final cacheKey = '${song.videoId ?? song.audioUrl}';
//     _sourceCache.remove(cacheKey);
//     print('🗑️ Removed cache entry for: ${song.title}');
//   }

//   void updateCacheEntry(Song song, AudioSourceInfo info) {
//     final cacheKey = '${song.videoId ?? song.audioUrl}';
//     _sourceCache[cacheKey] = info;
//     print('📝 Updated cache entry for: ${song.title}');
//   }

//   // ==================== DIAGNOSTICS ====================

//   Map<String, dynamic> getDiagnostics() {
//     return {
//       'cacheSize': _sourceCache.length,
//       'cacheEntries': _sourceCache.keys.toList(),
//     };
//   }

//   void printDiagnostics() {
//     print('🔍 === AUDIO SOURCE MANAGER DIAGNOSTICS ===');
//     print('   Cache entries: ${_sourceCache.length}');
//     print('   Cached sources:');

//     _sourceCache.forEach((key, info) {
//       print(
//         '     - $key: ${info.type.name} (${info.isAvailable ? 'Available' : 'Unavailable'})',
//       );
//     });

//     print('==========================================');
//   }

//   void dispose() {
//     clearCache();
//   }
// }
