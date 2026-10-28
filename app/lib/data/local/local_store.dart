import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/draft.dart';
import 'app_database.dart';

/// A queued write (offline submit).
@immutable
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.site,
    required this.body,
    required this.createdAt,
    this.inspectionId,
    this.lastError,
    this.attempts = 0,
    this.draft,
    this.requestKey,
  });

  final int id;
  final String kind;
  final String? inspectionId;
  final String site;
  final Map<String, Object?> body;
  final DateTime createdAt;
  final String? lastError;

  /// Server rejections so far.
  final int attempts;

  /// The draft the entry was made from, to reopen a rejected report.
  final InspectionDraft? draft;

  /// Sent as `Idempotency-Key` with a create (see [InspectionsRepository.save]).
  final String? requestKey;

  OutboxEntry _copy({String? Function()? lastError, int? attempts}) => OutboxEntry(
    id: id,
    kind: kind,
    site: site,
    body: body,
    createdAt: createdAt,
    inspectionId: inspectionId,
    lastError: lastError != null ? lastError() : this.lastError,
    attempts: attempts ?? this.attempts,
    draft: draft,
    requestKey: requestKey,
  );
}

/// Drafts and outbox. Drift (SQLite) in the app, in-memory in tests.
abstract interface class LocalStore {
  Future<InspectionDraft?> draft(String key);
  Future<void> saveDraft(String key, InspectionDraft draft);
  Future<void> deleteDraft(String key);
  Stream<Map<String, InspectionDraft>> watchDrafts();

  Future<int> enqueue({
    required String kind,
    required String site,
    required Map<String, Object?> body,
    String? inspectionId,
    InspectionDraft? draft,
    String? requestKey,
  });
  Future<List<OutboxEntry>> outbox();
  Stream<List<OutboxEntry>> watchOutbox();
  Future<void> removeFromOutbox(int id);

  /// Records a server rejection; the entry is skipped until [retryEntry].
  Future<void> markFailed(int id, String error);

  /// Clears a rejection so the next sync sends the entry again.
  Future<void> retryEntry(int id);

  Future<void> putBlob(String id, Uint8List data, String mime);
  Future<Uint8List?> blob(String id);
  Future<void> deleteBlob(String id);

  /// Deletes every draft, queued write and stored file (sign-out).
  Future<void> clearAll();
}

class DriftLocalStore implements LocalStore {
  DriftLocalStore(this._db);

  final AppDatabase _db;

  InspectionDraft _parse(Draft row) => InspectionDraft.fromJson(jsonDecode(row.json) as Map<String, Object?>);

  @override
  Future<InspectionDraft?> draft(String key) async {
    final row = await (_db.select(_db.drafts)..where((d) => d.key.equals(key))).getSingleOrNull();
    return row == null ? null : _parse(row);
  }

  @override
  Future<void> saveDraft(String key, InspectionDraft draft) => _db
      .into(_db.drafts)
      .insertOnConflictUpdate(
        DraftsCompanion.insert(key: key, json: jsonEncode(draft.toJson()), updatedAt: draft.updatedAt ?? DateTime.now()),
      );

  @override
  Future<void> deleteDraft(String key) => (_db.delete(_db.drafts)..where((d) => d.key.equals(key))).go();

  @override
  Stream<Map<String, InspectionDraft>> watchDrafts() =>
      _db.select(_db.drafts).watch().map((rows) => {for (final r in rows) r.key: _parse(r)});

  OutboxEntry _entry(OutboxData r) => OutboxEntry(
    id: r.id,
    kind: r.kind,
    inspectionId: r.inspectionId,
    site: r.site,
    body: jsonDecode(r.body) as Map<String, Object?>,
    createdAt: r.createdAt,
    lastError: r.lastError,
    attempts: r.attempts,
    draft: r.draftJson == null ? null : InspectionDraft.fromJson(jsonDecode(r.draftJson!) as Map<String, Object?>),
    requestKey: r.requestKey,
  );

