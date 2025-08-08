import 'dart:async';
import 'dart:collection';
import '../../models/song.dart';

enum OperationType {
  USER_PLAY, // Priority 1 - User initiated playback
  USER_NAVIGATE, // Priority 1 - User navigation (next/previous)
  QUEUE_SYNC, // Priority 2 - Queue synchronization
  AUTOPLAY, // Priority 3 - Automatic progression
  ERROR_RECOVERY, // Priority 2 - Error recovery operations
  BACKGROUND_FETCH, // Priority 5 - Background operations
}

class AudioOperation {
  final OperationType type;
  final int priority;
  final Song? targetSong;
  final int? targetIndex;
  final String operationId;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final Completer<bool> completer;

  AudioOperation({
    required this.type,
    required this.priority,
    this.targetSong,
    this.targetIndex,
    required this.operationId,
    this.metadata,
  }) : createdAt = DateTime.now(),
       completer = Completer<bool>();

  Duration get age => DateTime.now().difference(createdAt);

  bool get isExpired =>
      age.inSeconds > 30; // Operations expire after 30 seconds

  Future<bool> get future => completer.future;

  void complete([bool result = true]) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  void completeError(dynamic error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  @override
  String toString() {
    return 'AudioOperation(${type.name}, priority: $priority, id: $operationId, age: ${age.inMilliseconds}ms)';
  }
}

/// Manages operation priorities and queuing to prevent race conditions
class OperationManager {
  final Queue<AudioOperation> _operationQueue = Queue<AudioOperation>();
  AudioOperation? _currentOperation;
  bool _isProcessing = false;
  Timer? _processingTimer;

  // Statistics
  int _totalOperations = 0;
  int _completedOperations = 0;
  int _cancelledOperations = 0;
  final List<String> _recentOperations = [];

  /// Queue an operation for processing
  Future<bool> queueOperation(AudioOperation operation) async {
    print('📥 Queuing operation: ${operation.toString()}');

    _totalOperations++;
    _recordRecentOperation('QUEUED: ${operation.type.name}');

    // Check if we should interrupt current operation
    if (_shouldInterruptCurrentOperation(operation.type)) {
      await _interruptCurrentOperation(
        'Higher priority operation: ${operation.type.name}',
      );
    }

    // Remove expired operations
    _cleanupExpiredOperations();

    // Check for duplicate operations
    _removeDuplicateOperations(operation);

    // Add to queue in priority order
    _insertByPriority(operation);

    // Start processing if not already processing
    if (!_isProcessing) {
      _startProcessing();
    }

    try {
      return await operation.future;
    } catch (e) {
      print('❌ Operation failed: $e');
      return false;
    }
  }

  /// Check if current operation should be interrupted
  bool shouldInterruptCurrentOperation(OperationType newType) {
    if (_currentOperation == null) return false;

    final currentPriority = _currentOperation!.priority;
    final newPriority = _getOperationPriority(newType);

    return newPriority < currentPriority; // Lower number = higher priority
  }

  /// Process the operation queue
  void processOperationQueue() {
    if (_isProcessing) return;
    _startProcessing();
  }

  /// Clear low priority operations
  void clearLowPriorityOperations() {
    final highPriorityTypes = {
      OperationType.USER_PLAY,
      OperationType.USER_NAVIGATE,
      OperationType.ERROR_RECOVERY,
    };

    final originalSize = _operationQueue.length;
    _operationQueue.removeWhere((op) => !highPriorityTypes.contains(op.type));

    final removed = originalSize - _operationQueue.length;
    if (removed > 0) {
      print('🧹 Cleared $removed low priority operations');
      _recordRecentOperation('CLEARED: $removed low priority ops');
    }
  }

  // ==================== PRIVATE METHODS ====================

  void _startProcessing() {
    if (_isProcessing) return;

    _isProcessing = true;
    _processNextOperation();
  }

