import 'package:houston/providers/lyrics_provider.dart';

class AppSettings {
  final String themeMode;
  final bool breathingAnimation; // Add this line

  final String audioQuality;
  final String thumbnailQuality;
  final int limit;
  final bool downloadMode;
  final bool wordByWordLyrics;
  final String lyricsFont;
  final String appFont;
  final LyricsSource lyricsProvider;

  AppSettings({
    required this.themeMode,
    required this.audioQuality,
    required this.thumbnailQuality,
    required this.limit,
    required this.downloadMode,
    this.breathingAnimation = false, // Add this with default value

    required this.wordByWordLyrics,
    required this.lyricsFont,
    required this.appFont,
    required this.lyricsProvider,
  });

  AppSettings copyWith({
    String? themeMode,
    String? audioQuality,
    String? thumbnailQuality,
    int? limit,
    bool? downloadMode,
    bool? wordByWordLyrics,
    String? lyricsFont,
    String? appFont,
    bool? breathingAnimation,
    LyricsSource? lyricsProvider,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      audioQuality: audioQuality ?? this.audioQuality,
      thumbnailQuality: thumbnailQuality ?? this.thumbnailQuality,
      limit: limit ?? this.limit,
      downloadMode: downloadMode ?? this.downloadMode,
      wordByWordLyrics: wordByWordLyrics ?? this.wordByWordLyrics,
      lyricsFont: lyricsFont ?? this.lyricsFont,
      breathingAnimation: breathingAnimation ?? this.breathingAnimation,

      appFont: appFont ?? this.appFont, // Add this
      lyricsProvider: lyricsProvider ?? this.lyricsProvider,
    );
  }
}
