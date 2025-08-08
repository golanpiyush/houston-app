import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song.dart';
import '../../screens/related_songs_queue.dart';
import '../../providers/ytmusic_provider.dart';

class RelatedSongsService {
  final Ref _ref;
  final Function(List<Song>, bool) _onRelatedSongsUpdate;
  final Function() _onQueueEmpty;

  // State tracking
  bool _isFetchingRelated = false;
  bool _hasTriggeredRelatedFetch = false;
  String? _lastSearchQuery;
  Song? _seedSong;
  String? _lastRelatedSongTitle;
  String? _lastRelatedSongArtist;

  // Timers and operations
  Timer? _autoplayTimer;
  bool _isAutoSwitching = false;
  ProviderSubscription<YtMusicState>? _relatedSongsSubscription;

  RelatedSongsService(
    this._ref,
    this._onRelatedSongsUpdate,
    this._onQueueEmpty,
  );

  void dispose() {
    // Removed @override and super.dispose()
    _relatedSongsSubscription?.close();
    _autoplayTimer?.cancel();
    clearRelatedData();
  }
  // ==================== PUBLIC INTERFACE ====================

  bool get isFetchingRelated => _isFetchingRelated;
  bool get hasTriggeredRelatedFetch => _hasTriggeredRelatedFetch;

  /// Auto-fetch related songs for a given song and source
  void autoFetchRelatedSongs(Song song, String source) {
    print('🔍 === AUTO FETCH RELATED SONGS ===');
    print('   Song: ${song.title} by ${song.artists}');
    print('   Source: $source');
    print('   Already triggered: $_hasTriggeredRelatedFetch');

    // Don't auto-fetch for related songs themselves
    if (source == 'related') {
      print('   ⏭️ Skipping auto-fetch for related song');
      return;
    }

    // Don't fetch if already triggered for this song
    if (_hasTriggeredRelatedFetch && _seedSong?.videoId == song.videoId) {
      print('   ⏭️ Already triggered for this song');
      return;
    }

    // Mark as triggered and start fetch
    _hasTriggeredRelatedFetch = true;
    _seedSong = song;

    print('   🚀 Starting related songs fetch');
    fetchForSong(song);
  }

  /// Prepare for autoplay at 50% mark
  void prepareForAutoplay(Song song, String source, bool alreadyTriggered) {
    if (source == 'related') return;

    print('🎯 Preparing for autoplay: ${song.title}');

    // Don't duplicate fetches
    if (!_hasTriggeredRelatedFetch || _seedSong?.videoId != song.videoId) {
      _hasTriggeredRelatedFetch = true;
      _seedSong = song;
      fetchForSong(song);
    }
  }

  /// Attempt to auto-switch to related songs queue
  Future<bool> autoSwitchToQueue() async {
    if (_isAutoSwitching) return false;

    _isAutoSwitching = true;

    try {
      final queueState = _ref.read(queueStateProvider);

      if (queueState.currentOrder.isNotEmpty) {
        print('🔄 Auto-switching to related songs queue');

        final queueNotifier = _ref.read(queueStateProvider.notifier);
        queueNotifier.setCurrentIndex(0);

        return true;
      } else {
        print('⚠️ No related songs available for auto-switch');
        return false;
      }
    } catch (e) {
      print('❌ Error in auto-switch: $e');
      return false;
    } finally {
      _isAutoSwitching = false;
    }
  }

