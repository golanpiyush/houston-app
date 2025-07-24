// models/media_track.dart

import 'package:houston/models/song.dart';

class MediaTrack {
  final String id;
  final String title;
  final String artists;
  final String? album;
  final String? albumArt;
  final String? audioUrl;
  final String? videoId;
  final Duration? duration;
  final bool isLocal;
  final Map<String, dynamic>? metadata;

  MediaTrack({
    required this.id,
    required this.title,
    required this.artists,
    this.album,
    this.albumArt,
    this.audioUrl,
    this.videoId,
    this.duration,
    this.isLocal = false,
    this.metadata,
  });

  // Create MediaTrack from Song model
  factory MediaTrack.fromSong(Song song) {
    Duration? parsedDuration;
    if (song.duration != null) {
      // Parse duration string (e.g., "3:45" or "245" seconds)
      try {
        if (song.duration!.contains(':')) {
          final parts = song.duration!.split(':');
          final minutes = int.parse(parts[0]);
          final seconds = int.parse(parts[1]);
          parsedDuration = Duration(minutes: minutes, seconds: seconds);
        } else {
          parsedDuration = Duration(seconds: int.parse(song.duration!));
        }
      } catch (e) {
        parsedDuration = null;
      }
    }

    return MediaTrack(
      id: song.videoId,
      title: song.title,
      artists: song.artists,
      albumArt: song.albumArt,
      audioUrl: song.audioUrl,
      videoId: song.videoId,
      duration: parsedDuration,
      isLocal: false,
      metadata: {'year': song.year, 'isOriginal': song.isOriginal},
    );
  }

  // Create MediaTrack for local files
  factory MediaTrack.local({
    required String filePath,
    required String title,
    String? artist,
    String? album,
    String? albumArt,
    Duration? duration,
  }) {
    return MediaTrack(
      id: filePath.hashCode.toString(),
      title: title,
      artists: artist ?? 'Unknown Artist',
      album: album,
      albumArt: albumArt,
      audioUrl: filePath,
      isLocal: true,
      duration: duration,
    );
  }

  MediaTrack copyWith({
    String? id,
    String? title,
    String? artists,
    String? album,
    String? albumArt,
    String? audioUrl,
    String? videoId,
    Duration? duration,
    bool? isLocal,
    Map<String, dynamic>? metadata,
  }) {
    return MediaTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      audioUrl: audioUrl ?? this.audioUrl,
      videoId: videoId ?? this.videoId,
      duration: duration ?? this.duration,
      isLocal: isLocal ?? this.isLocal,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artists': artists,
      'album': album,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
      'videoId': videoId,
      'duration': duration?.inSeconds,
      'isLocal': isLocal,
      'metadata': metadata,
    };
  }

  factory MediaTrack.fromJson(Map<String, dynamic> json) {
    return MediaTrack(
      id: json['id'],
      title: json['title'],
      artists: json['artists'],
      album: json['album'],
      albumArt: json['albumArt'],
      audioUrl: json['audioUrl'],
      videoId: json['videoId'],
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'])
          : null,
      isLocal: json['isLocal'] ?? false,
      metadata: json['metadata'],
    );
  }

  @override
  String toString() {
    return 'MediaTrack(id: $id, title: $title, artists: $artists, isLocal: $isLocal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaTrack && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
