// playlist_manager.dart
import 'dart:convert';
import 'dart:io';
import 'package:houston/providers/managers/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:houston/services/storage_service.dart';
import 'package:houston/models/song.dart';

class Playlist {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<Map<String, dynamic>> songs;
  final String? coverImage;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.songs,
    this.coverImage,
  });

  int get songCount => songs.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'songs': songs,
      'coverImage': coverImage,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      songs: List<Map<String, dynamic>>.from(json['songs'] ?? []),
      coverImage: json['coverImage'],
    );
  }

  Playlist copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<Map<String, dynamic>>? songs,
    String? coverImage,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      songs: songs ?? this.songs,
      coverImage: coverImage ?? this.coverImage,
    );
  }
}

class PlaylistManager {
  static const String _playlistsKey = 'user_playlists';
  static PlaylistManager? _instance;

  // Add dependencies
  final StorageService _storageService = StorageService();
  final DownloadManager _downloadManager = DownloadManager();

  // Singleton pattern
  factory PlaylistManager() {
    _instance ??= PlaylistManager._internal();
    return _instance!;
  }

  PlaylistManager._internal();

  // Get SharedPreferences instance
  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  // Generate unique ID for playlist
  String _generatePlaylistId() {
    return 'playlist_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Create a new playlist
  Future<Playlist> createPlaylist(String name) async {
    if (name.trim().isEmpty) {
      throw Exception('Playlist name cannot be empty');
    }

    final newPlaylist = Playlist(
      id: _generatePlaylistId(),
      name: name.trim(),
      createdAt: DateTime.now(),
      songs: [],
    );

    await _savePlaylist(newPlaylist);
    return newPlaylist;
  }

  // Get all playlists
  Future<List<Playlist>> getAllPlaylists() async {
    try {
      final prefs = await _prefs;
      final playlistsJson = prefs.getStringList(_playlistsKey) ?? [];

      return playlistsJson.map((jsonString) {
        final json = jsonDecode(jsonString);
        return Playlist.fromJson(json);
      }).toList()..sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      ); // Sort by newest first
    } catch (e) {
      throw Exception('Failed to load playlists: $e');
    }
  }

  // Get playlist by ID
  Future<Playlist?> getPlaylistById(String playlistId) async {
    final playlists = await getAllPlaylists();
    try {
      return playlists.firstWhere((playlist) => playlist.id == playlistId);
    } catch (e) {
      return null;
    }
  }

  // Save playlist to storage
  Future<void> _savePlaylist(Playlist playlist) async {
    try {
      final prefs = await _prefs;
      final playlists = await getAllPlaylists();

      // Remove existing playlist with same ID if it exists
      playlists.removeWhere((p) => p.id == playlist.id);

      // Add the new/updated playlist
      playlists.add(playlist);

      // Convert to JSON strings
      final playlistsJson = playlists
          .map((p) => jsonEncode(p.toJson()))
          .toList();

      // Save to SharedPreferences
      await prefs.setStringList(_playlistsKey, playlistsJson);
    } catch (e) {
      throw Exception('Failed to save playlist: $e');
    }
  }