  Future<void> fetchForSong(Song song) async {
    if (_isFetchingRelated) {
      print('⚠️ Already fetching related songs');
      return;
    }

    _isFetchingRelated = true;
    _onRelatedSongsUpdate([], true);

    try {
      print('🔍 Fetching related songs for: ${song.title}');

      // Close any existing subscription
      _relatedSongsSubscription?.close();
      _relatedSongsSubscription = null;

      final ytMusicNotifier = _ref.read(ytMusicProvider.notifier);
      ytMusicNotifier.streamRelatedSongs(
        songName: song.title,
        artistName: song.artists,
        limit: 5,
        audioQuality: 'high',
      );

      // Listen to the state changes for related songs
      _relatedSongsSubscription = _ref.listen<YtMusicState>(ytMusicProvider, (
        _,
        next,
      ) {
        if (next.relatedSongs.isNotEmpty) {
          final filteredSongs = next.relatedSongs
              .where((s) => s.videoId != song.videoId)
              .toList();

          if (filteredSongs.isNotEmpty) {
            print('📋 Adding ${filteredSongs.length} songs to queue');

            final queueNotifier = _ref.read(queueStateProvider.notifier);
            queueNotifier.updateQueue(filteredSongs, '0'); // Changed to String

            _onRelatedSongsUpdate(filteredSongs, false);

            _lastRelatedSongTitle = filteredSongs.first.title;
            _lastRelatedSongArtist = filteredSongs.first.artists;

            print('✅ Related songs loaded successfully');
            _isFetchingRelated = false;
          } else {
            print('⚠️ No valid related songs after filtering');
            _onQueueEmpty();
            _isFetchingRelated = false;
          }
        } else if (next.error != null) {
          print('❌ Error fetching related songs: ${next.error}');
          _onQueueEmpty();
          _isFetchingRelated = false;
        }
      });
    } catch (e) {
      print('❌ Error fetching related songs: $e');
      _onQueueEmpty();
      _isFetchingRelated = false;
      _onRelatedSongsUpdate([], false);
    }
  }

  /// Move to next song in queue
  bool moveToNextInQueue() {
    try {
      final queueState = _ref.read(queueStateProvider);
      final queueNotifier = _ref.read(queueStateProvider.notifier);

      if (queueState.currentOrder.isNotEmpty &&
          queueState.currentIndex < queueState.currentOrder.length - 1) {
        print(
          '⏭️ Moving to next in queue: index ${queueState.currentIndex + 1}',
        );
        queueNotifier.setCurrentIndex(queueState.currentIndex + 1);
        return true;
      }

      print('⚠️ No next song in queue');
      return false;
    } catch (e) {
      print('❌ Error moving to next in queue: $e');
      return false;
    }
  }

  /// Play a specific related song
  bool playRelatedSong(Song song) {
    try {
      final queueState = _ref.read(queueStateProvider);
      final queueNotifier = _ref.read(queueStateProvider.notifier);

      // Find song in queue
      final songIndex = queueState.currentOrder.indexWhere(
        (s) => s.videoId == song.videoId,
      );

      if (songIndex >= 0) {
        print('🎵 Playing related song at index: $songIndex');
        queueNotifier.setCurrentIndex(songIndex);
        return true;
      } else {
        print('❌ Related song not found in queue');
        return false;
      }
    } catch (e) {
      print('❌ Error playing related song: $e');
      return false;
    }
  }

  /// Handle new search query
  void handleNewSearchQuery(String query) {
    print('🔍 New search query: "$query"');

    // Clear previous related data
    clearRelatedData();

    // Store search query for related song fetching
    _lastSearchQuery = query;
  }

  void clearRelatedData() {
    print('🧹 Clearing related songs data');

    _hasTriggeredRelatedFetch = false;
    _seedSong = null;
    _lastRelatedSongTitle = null;
    _lastRelatedSongArtist = null;
    _isFetchingRelated = false;

    _autoplayTimer?.cancel();
    _autoplayTimer = null;
    _isAutoSwitching = false;
    _relatedSongsSubscription?.close();
    _relatedSongsSubscription = null;

    try {
      final queueNotifier = _ref.read(queueStateProvider.notifier);
      queueNotifier.clearQueue();
    } catch (e) {
      print('❌ Error clearing queue: $e');
    }

    _onRelatedSongsUpdate([], false);
  }

  // ==================== QUEUE MANAGEMENT ====================

  /// Get current queue state summary
  Map<String, dynamic> getQueueSummary() {
    try {
      final queueState = _ref.read(queueStateProvider);

      return {
        'queueLength': queueState.currentOrder.length,
        'currentIndex': queueState.currentIndex,
        'currentSong':
            queueState.currentOrder.isNotEmpty &&
                queueState.currentIndex < queueState.currentOrder.length
            ? queueState.currentOrder[queueState.currentIndex].title
            : null,
        'hasNext': queueState.currentIndex < queueState.currentOrder.length - 1,
        'hasPrevious': queueState.currentIndex > 0,
      };
    } catch (e) {
      print('❌ Error getting queue summary: $e');
      return {
        'queueLength': 0,
        'currentIndex': -1,
        'currentSong': null,
        'hasNext': false,
        'hasPrevious': false,
      };
    }
  }

