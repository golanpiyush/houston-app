import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:wikipedia/wikipedia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/models/song.dart';
import 'package:houston/providers/audio_state_provider.dart';
import 'package:houston/providers/ytmusic_provider.dart';

class ArtistInfoPage extends ConsumerStatefulWidget {
  final String artistName;
  final String? artistImage;
  final List<Song>? initialSongs;

  const ArtistInfoPage({
    super.key,
    required this.artistName,
    this.artistImage,
    this.initialSongs,
  });

  @override
  ConsumerState<ArtistInfoPage> createState() => _ArtistInfoPageState();
}

class _ArtistInfoPageState extends ConsumerState<ArtistInfoPage>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _listController;
  late Animation<double> _headerAnimation;
  late Animation<double> _listAnimation;

  // Add these new variables
  bool _showWikipediaInfo = false;
  String? _artistBio;
  String? _activeYears;
  String? _wikipediaImageUrl;
  bool _loadingWikipedia = false;
  String? _wikipediaArtistImage;
  late AnimationController _wikipediaController;
  late Animation<double> _wikipediaAnimation;

  List<Song> _songs = [];
  bool _hasStartedFetching = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSongs();
    _initializeWikipediaAnimation(); // Add this
    _fetchWikipediaArtistImage();
  }

  // Add this new method
  void _initializeWikipediaAnimation() {
    _wikipediaController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _wikipediaAnimation = CurvedAnimation(
      parent: _wikipediaController,
      curve: Curves.easeInOutCubic,
    );
  }

  void _initializeAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutQuart,
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _listController.forward();
    });
  }

  void _initializeSongs() {
    if (widget.initialSongs != null) {
      setState(() {
        _songs = widget.initialSongs!;
      });
    } else {
      // Multiple approaches to ensure fetch gets called
      print('No initial songs, scheduling fetch...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('Post frame callback executing...');
          _fetchArtistSongs();
        }
      });

      // Also try with microtask as backup
      Future.microtask(() {
        if (mounted && !_hasStartedFetching) {
          print('Microtask backup executing...');
          _fetchArtistSongs();
        }
      });
    }
  }

  // 3. New method to fetch only Wikipedia image for artist profile
  Future<void> _fetchWikipediaArtistImage() async {
    try {
      final wikipedia = Wikipedia();
      final searchResults = await wikipedia.searchQuery(
        searchQuery: widget.artistName,
        limit: 1,
      );

      if (searchResults != null &&
          searchResults.query != null &&
          searchResults.query!.search != null &&
          searchResults.query!.search!.isNotEmpty) {
        final firstResult = searchResults.query!.search!.first;

        if (firstResult.pageid != null) {
          // Get high-quality Wikipedia image
          try {
            final imageResponse = await http.get(
              Uri.parse(
                'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(firstResult.title ?? widget.artistName)}',
              ),
            );
            if (imageResponse.statusCode == 200) {
              final imageData = json.decode(imageResponse.body);
              if (imageData['thumbnail'] != null) {
                // Get original high-quality image instead of thumbnail
                String imageUrl = imageData['thumbnail']['source'];
                // Replace thumbnail resolution with higher quality
                imageUrl = imageUrl.replaceAll(RegExp(r'/thumb/'), '/');
                imageUrl = imageUrl.replaceAll(RegExp(r'/\d+px-[^/]+$'), '');

                if (mounted) {
                  setState(() {
                    _wikipediaArtistImage = imageUrl;
                  });
                }
              }
            }
          } catch (e) {
            print('Error fetching Wikipedia artist image: $e');
          }
        }
      }
    } catch (e) {
      print('Error in _fetchWikipediaArtistImage: $e');
    }
  }

  // Fix 2: Update _fetchArtistSongs method
  Future<void> _fetchArtistSongs() async {
    print('_fetchArtistSongs called for: ${widget.artistName}');
    if (!mounted) return;
    if (_hasStartedFetching) return;
    setState(() {
      _hasStartedFetching = true;
    });
    try {
      final ytMusicNotifier = ref.read(ytMusicProvider.notifier);
      ytMusicNotifier.clearArtistSongs();
      // Start streaming with proper await for initial response
      ytMusicNotifier.streamArtistSongs(
        artistName: widget.artistName,
        limit: 15,
        context: context,
      );
      // Wait longer for initial results before showing empty state
      await Future.delayed(const Duration(seconds: 5));
    } catch (e) {
      print('Error in _fetchArtistSongs: $e');
      if (mounted) {
        setState(() {
          _hasStartedFetching = false;
        });
      }
    }
  }

  // Fixed Wikipedia fetch method
  Future<void> _fetchWikipediaInfo() async {
    if (_loadingWikipedia) return;
    setState(() {
      _loadingWikipedia = true;
    });
    try {
      final wikipedia = Wikipedia();
      // Search for the artist - FIXED: Added searchQuery parameter
      final searchResults = await wikipedia.searchQuery(
        searchQuery: widget.artistName,
        limit: 5, // Changed from resultsLimit to limit
      );

      // FIXED: Null safety check
      if (searchResults != null &&
          searchResults.query != null &&
          searchResults.query!.search != null &&
          searchResults.query!.search!.isNotEmpty) {
        // Get the first result (most relevant)
        final firstResult = searchResults.query!.search!.first;

        // FIXED: Use the correct method to get page data
        if (firstResult.pageid != null) {
          final pageData = await wikipedia.searchSummaryWithPageId(
            pageId: firstResult.pageid!,
          );

          if (pageData != null) {
            // Extract bio (first paragraph)
            String bio = pageData.extract ?? pageData.description ?? '';
            if (bio.length > 300) {
              bio = bio.substring(0, 300) + '...';
            }

            // Try to extract active years from the extract
            String? activeYears;
            final yearRegex = RegExp(r'(\d{4})[-–](\d{4}|\w+)');
            final match = yearRegex.firstMatch(pageData.extract ?? '');
            if (match != null) {
              activeYears = 'Active: ${match.group(0)}';
            } else {
              // Look for birth year patterns
              final birthRegex = RegExp(r'born.*?(\d{4})');
              final birthMatch = birthRegex.firstMatch(pageData.extract ?? '');
              if (birthMatch != null) {
                activeYears = 'Active since ${birthMatch.group(1)}';
              }
            }

            // Try to get Wikipedia image
            String? imageUrl;
            try {
              final imageResponse = await http.get(
                Uri.parse(
                  'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(pageData.title ?? widget.artistName)}',
                ),
              );
              if (imageResponse.statusCode == 200) {
                final imageData = json.decode(imageResponse.body);
                if (imageData['thumbnail'] != null) {
                  imageUrl = imageData['thumbnail']['source'];
                }
              }
            } catch (e) {
              print('Error fetching Wikipedia image: $e');
            }

            if (mounted) {
              setState(() {
                _artistBio = bio;
                _activeYears = activeYears ?? 'Active years unknown';
                _wikipediaImageUrl = imageUrl;
                _loadingWikipedia = false;
              });
            }
          } else {
            // Handle case where page data is null
            if (mounted) {
              setState(() {
                _loadingWikipedia = false;
                _artistBio = 'No detailed information available';
                _activeYears = 'Information unavailable';
              });
            }
          }
        }
      } else {
        // Handle case where search results are empty or null
        if (mounted) {
          setState(() {
            _loadingWikipedia = false;
            _artistBio = 'No information found for this artist';
            _activeYears = 'Information unavailable';
          });
        }
      }
    } catch (e) {
      print('Error fetching Wikipedia info: $e');
      if (mounted) {
        setState(() {
          _loadingWikipedia = false;
          _artistBio = 'Unable to load artist information';
          _activeYears = 'Information unavailable';
        });
      }
    }
  }

  // Add this new method to create individual shimmer tiles
  Widget _buildShimmerTile(int index, bool isDark) {
    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        final animationDelay = index * 0.1;
        final adjustedAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _listController,
            curve: Interval(
              animationDelay.clamp(0.0, 1.0),
              (animationDelay + 0.3).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        return Transform.translate(
          offset: Offset(0, 30 * (1 - adjustedAnimation.value)),
          child: Opacity(
            opacity: adjustedAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Shimmer album art
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shimmer title
                        Container(
                          width: 200,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Shimmer artist
                        Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Shimmer more button
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    _wikipediaController.dispose(); // Add this
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Build called - hasStartedFetching: $_hasStartedFetching');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch the ytMusic provider state and react to changes
    final ytMusicState = ref.watch(ytMusicProvider);
    print(
      'ytMusicState - isLoading: ${ytMusicState.isLoading}, artistSongs count: ${ytMusicState.artistSongs.length}',
    );

    // FIXED: Listen to provider changes and update local state
    ref.listen<YtMusicState>(ytMusicProvider, (previous, current) {
      print(
        'Provider state changed - artistSongs: ${current.artistSongs.length}',
      );

      // Update local songs immediately for play functionality
      if (current.artistSongs.isNotEmpty && mounted) {
        setState(() {
          _songs = current.artistSongs;
        });
      }

      // Handle error states
      if (current.error != null && previous?.error != current.error) {
        print('Error state detected: ${current.error}');
        if (mounted) {
          setState(() {
            _hasStartedFetching = false;
          });
        }
      }
    });

    // Force trigger fetch in build if conditions are met
    if (widget.initialSongs == null &&
        !_hasStartedFetching &&
        ytMusicState.artistSongs.isEmpty &&
        !ytMusicState.isLoading) {
      print('Force triggering fetch from build method...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasStartedFetching) {
          print('Executing forced fetch...');
          _fetchArtistSongs();
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, isDark),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _listAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - _listAnimation.value)),
                  child: Opacity(
                    opacity: _listAnimation.value,
                    child: _buildContent(context, isDark, ytMusicState),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 320,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _headerAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * _headerAnimation.value),
              child: Opacity(
                opacity: _headerAnimation.value,
                child: _buildHeaderBackground(isDark),
              ),
            );
          },
        ),
      ),
    );
  }

  // Updated _buildHeaderBackground with Wikipedia integration
  Widget _buildHeaderBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF2D1B69), const Color(0xFF1A1A1A)]
              : [Colors.blue.shade400, Colors.white],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  AnimatedOpacity(
                    opacity: _showWikipediaInfo ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: _buildArtistImage(),
                  ),
                  const SizedBox(height: 16),
                  _buildArtistName(),
                  const SizedBox(height: 8),
                  _buildSongCount(),
                ],
              ),
              // Wikipedia info overlay
              if (_showWikipediaInfo)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _wikipediaAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 50 * (1 - _wikipediaAnimation.value)),
                        child: Opacity(
                          opacity: _wikipediaAnimation.value,
                          child: _buildWikipediaInfo(isDark),
                        ),
                      );
                    },
                  ),
                ),
              // Wikipedia info button
              Positioned(
                top: 80,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: _loadingWikipedia
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _showWikipediaInfo
                                ? Icons.close
                                : Icons.info_outline,
                            color: Colors.white,
                          ),
                    onPressed: _toggleWikipediaInfo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add Wikipedia info widget
  // Add Wikipedia info widget
  Widget _buildWikipediaInfo(bool isDark) {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 60,
          bottom: 40, // Increased bottom margin to prevent overflow
        ),
        child: SingleChildScrollView(
          // Added scroll view to handle overflow
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Centered artist icon with loading state
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _wikipediaImageUrl != null
                            ? Image.network(
                                _wikipediaImageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey.withOpacity(0.2),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white.withOpacity(0.8),
                                                ),
                                          ),
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildDefaultArtistIcon(),
                              )
                            : _buildDefaultArtistIcon(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.artistName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_activeYears != null)
                            Text(
                              _activeYears!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_artistBio != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 120, // Limit bio text height
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _artistBio!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.language,
                      size: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Wikipedia',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build default artist icon (centered)
  Widget _buildDefaultArtistIcon() {
    return Container(
      color: Colors.grey.withOpacity(0.2),
      child: Center(
        child: Icon(
          Icons.person,
          size: 30,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }

  // Add Wikipedia info toggle method
  void _toggleWikipediaInfo() async {
    if (_showWikipediaInfo) {
      // Hide Wikipedia info
      _wikipediaController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showWikipediaInfo = false;
          });
        }
      });
    } else {
      // Show Wikipedia info
      if (_artistBio == null && !_loadingWikipedia) {
        await _fetchWikipediaInfo();
      }

      setState(() {
        _showWikipediaInfo = true;
      });
      _wikipediaController.forward();
    }
  }

  Widget _buildArtistImage() {
    return Hero(
      tag: 'artist_${widget.artistName}',
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: _wikipediaArtistImage != null
              ? Image.network(
                  _wikipediaArtistImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to original artist image if Wikipedia fails
                    return widget.artistImage != null
                        ? Image.network(
                            widget.artistImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultArtistIcon(),
                          )
                        : _buildDefaultArtistIcon();
                  },
                )
              : widget.artistImage != null
              ? Image.network(
                  widget.artistImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildDefaultArtistIcon(),
                )
              : _buildDefaultArtistIcon(),
        ),
      ),
    );
  }

  Widget _buildArtistName() {
    return Text(
      widget.artistName,
      style: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [
          const Shadow(
            color: Colors.black54,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSongCount() {
    final ytMusicState = ref.watch(ytMusicProvider);
    final isLoading = _hasStartedFetching && ytMusicState.isLoading;
    final isStreaming = ytMusicState.isStreaming;

    // Use current songs count (either local _songs or from provider)
    final currentSongs = _songs.isNotEmpty ? _songs : ytMusicState.artistSongs;
    final totalSongs = currentSongs.length;

    if (isLoading && totalSongs == 0) {
      return Text(
        'Loading songs...',
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: Colors.white.withOpacity(0.9),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Text(
      isStreaming
          ? '$totalSongs songs (loading more...) / 15'
          : '$totalSongs songs',
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: Colors.white.withOpacity(0.9),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    YtMusicState ytMusicState,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlayAllButton(context, isDark, ytMusicState),
          const SizedBox(height: 24),
          _buildSongsSection(context, isDark, ytMusicState),
        ],
      ),
    );
  }

  Widget _buildPlayAllButton(
    BuildContext context,
    bool isDark,
    YtMusicState ytMusicState,
  ) {
    final currentSongs = _songs.isNotEmpty ? _songs : ytMusicState.artistSongs;
    final hasLoadedSongs = currentSongs.isNotEmpty;
    final isInitialLoading =
        _hasStartedFetching && ytMusicState.isLoading && currentSongs.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: (hasLoadedSongs && !isInitialLoading)
            ? () => _playAllSongs()
            : null,
        icon: isInitialLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow, size: 24),
        label: Text(
          isInitialLoading ? 'Loading...' : 'Play All',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
        ),
      ),
    );
  }

  // Updated _buildSongsSection to prevent premature empty state
  Widget _buildSongsSection(
    BuildContext context,
    bool isDark,
    YtMusicState ytMusicState,
  ) {
    // Use provider songs directly for real-time updates
    final currentSongs = ytMusicState.artistSongs;
    final isInitialLoading =
        _hasStartedFetching && ytMusicState.isLoading && currentSongs.isEmpty;
    final isStreaming = ytMusicState.isStreaming;
    final hasError = ytMusicState.error != null;

    if (hasError) {
      return _buildErrorState(ytMusicState.error!);
    }

    // Show loading state only if no songs have arrived yet
    if (isInitialLoading) {
      return _buildLoadingState();
    }

    // Show empty state only if loading is complete and no songs
    final hasNoSongs =
        !ytMusicState.isLoading &&
        !isStreaming &&
        currentSongs.isEmpty &&
        _hasStartedFetching;

    if (hasNoSongs) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                'Songs',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.white
                      : const Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              if (isStreaming) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Single ListView that combines real songs and shimmer tiles
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: isStreaming
              ? math.max(
                  currentSongs.length + 3,
                  8,
                ) // Show at least 8 items during streaming
              : currentSongs
                    .length, // Show only actual songs when not streaming
          itemBuilder: (context, index) {
            if (index < currentSongs.length) {
              // Show actual song tile
              return _buildSongTile(currentSongs[index], index, isDark);
            } else if (isStreaming) {
              // Show shimmer tile for expected songs
              return _buildShimmerTile(index, isDark);
            } else {
              // This shouldn't happen, but return empty container as fallback
              return const SizedBox.shrink();
            }
          },
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSongTile(Song song, int index, bool isDark) {
    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        final animationDelay = index * 0.1;
        final adjustedAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _listController,
            curve: Interval(
              animationDelay.clamp(0.0, 1.0),
              (animationDelay + 0.3).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        return Transform.translate(
          offset: Offset(0, 30 * (1 - adjustedAnimation.value)),
          child: Opacity(
            opacity: adjustedAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _playSong(song, index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // Made tiles completely transparent/invisible
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildAlbumArt(song),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                song.artists,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showSongOptions(song),
                          icon: Icon(
                            Icons.more_vert,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumArt(Song song) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: song.albumArt != null && song.albumArt!.isNotEmpty
            ? Image.network(
                song.albumArt!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAlbumArt(),
              )
            : _buildDefaultAlbumArt(),
      ),
    );
  }

  Widget _buildDefaultAlbumArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade400],
        ),
      ),
      child: const Icon(Icons.music_note, size: 28, color: Colors.white),
    );
  }

  // Fix 3: Update the loading state builder to remove shimmer opacity
  Widget _buildLoadingState() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 8,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 200,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.music_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No songs found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This artist doesn\'t have any songs available.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchArtistSongs,
              icon: const Icon(Icons.refresh),
              label: Text('Try Again', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playSong(Song song, int index) {
    try {
      final audioNotifier = ref.read(audioProvider.notifier);
      audioNotifier.playArtistSongs(_songs, startIndex: index);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playing: ${song.title} by ${song.artists}',
            style: GoogleFonts.poppins(),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error playing song: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _playAllSongs() {
    if (_songs.isEmpty) return;

    try {
      final audioNotifier = ref.read(audioProvider.notifier);
      audioNotifier.playArtistSongs(_songs, startIndex: 0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playing all songs by ${widget.artistName}',
            style: GoogleFonts.poppins(),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error playing songs: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showSongOptions(Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSongOptionsSheet(song),
    );
  }

  Widget _buildSongOptionsSheet(Song song) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildAlbumArt(song),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artists,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: Icons.play_arrow,
              title: 'Play',
              onTap: () {
                Navigator.pop(context);
                final index = _songs.indexOf(song);
                _playSong(song, index);
              },
            ),
            _buildOptionTile(
              icon: Icons.playlist_add,
              title: 'Add to Playlist',
              onTap: () {
                Navigator.pop(context);
                // Implement add to playlist functionality
              },
            ),
            _buildOptionTile(
              icon: Icons.favorite_border,
              title: 'Add to Favorites',
              onTap: () {
                Navigator.pop(context);
                // Implement add to favorites functionality
              },
            ),
            _buildOptionTile(
              icon: Icons.download,
              title: 'Download',
              onTap: () {
                Navigator.pop(context);
                // Implement download functionality
              },
            ),
            _buildOptionTile(
              icon: Icons.share,
              title: 'Share',
              onTap: () {
                Navigator.pop(context);
                // Implement share functionality
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white : Colors.black87),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
