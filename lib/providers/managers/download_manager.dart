// services/download_manager.dart
import 'package:dio/dio.dart';
import 'package:houston/models/song.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DownloadManager {
  final Dio _dio = Dio();

  Future<String?> downloadAudio(Song song) async {
    if (song.audioUrl == null) return null;
    return _downloadFile(song.audioUrl!, '${song.title}_audio.mp3');
  }

  Future<String?> downloadAlbumArt(Song song) async {
    if (song.albumArt == null) return null;

    try {
      // Sanitize the filename to remove invalid characters
      final sanitizedTitle = song.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      final fileName = '${sanitizedTitle}_art.jpg';

      // Get the downloads directory
      final directory = await getApplicationDownloadsDirectory();
      final filePath = '${directory.path}/$fileName';

      // Create directory if it doesn't exist
      await Directory(directory.path).create(recursive: true);

      // Download the file
      final response = await Dio().download(
        song.albumArt!,
        filePath,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print(
              'Download progress: ${(received / total * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      if (response.statusCode == 200) {
        return filePath;
      }
      return null;
    } catch (e) {
      print('Error downloading album art: $e');
      return null;
    }
  }

  Future<Directory> getApplicationDownloadsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/downloads');
  }

  Future<String?> _downloadFile(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/downloads/$fileName';
      final file = File(path);

      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);

      // Download file
      await _dio.download(
        url,
        path,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print('${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      return path;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }
}