  /// Validate queue consistency
  bool validateQueueConsistency() {
    try {
      final queueState = _ref.read(queueStateProvider);

      if (queueState.currentOrder.isEmpty) {
        return true; // Empty queue is consistent
      }

      // Check index bounds
      if (queueState.currentIndex < 0 ||
          queueState.currentIndex >= queueState.currentOrder.length) {
        print('❌ Queue index out of bounds: ${queueState.currentIndex}');
        return false;
      }

      // Check for songs without audio URLs
      int invalidSongs = 0;
      for (final song in queueState.currentOrder) {
        if (song.audioUrl == null || song.audioUrl!.isEmpty) {
          invalidSongs++;
        }
      }

      if (invalidSongs > 0) {
        print('⚠️ Queue has $invalidSongs songs without audio URLs');
      }

      return true;
    } catch (e) {
      print('❌ Error validating queue: $e');
      return false;
    }
  }

  // ==================== DIAGNOSTICS ====================

  Map<String, dynamic> getDiagnostics() {
    final queueSummary = getQueueSummary();

    return {
      'service': {
        'isFetchingRelated': _isFetchingRelated,
        'hasTriggeredRelatedFetch': _hasTriggeredRelatedFetch,
        'lastSearchQuery': _lastSearchQuery,
        'seedSong': _seedSong?.title,
        'lastRelatedSong': _lastRelatedSongTitle,
        'isAutoSwitching': _isAutoSwitching,
      },
      'queue': queueSummary,
      'timers': {'autoplayTimer': _autoplayTimer != null},
    };
  }

  void printDiagnostics() {
    final diagnostics = getDiagnostics();

    print('🔍 === RELATED SONGS SERVICE DIAGNOSTICS ===');

    final service = diagnostics['service'];
    print('   Service State:');
    print('     Fetching: ${service['isFetchingRelated']}');
    print('     Triggered: ${service['hasTriggeredRelatedFetch']}');
    print('     Search Query: ${service['lastSearchQuery'] ?? 'None'}');
    print('     Seed Song: ${service['seedSong'] ?? 'None'}');
    print('     Last Related: ${service['lastRelatedSong'] ?? 'None'}');
    print('     Auto Switching: ${service['isAutoSwitching']}');

    final queue = diagnostics['queue'];
    print('   Queue State:');
    print('     Length: ${queue['queueLength']}');
    print('     Current Index: ${queue['currentIndex']}');
    print('     Current Song: ${queue['currentSong'] ?? 'None'}');
    print('     Has Next: ${queue['hasNext']}');
    print('     Has Previous: ${queue['hasPrevious']}');

    final timers = diagnostics['timers'];
    print('   Timers:');
    print('     Autoplay Timer: ${timers['autoplayTimer']}');

    print('==========================================');
  }

  // ==================== UTILITY METHODS ====================

  /// Check if queue has songs
  bool hasQueuedSongs() {
    try {
      final queueState = _ref.read(queueStateProvider);
      return queueState.currentOrder.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get next song in queue without changing index
  Song? peekNextSong() {
    try {
      final queueState = _ref.read(queueStateProvider);

      if (queueState.currentOrder.isNotEmpty &&
          queueState.currentIndex < queueState.currentOrder.length - 1) {
        return queueState.currentOrder[queueState.currentIndex + 1];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Force refresh related songs for current seed
  Future<void> refreshRelatedSongs() async {
    if (_seedSong != null) {
      print('🔄 Force refreshing related songs');
      clearRelatedData();
      await fetchForSong(_seedSong!);
    } else {
      print('⚠️ No seed song available for refresh');
    }
  }

  /// Emergency queue cleanup
  void emergencyCleanup() {
    print('🚨 Emergency cleanup of related songs service');

    _autoplayTimer?.cancel();
    _autoplayTimer = null;

    _isFetchingRelated = false;
    _isAutoSwitching = false;

    try {
      final queueNotifier = _ref.read(queueStateProvider.notifier);
      queueNotifier.clearQueue();
    } catch (e) {
      print('❌ Error in emergency cleanup: $e');
    }

    _onRelatedSongsUpdate([], false);
    _onQueueEmpty();
  }
}
