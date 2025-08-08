import 'package:houston/models/song.dart';
import 'package:houston/services/storage_service.dart';

class AlbumArtService {
  final StorageService storageService;

  AlbumArtService(this.storageService);

  Future<String?> getAlbumArtPath(Map<String, dynamic> songData) async {
    final tempSong = Song(
      title: songData['title'] ?? 'Unknown Title',
      artists: songData['artist'] ?? 'Unknown Artist',
      albumArt: songData['albumart'] ?? songData['artwork'],
      videoId:
          songData['videoid'] ?? songData['videoId'] ?? songData['id'] ?? '',
      duration: songData['duration'],
    );

    final isDownloaded = await storageService.isSongSaved(tempSong);

    if (isDownloaded) {
      final savedSongs = await storageService.getAllSavedSongs();
      final downloadedSong = savedSongs.firstWhere(
        (s) => s.title == tempSong.title && s.artist == tempSong.artists,
      );

      return downloadedSong.localAlbumArtPath != null
          ? 'file://${downloadedSong.localAlbumArtPath}'
          : songData['albumart'] ?? songData['artwork'];
    }

    return songData['albumart'] ?? songData['artwork'];
  }
}
