// import 'dart:io';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as path;

// // Download progress callback
// typedef ProgressCallback = void Function(double progress);

// class ApkUpdater {
//   static const MethodChannel _channel = MethodChannel('apk_installer');

//   /// Downloads APK file and returns the local path
//   Future<String> downloadApk({
//     required String downloadUrl,
//     ProgressCallback? onProgress,
//   }) async {
//     try {
//       print('Starting download from: $downloadUrl');

//       // Create a client for the download
//       final client = http.Client();
//       final request = http.Request('GET', Uri.parse(downloadUrl));
//       final response = await client.send(request);

//       if (response.statusCode != 200) {
//         throw Exception('Failed to download APK: HTTP ${response.statusCode}');
//       }

//       // Get the downloads directory
//       final directory = await getExternalStorageDirectory();
//       if (directory == null) {
//         throw Exception('Could not access external storage');
//       }

//       // Create downloads folder if it doesn't exist
//       final downloadsDir = Directory(path.join(directory.path, 'downloads'));
//       if (!await downloadsDir.exists()) {
//         await downloadsDir.create(recursive: true);
//       }

//       // Create the APK file
//       final apkFile = File(path.join(downloadsDir.path, 'houston_update.apk'));

//       // Delete existing file if it exists
//       if (await apkFile.exists()) {
//         await apkFile.delete();
//       }

//       // Download with progress tracking
//       final contentLength = response.contentLength ?? 0;
//       var downloadedBytes = 0;

//       final sink = apkFile.openWrite();

//       await for (final chunk in response.stream) {
//         sink.add(chunk);
//         downloadedBytes += chunk.length;

//         if (onProgress != null && contentLength > 0) {
//           final progress = downloadedBytes / contentLength;
//           onProgress(progress);
//         }
//       }

//       await sink.close();
//       client.close();

//       print('Download completed: ${apkFile.path}');
//       return apkFile.path;
//     } catch (e) {
//       print('Download error: $e');
//       throw Exception('Download failed: $e');
//     }
//   }

//   /// Installs the APK using the native Android method
//   Future<void> installApk(String apkPath) async {
//     try {
//       print('Installing APK: $apkPath');

//       final result = await _channel.invokeMethod('installApk', {
//         'apkPath': apkPath,
//       });

//       print('Installation result: $result');
//     } on PlatformException catch (e) {
//       print('Platform exception during installation: ${e.code} - ${e.message}');
//       throw Exception('Installation failed: ${e.message}');
//     } catch (e) {
//       print('General error during installation: $e');
//       throw Exception('Installation failed: $e');
//     }
//   }

//   /// Opens the app settings for unknown sources
//   Future<void> openAppSettings() async {
//     try {
//       await _channel.invokeMethod('openAppSettings');
//     } on PlatformException catch (e) {
//       print('Error opening app settings: ${e.code} - ${e.message}');
//       throw Exception('Could not open app settings: ${e.message}');
//     }
//   }

//   /// Gets current app version info
//   Future<Map<String, dynamic>> getAppInfo() async {
//     try {
//       final result = await _channel.invokeMethod('getAppInfo');
//       return Map<String, dynamic>.from(result);
//     } on PlatformException catch (e) {
//       print('Error getting app info: ${e.code} - ${e.message}');
//       throw Exception('Could not get app info: ${e.message}');
//     }
//   }

//   /// Checks if app can install packages
//   Future<bool> canInstallPackages() async {
//     try {
//       // This will be handled by the MainActivity
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Cleanup method
//   void dispose() {
//     // Any cleanup if needed
//   }
// }
