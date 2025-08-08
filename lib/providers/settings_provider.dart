import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/providers/lyrics_provider.dart';
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
          audioQuality: AudioQuality.high.value,
          thumbnailQuality: ThumbnailQuality.veryHigh.value,
          limit: 12,
          breathingAnimation: false, // Add this with default value

          downloadMode: false,
          wordByWordLyrics: true,
          lyricsFont: 'Poppins',
          appFont: 'Poppins', // Add this line
          lyricsProvider: LyricsSource.kugou,
        ),
      ) {
    _loadSettings();
  }

  static const List<String> availableFonts = [
    'Poppins',
    'Roboto',
    'Open Sans',
    'Barlow',
    'Montserrat',
    'Lato',
    'Nunito',
    'Inter',
    'Raleway',
    'Playfair Display',
    'Luckiest Guy',
    'Oswald',
    'Merriweather',
    'Ubuntu',
    'Fira Sans',
    'Crimson Text',
    'Libre Baskerville',
    'PT Sans',
    'Quicksand',
    'Caveat',
    'Dancing Script',
    'Comfortaa',
    'Pacifico',
    'Satisfy',
    'Great Vibes',
  ];

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    state = AppSettings(
      themeMode: prefs.getString('theme_mode') ?? 'material',
      audioQuality: prefs.getString('audio_quality') ?? AudioQuality.high.value,
      thumbnailQuality:
          prefs.getString('thumbnail_quality') ??
          ThumbnailQuality.veryHigh.value,
      breathingAnimation:
          prefs.getBool('breathing_animation') ?? false, // Add this

      limit: (prefs.getInt('limit') ?? 6).clamp(2, 12),
      downloadMode: prefs.getBool('download_mode') ?? false,
      wordByWordLyrics: prefs.getBool('word_by_word_lyrics') ?? true,
      lyricsFont: prefs.getString('lyrics_font') ?? 'Poppins',
      appFont: prefs.getString('app_font') ?? 'Poppins', // Add this line
      lyricsProvider: LyricsSource.values[prefs.getInt('lyrics_provider') ?? 0],
    );
  }

  Future<void> debugPrintCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    print(
      'DEBUG_SETTINGS: Current stored lyrics_provider index: ${prefs.getInt('lyrics_provider')}',
    );
    print(
      'DEBUG_SETTINGS: Current state lyricsProvider: ${state.lyricsProvider}',
    );
    print('DEBUG_SETTINGS: Available sources: ${LyricsSource.values}');
    print(
      'DEBUG_SETTINGS: State lyricsProvider index: ${state.lyricsProvider.index}',
    );
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', state.themeMode);
    await prefs.setString('audio_quality', state.audioQuality);
    await prefs.setString('thumbnail_quality', state.thumbnailQuality);
    await prefs.setInt('limit', state.limit);
    await prefs.setBool('download_mode', state.downloadMode);
    await prefs.setBool('word_by_word_lyrics', state.wordByWordLyrics);
    await prefs.setString('lyrics_font', state.lyricsFont);
    await prefs.setString('app_font', state.appFont); // Add this line
    await prefs.setInt('lyrics_provider', state.lyricsProvider.index);
    await prefs.setBool(
      'breathing_animation',
      state.breathingAnimation,
    ); // Add this
  }

  Future<void> toggleBreathingAnimation() async {
    state = state.copyWith(breathingAnimation: !state.breathingAnimation);
    await saveSettings();
  }

  Future<void> updateLyricsFont(String font) async {
    state = state.copyWith(lyricsFont: font);
    await saveSettings();
  }

  Future<void> updateAppFont(String font) async {
    state = state.copyWith(appFont: font);
    await saveSettings();
  }

  Future<void> updateLyricsProvider(LyricsSource provider) async {
    print('SETTINGS_NOTIFIER: Updating lyrics provider to: $provider');
    state = state.copyWith(lyricsProvider: provider);
    await saveSettings();
  }

  Future<void> updateTheme(String theme) async {
    state = state.copyWith(themeMode: theme);
    await saveSettings();
  }

  Future<void> updateAudioQuality(String quality) async {
    state = state.copyWith(audioQuality: quality);
    await saveSettings();
  }

  Future<void> updateThumbnailQuality(String quality) async {
    state = state.copyWith(thumbnailQuality: quality);
    await saveSettings();
  }

  Future<void> updateLimit(int limit) async {
    state = state.copyWith(limit: limit.clamp(2, 12));
    await saveSettings();
  }

  Future<void> toggleDownloadMode() async {
    state = state.copyWith(downloadMode: !state.downloadMode);
    await saveSettings();
  }

  Future<void> toggleWordByWordLyrics() async {
    state = state.copyWith(wordByWordLyrics: !state.wordByWordLyrics);
    await saveSettings();
  }
}
