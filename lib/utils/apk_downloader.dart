import 'package:flutter/services.dart';

class HoustonInstaller {
  static const MethodChannel _channel = MethodChannel('apk_installer');

  /// Install the APK from given [apkPath]
  static Future<void> installApk(String apkPath) async {
    try {
      await _channel.invokeMethod('installApk', {'apkPath': apkPath});
    } on PlatformException catch (e) {
      throw Exception("Install failed: ${e.message}");
    }
  }

  /// Returns whether unknown sources install permission is granted
  static Future<bool> canInstallPackages() async {
    try {
      final bool granted = await _channel.invokeMethod('canInstallPackages');
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Opens the settings to allow unknown sources install
  static Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      throw Exception("Failed to open settings: $e");
    }
  }

  /// Fetches app info like appName, version, etc.
  static Future<AppInfo> getAppInfo() async {
    try {
      final data = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getAppInfo',
      );
      return AppInfo.fromMap(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      throw Exception("Failed to get app info: $e");
    }
  }
}

class AppInfo {
  final String appName;
  final String packageName;
  final String versionName;
  final int versionCode;
  final int targetSdkVersion;

  AppInfo({
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.targetSdkVersion,
  });

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      appName: map['appName'] ?? 'Unknown',
      packageName: map['packageName'] ?? '',
      versionName: map['versionName'] ?? '0.0.0',
      versionCode: map['versionCode'] ?? 0,
      targetSdkVersion: map['targetSdkVersion'] ?? 0,
    );
  }

  @override
  String toString() {
    return '$appName $versionName ($versionCode)';
  }
}