  Future<void> _processNextOperation() async {
    while (_operationQueue.isNotEmpty && _isProcessing) {
      final operation = _operationQueue.removeFirst();

      // Skip expired operations
      if (operation.isExpired) {
        print('⏰ Skipping expired operation: ${operation.operationId}');
        operation.complete(false);
        _cancelledOperations++;
        continue;
      }

      print('🔄 Processing operation: ${operation.toString()}');
      _currentOperation = operation;
      _recordRecentOperation('PROCESSING: ${operation.type.name}');

      try {
        // Simulate operation processing
        // In real implementation, this would trigger the actual audio operation
        await _executeOperation(operation);

        operation.complete(true);
        _completedOperations++;
        _recordRecentOperation('COMPLETED: ${operation.type.name}');
      } catch (e) {
        print('❌ Operation execution failed: $e');
        operation.completeError(e);
        _cancelledOperations++;
        _recordRecentOperation('FAILED: ${operation.type.name}');
      }

      _currentOperation = null;

      // Small delay between operations
      await Future.delayed(Duration(milliseconds: 50));
    }

    _isProcessing = false;
    print('✅ Operation queue processing completed');
  }

  Future<void> _executeOperation(AudioOperation operation) async {
    // This is where the actual operation execution would happen
    // For now, just simulate processing time based on operation type
    switch (operation.type) {
      case OperationType.USER_PLAY:
      case OperationType.USER_NAVIGATE:
        await Future.delayed(Duration(milliseconds: 100));
        break;
      case OperationType.QUEUE_SYNC:
        await Future.delayed(Duration(milliseconds: 50));
        break;
      case OperationType.ERROR_RECOVERY:
        await Future.delayed(Duration(milliseconds: 200));
        break;
      case OperationType.AUTOPLAY:
        await Future.delayed(Duration(milliseconds: 150));
        break;
      case OperationType.BACKGROUND_FETCH:
        await Future.delayed(Duration(milliseconds: 300));
        break;
    }
  }

  bool _shouldInterruptCurrentOperation(OperationType newType) {
    if (_currentOperation == null) return false;

    // User operations always interrupt others
    if (_isUserOperation(newType) &&
        !_isUserOperation(_currentOperation!.type)) {
      return true;
    }

    // Error recovery interrupts non-user operations
    if (newType == OperationType.ERROR_RECOVERY &&
        !_isUserOperation(_currentOperation!.type)) {
      return true;
    }

    return false;
  }

  Future<void> _interruptCurrentOperation(String reason) async {
    if (_currentOperation == null) return;

    print('🚫 Interrupting current operation: $reason');
    _recordRecentOperation('INTERRUPTED: ${_currentOperation!.type.name}');

    _currentOperation!.complete(false);
    _currentOperation = null;
    _cancelledOperations++;

    // Stop processing temporarily
    _isProcessing = false;

    // Restart processing after brief delay
    Timer(Duration(milliseconds: 100), () {
      _startProcessing();
    });
  }

  void _insertByPriority(AudioOperation operation) {
    // Find insertion point based on priority
    int insertIndex = 0;

    for (int i = 0; i < _operationQueue.length; i++) {
      final existing = _operationQueue.elementAt(i);
      if (operation.priority < existing.priority) {
        insertIndex = i;
        break;
      }
      insertIndex = i + 1;
    }

    // Convert to list for insertion, then back to queue
    final list = _operationQueue.toList();
    list.insert(insertIndex, operation);

    _operationQueue.clear();
    _operationQueue.addAll(list);

    print(
      '📍 Inserted operation at position $insertIndex (priority ${operation.priority})',
    );
  }

  void _removeDuplicateOperations(AudioOperation newOperation) {
    final duplicates = _operationQueue
        .where(
          (op) =>
              op.type == newOperation.type &&
              op.targetSong?.videoId == newOperation.targetSong?.videoId,
        )
        .toList();

    for (final duplicate in duplicates) {
      _operationQueue.remove(duplicate);
      duplicate.complete(false);
      print('🗑️ Removed duplicate operation: ${duplicate.operationId}');
    }
  }

