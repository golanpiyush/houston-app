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
  bool _hasStartedStreaming = false; // NEW: Track if streaming has actually started

  RelatedSongsManager(this._ref, this._onUpdate) {
    print('🏗️ RelatedSongsManager initialized');
    _initStream();
  }

  void _initStream() {
    print('🔧 Initializing stream controller');
    _songStreamController = StreamController<List<Song>>.broadcast(
      onCancel: () {
        print('📡 Stream controller cancelled');
        _cleanup();
      },
    );
  }

  Future<void> fetchForSong(Song song) async {
  print('🎯 fetchForSong called for: ${song.title} by ${song.artists}');
  print('🔍 Current seed song: ${_currentSeedSong?.title}');
  print('🔄 Is fetching: $_isFetching');
  
  if (_isSameSong(song)) {
    print('⏭️ Same song, skipping fetch');
    return;
  }
  
  // Cancel ongoing fetch BEFORE setting new operation ID
  await _cancelOngoingFetch();
  
  // Clear related songs immediately when starting a new search
  _relatedSongs.clear();
  print('🧹 Cleared existing related songs for new search');
  
  // Set operation ID AFTER cancelling previous operations
  final operationId = DateTime.now().millisecondsSinceEpoch.toString();
  _currentOperationId = operationId;
  _currentSeedSong = song;
  _hasStartedStreaming = false; // Reset streaming flag

  print('🆔 New operation ID: $operationId');

  // Update UI immediately with empty list to show the clear state
  _onUpdate(_relatedSongs, false);

  _isFetching = true;
  _onUpdate(_relatedSongs, true);

  print('🚀 Starting related songs fetch for: ${song.title}');

  try {
    final ytNotifier = _ref.read(ytMusicProvider.notifier);
    print('📻 Got YtMusic notifier');
    
    ytNotifier.clearRelatedSongs();
    print('🧽 Cleared previous related songs from YtMusic');

    // Setup timeout with longer duration for initial fetch
    _fetchTimeoutTimer = Timer(const Duration(seconds: 30), () {
      print('⏰ Fetch timeout triggered for operation: $operationId');
      if (_currentOperationId == operationId && _isFetching) {
        print('⏰ Timeout fetching related songs - handling error');
        _handleFetchError('Timeout reached');
      }
    });

    print('⏱️ Timeout timer set (30 seconds)');

    // Listen for updates BEFORE starting the fetch
    print('👂 Setting up YtMusic state listener');
    _ytSubscription = _ref.listen<YtMusicState>(
      ytMusicProvider,
      (previous, next) {
        print('🔔 YtMusic state changed - operation: $operationId');
        print('   Previous state: isLoading=${previous?.isLoading}, isStreaming=${previous?.isStreaming}, songs=${previous?.relatedSongs.length ?? 0}');
        print('   Next state: isLoading=${next.isLoading}, isStreaming=${next.isStreaming}, songs=${next.relatedSongs.length}, error=${next.error}');
        _handleYtMusicStateChange(next, operationId);
      },
      fireImmediately: false, // Don't fire immediately to avoid stale state
    );

    print('🎵 Starting streamRelatedSongs...');
    // Start streaming related songs
    ytNotifier.streamRelatedSongs(
      songName: song.title,
      artistName: song.artists,
      limit: 35,
      audioQuality: 'high',
      thumbnailQuality: 'very_high',
    );
    print('✅ streamRelatedSongs call completed');

    // Add a small delay to allow the streaming to start
    // Then check the state to see if streaming has begun
    Timer(const Duration(milliseconds: 500), () {
      if (_currentOperationId == operationId && _isFetching) {
        final currentState = _ref.read(ytMusicProvider);
        print('🔍 Checking state after delay: isLoading=${currentState.isLoading}, isStreaming=${currentState.isStreaming}');
        
        // If we're not loading or streaming after the delay, something might be wrong
        // But give it more time before failing
        if (!currentState.isLoading && !currentState.isStreaming && !_hasStartedStreaming) {
          print('⚠️ No streaming activity detected, but giving it more time...');
          
          // Set another check after more time
          Timer(const Duration(seconds: 3), () {
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

  } catch (e) {
    print('💥 Exception in fetchForSong: $e');
    _handleFetchError(e.toString());
  }
}

void removeFirstN(int count) {
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
  
  _onUpdate(_relatedSongs, _isFetching);

  // Trigger queue expansion if needed
  if (_relatedSongs.length <= 3 && !_isFetching) {
    print('🔍 Queue running low, triggering additional fetch');
    _fetchAdditionalSongs();
  }
}

  bool _isSameSong(Song song) {
    final isSame = _currentSeedSong?.videoId == song.videoId && _isFetching;
    print('🔄 Checking if same song: ${song.videoId} == ${_currentSeedSong?.videoId} && $_isFetching = $isSame');
    return isSame;
  }

  void _handleYtMusicStateChange(YtMusicState state, String operationId) {
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

    // FIXED: Track if we've started streaming at any point
    if (state.isLoading || state.isStreaming) {
      _hasStartedStreaming = true;
      print('🚀 Streaming has started!');
    }

    // FIXED: Only consider it "complete" if we've actually started streaming first
    if (!state.isStreaming && !state.isLoading && _hasStartedStreaming) {
      print('✅ Streaming/loading completed (after starting)');
      if (state.relatedSongs.isNotEmpty) {
        print('🎉 Found ${state.relatedSongs.length} related songs');
        _handleNewSongs(state.relatedSongs, operationId);
      } else {
        print('😔 No songs returned after completion');
        _handleFetchError('No songs returned');
      }
    } else if (state.relatedSongs.isNotEmpty) {
      print('📈 Progressive loading - ${state.relatedSongs.length} songs available');
      _hasStartedStreaming = true; // Mark as started when we receive songs
      // Progressive loading - update UI as songs arrive
      _handleNewSongs(state.relatedSongs, operationId, partial: true);
    } else if (!_hasStartedStreaming) {
      print('⏳ Waiting for streaming to start...');
    } else {
      print('⏳ Still loading/streaming, no songs yet');
    }
  }

  void _handleNewSongs(List<Song> newSongs, String operationId, {bool partial = false}) {
    print('🎼 _handleNewSongs called');
    print('   Operation ID: $operationId (current: $_currentOperationId)');
    print('   New songs: ${newSongs.length}');
    print('   Partial: $partial');

    if (_currentOperationId != operationId) {
      print('⚠️ Operation ID mismatch in _handleNewSongs, ignoring');
      return;
    }

    // Deduplicate songs
    final existingIds = _relatedSongs.map((s) => s.videoId).toSet();
    final uniqueSongs = newSongs.where((s) => !existingIds.contains(s.videoId)).toList();

    print('🔍 Existing songs: ${_relatedSongs.length}');
    print('🆕 Unique new songs: ${uniqueSongs.length}');

    if (uniqueSongs.isEmpty && _relatedSongs.isNotEmpty) {
      print('⏭️ No unique songs to add, but we have existing songs');
      if (!partial) {
        _isFetching = false;
        _fetchTimeoutTimer?.cancel();
        _fetchTimeoutTimer = null;
      }
      return;
    }

    if (uniqueSongs.isNotEmpty) {
      _relatedSongs.addAll(uniqueSongs);
      
      // Update stream controller
      if (_songStreamController != null && !_songStreamController!.isClosed) {
        _songStreamController!.add(_relatedSongs);
        print('📡 Updated stream controller with ${_relatedSongs.length} songs');
      } else {
        print('⚠️ Stream controller is null or closed');
      }
      
      _onUpdate(_relatedSongs, partial);
      print('🔄 Called _onUpdate callback');
      print('🎵 Added ${uniqueSongs.length} related songs (${_relatedSongs.length} total)');
    }

    // Mark as not fetching if this is the final update
    if (!partial) {
      print('✅ Fetch completed, setting _isFetching to false');
      _isFetching = false;
      _fetchTimeoutTimer?.cancel();
      _fetchTimeoutTimer = null;
    }

    // Check if we need to fetch more (queue expansion)
    if (!partial && _relatedSongs.length <= 5) {
      print('🔍 Need more songs, triggering additional fetch');
      _fetchAdditionalSongs();
    }
  }

  Future<void> _fetchAdditionalSongs() async {
    print('🔍 _fetchAdditionalSongs called');
    print('   Current seed song: ${_currentSeedSong?.title}');
    print('   Is fetching: $_isFetching');

    if (_currentSeedSong == null || _isFetching) {
      print('⏭️ Skipping additional fetch - no seed song or already fetching');
      return;
    }

    print('🔍 Fetching additional related songs...');
    _isFetching = true;
    _hasStartedStreaming = false; // Reset for additional fetch
    _onUpdate(_relatedSongs, true);

    try {
      final ytNotifier = _ref.read(ytMusicProvider.notifier);
      ytNotifier.streamRelatedSongs(
        songName: _currentSeedSong!.title,
        artistName: _currentSeedSong!.artists,
        limit: 10, // Increased limit for additional fetch
        audioQuality: 'high',
        thumbnailQuality: 'high',
      );
      print('✅ Additional fetch initiated');
    } catch (e) {
      print('⚠️ Error fetching additional songs: $e');
      _isFetching = false;
      _onUpdate(_relatedSongs, false);
    }
  }

  void _handleFetchError(String error) {
    print('❌ _handleFetchError called: $error');
    _cleanup();
    _isFetching = false;
    _onUpdate(_relatedSongs, false);
    print('🧹 Cleaned up after error');
  }

 Future<void> _cancelOngoingFetch() async {
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
  
  _hasStartedStreaming = false; // Reset streaming flag
  
  // Clear the related songs list when cancelling
  if (_relatedSongs.isNotEmpty) {
    _relatedSongs.clear();
    print('🧹 Cleared related songs during cancellation');
  }
  
  print('🆔 Ready for new fetch operation');

  try {
    final ytNotifier = _ref.read(ytMusicProvider.notifier);
    ytNotifier.clearRelatedSongs();
    print('🧽 Cleared YtMusic related songs');
  } catch (e) {
    print('⚠️ Error cancelling fetch: $e');
  }
}
  void removeFirst() {
    print('🗑️ removeFirst called');
    print('   Current queue size: ${_relatedSongs.length}');
    
    if (_relatedSongs.isEmpty) {
      print('⚠️ Queue is empty, nothing to remove');
      return;
    }
    
    final removedSong = _relatedSongs.removeAt(0);
    print('🎵 Removed song: ${removedSong.title}');
    print('   New queue size: ${_relatedSongs.length}');
    
    _onUpdate(_relatedSongs, _isFetching);

    // Trigger queue expansion if needed
    if (_relatedSongs.length <= 3 && !_isFetching) {
      print('🔍 Queue running low, triggering additional fetch');
      _fetchAdditionalSongs();
    } else {
      print('✅ Queue has enough songs or already fetching');
    }
  }

  Future<void> dispose() async {
    print('♻️ RelatedSongsManager dispose called');
    await _cancelOngoingFetch();
    
    if (_songStreamController != null && !_songStreamController!.isClosed) {
      await _songStreamController!.close();
      print('📡 Stream controller closed');
    }
    _songStreamController = null;
    
    _relatedSongs.clear();
    print('♻️ RelatedSongsManager disposed');
  }

  void _cleanup() {
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
    
    _hasStartedStreaming = false; // Reset streaming flag
  }
}