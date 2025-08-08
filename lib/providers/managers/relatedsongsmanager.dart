import 'package:houston/models/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/providers/ytmusic_provider.dart';
import 'dart:async';

class RelatedSongsManager {
  final Ref _ref;
  final Function(List<Song>, bool) _onUpdate;
  final List<Song> _relatedSongs = [];
  bool _isFetching = false;
  ProviderSubscription<YtMusicState>? _ytSubscription;
  StreamController<List<Song>>? _songStreamController;
  String? _currentOperationId;
  Timer? _fetchTimeoutTimer;
  Song? _currentSeedSong;
  bool _hasStartedStreaming = false;
  bool _isDisposed = false;

  // Queue management
  final Map<String, List<Song>> _queueCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidDuration = Duration(minutes: 15);

  RelatedSongsManager(this._ref, this._onUpdate) {
    print('🏗️ RelatedSongsManager initialized');
    _initStream();
  }

  void _initStream() {
    if (_isDisposed) return;
    
    print('🔧 Initializing stream controller');
    _songStreamController = StreamController<List<Song>>.broadcast(
      onCancel: () {
        print('📡 Stream controller cancelled');
        _cleanup();
      },
    );
  }

   Future<void> fetchForSong(Song song) async {
  if (_isDisposed) return;

  print('🎯 fetchForSong called for: ${song.title} by ${song.artists}');
  
  // FIXED: Always allow new fetch for different songs, even if currently fetching
  if (_isFetching) {
    if (_currentSeedSong?.videoId == song.videoId) {
      print('⚠️ Already fetching for the same song, ignoring duplicate request');
      return;
    } else {
      print('🔄 New song while fetching, cancelling current fetch');
      await _cancelOngoingFetch();
    }
  }
  
  // FIXED: Clear previous state for new fetches
  await _cancelOngoingFetch();
  _relatedSongs.clear();
  
  final operationId = DateTime.now().millisecondsSinceEpoch.toString();
  _currentOperationId = operationId;
  _currentSeedSong = song;
  _hasStartedStreaming = false;

  print('🆔 New operation ID: $operationId');
  
  // Check cache first
  final cacheKey = '${song.videoId}_${song.title}_${song.artists}';
  if (_queueCache.containsKey(cacheKey)) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp != null && DateTime.now().difference(timestamp) < _cacheValidDuration) {
      print('💾 Using cached songs for: ${song.title}');
      final cachedSongs = _queueCache[cacheKey]!;
      _relatedSongs.addAll(cachedSongs);
      _updateStreamController();
      _onUpdate(_relatedSongs, false);
      return;
    }
  }
  
  _isFetching = true;
  _onUpdate(_relatedSongs, true);

  try {
    await _performFetch(song, operationId, cacheKey);
  } catch (e) {
    print('❌ Error in fetchForSong: $e');
    _handleFetchError(e.toString());
  }
}
  Future<void> _performFetch(Song song, String operationId, String cacheKey) async {
    if (_isDisposed) return;

    print('🚀 Starting related songs fetch for: ${song.title}');

    final ytNotifier = _ref.read(ytMusicProvider.notifier);
    print('📻 Got YtMusic notifier');
    
    ytNotifier.clearRelatedSongs();
    print('🧽 Cleared previous related songs from YtMusic');

    // Setup timeout with longer duration for initial fetch
    _fetchTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_isDisposed) return;
      
      print('⏰ Fetch timeout triggered for operation: $operationId');
      if (_currentOperationId == operationId && _isFetching) {
        print('⏰ Timeout fetching related songs - handling error');
        _handleFetchError('Timeout reached');
      }
    });

    print('⏱️ Timeout timer set (45 seconds)');

    // Listen for updates BEFORE starting the fetch
    print('👂 Setting up YtMusic state listener');
    _ytSubscription = _ref.listen<YtMusicState>(
      ytMusicProvider,
      (previous, next) {
        if (_isDisposed) return;
        
        print('🔔 YtMusic state changed - operation: $operationId');
        print('   Previous state: isLoading=${previous?.isLoading}, isStreaming=${previous?.isStreaming}, songs=${previous?.relatedSongs.length ?? 0}');
        print('   Next state: isLoading=${next.isLoading}, isStreaming=${next.isStreaming}, songs=${next.relatedSongs.length}, error=${next.error}');
        _handleYtMusicStateChange(next, operationId, cacheKey);
      },
      fireImmediately: false,
    );

    print('🎵 Starting streamRelatedSongs...');
    // Start streaming related songs
    ytNotifier.streamRelatedSongs(
      songName: song.title,
      artistName: song.artists,
      limit: 5, // Increased limit for better queue
      audioQuality: 'high',
      thumbnailQuality: 'very_high',
    );
    print('✅ streamRelatedSongs call completed');

    // Monitor streaming start
    _monitorStreamingStart(operationId);
  }

  void _monitorStreamingStart(String operationId) {
    if (_isDisposed) return;

    Timer(const Duration(milliseconds: 500), () {
      if (_isDisposed) return;
      
      if (_currentOperationId == operationId && _isFetching) {
        final currentState = _ref.read(ytMusicProvider);
        print('🔍 Checking state after delay: isLoading=${currentState.isLoading}, isStreaming=${currentState.isStreaming}');
        
        if (!currentState.isLoading && !currentState.isStreaming && !_hasStartedStreaming) {
          print('⚠️ No streaming activity detected, but giving it more time...');
          
          Timer(const Duration(seconds: 5), () {
            if (_isDisposed) return;
            
            if (_currentOperationId == operationId && _isFetching) {
              final laterState = _ref.read(ytMusicProvider);
              if (!laterState.isLoading && !laterState.isStreaming && 
                  laterState.relatedSongs.isEmpty && !_hasStartedStreaming) {
                print('❌ Still no activity after extended wait - timing out');
                _handleFetchError('No streaming activity detected');
              }
            }
          });
        }
      }
    });
  }

  /// Remove first N songs - FIXED in RelatedSongsManager
