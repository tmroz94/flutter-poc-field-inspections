import 'dart:async';
import 'dart:convert';

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

  /// The server stores the save, then the answer is lost on the way back.
  bool loseResponse = false;

  /// The server stores the save, then a gateway answers 502.
  bool gatewayError = false;

  /// Holds saves until completed.
  Completer<void>? hold;

  final keys = <String?>[];

  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false, String? requestKey}) async {
    keys.add(requestKey);
    await hold?.future;
    if (!online) throw const ApiException('network');
    final saved = await super.save(body, id: id, submit: submit, requestKey: requestKey);
    if (loseResponse) throw const ApiException('network');
    if (gatewayError) throw const ApiException('server', status: 502);
    return saved;
  }
}

final _allPass = {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass};

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

  test('a typed site keeps nothing of the site picked before it', () {
    final picked = _complete().copyWith(siteAddress: 'Riverside 4', siteLat: () => 52.2, siteLng: () => 21.0);
    final typed = picked.withNewSite('Riverside office, floor 5');
    expect((typed.siteId, typed.siteAddress, typed.siteLat, typed.siteLng), (null, '', null, null));
    expect(typed.siteName, 'Riverside office, floor 5');
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

    late MemoryStore kv;
    late FakeMedia media;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv),
          mediaServiceProvider.overrideWithValue(media),
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
      kv = MemoryStore(signedInStore());
      media = FakeMedia();
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

    test('a submit whose answer was lost is queued with its key and not created twice', () async {
      final c = container();
      final w = await open(c, 'new');
      w.update(
        (_) =>
            _complete().copyWith(answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass}),
      );
      repo
        ..online = true
        ..loseResponse = true;
      final result = await w.submit();
      expect(result?.outcome, SubmitOutcome.queued);
      expect(store.entries.single.requestKey, isNotNull);

      repo.loseResponse = false;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await c.read(syncServiceProvider.notifier).run();
      expect(store.entries, isEmpty);
      expect(db.listInspections(q: 'INS-1046')['total'], 1);
      expect(db.listInspections(q: 'INS-1047')['total'], 0, reason: 'the outbox resend returned INS-1046');
    });

    test('a second submit after a gateway error sends the same key: one inspection', () async {
      final c = container();
      final w = await open(c, 'new');
      w.update((_) => _complete().copyWith(answers: _allPass));
      repo
        ..online = true
        ..gatewayError = true;
      expect(await w.submit(), isNull);
      expect(c.read(wizardControllerProvider('new')).submitError?.code, 'server');
      expect(store.drafts['new']?.requestKey, isNotNull, reason: 'kept with the draft for a retry after leaving');

      repo.gatewayError = false;
      final result = await w.submit();
      expect(result?.id, 'INS-1046', reason: 'the server returned the inspection the first attempt made');
      expect(repo.keys.toSet(), hasLength(1));
      expect(db.listInspections(q: 'INS-1047')['total'], 0);
    });

    test('nothing in the draft changes while it is being sent', () async {
      repo
        ..online = true
        ..hold = Completer<void>();
      final c = container();
      final w = await open(c, 'new');
      w.update((_) => _complete().copyWith(answers: _allPass, notes: 'Sent'));
      final submit = w.submit();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(wizardControllerProvider('new')).submitting, isTrue);
      w.update((d) => d.copyWith(notes: 'Typed while sending'));
      expect(c.read(wizardControllerProvider('new')).draft.notes, 'Sent', reason: 'the screen shows what is being sent');
      expect(await w.saveNow(), isFalse);
      await w.discard();
      expect(store.drafts['new']?.notes, 'Sent', reason: 'discard waits: a rejected submit still needs the draft');
      repo.hold!.complete();
      expect((await submit)?.outcome, SubmitOutcome.sent);
      c.dispose();
      expect(store.drafts, isEmpty, reason: 'no late save brings the sent draft back');
      expect(db.getInspection('INS-1046')['notes'], 'Sent');
    });

    test('a saved new draft that is emptied again is deleted, not restored next time', () async {
      final c = container();
      final w = await open(c, 'new');
      w.update((d) => d.copyWith(siteName: 'New depot'));
      expect(await w.saveNow(), isTrue);
      w.update((d) => d.copyWith(siteName: ''));
      await Future<void>.delayed(Duration.zero);
      expect(store.drafts, isEmpty);
      expect(c.read(wizardControllerProvider('new')).savedAt, isNull);
      c.dispose();
      expect(store.drafts, isEmpty, reason: 'nothing stale is flushed on close');
    });

    test('Save draft says when there is nothing to keep yet; a date alone counts', () async {
      final c = container();
      final w = await open(c, 'new');
      expect(await w.saveNow(), isFalse);
      w.update((d) => d.copyWith(date: () => DateTime(2026, 10, 30)));
      expect(await w.saveNow(), isTrue);
      expect(store.drafts['new']?.date, DateTime(2026, 10, 30));
    });

    test('typing just before the wizard closes is saved by the close', () async {
      final c = container();
      final w = await open(c, 'new');
      w.update((d) => d.copyWith(siteName: 'Last-second depot'));
      c.dispose();
      expect(store.drafts['new']?.siteName, 'Last-second depot');
    });

    test('a camera photo recovered after a restart goes to the wizard it was taken for', () async {
      media.lost = PickedFile(name: 'IMG_9.png', bytes: tinyPng, mime: 'image/png');
      await kv.setString('wizard.cameraFor', jsonEncode({'key': 'INS-1042', 'forItem': 'c02'}));
      final c = container();
      await open(c, 'new');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(wizardControllerProvider('new')).draft.attachments, isEmpty);
      expect(media.lost, isNotNull, reason: 'left for the edit of INS-1042');

      await open(c, 'INS-1042');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final added = c.read(wizardControllerProvider('INS-1042')).draft.attachments.where((a) => !a.stored).single;
      expect(added.forItem, 'c02');
      expect(kv.getString('wizard.cameraFor'), isNull);
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
