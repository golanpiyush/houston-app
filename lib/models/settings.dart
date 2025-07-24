import 'package:houston/providers/lyrics_provider.dart';

class AppSettings {
  final String themeMode;
  final String audioQuality;
  final String thumbnailQuality;
  final int limit;
  final bool downloadMode;
  final bool wordByWordLyrics;
  final String lyricsFont;
  final LyricsSource lyricsProvider;

  AppSettings({
    required this.themeMode,
    required this.audioQuality,
    required this.thumbnailQuality,
    required this.limit,
    required this.downloadMode,
    required this.wordByWordLyrics,
    required this.lyricsFont,
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
      lyricsProvider: lyricsProvider ?? this.lyricsProvider,
    );
  }
}