void removeFirstN(int count) {
  if (_isDisposed) return;
  
  print('🗑️ removeFirstN called with count: $count');
  print('   Current queue size: ${_relatedSongs.length}');
  
  if (count <= 0 || _relatedSongs.isEmpty) {
    print('⚠️ Invalid count or empty queue, nothing to remove');
    return;
  }
  
  final actualCount = count > _relatedSongs.length ? _relatedSongs.length : count;
  _relatedSongs.removeRange(0, actualCount);
  
  print('🎵 Removed $actualCount songs');
  print('   New queue size: ${_relatedSongs.length}');
  
  _updateStreamController();
  _onUpdate(_relatedSongs, _isFetching);

  // FIXED: Only trigger additional fetch if queue is critically low
  if (_relatedSongs.length <= 2 && !_isFetching && _currentSeedSong != null) {
    print('🔍 Queue critically low (${_relatedSongs.length}), triggering fetch');
    Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        // _fetchAdditionalSongs();
        print('PASSED-FIRST-N-REMOVE');
      }
    });
  }
}
  void removeFirst() {
    removeFirstN(1);
  }

  bool _isSameSong(Song song) {
  // Only consider it the same song if we're currently fetching
  if (_isFetching) {
    final isSame = _currentSeedSong?.videoId == song.videoId;
    print('🔄 Checking if same song during fetch: ${song.videoId} == ${_currentSeedSong?.videoId} = $isSame');
    return isSame;
  }
  
  // If not fetching, always allow new fetches
  return false;
}

   void _handleYtMusicStateChange(YtMusicState state, String operationId, String cacheKey) {
    if (_isDisposed) return;
    
    print('🎵 _handleYtMusicStateChange called');
    print('   Operation ID: $operationId (current: $_currentOperationId)');
    print('   State: isLoading=${state.isLoading}, isStreaming=${state.isStreaming}');
    print('   Related songs: ${state.relatedSongs.length}');
    print('   Error: ${state.error}');
    print('   Has started streaming: $_hasStartedStreaming');

    if (_currentOperationId != operationId) {
      print('! Operation ID mismatch, ignoring state change');
      return;
    }

    if (state.error != null) {
      print('❌ Error in YtMusic state: ${state.error}');
      _handleFetchError(state.error!);
      return;
    }

    // Track if we've started streaming at any point
    if (state.isLoading || state.isStreaming) {
      if (!_hasStartedStreaming) {
        _hasStartedStreaming = true;
        print('🚀 Streaming has started!');
      }
    }

    // Handle progressive loading - process songs as they come
    if (state.relatedSongs.isNotEmpty) {
      final currentSongsCount = _relatedSongs.length;
      final newSongsAvailable = state.relatedSongs.length > currentSongsCount;
      
      if (newSongsAvailable || currentSongsCount == 0) {
        print('📈 Processing songs - current: $currentSongsCount, available: ${state.relatedSongs.length}');
        _hasStartedStreaming = true;
        
        // Determine if this is partial or complete
        final isPartial = state.isStreaming || state.isLoading;
        _handleNewSongs(state.relatedSongs, operationId, partial: isPartial, cacheKey: cacheKey);
      }
    }

    // Handle completion
    if (!state.isStreaming && !state.isLoading && _hasStartedStreaming) {
      print('✅ Streaming/loading completed');
      
      if (state.relatedSongs.isEmpty && _relatedSongs.isEmpty) {
        print('😔 No songs found after completion');
        _handleFetchError('No songs returned');
      } else if (state.relatedSongs.isNotEmpty) {
        print('🎉 Final processing of ${state.relatedSongs.length} songs');
        _handleNewSongs(state.relatedSongs, operationId, partial: false, cacheKey: cacheKey);
      } else {
        print('✅ Using ${_relatedSongs.length} songs already processed');
        _completeFetch();
        _onUpdate(_relatedSongs, false);
      }
    } else if (!_hasStartedStreaming && !state.isLoading && !state.isStreaming) {
      print('⏳ Waiting for streaming to start...');
    }
  }

  /// Handle new songs - FIXED in RelatedSongsManager
