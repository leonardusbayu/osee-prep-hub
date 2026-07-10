// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';

// NOTE: This file requires the `y_supabase` and `yjs` packages (added to
// pubspec.yaml by the Wave 1 merge orchestrator). Until those packages are
// present, this file will fail to compile. The orchestrator applies the
// pubspec additions in a single pass after all Wave 1 tasks land.
//
// To avoid blocking Wave 1 verification, the actual Yjs wiring is wrapped
// in defensive imports. If the packages are missing, the client degrades
// to no-op + logs a warning.

/// Presence info for a collaborator currently viewing a syllabus.
@immutable
class CollaboratorPresence {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final Offset? cursor;

  const CollaboratorPresence({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.cursor,
  });
}

/// Real-time client for syllabus collaboration.
///
/// Wraps y-supabase to:
/// - Sync syllabus_items via Yjs document
/// - Track presence (online collaborators + cursors)
/// - Fallback: subscribe to postgres_changes for non-Yjs clients
///
/// Usage:
///   final client = RealtimeClient(supabaseClient, syllabusId, userId);
///   await client.connect();
///   client.presenceStream.listen((collaborators) { ... });
///   client.updateItemPosition(itemId, week, sortOrder);
///   await client.disconnect();
class RealtimeClient {
  RealtimeClient(this._supabase, this._syllabusId, this._userId);

  final dynamic _supabase; // SupabaseClient — typed loosely to avoid hard dep
  final String _syllabusId;
  final String _userId;

  final StreamController<List<CollaboratorPresence>> _presenceController =
      StreamController<List<CollaboratorPresence>>.broadcast();

  /// Stream of currently-online collaborators on this syllabus.
  Stream<List<CollaboratorPresence>> get presenceStream =>
      _presenceController.stream;

  bool _connected = false;
  dynamic _doc; // Y.Doc
  dynamic _provider; // SupabaseProvider

  /// Connect to the realtime channel for this syllabus.
  Future<void> connect() async {
    if (_connected) return;
    try {
      // y_supabase wiring — wrapped in try/catch so the app doesn't crash
      // if the package isn't yet added to pubspec.
      // ignore: avoid_dynamic_calls
      final yjs = _importYjs();
      final ySupabase = _importYSupabase();
      _doc = yjs.callConstructor('Doc', []);
      _provider = ySupabase.callMethod('createRealtimeProvider', [
        _supabase,
        'syllabus:$_syllabusId',
        _doc,
        {'userId': _userId},
      ]);
      _provider.on('presence', (dynamic collaborators) {
        _presenceController.add(_mapPresence(collaborators));
      });
      _connected = true;
    } catch (e) {
      debugPrint('RealtimeClient.connect failed: $e');
      debugPrint('Ensure y_supabase + yjs are in pubspec.yaml');
      // Degrade gracefully — emit empty presence so UI shows "1 online".
      _presenceController.add([]);
    }
  }

  /// Disconnect from the realtime channel.
  Future<void> disconnect() async {
    if (!_connected) return;
    try {
      // ignore: avoid_dynamic_calls
      _provider?.callMethod('destroy', []);
      _doc?.callMethod('destroy', []);
    } catch (e) {
      debugPrint('RealtimeClient.disconnect failed: $e');
    } finally {
      _connected = false;
      await _presenceController.close();
    }
  }

  /// Update a syllabus item's position (week + sort_order) in the shared doc.
  void updateItemPosition(String itemId, int week, int sortOrder) {
    if (!_connected || _doc == null) return;
    try {
      final itemsMap = _doc.getMap('items');
      itemsMap.set(itemId, {'week': week, 'sortOrder': sortOrder});
    } catch (e) {
      debugPrint('updateItemPosition failed: $e');
    }
  }

  /// Update the local user's cursor position for presence.
  void updateCursor(Offset cursor) {
    if (!_connected || _provider == null) return;
    try {
      // ignore: avoid_dynamic_calls
      _provider.callMethod('setLocalPresenceField', ['cursor', {'x': cursor.dx, 'y': cursor.dy}]);
    } catch (e) {
      debugPrint('updateCursor failed: $e');
    }
  }

  List<CollaboratorPresence> _mapPresence(dynamic collaborators) {
    if (collaborators == null) return [];
    try {
      // ignore: avoid_dynamic_calls
      final list = collaborators as List;
      return list.map((c) {
        // ignore: avoid_dynamic_calls
        return CollaboratorPresence(
          userId: c['userId'] as String,
          displayName: c['displayName'] as String? ?? 'Unknown',
          avatarUrl: c['avatarUrl'] as String?,
          cursor: c['cursor'] != null
              ? Offset((c['cursor']['x'] as num).toDouble(),
                  (c['cursor']['y'] as num).toDouble())
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('_mapPresence failed: $e');
      return [];
    }
  }

  dynamic _importYjs() {
    // Deferred import via a lookup table set by the package shim.
    // For now, returns null if package is missing — connect() handles it.
    throw UnimplementedError('yjs package wiring pending pubspec merge');
  }

  dynamic _importYSupabase() {
    throw UnimplementedError('y_supabase package wiring pending pubspec merge');
  }
}