  @override
  Future<int> enqueue({
    required String kind,
    required String site,
    required Map<String, Object?> body,
    String? inspectionId,
    InspectionDraft? draft,
    String? requestKey,
  }) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          kind: kind,
          site: site,
          body: jsonEncode(body),
          createdAt: DateTime.now(),
          inspectionId: Value(inspectionId),
          draftJson: Value(draft == null ? null : jsonEncode(draft.toJson())),
          requestKey: Value(requestKey),
        ),
      );

  SimpleSelectStatement<$OutboxTable, OutboxData> get _ordered => _db.select(_db.outbox)..orderBy([(o) => OrderingTerm.asc(o.id)]);

  @override
  Future<List<OutboxEntry>> outbox() async => (await _ordered.get()).map(_entry).toList();

  @override
  Stream<List<OutboxEntry>> watchOutbox() => _ordered.watch().map((rows) => rows.map(_entry).toList());

  @override
  Future<void> removeFromOutbox(int id) => (_db.delete(_db.outbox)..where((o) => o.id.equals(id))).go();

  @override
  Future<void> markFailed(int id, String error) => _db.customUpdate(
    'UPDATE outbox SET last_error = ?, attempts = attempts + 1 WHERE id = ?',
    variables: [Variable.withString(error), Variable.withInt(id)],
    updates: {_db.outbox},
  );

  @override
  Future<void> retryEntry(int id) =>
      (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(const OutboxCompanion(lastError: Value(null)));

  @override
  Future<void> putBlob(String id, Uint8List data, String mime) =>
      _db.into(_db.blobs).insertOnConflictUpdate(BlobsCompanion.insert(id: id, data: data, mime: mime, createdAt: DateTime.now()));

  @override
  Future<Uint8List?> blob(String id) async => (await (_db.select(_db.blobs)..where((b) => b.id.equals(id))).getSingleOrNull())?.data;

  @override
  Future<void> deleteBlob(String id) => (_db.delete(_db.blobs)..where((b) => b.id.equals(id))).go();

  @override
  Future<void> clearAll() => _db.transaction(() async {
    await _db.delete(_db.drafts).go();
    await _db.delete(_db.outbox).go();
    await _db.delete(_db.blobs).go();
  });
}

/// In-memory store for tests. Drafts go through JSON like the SQLite store,
/// so a field missing from `toJson`/`fromJson` fails the same way.
class MemoryLocalStore implements LocalStore {
  final Map<String, InspectionDraft> drafts = {};
  final Map<String, Uint8List> blobs = {};
  final List<OutboxEntry> entries = [];
  final _draftsCtl = StreamController<Map<String, InspectionDraft>>.broadcast();
  final _outboxCtl = StreamController<List<OutboxEntry>>.broadcast();
  int _nextId = 1;

  static InspectionDraft _roundTrip(InspectionDraft d) =>
      InspectionDraft.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, Object?>);

  void _emit() {
    _draftsCtl.add(Map.of(drafts));
    _outboxCtl.add(List.of(entries));
  }

  @override
  Future<InspectionDraft?> draft(String key) async => drafts[key];

  @override
  Future<void> saveDraft(String key, InspectionDraft draft) async {
    drafts[key] = _roundTrip(draft);
    _emit();
  }

  @override
  Future<void> deleteDraft(String key) async {
    drafts.remove(key);
    _emit();
  }

  @override
  Stream<Map<String, InspectionDraft>> watchDrafts() async* {
    yield Map.of(drafts);
    yield* _draftsCtl.stream;
  }

  @override
  Future<int> enqueue({
    required String kind,
    required String site,
    required Map<String, Object?> body,
    String? inspectionId,
    InspectionDraft? draft,
    String? requestKey,
  }) async {
    final id = _nextId++;
    entries.add(
      OutboxEntry(
        id: id,
        kind: kind,
        site: site,
        body: jsonDecode(jsonEncode(body)) as Map<String, Object?>,
        createdAt: DateTime.now(),
        inspectionId: inspectionId,
        draft: draft == null ? null : _roundTrip(draft),
        requestKey: requestKey,
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<List<OutboxEntry>> outbox() async => List.of(entries);

  @override
  Stream<List<OutboxEntry>> watchOutbox() async* {
    yield List.of(entries);
    yield* _outboxCtl.stream;
  }

  @override
  Future<void> removeFromOutbox(int id) async {
    entries.removeWhere((e) => e.id == id);
    _emit();
  }

  void _update(int id, OutboxEntry Function(OutboxEntry e) change) {
    final i = entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    entries[i] = change(entries[i]);
    _emit();
  }

  @override
  Future<void> markFailed(int id, String error) async => _update(id, (e) => e._copy(lastError: () => error, attempts: e.attempts + 1));

  @override
  Future<void> retryEntry(int id) async => _update(id, (e) => e._copy(lastError: () => null));

  @override
  Future<void> putBlob(String id, Uint8List data, String mime) async => blobs[id] = data;

  @override
  Future<Uint8List?> blob(String id) async => blobs[id];

  @override
  Future<void> deleteBlob(String id) async => blobs.remove(id);

  @override
  Future<void> clearAll() async {
    drafts.clear();
    entries.clear();
    blobs.clear();
    _emit();
  }
}

final localStoreProvider = Provider<LocalStore>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return DriftLocalStore(db);
});

/// Drafts on this device keyed by wizard key (`new` or an inspection id).
final draftsProvider = StreamProvider<Map<String, InspectionDraft>>((ref) => ref.watch(localStoreProvider).watchDrafts());

final outboxProvider = StreamProvider<List<OutboxEntry>>((ref) => ref.watch(localStoreProvider).watchOutbox());

/// Bytes of a photo or file saved with a draft; null for simulated entries.
/// Dropped when no screen shows it, so viewed photos don't pile up in memory.
final blobProvider = FutureProvider.autoDispose.family<Uint8List?, String>((ref, id) => ref.watch(localStoreProvider).blob(id));
