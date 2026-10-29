import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:field_inspections/data/local/app_database.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tables as each older schema version created them (drift's SQL for the
/// columns of that time; dates are stored as Unix seconds).
const _v1 = [
  'CREATE TABLE "drafts" ("key" TEXT NOT NULL, "json" TEXT NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("key"))',
  'CREATE TABLE "outbox" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "kind" TEXT NOT NULL, "inspection_id" TEXT NULL, '
      '"site" TEXT NOT NULL, "body" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
      '"attempts" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL)',
];
const _v2 = [
  ..._v1,
  'CREATE TABLE "blobs" ("id" TEXT NOT NULL, "data" BLOB NOT NULL, "mime" TEXT NOT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
];
const _v3 = [..._v2, 'ALTER TABLE "outbox" ADD COLUMN "draft_json" TEXT NULL'];

const _draft = InspectionDraft(siteName: 'New depot', notes: 'Gate 3', duration: '45');

/// The same behaviour from the SQLite store the app uses and the in-memory one
/// the other tests use, so a test passing on [MemoryLocalStore] means
/// something for the app.
void _contract(String name, LocalStore Function() open) {
  group(name, () {
    late LocalStore store;
    setUp(() => store = open());

    test('drafts: save, read, replace, delete, watch', () async {
      final seen = <Map<String, InspectionDraft>>[];
      final sub = store.watchDrafts().listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await store.saveDraft('new', _draft);
      await store.saveDraft('new', _draft.copyWith(notes: 'Gate 4'));
      expect((await store.draft('new'))?.notes, 'Gate 4');
      expect((await store.draft('new'))?.duration, '45');
      await pumpEventQueue();
      expect(seen.last['new']?.notes, 'Gate 4');
      await store.deleteDraft('new');
      expect(await store.draft('new'), isNull);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
    });

    test('outbox: in order; a rejection is recorded and counted; Retry clears it', () async {
      final first = await store.enqueue(kind: 'create', site: 'A', body: {'site': 'A'}, draft: _draft, requestKey: 'sub-1');
      final second = await store.enqueue(kind: 'update', site: 'B', body: {'site': 'B'}, inspectionId: 'INS-1042');
      expect((await store.outbox()).map((e) => e.id), [first, second]);
      final a = (await store.outbox()).first;
      expect((a.kind, a.site, a.requestKey, a.draft?.notes), ('create', 'A', 'sub-1', 'Gate 3'));
      expect(a.body, {'site': 'A'});
      expect((await store.outbox())[1].inspectionId, 'INS-1042');

      await store.markFailed(first, 'site: required');
      await store.markFailed(first, 'site: required');
      final failed = (await store.outbox()).first;
      expect((failed.lastError, failed.attempts), ('site: required', 2));

      await store.retryEntry(first);
      expect((await store.outbox()).first.lastError, isNull);
      await store.removeFromOutbox(first);
      expect((await store.outbox()).map((e) => e.id), [second]);
    });

    test('blobs: put, read, replace, delete', () async {
      await store.putBlob('ph-1', Uint8List.fromList([1, 2, 3]), 'image/png');
      await store.putBlob('ph-1', Uint8List.fromList([4]), 'image/png');
      expect(await store.blob('ph-1'), [4]);
      await store.deleteBlob('ph-1');
      expect(await store.blob('ph-1'), isNull);
    });

    test('clearAll removes drafts, the outbox and files', () async {
      await store.saveDraft('new', _draft);
      await store.enqueue(kind: 'create', site: 'A', body: {});
      await store.putBlob('ph-1', Uint8List.fromList([1]), 'image/png');
      await store.clearAll();
      expect(await store.draft('new'), isNull);
      expect(await store.outbox(), isEmpty);
      expect(await store.blob('ph-1'), isNull);
    });
  });
}

void main() {
  _contract('MemoryLocalStore', MemoryLocalStore.new);
  _contract('DriftLocalStore (SQLite)', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return DriftLocalStore(db);
  });

  group('upgrading an older database keeps what is queued', () {
    for (final (version, tables) in [(1, _v1), (2, _v2), (3, _v3)]) {
      test('from v$version', () async {
        final db = AppDatabase(
          NativeDatabase.memory(
            setup: (raw) {
              // Only on the first open: the schema and a queued report of that version.
              if (raw.userVersion != 0) return;
              for (final sql in tables) {
                raw.execute(sql);
              }
              raw
                ..execute('INSERT INTO outbox (kind, site, body, created_at, attempts, last_error) VALUES (?, ?, ?, ?, ?, ?)', [
                  'create',
                  'Old depot',
                  '{"site":"Old depot"}',
                  1761300000,
                  1,
                  'server',
                ])
                ..execute('INSERT INTO drafts (key, json, updated_at) VALUES (?, ?, ?)', ['new', '{"siteName":"Old draft"}', 1761300000])
                ..userVersion = version;
            },
          ),
        );
        addTearDown(db.close);
        final store = DriftLocalStore(db);

        final old = (await store.outbox()).single;
        expect((old.site, old.lastError, old.attempts, old.draft, old.requestKey), ('Old depot', 'server', 1, null, null));
        expect((await store.draft('new'))?.siteName, 'Old draft');

        // Everything a newer app writes works on the upgraded database.
        await store.enqueue(kind: 'create', site: 'New', body: {}, draft: _draft, requestKey: 'sub-2');
        expect((await store.outbox()).last.requestKey, 'sub-2');
        expect((await store.outbox()).last.draft?.notes, 'Gate 3');
        await store.putBlob('ph-1', Uint8List.fromList([7]), 'image/jpeg');
        expect(await store.blob('ph-1'), [7]);
        expect(await db.customSelect('PRAGMA user_version').map((r) => r.read<int>('user_version')).getSingle(), 4);
      });
    }
  });
}
