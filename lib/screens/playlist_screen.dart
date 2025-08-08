// playlist_view_screen.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/models/song.dart';
import 'package:houston/providers/audio/audio_state_provider.dart';
import 'package:houston/providers/managers/playlist_manager.dart';
import 'package:houston/providers/playlists_downloader_service.dart';
import 'package:houston/providers/settings_provider.dart';
import 'package:houston/providers/ytmusic_provider.dart';
import 'package:houston/services/storage_service.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';

class PlaylistViewScreen extends ConsumerStatefulWidget {
  final String playlistId;
  final String playlistName;

  const PlaylistViewScreen({
    Key? key,
    required this.playlistId,
    required this.playlistName,
  }) : super(key: key);

  @override
  ConsumerState<PlaylistViewScreen> createState() => _PlaylistViewScreenState();
}

class _PlaylistViewScreenState extends ConsumerState<PlaylistViewScreen>
    with TickerProviderStateMixin {
  final PlaylistManager _playlistManager = PlaylistManager();
  Playlist? _playlist;
  bool _isLoading = true;
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPlaylist();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadPlaylist() async {
    try {
      final playlist = await _playlistManager.getPlaylistById(
        widget.playlistId,
      );
      if (mounted && playlist != null) {
        setState(() {
          _playlist = playlist;
          _nameController.text = playlist.name;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load playlist');
      }
    }
  }

  // Updated _playSong method for PlaylistViewScreen
  // Updated _playSong method for PlaylistViewScreen - Only plays, no downloading
  Future<void> _playSong(Map<String, dynamic> songData, int index) async {
    try {
      setState(() => _isLoading = true);

      String? videoId =
          songData['videoid'] ?? songData['videoId'] ?? songData['id'];

      if (videoId != null &&
          (videoId.contains('googlevideo.com') || videoId.contains('http'))) {
        videoId = null;
      }

      // Get all saved songs once for the entire playlist
      final storageService = StorageService();
      final savedSongs = await storageService.getAllSavedSongs();

      // Convert all playlist songs to Song objects
      final List<Song> playlistSongs = [];
      for (int i = 0; i < _playlist!.songs.length; i++) {
        final songMap = _playlist!.songs[i];

        String? currentVideoId =
            songMap['videoid'] ?? songMap['videoId'] ?? songMap['id'];
        if (currentVideoId != null &&
            (currentVideoId.contains('googlevideo.com') ||
                currentVideoId.contains('http'))) {
          currentVideoId = null;
        }

        // Check if this song is downloaded
        final isDownloaded = savedSongs.any(
          (s) =>
              s.title == (songMap['title'] ?? 'Unknown Title') &&
              s.artist == (songMap['artist'] ?? 'Unknown Artist'),
        );

        String? audioUrl;
        String? albumArt = songMap['albumart'] ?? songMap['artwork'];

        if (isDownloaded) {
          // Use local downloaded files
          final downloadedSong = savedSongs.firstWhere(
            (s) =>
                s.title == (songMap['title'] ?? 'Unknown Title') &&
                s.artist == (songMap['artist'] ?? 'Unknown Artist'),
          );

          audioUrl = 'file://${downloadedSong.localAudioPath}';
          albumArt = downloadedSong.localAlbumArtPath != null
              ? 'file://${downloadedSong.localAlbumArtPath}'
              : songMap['albumart'] ?? songMap['artwork'];
        } else {
          // Use streaming URL from playlist data
          audioUrl = songMap['url'] ?? songMap['audioUrl'];
        }

        playlistSongs.add(
          Song(
            title: songMap['title'] ?? 'Unknown Title',
            artists: songMap['artist'] ?? 'Unknown Artist',
            albumArt: albumArt,
            videoId: currentVideoId ?? '',
            audioUrl: audioUrl,
            duration: songMap['duration'],
          ),
        );
      }

      setState(() => _isLoading = false);

      final audioNotifier = ref.read(audioProvider.notifier);

      // Force cancel any ongoing operations first
      await audioNotifier.cancelCurrentOperation('User selected playlist song');

      // Small delay to ensure cancellation is processed
      await Future.delayed(Duration(milliseconds: 100));

      await audioNotifier.playSong(
        playlistSongs[index], // Play the song at the tapped index
        playlist: playlistSongs,
        index: index,
        playlistType: 'playlist',
        playbackSource: 'playlist',
      );

      _showSuccessSnackBar(
        'Now playing: ${songData['title'] ?? 'Unknown Title'}',
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to play song: $e');
      debugPrint('Error playing song: $e');
    }
  }

  // Helper method to show success message
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.getFont(ref.read(settingsProvider).appFont),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper method to show error message
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.getFont(ref.read(settingsProvider).appFont),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _removeSongFromPlaylist(String songId) async {
    try {
      await _playlistManager.removeSongFromPlaylist(widget.playlistId, songId);
      await _loadPlaylist(); // Reload to update UI
      _showSuccessSnackBar('Song removed from playlist');
    } catch (e) {
      _showErrorSnackBar('Failed to remove song');
    }
  }

  Future<void> _updatePlaylistName(String newName) async {
    if (newName.trim().isEmpty || newName.trim() == _playlist?.name) {
      setState(() {
        _isEditingName = false;
        _nameController.text = _playlist?.name ?? '';
      });
      return;
    }

    try {
      await _playlistManager.updatePlaylistName(
        widget.playlistId,
        newName.trim(),
      );
      await _loadPlaylist();
      setState(() {
        _isEditingName = false;
      });
      _showSuccessSnackBar('Playlist name updated');
    } catch (e) {
      _showErrorSnackBar('Failed to update playlist name');
      setState(() {
        _isEditingName = false;
        _nameController.text = _playlist?.name ?? '';
      });
    }
  }

  Future<void> _shufflePlay() async {
    if (_playlist?.songs.isEmpty ?? true) return;

    try {
      final songs = List<Map<String, dynamic>>.from(_playlist!.songs);
      songs.shuffle();

      final queue = songs
          .map(
            (s) => {
              'videoId': s['videoId'] ?? s['id'],
              'title': s['title'] ?? 'Unknown Title',
              'artists': s['artist'] ?? 'Unknown Artist',
              'albumArt': s['artwork'],
              'duration': s['duration'],
              'url': s['url'],
            },
          )
          .toList();

      // await ref.read(audioProvider.notifier).playFromQueue(queue, 0);
      _showSuccessSnackBar('Shuffling playlist');
    } catch (e) {
      _showErrorSnackBar('Failed to shuffle playlist');
    }
  }

  Widget _buildPlaylistHeader() {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_playlist == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Playlist artwork
            Hero(
              tag: 'playlist_${_playlist!.id}',
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _playlist!.coverImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          _playlist!.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultArtwork(),
                        ),
                      )
                    : _buildDefaultArtworkSpotify(),
              ),
            ),

            const SizedBox(height: 24),

            // Playlist name (editable)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isEditingName = true;
                });
              },
              child: _isEditingName
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.getFont(
                          settings.appFont,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Playlist name',
                          hintStyle: GoogleFonts.getFont(
                            settings.appFont,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        onSubmitted: _updatePlaylistName,
                        onEditingComplete: () =>
                            _updatePlaylistName(_nameController.text),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _playlist!.name,
                            style: GoogleFonts.getFont(
                              settings.appFont,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit,
                          size: 20,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 8),

            // Date created and song count
            Text(
              'Created ${DateFormat('MMM dd, yyyy').format(_playlist!.createdAt)}',
              style: GoogleFonts.getFont(
                settings.appFont,
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),

            const SizedBox(height: 4),

            Text(
              '${_playlist!.songs.length} ${_playlist!.songs.length == 1 ? 'song' : 'songs'}',
              style: GoogleFonts.getFont(
                settings.appFont,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            if (_playlist!.songs.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play button
                  ElevatedButton.icon(
                    onPressed: () => _playSong(_playlist!.songs.first, 0),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: Text(
                      'Play',
                      style: GoogleFonts.getFont(
                        settings.appFont,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 4,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Shuffle button
                  ElevatedButton.icon(
                    onPressed: _shufflePlay,
                    icon: const Icon(Icons.shuffle),
                    label: Text(
                      'Shuffle',
                      style: GoogleFonts.getFont(
                        settings.appFont,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.purple.shade700,
      Colors.blue.shade700,
      Colors.teal.shade700,
      Colors.deepPurple.shade700,
    ];
    return colors[index % colors.length];
  }

  Widget _buildDefaultArtworkSpotify() {
    // Get all songs with artwork
    final availableSongs = _playlist!.songs
        .where((song) => song['albumart'] != null || song['artwork'] != null)
        .toList();

    // If no songs have artwork, use gradient fallback
    if (availableSongs.isEmpty) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.purple, Colors.blue, Colors.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.playlist_play, color: Colors.white, size: 80),
      );
    }

    // 1 song - show single album art
    if (availableSongs.length == 1) {
      final artwork =
          availableSongs[0]['albumart'] ?? availableSongs[0]['artwork'];
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 200,
          height: 200,
          child: Image.network(
            artwork!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackTile(0),
          ),
        ),
      );
    }

    // 2 songs - show 2x2 grid (each song appears twice)
    if (availableSongs.length == 2) {
      return Container(
        width: 200,
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Colors.black.withOpacity(0.1),
                              width: 0.5,
                            ),
                            bottom: BorderSide(
                              color: Colors.black.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: _buildArtworkTile(availableSongs, 0),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.black.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: _buildArtworkTile(availableSongs, 1),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Colors.black.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: _buildArtworkTile(
                          availableSongs,
                          0,
                        ), // Repeat first song
                      ),
                    ),
                    Expanded(
                      child: _buildArtworkTile(
                        availableSongs,
                        1,
                      ), // Repeat second song
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3 or more songs - show 2x2 grid with first 4 songs
    final songsToShow = availableSongs.take(4).toList();
    return Container(
      width: 200,
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.black.withOpacity(0.1),
                            width: 0.5,
                          ),
                          bottom: BorderSide(
                            color: Colors.black.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: _buildArtworkTile(songsToShow, 0),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.black.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: _buildArtworkTile(songsToShow, 1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.black.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: _buildArtworkTile(songsToShow, 2),
                    ),
                  ),
                  Expanded(child: _buildArtworkTile(songsToShow, 3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkTile(
    List<Map<String, dynamic>> availableSongs,
    int index,
  ) {
    // For 2x2 grid, cycle through available songs if we have fewer than 4
    final songIndex = index % availableSongs.length;
    final song = availableSongs[songIndex];
    final artwork = song['albumart'] ?? song['artwork'];

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: artwork != null
          ? Image.network(
              artwork,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackTile(index),
            )
          : _buildFallbackTile(index),
    );
  }

  Widget _buildFallbackTile(int index) {
    return Container(
      color: _getColorForIndex(index),
      child: const Icon(Icons.music_note, color: Colors.white, size: 24),
    );
  }

  Widget _buildDefaultArtwork() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.purple, Colors.blue, Colors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.playlist_play, color: Colors.white, size: 80),
    );
  }

  // Updated _buildSongItem method with fixed PopupMenuButton
  Widget _buildSongItem(Map<String, dynamic> song, int index) {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final audioState = ref.watch(audioProvider);
    final isCurrentSong =
        audioState.currentSong?.videoId == song['videoId'] ||
        audioState.currentSong?.videoId == song['id'];

    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + (index * 50)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playSong(song, index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentSong
                  ? (isDarkMode
                        ? Colors.blue[900]?.withOpacity(0.3)
                        : Colors.blue[50])
                  : (isDarkMode
                        ? const Color.fromARGB(0, 48, 48, 48)
                        : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentSong
                    ? Colors.blue
                    : (isDarkMode
                          ? const Color.fromARGB(255, 0, 0, 0)!
                          : Colors.grey[200]!),
                width: isCurrentSong ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.black26 : Colors.grey[200]!,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Song artwork with local/remote support
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(66, 139, 5, 5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: FutureBuilder<String?>(
                    future: _getAlbumArtPathForSong(song),
                    builder: (context, snapshot) {
                      final albumArtPath =
                          snapshot.data ?? song['artwork'] ?? song['albumart'];

                      if (albumArtPath != null) {
                        if (albumArtPath.startsWith('file://')) {
                          // Local file
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(albumArtPath.replaceFirst('file://', '')),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildDefaultSongArtwork(),
                            ),
                          );
                        } else {
                          // Network image
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              albumArtPath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildDefaultSongArtwork(),
                            ),
                          );
                        }
                      }
                      return _buildDefaultSongArtwork();
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Song info with download indicator
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              song['title'] ?? 'Unknown Title',
                              style: GoogleFonts.getFont(
                                settings.appFont,
                                fontWeight: isCurrentSong
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 16,
                                color: isCurrentSong
                                    ? Colors.blue
                                    : (isDarkMode
                                          ? Colors.white
                                          : const Color.fromARGB(0, 0, 0, 0)),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Download indicator
                          FutureBuilder<bool>(
                            future: _isAudioDownloaded(song),
                            builder: (context, snapshot) {
                              if (snapshot.data == true) {
                                return Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.download_done,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song['artist'] ?? 'Unknown Artist',
                        style: GoogleFonts.getFont(
                          settings.appFont,
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Play indicator or menu
                if (isCurrentSong && audioState.isPlaying)
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.volume_up, color: Colors.blue, size: 20),
                  )
                else
                  // Fixed PopupMenuButton - use a StatefulBuilder to handle async operations
                  StatefulBuilder(
                    builder: (context, setMenuState) {
                      return FutureBuilder<bool>(
                        future: _isAudioDownloaded(song),
                        builder: (context, snapshot) {
                          final isDownloaded = snapshot.data ?? false;

                          return PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'remove') {
                                _removeSongFromPlaylist(
                                  song['id'] ?? song['videoId'],
                                );
                              } else if (value == 'download') {
                                // await _downloadSong(song);
                              } else if (value == 'delete_download') {
                                await _deleteDownloadedSong(song);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remove from playlist',
                                      style: GoogleFonts.getFont(
                                        settings.appFont,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: isDownloaded
                                    ? 'delete_download'
                                    : 'download',
                                child: Row(
                                  children: [
                                    Icon(
                                      isDownloaded
                                          ? Icons.delete
                                          : Icons.download,
                                      color: isDownloaded
                                          ? Colors.orange
                                          : Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isDownloaded
                                          ? 'Delete download'
                                          : 'Download',
                                      style: GoogleFonts.getFont(
                                        settings.appFont,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.more_vert,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                size: 20,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get album art path for a specific song
  Future<String?> _getAlbumArtPathForSong(Map<String, dynamic> songData) async {
    final tempSong = Song(
      title: songData['title'] ?? 'Unknown Title',
      artists: songData['artist'] ?? 'Unknown Artist',
      albumArt: songData['albumart'] ?? songData['artwork'],
      videoId:
          songData['videoid'] ?? songData['videoId'] ?? songData['id'] ?? '',
      duration: songData['duration'],
    );

    final storageService = StorageService();
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

  // Helper method to check if audio is downloaded
  Future<bool> _isAudioDownloaded(Map<String, dynamic> songData) async {
    final tempSong = Song(
      title: songData['title'] ?? 'Unknown Title',
      artists: songData['artist'] ?? 'Unknown Artist',
      albumArt: songData['albumart'] ?? songData['artwork'],
      videoId:
          songData['videoid'] ?? songData['videoId'] ?? songData['id'] ?? '',
      duration: songData['duration'],
    );

    final storageService = StorageService();
    return await storageService.isSongSaved(tempSong);
  }

  Future<void> _deleteDownloadedSong(Map<String, dynamic> songData) async {
    try {
      final tempSong = Song(
        title: songData['title'] ?? 'Unknown Title',
        artists: songData['artist'] ?? 'Unknown Artist',
        albumArt: songData['albumart'] ?? songData['artwork'],
        videoId:
            songData['videoid'] ?? songData['videoId'] ?? songData['id'] ?? '',
        duration: songData['duration'],
      );

      final storageService = StorageService();
      final savedSongs = await storageService.getAllSavedSongs();
      final downloadedSong = savedSongs.firstWhere(
        (s) => s.title == tempSong.title && s.artist == tempSong.artists,
      );

      // Delete audio file
      if (downloadedSong.localAudioPath != null) {
        final audioFile = File(downloadedSong.localAudioPath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }

      // Delete album art file
      if (downloadedSong.localAlbumArtPath != null) {
        final artFile = File(downloadedSong.localAlbumArtPath!);
        if (await artFile.exists()) {
          await artFile.delete();
        }
      }

      // Remove from storage service
      await storageService.removeSong(tempSong);

      setState(() {}); // Refresh UI
      _showSuccessSnackBar('Downloaded files deleted');
    } catch (e) {
      _showErrorSnackBar('Failed to delete files: $e');
    }
  }

  // Method to delete downloaded song

  Widget _buildDefaultSongArtwork() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.purple, Colors.blue]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: Colors.white, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[50],
      // Add this import at the top of your file

      // Replace your existing AppBar with this:
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.3),
              elevation: 0,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode
                        ? [
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.1),
                          ]
                        : [
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0.1),
                          ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: isDarkMode ? Colors.white : Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ),
              actions: [
                if (!_isLoading && _playlist != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: AlertDialog(
                                backgroundColor: isDarkMode
                                    ? Colors.grey[900]?.withOpacity(0.95)
                                    : Colors.white.withOpacity(0.95),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.1),
                                  ),
                                ),
                                title: Text(
                                  'Delete Playlist',
                                  style: GoogleFonts.getFont(
                                    settings.appFont,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                content: Text(
                                  'Are you sure you want to delete "${_playlist!.name}"? This action cannot be undone.',
                                  style: GoogleFonts.getFont(
                                    settings.appFont,
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    style: TextButton.styleFrom(
                                      backgroundColor: isDarkMode
                                          ? Colors.grey[800]?.withOpacity(0.5)
                                          : Colors.grey[200]?.withOpacity(0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.getFont(
                                        settings.appFont,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.red.withOpacity(
                                        0.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Delete',
                                      style: GoogleFonts.getFont(
                                        settings.appFont,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (confirmed == true) {
                            await _playlistManager.deletePlaylist(
                              widget.playlistId,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              _showSuccessSnackBar('Playlist deleted');
                            }
                          }
                        }
                      },
                      color: isDarkMode
                          ? Colors.grey[800]?.withOpacity(0.95)
                          : Colors.white.withOpacity(0.95),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Delete Playlist',
                                  style: GoogleFonts.getFont(
                                    settings.appFont,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      icon: Icon(
                        Icons.more_vert,
                        color: isDarkMode ? Colors.white : Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      // Replace the body section of your build method with this:
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(
                      isDarkMode ? Colors.white : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading playlist...',
                    style: GoogleFonts.getFont(
                      settings.appFont,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _playlist == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Playlist not found',
                    style: GoogleFonts.getFont(
                      settings.appFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // Playlist header as a sliver
                  SliverToBoxAdapter(child: _buildPlaylistHeader()),

                  // Songs list
                  _playlist!.songs.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.music_note,
                                  size: 64,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No songs in this playlist',
                                  style: GoogleFonts.getFont(
                                    settings.appFont,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add some songs to get started',
                                  style: GoogleFonts.getFont(
                                    settings.appFont,
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.only(top: 8, bottom: 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _buildSongItem(
                                _playlist!.songs[index],
                                index,
                              );
                            }, childCount: _playlist!.songs.length),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
