// screens/player_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: audioState.currentSong != null
          ? _buildPlayerContent(context, ref, audioState)
          : const Center(child: Text('No song playing')),
    );
  }

  Widget _buildPlayerContent(
    BuildContext context,
    WidgetRef ref,
    AudioState audioState,
  ) {
    final song = audioState.currentSong!;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Album Art
          Expanded(
            flex: 3,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: song.albumArt ?? '',
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note, size: 100),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note, size: 100),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Song Info
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  song.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  song.artists,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Progress Bar
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Slider(
                  value: audioState.currentPosition.inMilliseconds.toDouble(),
                  max: audioState.totalDuration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    ref
                        .read(audioProvider.notifier)
                        .seekTo(Duration(milliseconds: value.toInt()));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(audioState.currentPosition)),
                      Text(_formatDuration(audioState.totalDuration)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    ref.read(audioProvider.notifier).playPrevious();
                  },
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 40,
                ),
                IconButton(
                  onPressed: () {
                    ref.read(audioProvider.notifier).pauseResume();
                  },
                  icon: Icon(
                    audioState.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  iconSize: 64,
                ),
                IconButton(
                  onPressed: () {
                    ref.read(audioProvider.notifier).playNext();
                  },
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Heart Icon
          IconButton(
            onPressed: () {
              ref.read(audioProvider.notifier).toggleFavorite();
            },
            icon: Icon(
              audioState.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: audioState.isFavorite ? Colors.red : null,
            ),
            iconSize: 32,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