void _handleNewSongs(List<Song> newSongs, String operationId, {bool partial = false, String? cacheKey}) {
  if (_isDisposed) return;
  
  print('🎼 _handleNewSongs called');
  print('   Operation ID: $operationId (current: $_currentOperationId)');
  print('   New songs: ${newSongs.length}');
  print('   Partial: $partial');
  print('   Current queue size: ${_relatedSongs.length}');

  if (_currentOperationId != operationId) {
    print('⚠️ Operation ID mismatch in _handleNewSongs, ignoring');
    return;
  }

  // Filter and deduplicate songs
  final filteredSongs = _filterAndDeduplicateSongs(newSongs);
  print('   Filtered songs: ${filteredSongs.length}');
  
  bool hasNewSongs = false;
  if (filteredSongs.isNotEmpty) {
    _relatedSongs.addAll(filteredSongs);
    hasNewSongs = true;
    print('🎵 Added ${filteredSongs.length} songs (total: ${_relatedSongs.length})');
    
    // Update stream controller
    _updateStreamController();
  }

  // FIXED: Always call callback when fetch completes, even with no new songs
  if (!partial) {
    print('✅ Fetch completed');
    _completeFetch();
    
    // Final callback - this is crucial for autoplay to work
    _onUpdate(_relatedSongs, false);
    print('🔄 Final callback with ${_relatedSongs.length} songs');
    
    // Cache the results
    if (cacheKey != null && _relatedSongs.isNotEmpty) {
      _queueCache[cacheKey] = List.from(_relatedSongs);
      _cacheTimestamps[cacheKey] = DateTime.now();
      print('💾 Cached ${_relatedSongs.length} songs for key: $cacheKey');
    }
  } else if (hasNewSongs) {
    // For partial updates, only call if we have new songs
    _onUpdate(_relatedSongs, true);
    print('🔄 Partial update callback with ${_relatedSongs.length} songs');
  }

  // Check if we need more songs (only for completed fetches)
  if (!partial && _relatedSongs.length <= 10 && !_isDisposed) {
    print('🔍 Need more songs (${_relatedSongs.length}), scheduling additional fetch');
    Timer(const Duration(seconds: 2), () {
      if (!_isDisposed && _relatedSongs.length <= 10) {
        // _fetchAdditionalSongs();
        print('PASSED-_handleNewSongs');
      }
    });
  }
}

  /// Filter songs with better validation - ADD TO RelatedSongsManager
