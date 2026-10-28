// The real HTTP repositories and API client against the mock server's own
// handler (in-process): request encoding, the server's auth checks, JSON
// decoding, and the 401 → sign-out wiring in data/providers.dart.
import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/data/api/api_exception.dart';
import 'package:field_inspections/data/api/backend_config.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/models/list_query.dart';
import 'package:field_inspections/data/providers.dart';
import 'package:field_inspections/data/repositories/inspections_repository.dart';
import 'package:field_inspections/data/sync/sync_service.dart';
import 'package:field_inspections/features/auth/auth_controller.dart';
import 'package:field_inspections/features/auth/auth_models.dart';
import 'package:field_inspections/features/inspections/inspections_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/mock_server_adapter.dart';
import '../helpers/test_app.dart';

final _today = DateTime(2026, 10, 24, 10);

/// A complete new inspection for the day after [_today].
Map<String, Object?> _body() => InspectionDraft(
  siteId: 's-riverside-office',
  siteName: 'Riverside office, floor 4',
  type: 'Fire safety, annual',
  date: DateTime(2026, 10, 25),
  startMinutes: 9 * 60,
  duration: '60',
  answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
  confirmed: true,
).toApiBody();

void main() {
  late MockServerAdapter server;
  late MemoryStore kv;
  late MemoryLocalStore local;

  setUp(() {
    server = MockServerAdapter(now: _today);
    kv = MemoryStore();
    local = MemoryLocalStore();
  });

  /// The app's providers in HTTP mode; [store] seeds key-value storage.
  Future<ProviderContainer> start({Map<String, String>? store}) async {
    kv = MemoryStore(store);
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(kv),
        backendConfigProvider.overrideWithValue(const BackendConfig(mode: BackendMode.http, baseUrl: mockServerUrl)),
        httpClientAdapterProvider.overrideWithValue(server),
        localStoreProvider.overrideWithValue(local),
        connectivityProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(authControllerProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  /// The same data the server answers from, to compare against.
  final reference = MockDatabase(clock: () => _today);

  List<String> ids(Object? page) => [for (final i in (page! as Map)['items']! as List) (i as Map)['id']! as String];

  test('sign-in, then list filters and paging reach the server as it reads them', () async {
    final c = await start();
    await c.read(authControllerProvider.notifier).signIn(demoEmail, demoPassword);
    expect(c.read(authControllerProvider).status, AuthStatus.signedIn);
    final repo = c.read(inspectionsRepositoryProvider);
    expect(repo, isA<HttpInspectionsRepository>());

    const query = ListQuery(
      statuses: {InspectionStatus.overdue, InspectionStatus.draft, InspectionStatus.submitted},
      q: 'a',
      sort: SortOrder.siteAsc,
    );
    final expected = reference.listInspections(status: {'overdue', 'draft', 'submitted'}, q: 'a', sort: 'siteAsc', pageSize: 3);
    final first = await repo.list(query, pageSize: 3);
    expect(first.total, expected['total']);
    expect(first.total, greaterThan(3), reason: 'enough rows for a second page');
    expect([for (final i in first.items) i.id], ids(expected));
    expect(first.hasMore, isTrue);
    final second = await repo.list(query, page: 2, pageSize: 3);
    expect([
      for (final i in second.items) i.id,
    ], ids(reference.listInspections(status: {'overdue', 'draft', 'submitted'}, q: 'a', sort: 'siteAsc', page: 2, pageSize: 3)));

    // A custom range: local dates without a zone must mean the same days on the server.
    final range = ListQuery(due: DueWindow.custom, from: DateTime(2026, 10, 24), to: DateTime(2026, 10, 26));
    final inRange = await repo.list(range);
    expect([
      for (final i in inRange.items) i.id,
    ], ids(reference.listInspections(due: 'custom', from: DateTime(2026, 10, 24), to: DateTime(2026, 10, 26))));
    expect(inRange.items, isNotEmpty);
  });

  test('detail, checklist, types, sites and notifications decode', () async {
    final c = await start(store: signedInStore());
    final repo = c.read(inspectionsRepositoryProvider);

    final detail = await repo.get('INS-1042');
    expect(
      (detail.summary.id, detail.summary.site, detail.summary.status),
      ('INS-1042', 'Warehouse A – loading dock', InspectionStatus.inProgress),
    );
    expect((detail.answered, detail.total, detail.failed, detail.photos.length), (12, 18, 2, 6));
    expect(await repo.checklist(fireSafetyTemplateId), hasLength(18));
    expect(await repo.inspectionTypes(), contains('Fire safety, annual'));
    expect([for (final s in await repo.searchSites('River')) s.name], containsAll(['Riverside office, floor 4', 'River pumping station']));

    final notifications = await repo.notifications();
    expect(notifications, isNotEmpty);
    await repo.markNotificationsRead(id: notifications.first.id);
    await repo.deleteNotification(notifications.first.id);
    expect([for (final n in await repo.notifications()) n.id], isNot(contains(notifications.first.id)));
    await expectLater(repo.get('INS-9999'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'notFound')));
  });

  test('save: a submitted create, an update, and field errors from the server', () async {
    final c = await start(store: signedInStore());
    final repo = c.read(inspectionsRepositoryProvider);

    final created = await repo.save(_body(), submit: true);
    expect(created.summary.status, InspectionStatus.submitted, reason: '?submit=true reached the server');
    final updated = await repo.save({'notes': 'Gate 3'}, id: created.summary.id);
    expect((updated.summary.id, updated.notes), (created.summary.id, 'Gate 3'));

    await expectLater(
      repo.save({'site': 'x'}),
      throwsA(
        isA<ApiException>()
            .having((e) => (e.code, e.status), 'error', ('validation', 422))
            .having((e) => e.fields, 'fields', containsPair('site', 'required')),
      ),
    );
  });

  test('save: a create sent again with its Idempotency-Key returns the first inspection', () async {
    final c = await start(store: signedInStore());
    final repo = c.read(inspectionsRepositoryProvider);
    final first = await repo.save(_body(), submit: true, requestKey: 'sub-test-1');
    final again = await repo.save(_body(), submit: true, requestKey: 'sub-test-1');
    final other = await repo.save(_body(), submit: true);
    expect(again.summary.id, first.summary.id, reason: 'the header reached the server');
    expect(other.summary.id, isNot(first.summary.id));
  });

  test('the stored session is checked with the server on start', () async {
    final good = await start(store: signedInStore());
    expect(good.read(authControllerProvider).status, AuthStatus.signedIn);
    expect(server.requests.map((r) => r.path), contains('/me'));

    final ghost = await start(
      store: {'session': '{"token":"mock-u-ghost-1","user":{"id":"u-ghost","name":"Ghost","email":"ghost@example.com","initials":"G"}}'},
    );
    expect(ghost.read(authControllerProvider).status, AuthStatus.signedOut);
    expect(kv.getString('session'), isNull);
  });

  test('a 401 mid-session signs out; the stored session goes, this device\'s data stays', () async {
    final c = await start();
    await c.read(authControllerProvider.notifier).signUp(name: 'Field Tester', email: 'field.tester@example.com', password: 'inspect456');
    expect(c.read(authControllerProvider).status, AuthStatus.signedIn);
    await local.enqueue(kind: 'create', site: 'Riverside', body: _body());

    // The server forgets the account (reset to its fixtures), so its token is rejected.
    await server.reset();
    await expectLater(
      c.read(inspectionsRepositoryProvider).list(const ListQuery()),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthorized')),
    );
    await pumpEventQueue();
    expect(c.read(authControllerProvider).status, AuthStatus.signedOut);
    expect(kv.getString('session'), isNull);
    expect(local.entries, hasLength(1), reason: 'a forced sign-out keeps the outbox for the next sign-in');
  });

  test('wrong credentials are a form error, not a sign-out', () async {
    final c = await start(store: signedInStore());
    await expectLater(
      c.read(authControllerProvider.notifier).signIn(demoEmail, 'wrong-password1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalidCredentials')),
    );
    expect(c.read(authControllerProvider).status, AuthStatus.signedIn);
  });

  testWidgets('the app over HTTP: demo sign-in, a filtered list, the detail', (tester) async {
    final app = await pumpApp(tester, http: server, now: _today, initialLocation: '/inspections?status=draft');
    await tester.tap(find.text('Use demo account'));
    await tester.pumpAndSettle();
    expect(app.location, '/inspections?status=draft');
    expect(find.textContaining('INS-1040'), findsWidgets, reason: 'the draft');
    expect(find.textContaining('INS-1042'), findsNothing, reason: 'in progress, filtered out by the server');
    final list = server.requests.lastWhere((r) => r.path == '/inspections');
    expect(list.headers['Authorization'], startsWith('Bearer mock-u-anna-'));

    await app.go('/inspections/INS-1042');
    expect(find.text('Warehouse A – loading dock'), findsWidgets);
  });
}
