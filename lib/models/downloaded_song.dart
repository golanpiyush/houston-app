// models/downloaded_song.dart

import 'package:houston/models/song.dart';

class DownloadedSong {
  final String title;
  final String? artist;
  final String? albumArtUrl;
  final String? localAlbumArtPath;
  final String? audioUrl;
  final String? localAudioPath;
  final DateTime? dateSaved;
  final bool isFullyDownloaded;

  DownloadedSong({
    required this.title,
    this.artist,
    this.albumArtUrl,
    this.localAlbumArtPath,
    this.audioUrl,
    this.localAudioPath,
    this.dateSaved,
  }) : isFullyDownloaded = localAlbumArtPath != null && localAudioPath != null;

  factory DownloadedSong.fromSong(
    Song song, {
    String? audioPath,
    String? artPath,
  }) {
    return DownloadedSong(
      title: song.title,
      artist: song.artists,
      albumArtUrl: song.albumArt,
      localAlbumArtPath: artPath,
      audioUrl: song.audioUrl,
      localAudioPath: audioPath,
      dateSaved: DateTime.now(),
    );
  }
}