  // Enhanced method to add song to playlist with storage integration
  Future<void> addSongToPlaylist(
    String playlistId,
    Song song, {
    Function(double)? onDownloadProgress,
    Function(String)? onStatusUpdate,
  }) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) {
      throw Exception('Playlist not found');
    }

    // Check if song already exists in playlist
    final songExists = playlist.songs.any((s) => s['id'] == song.videoId);
    if (songExists) {
      throw Exception('Song already exists in playlist');
    }

    onStatusUpdate?.call('Checking if song is downloaded...');

    // Check if song is already downloaded using StorageService
    final isAlreadyDownloaded = await _storageService.isSongSaved(song);

    String? localAudioPath;
    String? localAlbumArtPath;

    if (isAlreadyDownloaded) {
      onStatusUpdate?.call('Song already downloaded, using existing files...');

      // Get the downloaded song details from storage
      final savedSongs = await _storageService.getAllSavedSongs();
      final downloadedSong = savedSongs.firstWhere(
        (s) => s.title == song.title && s.artist == song.artists,
        orElse: () => throw Exception('Downloaded song not found in storage'),
      );

      localAudioPath = downloadedSong.localAudioPath;
      localAlbumArtPath = downloadedSong.localAlbumArtPath;
    } else {
      onStatusUpdate?.call('Song not downloaded, starting download...');

      try {
        // Download audio file
        onStatusUpdate?.call('Downloading audio...');
        localAudioPath = await _downloadManager.downloadAudio(song);

        // Download album art
        onStatusUpdate?.call('Downloading album art...');
        localAlbumArtPath = await _downloadManager.downloadAlbumArt(song);

        // Save to storage service
        onStatusUpdate?.call('Saving to storage...');
        await _storageService.saveSong(
          title: song.title,
          artist: song.artists,
          audioUrl: song.audioUrl ?? '',
          audioPath: localAudioPath ?? '',
          albumArtUrl: song.albumArt,
          albumArtPath: localAlbumArtPath,
        );

        onStatusUpdate?.call('Download completed successfully');
      } catch (e) {
        onStatusUpdate?.call('Download failed: $e');
        throw Exception('Failed to download song: $e');
      }
    }

    // Create song data for playlist (with local paths)
    final playlistSongData = <String, dynamic>{
      'id': song.videoId,
      'title': song.title,
      'videoid': song.videoId,
      'artist': song.artists,
      'albumart': song.albumArt, // Keep original URL for display
      'localAudioPath': localAudioPath, // Add local audio path
      'localAlbumArtPath': localAlbumArtPath, // Add local album art path
      'audioUrl': song.audioUrl, // Keep original URL as backup
      'isDownloaded': true, // Flag to indicate it's downloaded
      'addedAt': DateTime.now().toIso8601String(), // Track when added
      // Add duration if available
      if (song.duration != null) 'duration': song.duration,
    };

    // Add song to playlist
    final updatedSongs = [...playlist.songs, playlistSongData];
    final updatedPlaylist = playlist.copyWith(songs: updatedSongs);

    await _savePlaylist(updatedPlaylist);
    onStatusUpdate?.call('Song added to playlist successfully');
  }

  // Enhanced method to get playlist songs with local paths
  Future<List<Map<String, dynamic>>> getPlaylistSongsWithLocalPaths(
    String playlistId,
  ) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return [];

    // Return songs with their local paths if available
    return playlist.songs.map((song) {
      return {
        ...song,
        'hasLocalFiles': song['localAudioPath'] != null,
        'isPlayable':
            song['localAudioPath'] != null || song['audioUrl'] != null,
      };
    }).toList();
  }

  // Method to check if a song in playlist is downloaded
  Future<bool> isPlaylistSongDownloaded(
    String playlistId,
    String songId,
  ) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return false;

    final song = playlist.songs.firstWhere(
      (s) => s['id'] == songId,
      orElse: () => <String, dynamic>{},
    );

    return song['isDownloaded'] == true && song['localAudioPath'] != null;
  }

  // Method to get playable path for a song (local first, then URL)
  Future<String?> getPlayablePath(String playlistId, String songId) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return null;

    final song = playlist.songs.firstWhere(
      (s) => s['id'] == songId,
      orElse: () => <String, dynamic>{},
    );

    if (song.isEmpty) return null;
    final exists = await File(
      '/data/user/0/com.example.houston/app_flutter/downloads/gale_lag_ja_version_1_art.jpg',
    ).exists();
    print('Exists: $exists');
    // Return local path if available, otherwise return URL
    return song['localAudioPath'] ?? song['audioUrl'];
  }

  // Remove song from playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) {
      throw Exception('Playlist not found');
    }

    final updatedSongs = playlist.songs
        .where((song) => song['id'] != songId)
        .toList();
    final updatedPlaylist = playlist.copyWith(songs: updatedSongs);

    await _savePlaylist(updatedPlaylist);
  }

  // Check if song exists in playlist
  Future<bool> isSongInPlaylist(String playlistId, dynamic songId) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return false;

    return playlist.songs.any((song) => song['id'] == songId);
  }

  // Update playlist name
  Future<void> updatePlaylistName(String playlistId, String newName) async {
    if (newName.trim().isEmpty) {
      throw Exception('Playlist name cannot be empty');
    }

    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) {
      throw Exception('Playlist not found');
    }

    final updatedPlaylist = playlist.copyWith(name: newName.trim());
    await _savePlaylist(updatedPlaylist);
  }

  // Delete playlist
  Future<void> deletePlaylist(String playlistId) async {
    try {
      final prefs = await _prefs;
      final playlists = await getAllPlaylists();

      playlists.removeWhere((playlist) => playlist.id == playlistId);

      final playlistsJson = playlists
          .map((p) => jsonEncode(p.toJson()))
          .toList();
      await prefs.setStringList(_playlistsKey, playlistsJson);
    } catch (e) {
      throw Exception('Failed to delete playlist: $e');
    }
  }

  // Get songs from playlist
  Future<List<Map<String, dynamic>>> getPlaylistSongs(String playlistId) async {
    final playlist = await getPlaylistById(playlistId);
    return playlist?.songs ?? [];
  }

  // Update playlist cover image
  Future<void> updatePlaylistCover(
    String playlistId,
    String? coverImageUrl,
  ) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) {
      throw Exception('Playlist not found');
    }

    final updatedPlaylist = playlist.copyWith(coverImage: coverImageUrl);
    await _savePlaylist(updatedPlaylist);
  }

  // Reorder songs in playlist
  Future<void> reorderPlaylistSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) {
      throw Exception('Playlist not found');
    }

    final songs = [...playlist.songs];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex, song);

    final updatedPlaylist = playlist.copyWith(songs: songs);
    await _savePlaylist(updatedPlaylist);
  }

  // Search playlists by name
  Future<List<Playlist>> searchPlaylists(String query) async {
    final playlists = await getAllPlaylists();
    if (query.trim().isEmpty) return playlists;

    return playlists
        .where(
          (playlist) =>
              playlist.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  // Get playlist statistics
  Future<Map<String, dynamic>> getPlaylistStats(String playlistId) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) {
      throw Exception('Playlist not found');
    }

    // Calculate total duration if available
    int totalDurationMs = 0;
    int downloadedCount = 0;

    for (final song in playlist.songs) {
      if (song['duration'] != null) {
        totalDurationMs += (song['duration'] as int);
      }
      if (song['isDownloaded'] == true) {
        downloadedCount++;
      }
    }

    return {
      'songCount': playlist.songs.length,
      'downloadedCount': downloadedCount,
      'downloadedPercentage': playlist.songs.isNotEmpty
          ? (downloadedCount / playlist.songs.length * 100).round()
          : 0,
      'totalDurationMs': totalDurationMs,
      'totalDurationFormatted': _formatDuration(totalDurationMs),
      'createdAt': playlist.createdAt,
      'lastModified':
          playlist.createdAt, // Could track actual last modified time
    };
  }

  // Helper method to format duration
  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Clear all playlists (for testing or reset)
  Future<void> clearAllPlaylists() async {
    final prefs = await _prefs;
    await prefs.remove(_playlistsKey);
  }

  // Export playlists to JSON
  Future<String> exportPlaylists() async {
    final playlists = await getAllPlaylists();
    final exportData = {
      'playlists': playlists.map((p) => p.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    return jsonEncode(exportData);
  }

  // Import playlists from JSON
  Future<void> importPlaylists(
    String jsonData, {
    bool mergePlaylists = true,
  }) async {
    try {
      final data = jsonDecode(jsonData);
      final playlistsData = data['playlists'] as List;

      if (!mergePlaylists) {
        await clearAllPlaylists();
      }

      for (final playlistData in playlistsData) {
        final playlist = Playlist.fromJson(playlistData);
        await _savePlaylist(playlist);
      }
    } catch (e) {
      throw Exception('Failed to import playlists: $e');
    }
  }
}
