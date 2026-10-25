import 'dart:async';

import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/data/api/api_exception.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/providers.dart';
import 'package:field_inspections/data/repositories/inspections_repository.dart';
import 'package:field_inspections/data/sync/sync_service.dart';
import 'package:field_inspections/features/auth/auth_controller.dart';
import 'package:field_inspections/features/auth/auth_models.dart';
import 'package:field_inspections/features/auth/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/test_app.dart';

final _today = DateTime(2026, 10, 24, 10);

/// A complete new inspection for the day after [_today].
Map<String, Object?> _body(String siteId) => InspectionDraft(
  siteId: siteId,
  siteName: siteId,
  type: 'Fire safety, annual',
  date: DateTime(2026, 10, 25),
  startMinutes: 9 * 60,
  duration: '60',
  answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
  confirmed: true,
).toApiBody();

/// Fake backend whose saves can be held or made to fail.
class _Repo extends FakeInspectionsRepository {
  _Repo(super.db) : super(latency: Duration.zero);

  int saves = 0;
  Completer<void>? hold;
  Object? failWith;

  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false}) async {
    saves++;
    await hold?.future;
    if (failWith case final e?) throw e;
    return super.save(body, id: id, submit: submit);
  }
}

void main() {
  late MockDatabase db;
  late _Repo repo;
  late MemoryLocalStore store;
  late StreamController<bool> online;

  setUp(() {
    db = MockDatabase(clock: () => _today);
    repo = _Repo(db);
    store = MemoryLocalStore();
    online = StreamController<bool>.broadcast();
  });

  tearDown(() => online.close());

  Future<ProviderContainer> signedIn() async {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryStore(signedInStore())),
        mockDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(db, latency: Duration.zero)),
        inspectionsRepositoryProvider.overrideWithValue(repo),
        localStoreProvider.overrideWithValue(store),
        connectivityProvider.overrideWith((ref) => online.stream),
      ],
    );
    addTearDown(c.dispose);
    c
      ..listen(authControllerProvider, (_, _) {})
      ..listen(syncServiceProvider, (_, _) {});
    // Session restored; the sign-in sync has nothing to send yet.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.read(authControllerProvider).status, AuthStatus.signedIn);
    return c;
  }

  int created() => db.listInspections(pageSize: 1)['total']! as int;

  test('overlapping runs send each entry once', () async {
    final c = await signedIn();
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    repo.hold = Completer<void>();
    final sync = c.read(syncServiceProvider.notifier);
    // "Sync now" while the connectivity-triggered run is still going.
    final first = sync.run();
    final second = sync.run();
    expect(c.read(syncServiceProvider).syncing, isTrue);
    repo.hold!.complete();
    await Future.wait([first, second]);
    expect(repo.saves, 1);
    expect(store.entries, isEmpty);
    expect(c.read(syncServiceProvider).syncing, isFalse);
  });

  test('a rejected entry is marked, the next one still goes, and it is not resent', () async {
    final c = await signedIn();
    final before = created();
    await store.enqueue(kind: 'create', site: 'Bad', body: {'site': 'x'});
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    await c.read(syncServiceProvider.notifier).run();
    expect(store.entries, hasLength(1));
    expect(store.entries.single.lastError, contains('site'));
    expect(store.entries.single.attempts, 1);
    expect(created(), before + 1, reason: 'the good entry after the bad one was created');

    await c.read(syncServiceProvider.notifier).run();
    expect(repo.saves, 2, reason: 'the rejected entry waits for Retry');
  });

  test('Retry clears the rejection so the entry is sent again', () async {
    final c = await signedIn();
    final id = await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    repo.failWith = const ApiException('server', status: 500);
    await c.read(syncServiceProvider.notifier).run();
    expect(store.entries.single.lastError, 'server');

    repo.failWith = null;
    await store.retryEntry(id);
    await c.read(syncServiceProvider.notifier).run();
    expect(store.entries, isEmpty);
  });

  test('an unreadable answer parks the entry instead of stopping sync for good', () async {
    final c = await signedIn();
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    await store.enqueue(kind: 'create', site: 'Harbour', body: _body('s-warehouse-a'));
    repo.failWith = TypeError();
    await c.read(syncServiceProvider.notifier).run();
    expect(c.read(syncServiceProvider).syncing, isFalse);
    expect(store.entries.map((e) => e.lastError), ['unknown', 'unknown']);

    repo.failWith = null;
    for (final e in store.entries.toList()) {
      await store.retryEntry(e.id);
    }
    await c.read(syncServiceProvider.notifier).run();
    expect(store.entries, isEmpty);
  });

  test('a rejected session (401) keeps the entry for the next sign-in', () async {
    final c = await signedIn();
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    await store.enqueue(kind: 'create', site: 'Harbour', body: _body('s-warehouse-a'));
    repo.failWith = const ApiException('unauthorized', status: 401);
    await c.read(syncServiceProvider.notifier).run();
    expect(repo.saves, 1, reason: 'stops at the first 401');
    expect(store.entries.map((e) => e.lastError), [null, null]);
    expect(store.entries.map((e) => e.attempts), [0, 0]);
  });

  test('connectivity coming back sends the queue', () async {
    final c = await signedIn();
    online.add(false);
    await Future<void>.delayed(Duration.zero);
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    online.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(store.entries, isEmpty);
    expect(c.read(syncServiceProvider).lastSyncAt, isNotNull);
  });

  test('the outbox keeps the draft so a rejected report can be reopened', () async {
    final draft = InspectionDraft(siteName: 'New depot', type: 'Fire safety, annual', notes: 'Gate 3', date: DateTime(2026, 10, 25));
    await store.enqueue(kind: 'create', site: 'New depot', body: draft.toApiBody(), draft: draft);
    final saved = (await store.outbox()).single.draft!;
    expect(saved.siteName, 'New depot');
    expect(saved.notes, 'Gate 3');
    expect(saved.date, DateTime(2026, 10, 25));
  });
}
