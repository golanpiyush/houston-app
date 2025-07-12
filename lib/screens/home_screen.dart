// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/ytmusic_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Recent searches storage (in a real app, this would be persisted)
  final List<String> _recentSearches = [];
  bool _showRecentSearches = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _showRecentSearches =
            _searchFocusNode.hasFocus && _searchController.text.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _addToRecentSearches(String query) {
    if (query.isNotEmpty && !_recentSearches.contains(query)) {
      setState(() {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 10) {
          _recentSearches.removeLast();
        }
      });
    }
  }

  void _saveCurrentSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _addToRecentSearches(query);
      Fluttertoast.showToast(
        msg: "Search saved: $query",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    }
  }

  void _performSearch(String query) {
    if (query.isNotEmpty) {
      _addToRecentSearches(query);
      final settings = ref.read(settingsProvider);
      ref
          .read(ytMusicProvider.notifier)
          .searchMusic(
            query,
            limit: settings.limit,
            audioQuality: settings.audioQuality,
          );
      _searchFocusNode.unfocus();
      setState(() {
        _showRecentSearches = false;
      });
    }
  }

  // ignore: unused_element
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(text);
    }

    final List<TextSpan> spans = [];
    int start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final search = _recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(search),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _recentSearches.removeAt(index);
                    });
                  },
                ),
                onTap: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ytMusicState = ref.watch(ytMusicProvider);
    // final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('HOUSTON'), elevation: 0),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search for music...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.bookmark_add),
                              onPressed: _saveCurrentSearch,
                              tooltip: 'Save Search',
                            ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(ytMusicProvider.notifier).clearSearch();
                              setState(() {
                                _showRecentSearches = _searchFocusNode.hasFocus;
                              });
                            },
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _showRecentSearches =
                            _searchFocusNode.hasFocus && value.isEmpty;
                      });
                    },
                    onSubmitted: _performSearch,
                  ),
                ),
              ],
            ),
          ),

          // Search Results or Home Content
          Expanded(
            child: _showRecentSearches
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildRecentSearches(),
                  )
                : ytMusicState.isLoading
                ? Center(
                    child: SizedBox(
                      height: 250,
                      width: 250,
                      child: Lottie.asset('assets/animations/loadingHome.json'),
                    ),
                  )
                : ytMusicState.searchResults.isNotEmpty
                ? _buildSearchResults()
                : _buildHomeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final ytMusicState = ref.watch(ytMusicProvider);
    // final query = _searchController.text.trim();

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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Search for music to get started',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          if (_recentSearches.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Or tap the search bar to see recent searches',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