List<Song> _filterAndDeduplicateSongs(List<Song> newSongs) {
  final existingIds = _relatedSongs.map((s) => s.videoId).toSet();
  final uniqueSongs = newSongs.where((s) => 
    s.videoId.isNotEmpty && 
    !existingIds.contains(s.videoId) &&
    s.title.isNotEmpty &&
    s.artists.isNotEmpty &&
    s.audioUrl != null &&              // ADDED: Ensure audio URL exists
    s.audioUrl!.isNotEmpty &&          // ADDED: Ensure audio URL is not empty
    _isValidAudioUrl(s.audioUrl!)      // ADDED: Validate audio URL format
  ).toList();

  print('🔍 Existing songs: ${_relatedSongs.length}');
  print('🆕 Valid new songs: ${uniqueSongs.length}');
  
  return uniqueSongs;
}
/// Validate audio URL - ADD TO RelatedSongsManager
bool _isValidAudioUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  } catch (e) {
    print('⚠️ Invalid URL format: $url');
    return false;
  }
}

  void _updateStreamController() {
    if (_songStreamController != null && !_songStreamController!.isClosed) {
      _songStreamController!.add(List.from(_relatedSongs));
      print('📡 Updated stream controller with ${_relatedSongs.length} songs');
    } else {
      print('⚠️ Stream controller is null or closed');
    }
  }

  void _completeFetch() {
    if (_isDisposed) return;
    
    print('✅ Fetch completed, setting _isFetching to false');
    _isFetching = false;
    _fetchTimeoutTimer?.cancel();
    _fetchTimeoutTimer = null;
    
    // Close the YT subscription for this operation
    if (_ytSubscription != null) {
      _ytSubscription!.close();
      _ytSubscription = null;
    }
  }

  // Future<void> _fetchAdditionalSongs() async {
  //   if (_isDisposed || _currentSeedSong == null || _isFetching) {
  //     print('⏭️ Skipping additional fetch - disposed, no seed song, or already fetching');
  //     return;
  //   }

  //   print('🔍 Fetching additional related songs...');
  //   _isFetching = true;
  //   _hasStartedStreaming = false;
  //   _onUpdate(_relatedSongs, true);

  //   try {
  //     final ytNotifier = _ref.read(ytMusicProvider.notifier);
      
  //     // Use different search parameters for variety
  //      ytNotifier.streamRelatedSongs(
  //       songName: _currentSeedSong!.title,
  //       artistName: _currentSeedSong!.artists,
  //       limit: 3,
  //       audioQuality: 'high',
  //       thumbnailQuality: 'very_high',
  //     );
      
  //     print('✅ Additional fetch initiated');
      
  //     // Set a shorter timeout for additional fetches
  //     _fetchTimeoutTimer = Timer(const Duration(seconds: 20), () {
  //       if (_isDisposed) return;
        
  //       if (_isFetching) {
  //         print('⏰ Additional fetch timeout');
  //         _isFetching = false;
  //         _onUpdate(_relatedSongs, false);
  //       }
  //     });
      
  //   } catch (e) {
  //     print('⚠️ Error fetching additional songs: $e');
  //     _isFetching = false;
  //     _onUpdate(_relatedSongs, false);
  //   }
  // }

  void clearQueue() {
    if (_isDisposed) return;
    
    print('🧹 RelatedSongsManager: Clearing related songs queue');
    _relatedSongs.clear();
    
    // Clear cache for current seed
    if (_currentSeedSong != null) {
      final cacheKey = '${_currentSeedSong!.videoId}_${_currentSeedSong!.title}_${_currentSeedSong!.artists}';
      _queueCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
    }
    
    _updateStreamController();
    _onUpdate(_relatedSongs, false);
    print('🔄 Called _onUpdate callback with empty queue');
  }

  void _handleFetchError(String error) {
    if (_isDisposed) return;
    
    print('❌ _handleFetchError called: $error');
    _cleanup();
    _isFetching = false;
    _onUpdate(_relatedSongs, false);
    print('🧹 Cleaned up after error');
  }

  Future<void> _cancelOngoingFetch() async {
    if (_isDisposed) return;
    
    print('🛑 _cancelOngoingFetch called');
    
    if (_fetchTimeoutTimer != null) {
      _fetchTimeoutTimer!.cancel();
      _fetchTimeoutTimer = null;
      print('⏰ Cancelled timeout timer');
    }
    
    if (_ytSubscription != null) {
      _ytSubscription!.close();
      _ytSubscription = null;
      print('👂 Closed YtMusic subscription');
    }
    
    _hasStartedStreaming = false;
    _isFetching = false;
    
    print('🆔 Ready for new fetch operation');

    try {
      final ytNotifier = _ref.read(ytMusicProvider.notifier);
      ytNotifier.clearRelatedSongs();
      print('🧽 Cleared YtMusic related songs');
    } catch (e) {
      print('⚠️ Error cancelling fetch: $e');
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    
    print('♻️ RelatedSongsManager dispose called');
    _isDisposed = true;
    
    await _cancelOngoingFetch();
    
    if (_songStreamController != null && !_songStreamController!.isClosed) {
      await _songStreamController!.close();
      print('📡 Stream controller closed');
    }
    _songStreamController = null;
    
    _relatedSongs.clear();
    _queueCache.clear();
    _cacheTimestamps.clear();
    
    print('♻️ RelatedSongsManager disposed');
  }

  void _cleanup() {
    if (_isDisposed) return;
    
    print('🧹 _cleanup called');
    
    if (_fetchTimeoutTimer != null) {
      _fetchTimeoutTimer!.cancel();
      _fetchTimeoutTimer = null;
      print('⏰ Cleaned up timeout timer');
    }
    
    if (_ytSubscription != null) {
      _ytSubscription!.close();
      _ytSubscription = null;
      print('👂 Cleaned up YtMusic subscription');
    }
    
    _hasStartedStreaming = false;
  }

  // Getters
  int get queueSize => _relatedSongs.length;
  bool get isEmpty => _relatedSongs.isEmpty;
  bool get isFetching => _isFetching;
  List<Song> get currentQueue => List.unmodifiable(_relatedSongs);
  Song? get currentSeedSong => _currentSeedSong;
  
  // Stream getter for external listeners
  Stream<List<Song>>? get songStream => _songStreamController?.stream;
}