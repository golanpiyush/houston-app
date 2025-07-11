// models/settings.dart
class AppSettings {
  final String themeMode;
  final String audioQuality;
  final int limit;
  final String thumbnailQuality; // <-- add this

  AppSettings({
    required this.themeMode,
    required this.audioQuality,
    required this.limit,
    required this.thumbnailQuality, // <-- add this
  });

  AppSettings copyWith({
    String? themeMode,
    String? thumbnailQuality,
    String? audioQuality,
    int? limit,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      thumbnailQuality: thumbnailQuality ?? this.thumbnailQuality,

      audioQuality: audioQuality ?? this.audioQuality,
      limit: limit ?? this.limit,
    );
  }
}
