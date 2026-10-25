import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_models.dart';
import '../../features/inspections/inspections_controller.dart';
import '../api/api_exception.dart';
import '../local/local_store.dart';
import '../providers.dart';

/// True when the device has some network. Web uses the browser's
/// online/offline events; mobile uses the OS connectivity API.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);
  try {
    yield online(await c.checkConnectivity());
    yield* c.onConnectivityChanged.map(online);
  } on Object {
    // Plugin unavailable (tests, unsupported platform): assume online and let
    // requests fail with network errors if not.
    yield true;
  }
});

@immutable
class SyncState {
  const SyncState({this.syncing = false, this.lastSyncAt, this.offline = false});

  final bool syncing;
  final DateTime? lastSyncAt;

  /// The last attempt failed for lack of network.
  final bool offline;
}

/// Sends queued submits in order. Stops at the first network error (still
/// offline) or a rejected session (401: the entry waits for the next sign-in);
/// any other failure marks that entry failed and moves on.
class SyncService extends Notifier<SyncState> {
  /// The run in progress; callers during a run share it, so one entry is never sent twice.
  Future<void>? _running;

  @override
  SyncState build() {
    ref
      ..listen(connectivityProvider, (prev, next) {
        if (next.value == true && prev?.value != true) unawaited(run());
      })
      ..listen(authControllerProvider.select((s) => s.status), (prev, next) {
        if (next == AuthStatus.signedIn) unawaited(run());
      });
    return const SyncState();
  }

  Future<void> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    if (ref.read(authControllerProvider).status != AuthStatus.signedIn) return;
    final store = ref.read(localStoreProvider);
    state = SyncState(syncing: true, lastSyncAt: state.lastSyncAt);
    var sent = 0;
    var finished = false;
    var offline = false;
    var signedOut = false;
    try {
      final pending = (await store.outbox()).where((e) => e.lastError == null).toList();
      for (final entry in pending) {
        try {
          await ref.read(inspectionsRepositoryProvider).save(entry.body, id: entry.inspectionId, submit: true);
          await store.removeFromOutbox(entry.id);
          sent++;
        } on ApiException catch (e) {
          if (e.isNetwork) {
            offline = true;
            break;
          }
          // The client signs out on 401; keep the entry for the next sign-in.
          if (e.code == 'unauthorized') {
            signedOut = true;
            break;
          }
          await store.markFailed(entry.id, e.fields.isEmpty ? e.code : e.fields.entries.map((f) => '${f.key}: ${f.value}').join(', '));
        } on Object catch (e) {
          // An answer the app can't read: park the entry (the user can retry
          // it from Home) so the rest of the queue still goes.
          debugPrint('Sync: entry ${entry.id} failed: $e');
          await store.markFailed(entry.id, 'unknown');
        }
      }
      finished = true;
    } on Object catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      if (ref.mounted) {
        if (sent > 0) ref.read(inspectionsRevisionProvider.notifier).changed();
        final complete = finished && !offline && !signedOut;
        state = SyncState(lastSyncAt: complete ? DateTime.now() : state.lastSyncAt, offline: offline);
      }
    }
  }
}

final syncServiceProvider = NotifierProvider<SyncService, SyncState>(SyncService.new);
