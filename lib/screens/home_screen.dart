import 'dart:async';

import 'package:animated_icon/animated_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/models/song.dart';
import 'package:houston/providers/audio/audio_state_provider.dart';
import 'package:houston/providers/settings_provider.dart';
import 'package:houston/providers/ytmusic_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/screens/apiStatus.dart';
import 'package:houston/services/ytScraperLib.dart';
import 'package:houston/widgets/shimmer.dart';
import 'package:houston/widgets/song_options_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';

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
  Future<List<QuickPickSong>>? _quickPicksFuture;
  bool _isReloading = false;

  List<String> _suggestions = [];
  Timer? _debounce;

  // Search history
  List<String> _searchHistory = [];
  final int _maxHistoryItems = 10;

  String _currentSearchQuery = '';
  String _lastSearchQuery =
      ''; // Track the last search to prevent mixing results
  bool _hasPerformedSearch = false; // Track if search has been performed
  bool _isSearchInProgress =
      false; // Track if a search is currently in progress

  TextStyle _getGoogleFont(String fontName) {
    try {
      switch (fontName) {
        case 'Poppins':
          return GoogleFonts.poppins();
        case 'Roboto':
          return GoogleFonts.roboto();
        case 'Open Sans':
          return GoogleFonts.openSans();
        case 'Barlow':
          return GoogleFonts.barlow();
        case 'Montserrat':
          return GoogleFonts.montserrat();
        case 'Lato':
          return GoogleFonts.lato();
        case 'Nunito':
          return GoogleFonts.nunito();
        case 'Inter':
          return GoogleFonts.inter();
        case 'Raleway':
          return GoogleFonts.raleway();
        case 'Playfair Display':
          return GoogleFonts.playfairDisplay();
        case 'Oswald':
          return GoogleFonts.oswald();
        case 'Merriweather':
          return GoogleFonts.merriweather();
        case 'Ubuntu':
          return GoogleFonts.ubuntu();
        case 'Fira Sans':
          return GoogleFonts.firaSans();
        case 'Crimson Text':
          return GoogleFonts.crimsonText();
        case 'Quicksand':
          return GoogleFonts.quicksand();
        case 'Comfortaa':
          return GoogleFonts.comfortaa();
        default:
          return GoogleFonts.poppins();
      }
    } catch (e) {
      print('Error loading font $fontName: $e');
      return GoogleFonts.poppins();
    }
  }

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
    _quickPicksFuture = _loadQuickPicks(); // Initialize on startup
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    _debounce?.cancel();
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
    final query = _searchController.text.trim();

    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      if (query.isNotEmpty) {
        // Trigger suggestion fetch
        final ytScraper = YtScraperSearch();
        final results = await ytScraper.getSuggestions(query);

        setState(() {
          _suggestions = results;
          // Keep _showHistory = true so that _buildHistoryContent is called
          // The method will internally decide whether to show suggestions or history
          _showHistory = true;

          // Clear previous results if the query is significantly changed
          if (_showSearchResults && query != _lastSearchQuery) {
            _showSearchResults = false;
            _hasPerformedSearch = false;
            _isSearchInProgress = false;
            _lastSearchQuery = '';
          }
        });
      } else {
        // Empty search bar behavior
        ref.read(ytMusicProvider.notifier).clearSearch();

        setState(() {
          _suggestions = [];
          _showSearchResults = false;
          _showHistory = _searchFocusNode.hasFocus;
          _hasPerformedSearch = false;
          _lastSearchQuery = '';
          _isSearchInProgress = false;
        });
      }
    });
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
            // thumbnailQuality: thumbnailQuality,
            // ignore: use_build_context_synchronously
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
      return _buildHistoryContentWithSuggestions();
    }

    // Don't show loading for search operations
    if (_isLoading && !_showSearchResults) {
      return _buildLoadingContentWithSuggestions();
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
    return Consumer(
      builder: (context, ref, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: Duration(milliseconds: 500),
                    pageBuilder: (_, animation, secondaryAnimation) =>
                        ApiStatusScreen(),
                    transitionsBuilder:
                        (_, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                  ),
                );
              },
              child: Text(
                'Houston',
                style: _getCurrentFontStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ).copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 16),
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
                        style: _getCurrentFontStyle(fontSize: 13).copyWith(
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
      },
    );
  }

  Widget _buildSearchHeader(ThemeData theme) {
    return Consumer(
      builder: (context, ref, child) {
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _clearSearch,
              color: theme.colorScheme.onSurface,
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: _getCurrentFontStyle(
                  fontSize: 20,
                ).copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: _getCurrentFontStyle(fontSize: 20).copyWith(
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
      },
    );
  }

  // Reload Quick Picks method
  void reloadQuickPicks() async {
    if (_isReloading) return; // Prevent multiple simultaneous reloads

    print('🔄 Reloading Quick Picks...');

    setState(() {
      _isReloading = true;
    });

    // Show a brief feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color.fromARGB(255, 248, 7, 7),
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Refreshing quick picks',
              style: _getGoogleFont(ref.read(settingsProvider).appFont)
                  .copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    try {
      // Create a new future for the reload
      final newFuture = _loadQuickPicks();

      setState(() {
        _quickPicksFuture = newFuture;
      });

      // Wait for the result to show success/failure
      final result = await newFuture;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✨ Quick Picks refreshed! Found ${result.length} songs',
            style: _getGoogleFont(ref.read(settingsProvider).appFont).copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black45,
            ),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      print('✅ Quick Picks reloaded successfully: ${result.length} songs');
    } catch (e) {
      print('❌ Error reloading Quick Picks: $e');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '😒 Failed to refresh Quick Picks',
            style: _getGoogleFont(ref.read(settingsProvider).appFont).copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isReloading = false;
      });
    }
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Welcome header section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                // Quick Picks Section
                _buildQuickPicksSection(),

                const SizedBox(height: 3),
                // Music note icon with reload functionality
                AnimateIcon(
                  key: UniqueKey(),
                  onTap: reloadQuickPicks, // Connected to reload method
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
                  style: _getGoogleFont(ref.read(settingsProvider).appFont)
                      .copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Discover your favorite songs',
                  style: _getGoogleFont(ref.read(settingsProvider).appFont)
                      .copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPicksSection() {
    return Consumer(
      builder: (context, ref, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Picks',
                    style: _getCurrentFontStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ).copyWith(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Icon(
                    Icons.music_note_rounded,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.7),
                    size: 28,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: FutureBuilder<List<QuickPickSong>>(
                future: _quickPicksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerList();
                  }
                  if (snapshot.hasError) {
                    return _buildErrorStateQuickPicks();
                  }
                  final songs = snapshot.data ?? [];
                  if (songs.isEmpty) {
                    return _buildEmptyStateQuickPicks();
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      return _buildSongCard(songs[index]);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSongCard(QuickPickSong song) {
    return Consumer(
      builder: (context, ref, child) {
        final ytMusicState = ref.watch(ytMusicProvider);
        return Container(
          width: 160,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Card(
            color: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _playSong(song, ref),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: song.albumArt.isNotEmpty
                          ? Image.network(
                              song.albumArt,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderArt();
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return AlbumArtShimmer(
                                      size: 120,
                                      isLoading: true,
                                      borderRadius: 8,
                                    );
                                  },
                            )
                          : _buildPlaceholderArt(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.title,
                      style:
                          _getCurrentFontStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ).copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        song.artists.join(', '),
                        style:
                            _getCurrentFontStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w200,
                            ).copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: ytMusicState.isLoading
                            ? null
                            : () => _playSong(song, ref),
                        icon: ytMusicState.isLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Icon(Icons.play_arrow_rounded, size: 16),
                        label: Text(
                          ytMusicState.isLoading ? 'Loading...' : 'Play',
                          style:
                              _getCurrentFontStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w200,
                              ).copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      width: double.infinity,
      height: 120, // Match the reduced height
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          width: 160,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Album art shimmer
                  AlbumArtShimmer(
                    size: 120,
                    isLoading: true,
                    borderRadius: 8,
                  ), // Updated size

                  const SizedBox(height: 12),

                  // Title shimmer
                  TextShimmer(
                    width: double.infinity,
                    height: 16,
                    isLoading: true,
                  ),

                  const SizedBox(height: 8),

                  // Artist shimmer
                  TextShimmer(width: 100, height: 14, isLoading: true),

                  const Spacer(),

                  // Button shimmer
                  AppShimmer(
                    width: double.infinity,
                    height: 32,
                    isLoading: true,
                    borderRadius: BorderRadius.circular(16),
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorStateQuickPicks() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load Quick Picks',
            style: _getCurrentFontStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ).copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: reloadQuickPicks,
            icon: Icon(Icons.refresh_rounded),
            label: Text('Retry', style: _getCurrentFontStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateQuickPicks() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Quick Picks available',
            style: _getCurrentFontStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ).copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: reloadQuickPicks,
            icon: Icon(Icons.refresh_rounded),
            label: Text('Reload', style: _getCurrentFontStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // Updated helper methods
  Future<List<QuickPickSong>> _loadQuickPicks() async {
    try {
      final scraper = YtScraperSearch(apiKey: "YOUR_API_KEY_HERE");
      return await scraper.getQuickPicks(
        limit: 40,
        audioQuality: 'AUDIO_QUALITY_HIGH',
        thumbnailQuality: 'very_high',
      );
    } catch (e) {
      print('Error loading Quick Picks: $e');
      return [];
    }
  }

  // Updated _playSong method that uses YtMusicNotifier
  void _playSong(QuickPickSong song, WidgetRef ref) async {
    print('🎵 Playing: ${song.title} by ${song.artists.join(', ')}');

    try {
      // Get the YtMusicNotifier
      final ytMusicNotifier = ref.read(ytMusicProvider.notifier);

      // Show loading state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 12),
              Text(
                'Getting audio URL...',
                style: _getGoogleFont(ref.read(settingsProvider).appFont)
                    .copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                    ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Get audio URL using the flexible method
      final response = await ytMusicNotifier.getAudioUrlFlexible(
        videoId: song.videoId,
        title: song.title,
        artist: song.artists.isNotEmpty ? song.artists.first : null,
        audioQuality: AudioQuality.high,
      );

      if (response.success &&
          response.data != null &&
          response.data!.audioUrl != null) {
        // Create a Song object for your audio player
        final songToPlay = Song(
          title: song.title,
          artists: song.artists.join(
            ', ',
          ), // Convert list to string for artists field
          albumArt: song.albumArt,
          audioUrl: response.data!.audioUrl!,
          videoId: song.videoId,
        );

        // Play the song using your audio player provider
        final audioNotifier = ref.read(audioProvider.notifier);
        await audioNotifier.playSong(
          songToPlay,
          playlistType: 'quick_picks',
          playbackSource: 'youtube_quick_picks',
        );

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now playing: ${song.title}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        print('✅ Successfully got audio URL and started playback');
      } else {
        throw Exception(response.message ?? 'Failed to get audio URL');
      }
    } catch (e) {
      print('❌ Error playing song: $e');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play song: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildLoadingContentWithSuggestions() {
    return Column(
      children: [
        const SizedBox(height: 40),

        // Loading animation
        SizedBox(
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
                  style: _getGoogleFont(ref.read(settingsProvider).appFont)
                      .copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildHistoryContentWithSuggestions() {
    final query = _searchController.text.trim();

    // Show suggestions if we have a non-empty query AND we have suggestions
    // Otherwise show history
    final showSuggestions = query.isNotEmpty && _suggestions.isNotEmpty;
    final showHistory = !showSuggestions;

    final itemsToShow = showSuggestions ? _suggestions : _searchHistory;
    final title = showSuggestions ? 'suggestions' : 'Recent searches';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: _getGoogleFont(ref.read(settingsProvider).appFont)
                    .copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              // Only show clear all button for history, not suggestions
              if (showHistory && _searchHistory.isNotEmpty)
                TextButton(
                  onPressed: _clearHistory,
                  child: Text(
                    'Clear All',
                    style: _getGoogleFont(ref.read(settingsProvider).appFont)
                        .copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: itemsToShow.isEmpty
              ? Center(
                  child: Text(
                    showSuggestions
                        ? 'No suggestions found'
                        : 'No recent searches',
                    style: _getGoogleFont(ref.read(settingsProvider).appFont)
                        .copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                )
              : ListView.builder(
                  itemCount: itemsToShow.length,
                  itemBuilder: (context, index) {
                    final item = itemsToShow[index];
                    return ListTile(
                      leading: Icon(
                        showSuggestions ? Icons.search : Icons.history,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      title: Text(
                        item,
                        style:
                            _getGoogleFont(
                              ref.read(settingsProvider).appFont,
                            ).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      // Only show remove button for history items, not suggestions
                      trailing: showHistory
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              onPressed: () => _removeFromHistory(item),
                            )
                          : null,
                      onTap: () => _selectHistoryItem(item),
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
            style: _getGoogleFont(ref.read(settingsProvider).appFont).copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
                return _buildErrorStateQuickPicks();
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
                        style: _getCurrentFontStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artists,
                        style: _getCurrentFontStyle(fontSize: 14),
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
                    showSongOptionsSheet(context, ref, song);
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
            style: _getGoogleFont(ref.read(settingsProvider).appFont).copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for something else',
            style: _getGoogleFont(ref.read(settingsProvider).appFont).copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
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
            style: _getCurrentFontStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ).copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: _getCurrentFontStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ).copyWith(color: Theme.of(context).colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _performSearch(context),
            child: Text('Try Again', style: _getCurrentFontStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // Updated font style getter that reacts to changes
  TextStyle _getCurrentFontStyle({double? fontSize, FontWeight? fontWeight}) {
    final settings = ref.watch(settingsProvider);
    return _getGoogleFont(
      settings.appFont,
    ).copyWith(fontSize: fontSize, fontWeight: fontWeight);
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
