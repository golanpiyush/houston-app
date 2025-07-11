// models/song.dart
class Song {
  final String title;
  final String artists;
  final String? duration;
  final String? year;
  final String videoId;
  final String? albumArt;
  final String? audioUrl;
  final bool? isOriginal;

  Song({
    required this.title,
    required this.artists,
    this.duration,
    this.year,
    required this.videoId,
    this.albumArt,
    this.audioUrl,
    this.isOriginal,
  });
}