  void _cleanupExpiredOperations() {
    final expired = _operationQueue.where((op) => op.isExpired).toList();

    for (final expiredOp in expired) {
      _operationQueue.remove(expiredOp);
      expiredOp.complete(false);
      _cancelledOperations++;
      print('🗑️ Removed expired operation: ${expiredOp.operationId}');
    }
  }

  int _getOperationPriority(OperationType type) {
    switch (type) {
      case OperationType.USER_PLAY:
      case OperationType.USER_NAVIGATE:
        return 1; // Highest priority
      case OperationType.ERROR_RECOVERY:
        return 2;
      case OperationType.QUEUE_SYNC:
        return 3;
      case OperationType.AUTOPLAY:
        return 4;
      case OperationType.BACKGROUND_FETCH:
        return 5; // Lowest priority
    }
  }

  bool _isUserOperation(OperationType type) {
    return type == OperationType.USER_PLAY ||
        type == OperationType.USER_NAVIGATE;
  }

  void _recordRecentOperation(String operation) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _recentOperations.add('$timestamp: $operation');

    // Keep only last 20 operations
    if (_recentOperations.length > 20) {
      _recentOperations.removeAt(0);
    }
  }

  // ==================== PUBLIC UTILITIES ====================

  /// Get current operation status
  Map<String, dynamic> getOperationStatus() {
    return {
      'isProcessing': _isProcessing,
      'queueLength': _operationQueue.length,
      'currentOperation': _currentOperation?.toString(),
      'statistics': {
        'total': _totalOperations,
        'completed': _completedOperations,
        'cancelled': _cancelledOperations,
        'successRate': _totalOperations > 0
            ? '${(_completedOperations / _totalOperations * 100).toStringAsFixed(1)}%'
            : '0%',
      },
      'recentOperations': _recentOperations.take(10).toList(),
    };
  }

  /// Print detailed diagnostics
  void printDiagnostics() {
    final status = getOperationStatus();

    print('🔧 === OPERATION MANAGER DIAGNOSTICS ===');
    print('   Processing: ${status['isProcessing']}');
    print('   Queue Length: ${status['queueLength']}');
    print('   Current: ${status['currentOperation'] ?? 'None'}');

    final stats = status['statistics'];
    print('   Statistics:');
    print('     Total: ${stats['total']}');
    print('     Completed: ${stats['completed']}');
    print('     Cancelled: ${stats['cancelled']}');
    print('     Success Rate: ${stats['successRate']}');

    print('   Recent Operations:');
    for (final op in status['recentOperations']) {
      print('     $op');
    }

    if (_operationQueue.isNotEmpty) {
      print('   Queue Contents:');
      for (final op in _operationQueue.take(5)) {
        print('     ${op.toString()}');
      }
    }

    print('=========================================');
  }

  /// Force clear all operations
  void clearAllOperations() {
    final queueSize = _operationQueue.length;

    // Cancel all queued operations
    for (final op in _operationQueue) {
      op.complete(false);
    }
    _operationQueue.clear();

    // Interrupt current operation
    if (_currentOperation != null) {
      _currentOperation!.complete(false);
      _currentOperation = null;
    }

    _isProcessing = false;
    _cancelledOperations += queueSize;

    print(
      '🧹 Cleared all operations (queue: $queueSize, current: ${_currentOperation != null})',
    );
    _recordRecentOperation('CLEARED ALL: $queueSize operations');
  }

  /// Get queue summary
  List<String> getQueueSummary() {
    return _operationQueue
        .map(
          (op) =>
              '${op.type.name} (P${op.priority}) - ${op.age.inMilliseconds}ms old',
        )
        .toList();
  }

  void dispose() {
    clearAllOperations();
    _processingTimer?.cancel();
    _recentOperations.clear();
    print('🧹 Operation Manager disposed');
  }
}
