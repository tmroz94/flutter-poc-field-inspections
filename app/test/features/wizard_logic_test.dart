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

import '../helpers/test_app.dart';

final _items = [for (var i = 1; i <= 18; i++) ChecklistItem(id: 'c${i.toString().padLeft(2, '0')}', title: 'Item $i')];
final _today = DateTime(2026, 10, 24, 10);

InspectionDraft _complete() => InspectionDraft(
  siteId: 's-riverside-office',
  siteName: 'Riverside office, floor 4',
  type: 'Fire safety, annual',
  date: DateTime(2026, 10, 26),
  startMinutes: 13 * 60,
  duration: '90',
  answers: {for (final i in _items) i.id: Answer.pass},
  confirmed: true,
);

/// Repository that is offline until [online] is set.
class _SwitchableRepository extends FakeInspectionsRepository {
  _SwitchableRepository(super.db) : super(latency: Duration.zero);

  bool online = false;

  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false}) {
    if (!online) throw const ApiException('network');
    return super.save(body, id: id, submit: submit);
  }
}

void main() {
  final v = WizardValidator(ValidationText.en, today: _today, checklist: _items);

  group('WizardValidator', () {
    test('a complete draft can be submitted', () => expect(v.canSubmit(_complete()), isTrue));

    test('site: pick from the list or name a new site (3+ chars)', () {
      expect(v.site(const InspectionDraft()), {'site': 'Required'});
      expect(v.site(const InspectionDraft(siteName: 'ab')), contains('site'));
      expect(v.site(const InspectionDraft(siteName: 'New depot')), isEmpty);
      expect(v.site(const InspectionDraft(siteId: 's-1', siteName: 'x')), isEmpty);
    });

    test('details: type, date not in the past, time, duration 15–480, notes ≤ 500', () {
      final errors = v.details(InspectionDraft(date: DateTime(2026, 10, 23), duration: '5', notes: 'x' * 501));
      expect(errors.keys, containsAll(['type', 'date', 'time', 'duration', 'notes']));
      expect(errors['duration'], 'Enter a number from 15 to 480');
      expect(errors['date'], 'Pick today or a later date');
      expect(v.details(_complete()), isEmpty);
    });

    test('editing an existing inspection may keep a past date', () {
      final edit = InspectionDraft.fromJson({..._complete().toJson(), 'inspectionId': 'INS-1038', 'date': '2026-10-20T00:00:00.000'});
      expect(v.details(edit), isEmpty);
    });

    test('checklist: every item answered; a Fail needs a note or a photo', () {
      final missing = _complete().copyWith(answers: {..._complete().answers}..remove('c05'));
      expect(v.checklistErrors(missing), {'c05': 'Answer this item'});
      final failed = _complete().copyWith(answers: {..._complete().answers, 'c02': Answer.fail});
      expect(v.checklistErrors(failed), {'c02': 'Add a note or a photo for this failure'});
      expect(v.checklistErrors(failed.copyWith(failures: {'c02': const FailDetail(note: 'Blocked by pallets')})), isEmpty);
      expect(
        v.checklistErrors(
          failed.copyWith(
            attachments: [const DraftAttachment(id: 'p', name: 'a.jpg', sizeBytes: 1, forItem: 'c02')],
          ),
        ),
        isEmpty,
      );
    });

    test('photos: one required when anything failed; type and size limits', () {
      final failed = _complete().copyWith(answers: {..._complete().answers, 'c02': Answer.fail});
      expect(v.photos(failed).keys, ['photos']);
      expect(v.photos(_complete()), isEmpty);
      final bad = _complete().copyWith(
        attachments: [
          const DraftAttachment(id: '1', name: 'huge.jpg', sizeBytes: 25000000),
          const DraftAttachment(id: '2', name: 'notes.docx', sizeBytes: 100, isPhoto: false),
        ],
      );
      expect(v.photos(bad).keys, containsAll(['size', 'type']));
      final many = _complete().copyWith(
        attachments: [for (var i = 0; i < 21; i++) DraftAttachment(id: '$i', name: '$i.jpg', sizeBytes: 1)],
      );
      expect(v.photos(many)['photos'], 'Use 20 photos or fewer');
    });

    test('review needs confirmation; first invalid step is found in order', () {
      expect(v.review(_complete().copyWith(confirmed: false)), contains('confirmed'));
      final noDetails = _complete().copyWith(duration: '');
      expect(v.firstInvalidBefore(WizardStep.review, noDetails), WizardStep.details);
      expect(v.firstInvalidBefore(WizardStep.details, noDetails), isNull);
    });
  });

  test('draft JSON round-trips', () {
    final d = _complete().copyWith(
      failures: {'c02': const FailDetail(severity: 4, followUp: false, note: 'n')},
      attachments: [const DraftAttachment(id: 'p1', name: 'a.jpg', sizeBytes: 9, forItem: 'c02')],
      lastStep: 4,
    );
    final back = InspectionDraft.fromJson(d.toJson());
    expect(back.toJson(), d.toJson());
    expect(back.scheduledAt, DateTime(2026, 10, 26, 13));
    expect(d.toApiBody()['durationMin'], 90);
    expect(d.toApiBody()['siteId'], 's-riverside-office');
  });

  group('WizardController', () {
    late MemoryLocalStore store;
    late MockDatabase db;
    late _SwitchableRepository repo;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryStore(signedInStore())),
          mockDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(db, latency: Duration.zero)),
          inspectionsRepositoryProvider.overrideWithValue(repo),
          localStoreProvider.overrideWithValue(store),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(c.dispose);
      // The app keeps the session alive through the router; do the same here.
      c.listen(authControllerProvider, (_, _) {});
      return c;
    }

    setUp(() {
      store = MemoryLocalStore();
      // Same frozen day as the drafts: the backend rejects dates before its own today.
      db = MockDatabase(clock: () => _today);
      repo = _SwitchableRepository(db);
    });

    Future<WizardController> open(ProviderContainer c, String key) async {
      c.listen(wizardControllerProvider(key), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c.read(wizardControllerProvider(key).notifier);
    }

    test('autosaves and restores after the app is killed', () async {
      final first = container();
      final w = await open(first, 'new');
      w.update((d) => d.copyWith(siteName: 'New depot', duration: '45'));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(store.drafts['new']?.siteName, 'New depot');
      first.dispose();

      final second = container();
      await open(second, 'new');
      expect(second.read(wizardControllerProvider('new')).draft.duration, '45');
    });

    test('edit prefills from the inspection when there is no draft', () async {
      final c = container();
      await open(c, 'INS-1042');
      await Future<void>.delayed(Duration.zero);
      final d = c.read(wizardControllerProvider('INS-1042')).draft;
      expect((d.siteName, d.duration, d.answers.length), ('Warehouse A – loading dock', '90', 12));
    });

    test('online submit sends and removes the draft', () async {
      repo.online = true;
      final c = container();
      final w = await open(c, 'new');
      w.update(
        (_) =>
            _complete().copyWith(answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass}),
      );
      await w.saveNow();
      final result = await w.submit();
      expect(result?.outcome, SubmitOutcome.sent);
      expect(result?.id, 'INS-1046');
      expect(store.drafts, isEmpty);
    });

    test('offline submit goes to the outbox; sync sends it when back online', () async {
      final c = container();
      final w = await open(c, 'new');
      w.update(
        (_) =>
            _complete().copyWith(answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass}),
      );
      final result = await w.submit();
      expect(result?.outcome, SubmitOutcome.queued);
      expect(store.entries, hasLength(1));
      expect(store.drafts, isEmpty);

      // Wait for the restored session, then sync while still offline: stays queued.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(authControllerProvider).user, isNotNull);
      await c.read(syncServiceProvider.notifier).run();
      expect(store.entries, hasLength(1));
      expect(c.read(syncServiceProvider).offline, isTrue);

      repo.online = true;
      await c.read(syncServiceProvider.notifier).run();
      expect(store.entries, isEmpty);
      expect(db.listInspections(q: 'INS-1046')['total'], 1, reason: 'created from the outbox');
    });

    test('a server rejection marks the outbox entry and keeps going', () async {
      await store.enqueue(kind: 'create', site: 'Bad', body: {'site': 'x'});
      repo.online = true;
      final c = container();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await c.read(syncServiceProvider.notifier).run();
      expect(store.entries.single.lastError, contains('site'));
    });
  });
}
