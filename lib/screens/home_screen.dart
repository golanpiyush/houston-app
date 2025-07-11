// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import '../providers/ytmusic_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ytMusicState = ref.watch(ytMusicProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Music Player'), elevation: 0),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for music...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(ytMusicProvider.notifier).clearSearch();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (query) {
                if (query.isNotEmpty) {
                  ref
                      .read(ytMusicProvider.notifier)
                      .searchMusic(
                        query,
                        limit: settings.limit,
                        audioQuality: settings.audioQuality,
                      );
                }
              },
            ),
          ),

          // Search Results or Home Content
          Expanded(
            child: ytMusicState.searchResults.isNotEmpty
                ? _buildSearchResults()
                : _buildHomeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final ytMusicState = ref.watch(ytMusicProvider);

    if (ytMusicState.isLoading) {
      return Center(
        child: SizedBox(
          height: 200,
          child: Lottie.asset('assets/animations/loadingHome.json'),
        ),
      );
    }

    if (ytMusicState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${ytMusicState.error}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: ytMusicState.searchResults.length,
      itemBuilder: (context, index) {
        final song = ytMusicState.searchResults[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: song.albumArt ?? '',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 56,
                height: 56,
                color: Colors.grey[300],
                child: const Icon(Icons.music_note),
              ),
              errorWidget: (context, url, error) => Container(
                width: 56,
                height: 56,
                color: Colors.grey[300],
                child: const Icon(Icons.music_note),
              ),
            ),
          ),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            song.artists,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(song.duration ?? ''),
          onTap: () {
            ref
                .read(audioProvider.notifier)
                .playSong(
                  song,
                  playlist: ytMusicState.searchResults,
                  index: index,
                );
          },
        );
      },
    );
  }

  Widget _buildHomeContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Search for music to get started',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
