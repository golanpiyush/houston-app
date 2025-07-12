// providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';
import '../models/settings.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier()
    : super(
        AppSettings(
          themeMode: 'material',
          audioQuality: AudioQuality.high.value, // "HIGH"
          thumbnailQuality: ThumbnailQuality.veryHigh.value, // "VERY_HIGH"
          limit: 12,
          downloadMode: false, // Add default download mode
        ),
      ) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedLimit = prefs.getInt('limit') ?? 6;
    final validatedLimit = loadedLimit.clamp(2, 12);

    state = AppSettings(
      themeMode: prefs.getString('theme_mode') ?? 'material',
      audioQuality: prefs.getString('audio_quality') ?? AudioQuality.high.value,
      thumbnailQuality:
          prefs.getString('thumbnail_quality') ??
          ThumbnailQuality.veryHigh.value,
      limit: validatedLimit,
      downloadMode:
          prefs.getBool('download_mode') ?? false, // Load download mode
    );
  }

  Future<void> updateTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', theme);
    state = state.copyWith(themeMode: theme);
  }

  Future<void> updateAudioQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_quality', quality);
    state = state.copyWith(audioQuality: quality);
  }

  Future<void> updateThumbnailQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('thumbnail_quality', quality);
    state = state.copyWith(thumbnailQuality: quality);
  }

  Future<void> updateLimit(int limit) async {
    final validatedLimit = limit.clamp(2, 12);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('limit', validatedLimit);
    state = state.copyWith(limit: validatedLimit);
  }

  Future<void> toggleDownloadMode() async {
    final newValue = !state.downloadMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_mode', newValue);
    state = state.copyWith(downloadMode: newValue);
  }
}
