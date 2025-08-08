// services/download_manager.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/models/song.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

final downloadStateProvider =
    StateNotifierProvider<DownloadStateNotifier, Map<String, DownloadState>>((
      ref,
    ) {
      return DownloadStateNotifier();
    });

class DownloadStateNotifier extends StateNotifier<Map<String, DownloadState>> {
  DownloadStateNotifier() : super({});

  void startDownload(String songKey) {
    state = {...state, songKey: DownloadState.downloading(0)};
  }

  void updateProgress(String songKey, double progress) {
    state = {...state, songKey: DownloadState.downloading(progress)};
  }

  void completeDownload(String songKey) {
    state = {...state, songKey: DownloadState.completed()};
  }

  void failDownload(String songKey) {
    state = {...state, songKey: DownloadState.failed()};
  }

  void removeDownload(String songKey) {
    state = {...state..remove(songKey)};
  }
}

class DownloadState {
  final bool isDownloading;
  final bool isCompleted;
  final bool isFailed;
  final double progress;

  const DownloadState._({
    this.isDownloading = false,
    this.isCompleted = false,
    this.isFailed = false,
    this.progress = 0,
  });

  factory DownloadState.downloading(double progress) =>
      DownloadState._(isDownloading: true, progress: progress);

  factory DownloadState.completed() => DownloadState._(isCompleted: true);
  factory DownloadState.failed() => DownloadState._(isFailed: true);

  @override
  String toString() {
    if (isDownloading) {
      return 'Downloading ${(progress * 100).toStringAsFixed(1)}%';
    }
    if (isCompleted) return 'Completed';
    if (isFailed) return 'Failed';
    return 'Not downloading';
  }
}

class DownloadManager {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  final Map<String, double> _downloadProgress = {};

  double? getDownloadProgress(String key) => _downloadProgress[key];

  Future<String?> downloadAudio(Song song) async {
    if (song.audioUrl == null || song.audioUrl!.isEmpty) {
      print('❌ Audio URL is null or empty for song: ${song.title}');
      return null;
    }

    final key = '${song.title}|${song.artists}';
    _downloadProgress[key] = 0;

    try {
      print('🎵 Starting audio download for: ${song.title}');

      // Sanitize the filename to remove invalid characters
      final sanitizedTitle = _sanitizeFileName(song.title);
      final fileName = '${sanitizedTitle}_audio.mp3';

      final path = await _downloadFile(song.audioUrl!, fileName, 'audio', (
        received,
        total,
      ) {
        _downloadProgress[key] = received / total;
      });

      _downloadProgress.remove(key);

      if (path != null) {
        print('✅ Audio download completed: $path');

        // Verify file exists and has content
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          print('✅ Audio file verified: ${await file.length()} bytes');
          return path;
        } else {
          print('❌ Audio file verification failed');
          return null;
        }
      }

      return path;
    } catch (e) {
      print('❌ Audio download failed for ${song.title}: $e');
      _downloadProgress.remove(key);
      rethrow;
    }
  }

  Future<String?> downloadAlbumArt(Song song) async {
    if (song.albumArt == null || song.albumArt!.isEmpty) {
      print('❌ Album art URL is null or empty for song: ${song.title}');
      return null;
    }

    try {
      print('🎨 Starting album art download for: ${song.title}');
      print('🎨 Album art URL: ${song.albumArt}');

      // Sanitize the filename to remove invalid characters
      final sanitizedTitle = _sanitizeFileName(song.title);
      final fileName = '${sanitizedTitle}_art.jpg';

      final path = await _downloadFile(
        song.albumArt!,
        fileName,
        'images',
        null, // No progress callback for album art
      );

      if (path != null) {
        // Verify file exists and has content
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          print(
            '✅ Album art download completed: $path (${await file.length()} bytes)',
          );
          return path;
        } else {
          print('❌ Album art file verification failed');
          // Clean up empty file
          try {
            await file.delete();
          } catch (e) {
            print('⚠️ Could not delete empty album art file: $e');
          }
          return null;
        }
      }

      return null;
    } catch (e) {
      print('❌ Album art download failed for ${song.title}: $e');
      return null;
    }
  }

  Future<Directory> getApplicationDownloadsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/downloads');
  }

  Future<String?> _downloadFile(
    String url,
    String fileName,
    String subFolder,
    void Function(int received, int total)? onProgress,
  ) async {
    try {
      // Validate URL
      if (!_isValidUrl(url)) {
        print('❌ Invalid URL: $url');
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/downloads/$subFolder');

      // Create directory if it doesn't exist
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
        print('📁 Created directory: ${downloadDir.path}');
      }

      final filePath = '${downloadDir.path}/$fileName';
      final file = File(filePath);

      // Check if file already exists and is valid
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 0) {
          print('✅ File already exists: $filePath (${fileSize} bytes)');
          return filePath;
        } else {
          // Delete empty file
          await file.delete();
        }
      }

      print('⬇️ Downloading: $url');
      print('📁 To: $filePath');

      // Download file with retry logic
      await _downloadWithRetry(url, filePath, onProgress);

      // Verify download
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 0) {
          print('✅ Download successful: $filePath (${fileSize} bytes)');
          return filePath;
        } else {
          print('❌ Downloaded file is empty');
          await file.delete();
          return null;
        }
      } else {
        print('❌ Downloaded file does not exist');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading file: $e');
      return null;
    }
  }

  Future<void> _downloadWithRetry(
    String url,
    String filePath,
    void Function(int received, int total)? onProgress, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        attempts++;
        print('🔄 Download attempt $attempts/$maxRetries');

        final response = await _dio.download(
          url,
          filePath,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            validateStatus: (status) => status != null && status < 400,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          ),
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = received / total;
              print('📊 Progress: ${(progress * 100).toStringAsFixed(1)}%');
              onProgress?.call(received, total);
            }
          },
        );

        if (response.statusCode == 200) {
          print('✅ Download completed successfully');
          return;
        } else {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            message: 'HTTP ${response.statusCode}',
          );
        }
      } catch (e) {
        print('❌ Download attempt $attempts failed: $e');

        if (attempts >= maxRetries) {
          rethrow;
        }

        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
  }

  String _sanitizeFileName(String fileName) {
    // Remove invalid characters and limit length
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Remove invalid chars
        .replaceAll(
          RegExp(r'[^\w\s-.]'),
          '',
        ) // Keep only word chars, spaces, hyphens, dots
        .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscores
        .toLowerCase()
        .substring(
          0,
          fileName.length > 50 ? 50 : fileName.length,
        ) // Limit length
        .trim();
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // Method to clean up failed downloads
  Future<void> cleanupFailedDownloads() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/downloads');

      if (await downloadDir.exists()) {
        await for (final entity in downloadDir.list(recursive: true)) {
          if (entity is File) {
            final fileSize = await entity.length();
            if (fileSize == 0) {
              print('🧹 Cleaning up empty file: ${entity.path}');
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error cleaning up failed downloads: $e');
    }
  }

  // Method to get total download size
  Future<int> getTotalDownloadSize() async {
    int totalSize = 0;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/downloads');

      if (await downloadDir.exists()) {
        await for (final entity in downloadDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      print('❌ Error calculating download size: $e');
    }
    return totalSize;
  }

  // Method to clear all downloads
  Future<void> clearAllDownloads() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/downloads');

      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
        print('🧹 All downloads cleared');
      }
    } catch (e) {
      print('❌ Error clearing downloads: $e');
    }
  }
}
