import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/widgets/liked_animations.dart';
import '../models/downloaded_song.dart';
import '../models/song.dart';
import '../providers/audio/audio_state_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';

final savedSongsProvider = FutureProvider<List<DownloadedSong>>((ref) async {
  return StorageService().getAllSavedSongs();
});

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedSongsAsync = ref.watch(savedSongsProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final settings = ref.watch(settingsProvider);

    final themeMode = settings.themeMode;
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    final backgroundColor = switch (themeMode) {
      'amoled' => const Color(0xFF000000),
      'dark' || 'material' => const Color(0xFF0A0E1A),
      _ => const Color(0xFFF5F5F5),
    };
    final cardColor = isDarkMode ? const Color(0xFF1E2328) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        title: Text(
          'Saved Songs',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: textColor),
              onPressed: () => ref.refresh(savedSongsProvider),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: savedSongsAsync.when(
            loading: () => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your saved songs...',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            error: (error, stack) => Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading songs',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => ref.refresh(savedSongsProvider),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            data: (songs) =>
                _buildSongList(context, ref, songs, audioNotifier, settings),
          ),
        ),
      ),
    );
  }

  Widget _buildSongList(
    BuildContext context,
    WidgetRef ref,
    List<DownloadedSong> songs,
    AudioNotifier audioNotifier,
    dynamic settings,
  ) {
    final isDarkMode =
        settings.themeMode == 'dark' || settings.themeMode == 'material';
    final subtitleColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDarkMode ? const Color(0xFF1E2328) : Colors.white;

    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_outlined, size: 80, color: subtitleColor),
            const SizedBox(height: 16),
            Text(
              'No saved songs yet',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start exploring and save your favorite tracks',
              style: GoogleFonts.montserrat(fontSize: 14, color: subtitleColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(savedSongsProvider),
      color: Colors.red,
      backgroundColor: cardColor,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final randomDelay = Random().nextInt(3000) + 1000;

            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: _buildSongArt(song, settings),
                        title: Text(
                          song.title,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface, // ✅ uses system theme
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            song.artist ?? 'Unknown Artist',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withOpacity(0.6), // ✅ subtle contrast
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: RandomGlowLikedAnimation(
                          onTap: () => _removeSong(context, ref, song),
                          size: 24,
                          delay: randomDelay,
                        ),
                        onTap: () => _playSong(
                          context,
                          ref,
                          song,
                          index,
                          songs,
                          audioNotifier,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSongArt(DownloadedSong song, dynamic settings) {
    final isDarkMode =
        settings.themeMode == 'dark' || settings.themeMode == 'material';
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _getImageWidget(song),
      ),
    );
  }

  Widget _getImageWidget(DownloadedSong song) {
    if (song.localAlbumArtPath != null) {
      return Image.file(
        File(song.localAlbumArtPath!),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultMusicIcon(),
      );
    } else if (song.albumArtUrl != null) {
      return Image.network(
        song.albumArtUrl!,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 60,
            height: 60,
            color: const Color(0xFF2A2F36),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _defaultMusicIcon(),
      );
    }
    return _defaultMusicIcon();
  }

  Widget _defaultMusicIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.music_note, size: 30, color: Colors.red),
    );
  }

  Future<void> _removeSong(
    BuildContext context,
    WidgetRef ref,
    DownloadedSong song,
  ) async {
    final settings = ref.watch(settingsProvider);
    final isDarkMode =
        settings.themeMode == 'dark' || settings.themeMode == 'material';
    final cardColor = isDarkMode ? const Color(0xFF1E2328) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.grey[300] : Colors.grey[700];

    // Show confirmation dialog
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Remove Song',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: Text(
            'Are you sure you want to remove "${song.title}" from your saved songs?',
            style: GoogleFonts.montserrat(fontSize: 16, color: subtitleColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Remove',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      try {
        // Convert to Song before passing to removeSong
        await StorageService().removeSong(
          Song(
            videoId: song.audioUrl ?? song.title.hashCode.toString(),
            title: song.title,
            artists: song.artist ?? 'Unknown Artist',
            albumArt: song.albumArtUrl,
            audioUrl: song.audioUrl,
          ),
        );

        if (song.localAudioPath != null) {
          await File(song.localAudioPath!).delete();
        }
        if (song.localAlbumArtPath != null) {
          await File(song.localAlbumArtPath!).delete();
        }

        // Auto-refresh the provider
        ref.refresh(savedSongsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Song removed successfully',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              backgroundColor: cardColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${e.toString()}',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  Future<void> _playSong(
    BuildContext context,
    WidgetRef ref,
    DownloadedSong song,
    int index,
    List<DownloadedSong> playlist,
    AudioNotifier audioNotifier,
  ) async {
    if (song.isFullyDownloaded) {
      audioNotifier.playSong(
        Song(
          videoId: song.audioUrl ?? song.title.hashCode.toString(),
          title: song.title,
          artists: song.artist ?? 'Unknown Artist',
          albumArt: song.localAlbumArtPath,
          audioUrl: song.localAudioPath,
        ),
        playlist: playlist
            .map(
              (s) => Song(
                videoId: s.audioUrl ?? s.title.hashCode.toString(),
                title: s.title,
                artists: s.artist ?? 'Unknown Artist',
                albumArt: s.localAlbumArtPath ?? s.albumArtUrl,
                audioUrl: s.localAudioPath ?? s.audioUrl,
              ),
            )
            .toList(),
        index: index,
      );
    } else {
      // Show loading indicator for streaming
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Song not fully downloaded. Streaming not implemented yet.',
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
