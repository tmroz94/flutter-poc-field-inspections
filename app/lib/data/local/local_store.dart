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
  });

  final int id;
  final String kind;
  final String? inspectionId;
  final String site;
  final Map<String, Object?> body;
  final DateTime createdAt;
  final String? lastError;
}

/// Drafts and outbox. Drift (SQLite) in the app, in-memory in tests.
abstract interface class LocalStore {
  Future<InspectionDraft?> draft(String key);
  Future<void> saveDraft(String key, InspectionDraft draft);
  Future<void> deleteDraft(String key);
  Stream<Map<String, InspectionDraft>> watchDrafts();

  Future<int> enqueue({required String kind, required String site, required Map<String, Object?> body, String? inspectionId});
  Future<List<OutboxEntry>> outbox();
  Stream<List<OutboxEntry>> watchOutbox();
  Future<void> removeFromOutbox(int id);
  Future<void> markFailed(int id, String error);
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
  );

  @override
  Future<int> enqueue({required String kind, required String site, required Map<String, Object?> body, String? inspectionId}) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          kind: kind,
          site: site,
          body: jsonEncode(body),
          createdAt: DateTime.now(),
          inspectionId: Value(inspectionId),
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
  Future<void> markFailed(int id, String error) => (_db.update(
    _db.outbox,
  )..where((o) => o.id.equals(id))).write(OutboxCompanion(lastError: Value(error), attempts: const Value.absent()));
}

/// In-memory store for tests.
class MemoryLocalStore implements LocalStore {
  final Map<String, InspectionDraft> drafts = {};
  final List<OutboxEntry> entries = [];
  final _draftsCtl = StreamController<Map<String, InspectionDraft>>.broadcast();
  final _outboxCtl = StreamController<List<OutboxEntry>>.broadcast();
  int _nextId = 1;

  void _emit() {
    _draftsCtl.add(Map.of(drafts));
    _outboxCtl.add(List.of(entries));
  }

  @override
  Future<InspectionDraft?> draft(String key) async => drafts[key];

  @override
  Future<void> saveDraft(String key, InspectionDraft draft) async {
    drafts[key] = draft;
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
  Future<int> enqueue({required String kind, required String site, required Map<String, Object?> body, String? inspectionId}) async {
    final id = _nextId++;
    entries.add(OutboxEntry(id: id, kind: kind, site: site, body: body, createdAt: DateTime.now(), inspectionId: inspectionId));
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

  @override
  Future<void> markFailed(int id, String error) async {
    final i = entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = entries[i];
    entries[i] = OutboxEntry(
      id: e.id,
      kind: e.kind,
      site: e.site,
      body: e.body,
      createdAt: e.createdAt,
      inspectionId: e.inspectionId,
      lastError: error,
    );
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
