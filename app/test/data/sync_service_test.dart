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
import 'package:field_inspections/features/inspections/inspections_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/test_app.dart';

final _today = DateTime(2026, 10, 24, 10);

final _allPass = {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass};

/// A complete new inspection for the day after [_today].
Map<String, Object?> _body(String siteId) => InspectionDraft(
  siteId: siteId,
  siteName: siteId,
  type: 'Fire safety, annual',
  date: DateTime(2026, 10, 25),
  startMinutes: 9 * 60,
  duration: '60',
  answers: _allPass,
  confirmed: true,
).toApiBody();

/// Fake backend whose saves can be held or made to fail.
class _Repo extends FakeInspectionsRepository {
  _Repo(super.db) : super(latency: Duration.zero);

  int saves = 0;
  Completer<void>? hold;
  Object? failWith;

  /// Reference data fails like a device without network.
  bool offline = false;

  /// The server stores the save, then the answer is lost on the way back.
  bool loseResponse = false;

  int checklistLoads = 0;

  @override
  Future<List<ChecklistItem>> checklist(String templateId) {
    checklistLoads++;
    return offline ? Future.error(const ApiException('network')) : super.checklist(templateId);
  }

  @override
  Future<List<String>> inspectionTypes() => offline ? Future.error(const ApiException('network')) : super.inspectionTypes();

  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false, String? requestKey}) async {
    saves++;
    await hold?.future;
    if (failWith case final e?) throw e;
    final saved = await super.save(body, id: id, submit: submit, requestKey: requestKey);
    if (loseResponse) throw const ApiException('network');
    return saved;
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

  test('an entry retried while a run is going is sent by that run', () async {
    final c = await signedIn();
    final rejected = await store.enqueue(kind: 'create', site: 'Harbour', body: _body('s-warehouse-a'));
    await store.markFailed(rejected, 'server');
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    repo.hold = Completer<void>();
    final sync = c.read(syncServiceProvider.notifier);
    final running = sync.run();
    // Home → Retry while the run sends the other entry.
    await store.retryEntry(rejected);
    final retried = sync.run();
    repo.hold!.complete();
    await Future.wait([running, retried]);
    expect(store.entries, isEmpty);
    expect(repo.saves, 2);
  });

  test('a run stops sending when the session ends meanwhile', () async {
    final c = await signedIn();
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    await store.enqueue(kind: 'create', site: 'Harbour', body: _body('s-warehouse-a'));
    repo.hold = Completer<void>();
    final run = c.read(syncServiceProvider.notifier).run();
    await Future<void>.delayed(Duration.zero);
    // The first request is on its way when the user leaves (e.g. "Use password instead").
    await c.read(authControllerProvider.notifier).signOut();
    repo.hold!.complete();
    await run;
    expect(repo.saves, 1, reason: 'the second entry waits for its owner to sign in again');
    expect(store.entries, hasLength(1));
  });

  test('a queue that belongs to another account is never sent', () async {
    final c = await signedIn();
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    // The owner key still names someone else (switching owners failed).
    await c.read(keyValueStoreProvider).setString('local_data_owner', 'u-other');
    await c.read(syncServiceProvider.notifier).run();
    expect(repo.saves, 0);
    expect(store.entries, hasLength(1));
  });

  test('every run refreshes the reference data, even while a wizard keeps it loaded', () async {
    final c = await signedIn();
    c.listen(checklistProvider(fireSafetyTemplateId), (_, _) {});
    await c.read(checklistProvider(fireSafetyTemplateId).future);
    final before = repo.checklistLoads;
    await c.read(syncServiceProvider.notifier).run();
    expect(repo.checklistLoads, before + 1);
  });

  test('a queued edit updates the inspection instead of creating one', () async {
    final c = await signedIn();
    final before = created();
    final current = InspectionDraft.fromInspection(InspectionDetail.fromJson(db.getInspection('INS-1042')));
    final body = current.copyWith(notes: 'Edited offline', duration: '60', answers: _allPass, confirmed: true).toApiBody();
    await store.enqueue(kind: 'update', inspectionId: 'INS-1042', site: 'Warehouse A', body: body);
    await c.read(syncServiceProvider.notifier).run();
    expect(store.entries, isEmpty);
    expect(created(), before);
    expect(db.getInspection('INS-1042')['notes'], 'Edited offline');
  });

  test('a create whose answer was lost is not made twice when sync sends it again', () async {
    final c = await signedIn();
    final before = created();
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'), requestKey: 'sub-1');
    repo.loseResponse = true;
    await c.read(syncServiceProvider.notifier).run();
    expect(store.entries, hasLength(1), reason: 'looks like no network, so the entry stays');

    repo.loseResponse = false;
    await c.read(syncServiceProvider.notifier).run();
    expect(store.entries, isEmpty);
    expect(repo.saves, 2);
    expect(created(), before + 1, reason: 'the second send returned the first inspection');
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

  test('a sync keeps the checklist and types on the device, for a wizard opened offline later', () async {
    final c = await signedIn();
    await c.read(syncServiceProvider.notifier).run();
    final kv = c.read(keyValueStoreProvider);
    expect(kv.getString('cache.checklist.$fireSafetyTemplateId'), isNotNull);
    expect(kv.getString('cache.inspectionTypes'), isNotNull);

    // A later start without network, the wizard never opened online.
    repo.offline = true;
    final later = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(kv), inspectionsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(later.dispose);
    expect(await later.read(checklistProvider(fireSafetyTemplateId).future), hasLength(18));
    expect(await later.read(inspectionTypesProvider.future), contains('Fire safety, annual'));
  });

  test('without network the sync still finishes; the wizard reports the missing data itself', () async {
    repo.offline = true;
    final c = await signedIn();
    await store.enqueue(kind: 'create', site: 'Riverside', body: _body('s-riverside-office'));
    await c.read(syncServiceProvider.notifier).run();
    expect(store.entries, isEmpty, reason: 'the outbox is sent regardless');
    expect(c.read(syncServiceProvider).syncing, isFalse);
    expect(c.read(keyValueStoreProvider).getString('cache.checklist.$fireSafetyTemplateId'), isNull);
    await expectLater(c.read(checklistProvider(fireSafetyTemplateId).future), throwsA(isA<ApiException>()));
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
