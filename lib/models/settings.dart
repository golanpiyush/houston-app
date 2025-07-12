// models/settings.dart
class AppSettings {
  final String themeMode;
  final String audioQuality;
  final int limit;
  final String thumbnailQuality;
  final bool downloadMode; // Add this field

  AppSettings({
    required this.themeMode,
    required this.audioQuality,
    required this.limit,
    required this.thumbnailQuality, // <-- add this
    required this.downloadMode, // Add to constructor
  });

  AppSettings copyWith({
    String? themeMode,
    String? thumbnailQuality,
    String? audioQuality,
    int? limit,
    bool? downloadMode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      thumbnailQuality: thumbnailQuality ?? this.thumbnailQuality,
      downloadMode: downloadMode ?? this.downloadMode,
      audioQuality: audioQuality ?? this.audioQuality,
      limit: limit ?? this.limit,
    );
  }
}
