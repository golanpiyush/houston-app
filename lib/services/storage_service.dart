// services/storage_service.dart
import 'package:houston/models/downloaded_song.dart';
import 'package:houston/models/song.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _savedSongsKey = 'saved_songs';

  // This method returns DownloadedSong objects
  Future<List<DownloadedSong>> getAllSavedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsList = prefs.getStringList(_savedSongsKey) ?? [];
      return songsList
          .map((s) => _deserializeSong(s))
          .where((song) => song != null)
          .cast<DownloadedSong>()
          .toList();
    } catch (e) {
      print('Error loading saved songs: $e');
      return [];
    }
  }

  // Updated saveSong method - now works with DownloadedSong objects
  Future<void> saveSong({
    required String title,
    required String artist,
    required String audioUrl,
    required String audioPath,
    String? albumArtUrl,
    String? albumArtPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSongs = await getAllSavedSongs(); // Use getAllSavedSongs instead

    // Create a DownloadedSong object
    final newSong = DownloadedSong(
      title: title,
      artist: artist,
      audioUrl: audioUrl,
      localAudioPath: audioPath,
      albumArtUrl: albumArtUrl,
      localAlbumArtPath: albumArtPath,
      dateSaved: DateTime.now(),
    );

    savedSongs.add(newSong);

    await prefs.setStringList(
      _savedSongsKey,
      savedSongs.map((s) => _serializeSong(s)).toList(),
    );
  }

  Future<bool> isSongSaved(Song song) async {
    final saved = await getAllSavedSongs(); // Use getAllSavedSongs instead
    return saved.any((s) => s.title == song.title && s.artist == song.artists);
  }

  Future<void> removeSong(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSongs = await getAllSavedSongs(); // Use getAllSavedSongs instead
    savedSongs.removeWhere(
      (s) => s.title == song.title && s.artist == song.artists,
    );
    await prefs.setStringList(
      _savedSongsKey,
      savedSongs.map((s) => _serializeSong(s)).toList(),
    );
  }

  // Private helper method for serialization
  String _serializeSong(DownloadedSong song) {
    return [
      song.title,
      song.artist ?? '',
      song.albumArtUrl ?? '',
      song.localAlbumArtPath ?? '',
      song.audioUrl ?? '',
      song.localAudioPath ?? '',
      song.dateSaved?.millisecondsSinceEpoch.toString() ?? '',
    ].join('|');
  }

  // Private helper method for deserialization
  DownloadedSong? _deserializeSong(String serialized) {
    try {
      final parts = serialized.split('|');
      if (parts.length < 7) {
        print('Invalid song format: $serialized');
        return null;
      }

      return DownloadedSong(
        title: parts[0],
        artist: parts[1].isEmpty ? null : parts[1],
        albumArtUrl: parts[2].isEmpty ? null : parts[2],
        localAlbumArtPath: parts[3].isEmpty ? null : parts[3],
        audioUrl: parts[4].isEmpty ? null : parts[4],
        localAudioPath: parts[5].isEmpty ? null : parts[5],
        dateSaved: parts[6].isEmpty
            ? null
            : DateTime.fromMillisecondsSinceEpoch(int.parse(parts[6])),
      );
    } catch (e) {
      print('Error deserializing song: $e');
      return null;
    }
  }
}
