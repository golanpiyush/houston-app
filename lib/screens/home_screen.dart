import 'dart:async';

import 'package:animated_icon/animated_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/models/song.dart';
import 'package:houston/providers/audio_state_provider.dart';
import 'package:houston/providers/settings_provider.dart';
import 'package:houston/providers/ytmusic_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _searchAnimationController;
  late AnimationController _fadeAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _searchAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearchActive = false;
  bool _isLoading = false;
  bool _showSearchResults = false;
  bool _showHistory = false;

  // Search history
  List<String> _searchHistory = [];
  final int _maxHistoryItems = 10;

  String _currentSearchQuery = '';
  String _lastSearchQuery =
      ''; // Track the last search to prevent mixing results
  bool _hasPerformedSearch = false; // Track if search has been performed
  bool _isSearchInProgress =
      false; // Track if a search is currently in progress

  @override
  void initState() {
    super.initState();

    // Search expansion animation
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Fade animation for content switching
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Content transition animation
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    );

    _contentFadeAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeInOut,
    );

    _contentSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Start with animations at full opacity
    _fadeAnimationController.value = 1.0;
    _contentAnimationController.value = 1.0;

    // Listen to search controller changes
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);

    // Load search history
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    _fadeAnimationController.dispose();
    _contentAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('search_history') ?? [];
      setState(() {
        _searchHistory = historyJson;
      });
    } catch (e) {
      // Fallback to empty list if SharedPreferences fails
      setState(() {
        _searchHistory = [];
      });
    }
  }

  void _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (e) {
      // Handle error silently or log if needed
      print('Failed to save search history: $e');
    }
  }

  void _addToHistory(String query) {
    if (query.trim().isEmpty) return;

    final trimmedQuery = query.trim();

    setState(() {
      // Remove if already exists (case insensitive)
      _searchHistory.removeWhere(
        (item) => item.toLowerCase() == trimmedQuery.toLowerCase(),
      );

      // Add to beginning
      _searchHistory.insert(0, trimmedQuery);

      // Limit history size
      if (_searchHistory.length > _maxHistoryItems) {
        _searchHistory = _searchHistory.take(_maxHistoryItems).toList();
      }
    });

    _saveSearchHistory();
  }

  void _removeFromHistory(String query) {
    setState(() {
      _searchHistory.removeWhere(
        (item) => item.toLowerCase() == query.toLowerCase(),
      );
    });
    _saveSearchHistory();
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
    });
    _saveSearchHistory();
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() {
        _showHistory = true;
        _showSearchResults = false;
      });
    }
  }

  void _onSearchChanged() {
    final currentText = _searchController.text;

    if (currentText.isNotEmpty) {
      setState(() {
        _showHistory = false;
        // Clear search results and reset states when text changes significantly
        if (_showSearchResults && currentText != _lastSearchQuery) {
          _showSearchResults = false;
          _hasPerformedSearch = false;
          _isSearchInProgress = false; // Reset search progress
          _lastSearchQuery = ''; // Reset last search query
        }
      });
    } else {
      setState(() {
        _showSearchResults = false;
        _showHistory = _searchFocusNode.hasFocus;
        _hasPerformedSearch = false;
        _lastSearchQuery = '';
        _isSearchInProgress = false;
      });

      // Clear search results when text is empty
      ref.read(ytMusicProvider.notifier).clearSearch();
    }
  }

  void _activateSearch() {
    setState(() {
      _isSearchActive = true;
      _showHistory = true;
    });

    // Animate search bar expansion
    _searchAnimationController.forward();

    // Focus the search field
    _searchFocusNode.requestFocus();

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _performSearch(BuildContext context) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Only prevent duplicate searches if the exact same query is already in progress
    if (_isSearchInProgress && query == _lastSearchQuery) {
      return;
    }

    setState(() {
      _showSearchResults = true;
      _showHistory = false;
      _currentSearchQuery = query;
      _isLoading = true;
      _isSearchInProgress = true;
    });

    // Clear previous search results BEFORE starting new search
    ref.read(ytMusicProvider.notifier).clearSearch();

    // Small delay to ensure clearing is processed
    await Future.delayed(const Duration(milliseconds: 50));

    // Update last search query after clearing
    setState(() {
      _lastSearchQuery = query;
      _hasPerformedSearch = true;
    });

    // Add to history immediately
    _addToHistory(query);

    try {
      // Get settings for search parameters
      final settings = ref.read(settingsProvider);
      final limit = settings.limit;
      final audioQuality = settings.audioQuality;
      final thumbnailQuality = settings.thumbnailQuality;

      // Start streaming search results
      ref
          .read(ytMusicProvider.notifier)
          .streamSearchResults(
            query: query,
            limit: limit,
            audioQuality: audioQuality,
            thumbnailQuality: thumbnailQuality,
            context: context,
          );

      // Set a timer to stop loading state after a reasonable time
      Timer(const Duration(seconds: 5), () {
        if (mounted && _lastSearchQuery == query) {
          setState(() {
            _isLoading = false;
            _isSearchInProgress = false;
          });
        }
      });
    } catch (e) {
      if (mounted && _lastSearchQuery == query) {
        setState(() {
          _isLoading = false;
          _isSearchInProgress = false;
        });
      }
      print('Search error: $e');
    }

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  // Updated _selectHistoryItem method
  void _selectHistoryItem(String query) {
    _searchController.text = query;
    _searchFocusNode.unfocus();

    // Small delay to ensure text is set before performing search
    Future.delayed(const Duration(milliseconds: 100), () {
      _performSearch(context);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();

    // Clear search results from provider immediately
    ref.read(ytMusicProvider.notifier).clearSearch();

    setState(() {
      _isSearchActive = false;
      _isLoading = false;
      _showSearchResults = false;
      _showHistory = false;
      _currentSearchQuery = '';
      _lastSearchQuery = '';
      _hasPerformedSearch = false;
      _isSearchInProgress = false;
    });

    // Animate search bar collapse
    _searchAnimationController.reverse();

    // Fade back to home content with slide animation
    _contentAnimationController.reverse().then((_) {
      _fadeAnimationController.reverse().then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _fadeAnimationController.forward();
            _contentAnimationController.forward();
          }
        });
      });
    });

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header with search bar
            _buildHeader(theme),

            // Content area with enhanced animations
            Expanded(
              child: SlideTransition(
                position: _contentSlideAnimation,
                child: FadeTransition(
                  opacity: _contentFadeAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildCurrentContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentContent() {
    // Show search results when search is active and results exist or loading
    if (_showSearchResults && (_hasPerformedSearch || _isLoading)) {
      return _buildSearchContent();
    }

    if (_showHistory && _isSearchActive) {
      return _buildHistoryContent();
    }

    // Don't show loading for search operations
    if (_isLoading && !_showSearchResults) {
      return _buildLoadingContent();
    }

    return _buildHomeContent();
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedBuilder(
        animation: _searchAnimation,
        builder: (context, child) {
          return _isSearchActive
              ? _buildSearchHeader(theme)
              : _buildHomeHeader(theme);
        },
      ),
    );
  }

  Widget _buildHomeHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App title with Google Fonts
        Text(
          'Houston',
          style: GoogleFonts.caveat(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        // Search bar placeholder
        GestureDetector(
          onTap: _activateSearch,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap to search songs, artists, albums...',
                    style: GoogleFonts.caveat(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(ThemeData theme) {
    return Row(
      children: [
        // Back button
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _clearSearch,
          color: theme.colorScheme.onSurface,
        ),

        // Search bar
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            style: GoogleFonts.caveat(
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: GoogleFonts.caveat(
                fontSize: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _performSearch(context);
              }
            },
          ),
        ),

        // Clear button
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _clearSearch();
              setState(() {
                _showSearchResults = false;
                _showHistory = true;
              });
            },
            color: theme.colorScheme.onSurface,
          ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Music note icon
          AnimateIcon(
            key: UniqueKey(),
            onTap: () {}, // Optional: add animation trigger
            iconType: IconType.continueAnimation,
            height: 120,
            width: 120,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            animateIcon: AnimateIcons.mute,
          ),
          const SizedBox(height: 24),

          // Welcome text
          Text(
            'Welcome to Houston',
            style: GoogleFonts.caveat(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Search for your favorite songs',
            style: GoogleFonts.caveat(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      children: [
        const SizedBox(height: 40),

        // Loading animation
        Container(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Searching...',
                  style: GoogleFonts.caveat(
                    fontSize: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHistoryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // History header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: GoogleFonts.caveat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (_searchHistory.isNotEmpty)
                TextButton(
                  onPressed: _clearHistory,
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.caveat(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // History list
        Expanded(
          child: _searchHistory.isEmpty
              ? Center(
                  child: Text(
                    'No recent searches',
                    style: GoogleFonts.caveat(
                      fontSize: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _searchHistory.length,
                  itemBuilder: (context, index) {
                    final query = _searchHistory[index];
                    return ListTile(
                      leading: Icon(
                        Icons.history,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      title: Text(
                        query,
                        style: GoogleFonts.caveat(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: () => _removeFromHistory(query),
                      ),
                      onTap: () => _selectHistoryItem(query),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search results header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Search Results for "$_currentSearchQuery"',
            style: GoogleFonts.caveat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),

        // Search results list
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final ytMusicState = ref.watch(ytMusicProvider);

              if (ytMusicState.error != null) {
                return _buildErrorState(ytMusicState.error!);
              }

              // Always show the streaming list (mix of shimmer and actual results)
              return _buildStreamingSearchResults(ytMusicState);
            },
          ),
        ),
      ],
    );
  }

  // 4. New method to handle streaming results display
  Widget _buildStreamingSearchResults(YtMusicState ytMusicState) {
    final settings = ref.read(settingsProvider);
    final expectedCount = settings.limit;
    final actualResults = ytMusicState.searchResults;

    // Reset search in progress when we have results
    if (actualResults.isNotEmpty && _isSearchInProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isSearchInProgress = false;
            _isLoading = false;
          });
        }
      });
    }

    // Show loading shimmer when actively loading
    if (_isLoading && actualResults.isEmpty) {
      return _buildSearchResultsShimmer();
    }

    // Only show empty state if search is complete and no results
    if (actualResults.isEmpty &&
        !_isLoading &&
        !ytMusicState.isLoading &&
        _hasPerformedSearch &&
        !_isSearchInProgress) {
      return _buildEmptyState();
    }

    // Don't show anything if no search has been performed yet
    if (!_hasPerformedSearch && actualResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: (_isLoading || ytMusicState.isLoading)
          ? expectedCount
          : actualResults.length,
      itemBuilder: (context, index) {
        if (index < actualResults.length) {
          // Animate in the actual result
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              );
            },
            child: _buildSearchResultItem(actualResults[index]),
          );
        }

        if (_isLoading || ytMusicState.isLoading) {
          // Show shimmer with fade out animation when replaced
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: SearchResultShimmer(key: Key('shimmer_$index')),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSearchResultItem(Song song) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: const Color.fromARGB(0, 0, 0, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            // Play the song using AudioProvider
            await ref.read(audioProvider.notifier).playSong(song);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Album art
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.albumArt != null
                        ? Image.network(
                            song.albumArt!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                child: Icon(
                                  Icons.music_note,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 30,
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            child: Icon(
                              Icons.music_note,
                              color: Theme.of(context).colorScheme.primary,
                              size: 30,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.2, // Consistent line height
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artists,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                          height: 1.2, // Consistent line height
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // More button
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: () {
                    print('More options for: ${song.title}');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: GoogleFonts.caveat(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for something else',
            style: GoogleFonts.caveat(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Search Error',
            style: GoogleFonts.caveat(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: GoogleFonts.caveat(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _performSearch(context),
            child: Text('Try Again', style: GoogleFonts.caveat(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsShimmer() {
    return Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(settingsProvider);
        final shimmerCount = settings.limit ?? 10;

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: shimmerCount,
          itemBuilder: (context, index) {
            return const SearchResultShimmer();
          },
        );
      },
    );
  }
}

// Custom shimmer widget for search results
// Updated SearchResultShimmer widget
class SearchResultShimmer extends StatefulWidget {
  const SearchResultShimmer({super.key});

  @override
  State<SearchResultShimmer> createState() => _SearchResultShimmerState();
}

class _SearchResultShimmerState extends State<SearchResultShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ), // Match actual item margins
          child: Padding(
            padding: const EdgeInsets.all(12), // Match actual item padding
            child: Row(
              children: [
                // Album art shimmer - exact same size as actual
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300.withOpacity(_animation.value),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),

                // Text content shimmer with dynamic sizing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title shimmer - random width between 60-90% of available space
                      Container(
                        height: 20, // Match title text height
                        width:
                            MediaQuery.of(context).size.width *
                            (0.6 + (0.3 * (hashCode % 100) / 100)),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300.withOpacity(
                            _animation.value,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4), // Match spacing in actual item
                      // Artist shimmer - random width between 40-70% of available space
                      Container(
                        height: 16, // Match artist text height
                        width:
                            MediaQuery.of(context).size.width *
                            (0.4 + (0.3 * ((hashCode + 1) % 100) / 100)),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300.withOpacity(
                            _animation.value * 0.8,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),

                // More button placeholder (no shimmer)
                const SizedBox(width: 48, height: 48),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Grid shimmer placeholder widget
class GridShimmerPlaceholder extends StatefulWidget {
  final int itemCount;
  final int crossAxisCount;

  const GridShimmerPlaceholder({
    super.key,
    required this.itemCount,
    required this.crossAxisCount,
  });

  @override
  State<GridShimmerPlaceholder> createState() => _GridShimmerPlaceholderState();
}

class _GridShimmerPlaceholderState extends State<GridShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: widget.itemCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300.withOpacity(_animation.value),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          },
        );
      },
    );
  }
}
