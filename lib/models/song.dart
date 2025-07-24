// models/ytmusic_models.dart
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';

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

  factory Song.fromSearchResult(SearchResult result) {
    return Song(
      title: result.title,
      artists: result.artists,
      duration: result.duration,
      year: result.year,
      videoId: result.videoId,
      albumArt: result.albumArt,
      audioUrl: result.audioUrl,
    );
  }

  factory Song.fromArtistSong(ArtistSong song) {
    return Song(
      title: song.title,
      artists: song.artists,
      duration: song.duration,
      videoId: song.videoId,
      albumArt: song.albumArt,
      audioUrl: song.audioUrl,
    );
  }

  factory Song.fromRelatedSong(RelatedSong song) {
    return Song(
      title: song.title,
      artists: song.artists,
      duration: song.duration,
      videoId: song.videoId,
      albumArt: song.albumArt,
      audioUrl: song.audioUrl,
      isOriginal: song.isOriginal,
    );
  }
}

class SystemStatus {
  final bool success;
  final String message;
  final bool ytmusicReady;
  final String ytmusicVersion;
  final bool ytdlpReady;
  final String ytdlpVersion;

  SystemStatus({
    required this.success,
    required this.message,
    required this.ytmusicReady,
    required this.ytmusicVersion,
    required this.ytdlpReady,
    required this.ytdlpVersion,
  });

  factory SystemStatus.fromMap(Map<String, dynamic> map) {
    return SystemStatus(
      success: map['success'] ?? false,
      message: map['message'] ?? 'Unknown',
      ytmusicReady: map['ytmusic_ready'] ?? false,
      ytmusicVersion: map['ytmusic_version'] ?? 'Unknown',
      ytdlpReady: map['ytdlp_ready'] ?? false,
      ytdlpVersion: map['ytdlp_version'] ?? 'Unknown',
    );
  }

  bool get isFullyOperational => ytmusicReady && ytdlpReady;

  String get statusSummary {
    if (isFullyOperational) {
      return 'All systems operational';
    } else if (ytmusicReady || ytdlpReady) {
      return 'Partial functionality available';
    } else {
      return 'System offline';
    }
  }
}
