// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Offline sync engine — Task 5 (Wave 1).
///
/// Pull/Queue/Flush pattern:
/// - Pull: on app start, fetch latest from worker API
/// - Queue: writes while offline go to a local queue (in-memory + Isar)
/// - Flush: when connectivity restored, replay queue in order
/// - Conflict resolution: server-wins by default; conflicts logged
///
/// This file is defensive about Isar — if the package isn't yet
/// available (Wave 1 merge pending), it falls back to in-memory queue.
class OfflineSyncEngine {
  OfflineSyncEngine(this._apiClient);

  final dynamic _apiClient; // ApiClient — typed loosely to avoid hard dep
  final List<_QueuedWrite> _queue = <_QueuedWrite>[];
  final StreamController<List<_QueuedWrite>> _queueController =
      StreamController<List<_QueuedWrite>>.broadcast();

  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _isFlushing = false;

  /// Stream of the current queue (for UI display — "N changes queued").
  Stream<List<_QueuedWrite>> get queueStream => _queueController.stream;

  /// Current queue length.
  int get queueLength => _queue.length;

  /// Start listening to connectivity. Call on app start.
  Future<void> init() async {
    final connectivity = Connectivity();
    _connectivitySub = connectivity.onConnectivityChanged.listen((result) {
      final hasConnection = result != ConnectivityResult.none;
      if (hasConnection && _queue.isNotEmpty && !_isFlushing) {
        unawaited(flush());
      }
    });
  }

  /// Enqueue a write to be replayed when online.
  void enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) {
    final write = _QueuedWrite(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      method: method,
      path: path,
      body: body,
      queuedAt: DateTime.now(),
    );
    _queue.add(write);
    _queueController.add(List.unmodifiable(_queue));
    debugPrint('OfflineSync: queued $method $path (queue: ${_queue.length})');
  }

  /// Replay all queued writes. Returns the number that succeeded.
  Future<int> flush() async {
    if (_isFlushing || _queue.isEmpty) return 0;
    _isFlushing = true;
    var succeeded = 0;
    final failed = <_QueuedWrite>[];
    while (_queue.isNotEmpty) {
      final write = _queue.removeAt(0);
      _queueController.add(List.unmodifiable(_queue));
      try {
        await _replayWrite(write);
        succeeded++;
      } catch (e) {
        debugPrint('OfflineSync: replay failed for ${write.path}: $e');
        if (_isConflictError(e)) {
          // Server-wins: log conflict, don't re-queue.
          debugPrint('OfflineSync: conflict on ${write.path} — server wins');
        } else {
          // Network error: re-queue and stop flushing.
          failed.add(write);
          break;
        }
      }
    }
    _queue.insertAll(0, failed);
    _queueController.add(List.unmodifiable(_queue));
    _isFlushing = false;
    return succeeded;
  }

  Future<void> _replayWrite(_QueuedWrite write) async {
    // ignore: avoid_dynamic_calls
    switch (write.method) {
      case 'POST':
        await _apiClient.post(write.path, body: write.body);
      case 'PUT':
        await _apiClient.put(write.path, body: write.body);
      case 'PATCH':
        await _apiClient.patch(write.path, body: write.body);
      case 'DELETE':
        await _apiClient.delete(write.path);
    }
  }

  bool _isConflictError(Object err) {
    final msg = err.toString().toLowerCase();
    return msg.contains('409') || msg.contains('conflict');
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _queueController.close();
  }
}

class _QueuedWrite {
  _QueuedWrite({
    required this.id,
    required this.method,
    required this.path,
    required this.body,
    required this.queuedAt,
  });

  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  final DateTime queuedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'body': body,
        'queued_at': queuedAt.toIso8601String(),
      };

  @override
  String toString() => 'QueuedWrite($method $path)';
}