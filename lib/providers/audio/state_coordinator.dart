import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/song.dart';
import '../../screens/related_songs_queue.dart';
import 'navigation_controller.dart';

class AudioStateUpdate {
  final Song? song;
  final int? index;
  final PlaybackContext? context;
  final Map<String, dynamic>? additionalData;
  final DateTime timestamp;

  AudioStateUpdate({this.song, this.index, this.context, this.additionalData})
    : timestamp = DateTime.now();
}

/// Coordinates state synchronization across all providers
class AudioStateCoordinator {
  final dynamic _audioNotifier;
  final Ref _ref;

  // State tracking
  Song? _lastSyncedSong;
  int _lastSyncedIndex = -1;
  String _lastSyncedSource = '';
  DateTime? _lastSyncTime;

  // Conflict resolution
  final List<String> _stateConflicts = [];
  bool _isResolving = false;

  AudioStateCoordinator(this._audioNotifier, this._ref);

  /// Synchronize all state providers with new audio state
  void syncAllStates(Song song, int index, PlaybackContext context) {
    print('🔄 === STATE SYNC START ===');
    print('   Song: ${song.title}');
    print('   Index: $index');
    print('   Source: ${context.playbackSource}');
    print('   Context: ${context.playlistType}');

    if (_isResolving) {
      print('⚠️ Already resolving conflicts, queuing sync');
      _queueSync(song, index, context);
      return;
    }

    try {
      // Update related songs service state
      _syncRelatedSongsService(song, index, context);

      // Update queue state if needed
      _syncQueueState(song, index, context);

      // Update any playlist providers
      _syncPlaylistProviders(song, index, context);

      // Record sync
      _lastSyncedSong = song;
      _lastSyncedIndex = index;
      _lastSyncedSource = context.playbackSource;
      _lastSyncTime = DateTime.now();

      print('✅ State sync completed successfully');
    } catch (e) {
      print('❌ Error in state sync: $e');
      _recordStateConflict('Sync error: $e');
    }

    print('=========================');
  }

  /// Handle player state changes and update accordingly
  void handlePlayerStateChange(PlayerState playerState) {
    final currentState = _audioNotifier.state;

    final isNowPlaying = playerState.playing;
    final processingState = playerState.processingState;

    bool isLoading = false;

    switch (processingState) {
      case ProcessingState.idle:
        print('🔄 Player idle');
        break;
      case ProcessingState.loading:
        print('🔄 Loading audio...');
        isLoading = true;
        break;
      case ProcessingState.buffering:
        print('🔄 Buffering...');
        isLoading = true;
        break;
      case ProcessingState.ready:
        print('✅ Audio ready');
        break;
      case ProcessingState.completed:
        print('🏁 Audio completed');
        break;
    }

    // Update state if changed
    if (currentState.isPlaying != isNowPlaying ||
        currentState.isLoading != isLoading) {
      final newState = currentState.copyWith(
        isPlaying: isNowPlaying,
        isLoading: isLoading,
      );

      _audioNotifier.state = newState;
    }
  }

  /// Handle playback events
  void handlePlaybackEvent(PlaybackEvent event) {
    if (event.processingState == ProcessingState.ready) {
      print('✅ Playback event: Audio ready');
      _clearStateConflicts(); // Clear conflicts on successful playback
    }
  }

  /// Validate consistency across all state providers
  bool validateStateConsistency() {
    print('🔍 === STATE CONSISTENCY CHECK ===');

    final audioState = _audioNotifier.state;
    final queueState = _ref.read(queueStateProvider);

    bool isConsistent = true;
    final issues = <String>[];

    // Check audio state internal consistency
    if (audioState.playlist.isNotEmpty) {
      if (audioState.currentIndex < 0 ||
          audioState.currentIndex >= audioState.playlist.length) {
        issues.add('Audio index out of bounds: ${audioState.currentIndex}');
        isConsistent = false;
      }

      if (audioState.currentIndex < audioState.playlist.length) {
        final expectedSong = audioState.playlist[audioState.currentIndex];
        if (audioState.currentSong?.videoId != expectedSong.videoId) {
          issues.add('Current song mismatch in audio state');
          isConsistent = false;
        }
      }
    }

    // Check queue state consistency
    if (queueState.currentOrder.isNotEmpty &&
        audioState.playbackSource == 'related') {
      if (queueState.currentIndex < 0 ||
          queueState.currentIndex >= queueState.currentOrder.length) {
        issues.add('Queue index out of bounds: ${queueState.currentIndex}');
        isConsistent = false;
      }

      // Check if audio state matches queue state for related playback
      if (queueState.currentIndex < queueState.currentOrder.length) {
        final expectedQueueSong =
            queueState.currentOrder[queueState.currentIndex];
        if (audioState.currentSong?.videoId != expectedQueueSong.videoId) {
          issues.add('Audio/Queue song mismatch for related playback');
          isConsistent = false;
        }
      }
    }

    // Check playlist consistency
    if (audioState.playbackSource == 'related' &&
        queueState.currentOrder.isNotEmpty) {
      if (audioState.playlist.length != queueState.currentOrder.length) {
        issues.add('Playlist/Queue length mismatch');
        isConsistent = false;
      }
    }

    if (isConsistent) {
      print('✅ All states are consistent');
    } else {
      print('❌ State inconsistencies found:');
      for (final issue in issues) {
        print('   - $issue');
        _recordStateConflict(issue);
      }
    }

    print('===============================');
    return isConsistent;
  }

