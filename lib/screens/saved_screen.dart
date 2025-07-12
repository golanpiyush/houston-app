// screens/saved_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/downloaded_song.dart';
import '../models/song.dart';
import '../providers/audio_provider.dart';
import '../services/storage_service.dart';

final savedSongsProvider = FutureProvider<List<DownloadedSong>>((ref) async {
  return StorageService().getAllSavedSongs();
});

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedSongsAsync = ref.watch(savedSongsProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Songs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(savedSongsProvider),
          ),
        ],
      ),
      body: savedSongsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            children: [
              const Icon(Icons.error, size: 48),
              Text('Error loading songs'),
              TextButton(
                onPressed: () => ref.refresh(savedSongsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (songs) => _buildSongList(context, ref, songs, audioNotifier),
      ),
    );
  }

  Widget _buildSongList(
    BuildContext context,
    WidgetRef ref,
    List<DownloadedSong> songs,
    AudioNotifier audioNotifier,
  ) {
    if (songs.isEmpty) {
      return const Center(child: Text('No saved songs yet'));
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(savedSongsProvider),
      child: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return ListTile(
            leading: _buildSongArt(song),
            title: Text(song.title),
            subtitle: Text(song.artist ?? 'Unknown Artist'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  song.isFullyDownloaded ? Icons.download_done : Icons.download,
                  color: song.isFullyDownloaded ? Colors.green : Colors.grey,
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _removeSong(context, ref, song),
                ),
              ],
            ),
            onTap: () =>
                _playSong(context, ref, song, index, songs, audioNotifier),
          );
        },
      ),
    );
  }

  Widget _buildSongArt(DownloadedSong song) {
    if (song.localAlbumArtPath != null) {
      return Image.file(File(song.localAlbumArtPath!), width: 50, height: 50);
    } else if (song.albumArtUrl != null) {
      return Image.network(song.albumArtUrl!, width: 50, height: 50);
    }
    return const Icon(Icons.music_note, size: 50);
  }

  Future<void> _removeSong(
    BuildContext context,
    WidgetRef ref,
    DownloadedSong song,
  ) async {
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
      // ref.refresh(savedSongsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Song removed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
          videoId:
              song.audioUrl ??
              song.title.hashCode.toString(), // Use audioUrl or hash as videoId
          title: song.title,
          artists: song.artist ?? 'Unknown Artist',
          albumArt: song.localAlbumArtPath,
          audioUrl: song.localAudioPath,
        ),
        playlist: playlist
            .map(
              (s) => Song(
                videoId: s.audioUrl ?? s.title.hashCode.toString(), // Same here
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
      // Implement streaming logic if needed
    }
  }
}
