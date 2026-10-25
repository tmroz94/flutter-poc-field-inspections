import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/core/validation/validators.dart';
import 'package:field_inspections/data/api/api_exception.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/providers.dart';
import 'package:field_inspections/data/repositories/inspections_repository.dart';
import 'package:field_inspections/data/sync/sync_service.dart';
import 'package:field_inspections/features/auth/auth_controller.dart';
import 'package:field_inspections/features/auth/auth_repository.dart';
import 'package:field_inspections/features/wizard/wizard_controller.dart';
import 'package:field_inspections/features/wizard/wizard_validation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

final _today = DateTime(2026, 10, 24, 10);
final _allPass = {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass};

/// Backend that can be offline for reads and writes, or answer garbage.
class _Repo extends FakeInspectionsRepository {
  _Repo(super.db) : super(latency: Duration.zero);

  bool offline = false;
  Object? saveError;
  Object? checklistError;

  @override
  Future<InspectionDetail> get(String id) async {
    if (offline) throw const ApiException('network');
    return super.get(id);
  }

  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false}) async {
    if (saveError case final e?) throw e;
    return super.save(body, id: id, submit: submit);
  }

  @override
  Future<List<ChecklistItem>> checklist(String templateId) async {
    if (checklistError case final e?) throw e;
    return super.checklist(templateId);
  }
}