  /// Resolve state conflicts when detected
  void resolveStateConflicts() {
    if (_stateConflicts.isEmpty) return;

    print('🔧 === RESOLVING STATE CONFLICTS ===');
    _isResolving = true;

    try {
      final audioState = _audioNotifier.state;
      final queueState = _ref.read(queueStateProvider);

      // Strategy: Audio state is the authoritative source
      print('   Using audio state as authoritative source');

      // Resolve queue conflicts for related playback
      if (audioState.playbackSource == 'related' &&
          audioState.currentSong != null) {
        _resolveQueueConflicts(audioState, queueState);
      }

      // Resolve playlist conflicts
      _resolvePlaylistConflicts(audioState);

      // Clear resolved conflicts
      _clearStateConflicts();

      print('✅ State conflicts resolved');
    } catch (e) {
      print('❌ Error resolving conflicts: $e');
    } finally {
      _isResolving = false;
    }

    print('=================================');
  }

  /// Update all providers with state update
  void updateAllProviders(AudioStateUpdate update) {
    print('📤 Broadcasting state update to all providers');

    if (update.song != null && update.context != null) {
      syncAllStates(update.song!, update.index ?? 0, update.context!);
    }
  }

  // ==================== PRIVATE SYNC METHODS ====================

  void _syncRelatedSongsService(Song song, int index, PlaybackContext context) {
    try {
      final relatedService = _audioNotifier._relatedSongsService;

      // Update service state if needed
      if (context.playbackSource == 'related') {
        print('🔄 Syncing related songs service state');
        // The service will handle its own state through queue updates
      }
    } catch (e) {
      print('❌ Error syncing related songs service: $e');
    }
  }

  void _syncQueueState(Song song, int index, PlaybackContext context) {
    try {
      final queueState = _ref.read(queueStateProvider);
      final queueNotifier = _ref.read(queueStateProvider.notifier);

      // Only sync queue for related playback
      if (context.playbackSource == 'related') {
        // Find the song in current queue
        final songIndex = queueState.currentOrder.indexWhere(
          (s) => s.videoId == song.videoId,
        );

        if (songIndex >= 0 && songIndex != queueState.currentIndex) {
          print('🔄 Syncing queue index: $songIndex');
          queueNotifier.setCurrentIndex(songIndex);
        } else if (songIndex < 0) {
          print('⚠️ Song not found in queue, this might indicate a sync issue');
        }
      } else if (context.playbackSource == 'search') {
        // Clear queue for new search
        if (queueState.currentOrder.isNotEmpty) {
          print('🧹 Clearing queue for new search');
          queueNotifier.clearQueue();
        }
      }
    } catch (e) {
      print('❌ Error syncing queue state: $e');
    }
  }

  void _syncPlaylistProviders(Song song, int index, PlaybackContext context) {
    // Sync any other playlist providers if they exist
    // This is where you'd add synchronization with other state providers
    print('📋 Syncing playlist providers (if any)');
  }

  void _queueSync(Song song, int index, PlaybackContext context) {
    // Simple queuing - in a more complex system you might want a proper queue
    Future.delayed(Duration(milliseconds: 100), () {
      if (!_isResolving) {
        syncAllStates(song, index, context);
      }
    });
  }

  // ==================== CONFLICT RESOLUTION ====================

  void _resolveQueueConflicts(dynamic audioState, QueueState queueState) {
    print('🔧 Resolving queue conflicts');

    final queueNotifier = _ref.read(queueStateProvider.notifier);

    // Find current song in queue
    final currentSongIndex = queueState.currentOrder.indexWhere(
      (s) => s.videoId == audioState.currentSong?.videoId,
    );

    if (currentSongIndex >= 0) {
      // Song exists in queue, update index
      if (currentSongIndex != queueState.currentIndex) {
        print('   Correcting queue index: $currentSongIndex');
        queueNotifier.setCurrentIndex(currentSongIndex);
      }
    } else {
      // Song not in queue - this suggests the queue needs updating
      print('   Current song not in queue - queue may need refresh');

      if (audioState.playlist.isNotEmpty &&
          audioState.playbackSource == 'related') {
        print('   Updating queue with current playlist');
        queueNotifier.updateQueue(audioState.playlist, audioState.currentIndex);
      }
    }
  }

