// add_to_playlist_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/providers/managers/playlist_manager.dart';
import 'package:houston/providers/settings_provider.dart';
import 'package:houston/models/song.dart';
import 'package:icons_plus/icons_plus.dart';

class AddToPlaylistBottomSheet extends ConsumerStatefulWidget {
  final Song song;

  const AddToPlaylistBottomSheet({Key? key, required this.song})
    : super(key: key);

  @override
  ConsumerState<AddToPlaylistBottomSheet> createState() =>
      _AddToPlaylistBottomSheetState();
}

class _AddToPlaylistBottomSheetState
    extends ConsumerState<AddToPlaylistBottomSheet>
    with TickerProviderStateMixin {
  final PlaylistManager _playlistManager = PlaylistManager();
  final TextEditingController _newPlaylistController = TextEditingController();
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  bool _isCreatingPlaylist = false;
  bool _isAddingToPlaylist = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  String? _currentProcessingPlaylistId;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPlaylists();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Start animations
    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  Future<void> _loadPlaylists() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300)); // Smooth loading
      final playlists = await _playlistManager.getAllPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load playlists');
      }
    }
  }

  Future<void> _createPlaylistAndAddSong(String playlistName) async {
    if (playlistName.trim().isEmpty) {
      _showErrorSnackBar('Please enter a playlist name');
      return;
    }

    setState(() {
      _isCreatingPlaylist = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Creating playlist...';
    });

    try {
      final newPlaylist = await _playlistManager.createPlaylist(
        playlistName.trim(),
      );

      setState(() {
        _currentProcessingPlaylistId = newPlaylist.id;
      });

      await _playlistManager.addSongToPlaylist(
        newPlaylist.id,
        widget.song,
        onDownloadProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _downloadStatus = status;
            });
          }
        },
      );

      // Animate out before closing
      await _slideController.reverse();
      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('Created playlist "$playlistName" and added song');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create playlist: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPlaylist = false;
          _currentProcessingPlaylistId = null;
          _downloadProgress = 0.0;
          _downloadStatus = '';
        });
      }
    }
  }

  Future<void> _addSongToExistingPlaylist(Playlist playlist) async {
    setState(() {
      _isAddingToPlaylist = true;
      _currentProcessingPlaylistId = playlist.id;
      _downloadProgress = 0.0;
      _downloadStatus = 'Checking playlist...';
    });

    try {
      final songExists = await _playlistManager.isSongInPlaylist(
        playlist.id,
        widget.song.videoId,
      );

      if (songExists) {
        _showErrorSnackBar('Song already exists in "${playlist.name}"');
        return;
      }

      await _playlistManager.addSongToPlaylist(
        playlist.id,
        widget.song,
        onDownloadProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _downloadStatus = status;
            });
          }
        },
      );

      // Animate out before closing
      await _slideController.reverse();
      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('Added to "${playlist.name}"');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to add song to playlist: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToPlaylist = false;
          _currentProcessingPlaylistId = null;
          _downloadProgress = 0.0;
          _downloadStatus = '';
        });
      }
    }
  }

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
        elevation: 6,
      ),
    );
  }

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
        elevation: 6,
      ),
    );
  }

  Widget _buildDownloadProgressOverlay() {
    if (!_isCreatingPlaylist && !_isAddingToPlaylist)
      return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);

    return AnimatedOpacity(
      opacity: (_isCreatingPlaylist || _isAddingToPlaylist) ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [
                    Colors.blue[900]!.withOpacity(0.8),
                    Colors.purple[900]!.withOpacity(0.8),
                  ]
                : [Colors.blue[50]!, Colors.purple[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.blue[400]! : Colors.blue[200]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _downloadStatus.isEmpty ? 'Processing...' : _downloadStatus,
                    style: GoogleFonts.getFont(
                      settings.appFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (_downloadProgress > 0)
                  Text(
                    '${(_downloadProgress * 100).toInt()}%',
                    style: GoogleFonts.getFont(
                      settings.appFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
            if (_downloadProgress > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: isDarkMode
                      ? Colors.grey[700]
                      : Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePlaylistSection() {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.grey[900]!, Colors.grey[800]!]
              : [Colors.grey[50]!, Colors.grey[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.grey[300]!,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.blue],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Create New Playlist',
                style: GoogleFonts.getFont(
                  settings.appFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode ? Colors.black26 : Colors.grey[200]!,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _newPlaylistController,
                    enabled: !_isCreatingPlaylist && !_isAddingToPlaylist,
                    style: GoogleFonts.getFont(
                      settings.appFont,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter playlist name...',
                      hintStyle: GoogleFonts.getFont(
                        settings.appFont,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      filled: true,
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (value) => _createPlaylistAndAddSong(value),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: (_isCreatingPlaylist || _isAddingToPlaylist)
                      ? null
                      : () => _createPlaylistAndAddSong(
                          _newPlaylistController.text,
                        ),
                  style:
                      ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ).copyWith(
                        backgroundColor: MaterialStateProperty.resolveWith((
                          states,
                        ) {
                          return states.contains(MaterialState.disabled)
                              ? Colors.grey[400]
                              : null;
                        }),
                      ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: (_isCreatingPlaylist || _isAddingToPlaylist)
                          ? null
                          : const LinearGradient(
                              colors: [Colors.purple, Colors.blue],
                            ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: (_isCreatingPlaylist || _isAddingToPlaylist)
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          )
                        : const Icon(Icons.add, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(Playlist playlist, int index) {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isCurrentlyProcessing = _currentProcessingPlaylistId == playlist.id;
    final isDisabled = _isCreatingPlaylist || _isAddingToPlaylist;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + (index * 50)),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Opacity(
        opacity: isDisabled && !isCurrentlyProcessing ? 0.5 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled
                ? null
                : () => _addSongToExistingPlaylist(playlist),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrentlyProcessing
                      ? Colors.blue
                      : isDarkMode
                      ? Colors.grey[700]!
                      : Colors.grey[200]!,
                  width: isCurrentlyProcessing ? 2 : 1,
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
                  Hero(
                    tag: 'playlist_${playlist.id}',
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: playlist.coverImage != null
                            ? null
                            : const LinearGradient(
                                colors: [Colors.purple, Colors.blue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: playlist.coverImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                playlist.coverImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                              ),
                            )
                          : const Icon(
                              Icons.playlist_play,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          style: GoogleFonts.getFont(
                            settings.appFont,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.songCount} ${playlist.songCount == 1 ? 'song' : 'songs'}',
                          style: GoogleFonts.getFont(
                            settings.appFont,
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.blue],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isCurrentlyProcessing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo() {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Colors.blue[50]!, Colors.purple[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'current_song_${widget.song.videoId}',
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: widget.song.albumArt != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.song.albumArt!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.purple, Colors.blue],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.purple, Colors.blue],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.title,
                    style: GoogleFonts.getFont(
                      settings.appFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.song.artists,
                    style: GoogleFonts.getFont(
                      settings.appFont,
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.queue_music,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Header
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.purple, Colors.blue],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.playlist_add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add to Playlist',
                      style: GoogleFonts.getFont(
                        settings.appFont,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: (_isCreatingPlaylist || _isAddingToPlaylist)
                          ? null
                          : () async {
                              await _slideController.reverse();
                              if (mounted) Navigator.pop(context);
                            },
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Song info
            _buildSongInfo(),

            // Download progress overlay
            _buildDownloadProgressOverlay(),

            const SizedBox(height: 8),

            // Create playlist section
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildCreatePlaylistSection(),
            ),

            // Existing playlists
            Flexible(
              child: _isLoading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                isDarkMode ? Colors.white : Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading playlists...',
                              style: GoogleFonts.getFont(
                                settings.appFont,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _playlists.isEmpty
                  ? FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.purple, Colors.blue],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.playlist_add,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No playlists yet',
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
                                'Create your first playlist above',
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
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _playlists.length,
                        itemBuilder: (context, index) {
                          return _buildPlaylistItem(_playlists[index], index);
                        },
                      ),
                    ),
            ),

            // Bottom safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPlaylistController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _progressController.dispose();
    super.dispose();
  }
}

// Helper method to show the bottom sheet
class PlaylistBottomSheetHelper {
  static void showAddToPlaylistBottomSheet(
    BuildContext context,
    dynamic songData, // Accept any song type
  ) {
    // Convert various song formats to Song model
    Song song;

    if (songData is Song) {
      song = songData;
    } else if (songData is Map<String, dynamic>) {
      // Convert Map to Song model
      song = Song(
        videoId:
            songData['id'] ??
            songData['videoId'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: songData['title'] ?? 'Unknown Title',
        artists: songData['artist'] ?? songData['artists'] ?? 'Unknown Artist',
        albumArt:
            songData['artwork'] ??
            songData['albumart'] ??
            songData['thumbnailUrl'],

        audioUrl: songData['url'] ?? songData['audioUrl'],
      );
    } else {
      // Handle other object types (assuming they have similar properties)
      song = Song(
        videoId:
            _getProperty(songData, ['id', 'videoId']) ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _getProperty(songData, ['title']) ?? 'Unknown Title',
        artists:
            _getProperty(songData, ['artists', 'artist']) ?? 'Unknown Artist',
        albumArt: _getProperty(songData, [
          'albumArt',
          'artwork',
          'thumbnailUrl',
        ]),
        audioUrl: _getProperty(songData, ['audioUrl', 'url']),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return AddToPlaylistBottomSheet(song: song);
        },
      ),
    );
  }

  // Helper method to get property from object using reflection-like approach
  static dynamic _getProperty(dynamic obj, List<String> propertyNames) {
    for (String propertyName in propertyNames) {
      try {
        if (obj is Map) {
          if (obj.containsKey(propertyName)) {
            return obj[propertyName];
          }
        } else {
          // For objects with properties, we'd need reflection or specific handling
          // This is a simplified approach - you might need to adjust based on your actual objects
          var value = _tryGetObjectProperty(obj, propertyName);
          if (value != null) return value;
        }
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  static dynamic _tryGetObjectProperty(dynamic obj, String propertyName) {
    try {
      // This is a placeholder - you'd implement actual property access based on your objects
      // For now, just return null to avoid errors
      return null;
    } catch (e) {
      return null;
    }
  }

  static Duration? _getDuration(dynamic obj) {
    try {
      var duration = _getProperty(obj, ['duration']);
      if (duration == null) return null;

      if (duration is Duration) {
        return duration;
      } else if (duration is int) {
        return Duration(milliseconds: duration);
      } else if (duration is double) {
        return Duration(milliseconds: duration.toInt());
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