void main() {
  group('controller', () {
    late MockDatabase db;
    late _Repo repo;
    late MemoryLocalStore store;
    late FakeMedia media;

    setUp(() {
      db = MockDatabase(clock: () => _today);
      repo = _Repo(db);
      store = MemoryLocalStore();
      media = FakeMedia();
    });

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryStore(signedInStore())),
          mockDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(db, latency: Duration.zero)),
          inspectionsRepositoryProvider.overrideWithValue(repo),
          localStoreProvider.overrideWithValue(store),
          mediaServiceProvider.overrideWithValue(media),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(authControllerProvider, (_, _) {});
      return c;
    }

    Future<WizardController> open(ProviderContainer c, String key) async {
      c.listen(wizardControllerProvider(key), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return c.read(wizardControllerProvider(key).notifier);
    }

    test('editing keeps the photos and files already on the server', () async {
      final photos = (db.getInspection('INS-1042')['photos']! as List).length;
      expect(photos, greaterThan(0));
      final c = container();
      final w = await open(c, 'INS-1042');
      final prefilled = c.read(wizardControllerProvider('INS-1042')).draft;
      expect(prefilled.photos, hasLength(photos));
      expect(prefilled.photos.every((p) => p.stored), isTrue);

      w.update((d) => d.copyWith(duration: '120', answers: _allPass, confirmed: true));
      final result = await w.submit();
      expect(result?.outcome, SubmitOutcome.sent);
      final after = db.getInspection('INS-1042');
      expect((after['photos']! as List).length, photos, reason: 'the PUT sends them back by id');
      expect(after['durationMin'], 120);
    });

    test('stored photos with captions pass the file checks', () async {
      final c = container();
      await open(c, 'INS-1042');
      final d = c.read(wizardControllerProvider('INS-1042')).draft;
      final v = WizardValidator(ValidationText.en, today: _today);
      expect(v.photos(d), isNot(contains('type')));
    });

    test('failure details on the server come back into the edit', () async {
      db.updateInspection('INS-1042', {
        'answers': {for (final id in _allPass.keys) id: id == 'c02' ? 'fail' : 'pass'},
        'failures': {
          'c02': {'severity': 4, 'followUp': false, 'note': 'Exit blocked'},
        },
      });
      final c = container();
      await open(c, 'INS-1042');
      final d = c.read(wizardControllerProvider('INS-1042')).draft;
      expect(d.failures['c02']?.note, 'Exit blocked');
      expect(d.failures['c02']?.severity, 4);
    });

    test('opening Edit offline shows the error and saves nothing; Try again prefills', () async {
      repo.offline = true;
      final c = container();
      final w = await open(c, 'INS-1042');
      expect(c.read(wizardControllerProvider('INS-1042')).loadError, isA<ApiException>());
      await w.saveNow();
      expect(store.drafts, isEmpty, reason: 'an empty edit draft would hide the prefill from then on');

      repo.offline = false;
      await w.reload();
      final state = c.read(wizardControllerProvider('INS-1042'));
      expect(state.loadError, isNull);
      expect(state.draft.siteName, 'Warehouse A – loading dock');
    });

    test('an untouched edit has nothing to save or discard', () async {
      final c = container();
      final w = await open(c, 'INS-1042');
      w.reachStep(3);
      expect(c.read(wizardControllerProvider('INS-1042')).hasDraft, isFalse);
      await w.saveNow();
      expect(store.drafts, isEmpty);
    });

    test('discard deletes the draft and the files saved with it', () async {
      final c = container();
      final w = await open(c, 'new');
      w.update((d) => d.copyWith(siteName: 'Depot'));
      expect(await w.addFile(PickedFile(name: 'a.png', bytes: tinyPng, mime: 'image/png')), isTrue);
      await w.saveNow();
      expect(store.blobs, hasLength(1));
      await w.discard();
      expect(store.drafts, isEmpty);
      expect(store.blobs, isEmpty);
    });

    test('an unreadable answer on submit ends "submitting" with an error', () async {
      final c = container();
      final w = await open(c, 'new');
      repo.saveError = TypeError();
      expect(await w.submit(), isNull);
      final state = c.read(wizardControllerProvider('new'));
      expect(state.submitting, isFalse);
      expect(state.submitError?.code, 'unknown');
    });

    test('a photo Android delivered after a restart is added to the draft', () async {
      media.lost = PickedFile(name: 'IMG_9.png', bytes: tinyPng, mime: 'image/png');
      final c = container();
      await open(c, 'new');
      final state = c.read(wizardControllerProvider('new'));
      expect(state.draft.photos.single.name, 'IMG_9.png');
      expect(state.recoveredPhoto, isTrue);
    });
  });

  test('attachment ids stay unique even within one clock tick', () {
    final ids = {for (var i = 0; i < 2000; i++) newAttachmentId(photo: true)};
    expect(ids, hasLength(2000));
  });

  test('without the checklist, step 3 is invalid (no submit with zero answers)', () {
    final v = WizardValidator(ValidationText.en, today: _today);
    final d = InspectionDraft(answers: _allPass, confirmed: true);
    expect(v.checklistErrors(d), {'checklist': "The checklist hasn't loaded yet"});
    expect(v.canSubmit(d), isFalse);
  });

  group('screens', () {
    testWidgets('a checklist that fails to load offers Try again', (tester) async {
      late _Repo repo;
      final store = MemoryLocalStore()
        ..drafts['new'] = InspectionDraft(
          siteId: 's-riverside-office',
          siteName: 'Riverside office, floor 4',
          type: 'Fire safety, annual',
          date: DateTime.now().add(const Duration(days: 1)),
          startMinutes: 9 * 60,
          duration: '60',
          lastStep: 3,
        );
      await pumpApp(
        tester,
        initialLocation: '/inspections/new?step=3',
        store: signedInStore(),
        localStore: store,
        inspections: (db) => repo = _Repo(db)..checklistError = const ApiException('server', status: 500),
      );
      expect(find.text("Couldn't load the checklist."), findsOneWidget);
      repo.checklistError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load the checklist."), findsNothing);
      expect(find.text('Pass'), findsWidgets);
    });

    testWidgets('an edit opened and closed without changes asks nothing and saves nothing', (tester) async {
      final store = MemoryLocalStore();
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042/edit?step=1', store: signedInStore(), localStore: store);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Leave without submitting?'), findsNothing);
      expect(app.location, isNot(contains('/edit')));
      expect(store.drafts, isEmpty);
    });

    testWidgets('Discard on a later step leaves the wizard', (tester) async {
      final store = MemoryLocalStore()
        ..drafts['new'] = const InspectionDraft(siteId: 's-riverside-office', siteName: 'Riverside office, floor 4', lastStep: 2);
      final app = await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), localStore: store);
      await app.go('/inspections/new?step=2');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      expect(app.location, isNot(startsWith('/inspections/new')));
      expect(store.drafts, isEmpty);
    });

    testWidgets('a queued edit offers no View or PDF (the server has the old version)', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections/INS-1042/submitted?queued=1&site=Warehouse', store: signedInStore());
      expect(find.text('Report saved and queued'), findsOneWidget);
      expect(find.text('View inspection'), findsNothing);
      expect(find.text('Share PDF report'), findsNothing);
    });
  });
}