  void _resolvePlaylistConflicts(dynamic audioState) {
    print('🔧 Resolving playlist conflicts');

    // Validate current index
    if (audioState.currentIndex < 0 ||
        audioState.currentIndex >= audioState.playlist.length) {
      print('   Correcting invalid index');

      // Find correct index for current song
      if (audioState.currentSong != null && audioState.playlist.isNotEmpty) {
        final correctIndex = audioState.playlist.indexWhere(
          (s) => s.videoId == audioState.currentSong?.videoId,
        );

        if (correctIndex >= 0) {
          print('   Found correct index: $correctIndex');
          final correctedState = audioState.copyWith(
            currentIndex: correctIndex,
          );
          _audioNotifier.state = correctedState;
        }
      }
    }
  }

  void _recordStateConflict(String conflict) {
    _stateConflicts.add('${DateTime.now().toIso8601String()}: $conflict');
    print('⚠️ State conflict recorded: $conflict');

    // Keep only recent conflicts (last 10)
    if (_stateConflicts.length > 10) {
      _stateConflicts.removeAt(0);
    }
  }

  void _clearStateConflicts() {
    if (_stateConflicts.isNotEmpty) {
      print('🧹 Clearing ${_stateConflicts.length} resolved conflicts');
      _stateConflicts.clear();
    }
  }

  // ==================== DIAGNOSTICS ====================

  Map<String, dynamic> getStateReport() {
    final audioState = _audioNotifier.state;
    final queueState = _ref.read(queueStateProvider);

    return {
      'lastSync': {
        'song': _lastSyncedSong?.title,
        'index': _lastSyncedIndex,
        'source': _lastSyncedSource,
        'time': _lastSyncTime?.toIso8601String(),
      },
      'currentState': {
        'audio': {
          'song': audioState.currentSong?.title,
          'index': audioState.currentIndex,
          'playlistLength': audioState.playlist.length,
          'source': audioState.playbackSource,
          'isPlaying': audioState.isPlaying,
          'isLoading': audioState.isLoading,
        },
        'queue': {
          'currentIndex': queueState.currentIndex,
          'queueLength': queueState.currentOrder.length,
          'currentSong':
              queueState.currentOrder.isNotEmpty &&
                  queueState.currentIndex < queueState.currentOrder.length
              ? queueState.currentOrder[queueState.currentIndex].title
              : null,
        },
      },
      'conflicts': _stateConflicts,
      'isResolving': _isResolving,
      'isConsistent': validateStateConsistency(),
    };
  }

  void printStateReport() {
    final report = getStateReport();

    print('📊 === STATE COORDINATOR REPORT ===');
    print('   Last Sync:');
    print('     Song: ${report['lastSync']['song'] ?? 'None'}');
    print('     Index: ${report['lastSync']['index']}');
    print('     Source: ${report['lastSync']['source']}');
    print('     Time: ${report['lastSync']['time'] ?? 'Never'}');

    print('   Current Audio State:');
    final audioState = report['currentState']['audio'];
    print('     Song: ${audioState['song'] ?? 'None'}');
    print('     Index: ${audioState['index']}');
    print('     Playlist Length: ${audioState['playlistLength']}');
    print('     Source: ${audioState['source']}');
    print('     Playing: ${audioState['isPlaying']}');
    print('     Loading: ${audioState['isLoading']}');

    print('   Current Queue State:');
    final queueState = report['currentState']['queue'];
    print('     Index: ${queueState['currentIndex']}');
    print('     Length: ${queueState['queueLength']}');
    print('     Song: ${queueState['currentSong'] ?? 'None'}');

    print('   Status:');
    print('     Conflicts: ${report['conflicts'].length}');
    print('     Resolving: ${report['isResolving']}');
    print('     Consistent: ${report['isConsistent']}');

    if (report['conflicts'].isNotEmpty) {
      print('   Recent Conflicts:');
      for (final conflict in report['conflicts']) {
        print('     - $conflict');
      }
    }

    print('==================================');
  }

  // ==================== UTILITY ====================

  bool hasRecentConflicts() {
    return _stateConflicts.isNotEmpty;
  }

  void forceSync() {
    final audioState = _audioNotifier.state;
    if (audioState.currentSong != null) {
      syncAllStates(
        audioState.currentSong!,
        audioState.currentIndex,
        PlaybackContext(
          playlistType: audioState.playlistType,
          playbackSource: audioState.playbackSource,
          currentPlaylist: audioState.playlist,
          isNetworkPlayback: audioState.isNetworkPlayback,
          searchQuery: audioState.lastSearchQuery,
        ),
      );
    }
  }

  void dispose() {
    _stateConflicts.clear();
    _lastSyncedSong = null;
    _isResolving = false;
  }
}
