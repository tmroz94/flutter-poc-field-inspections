import 'package:mock_data/mock_data.dart';
import 'package:test/test.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 22, 9, 0);
  late MockDatabase db;

  setUp(() => db = MockDatabase(clock: () => fixedNow));

  group('fixtures', () {
    test('has the 44 coverage scenarios with valid status codes', () {
      expect(scenarioSeed, hasLength(44));
      expect(scenarioSeed.map((s) => s.id).toSet(), hasLength(44));
      for (final s in scenarioSeed) {
        for (final code in [s.ios, s.android, s.web]) {
          expect('PHFUN'.contains(code), isTrue, reason: '${s.id}: $code');
        }
        expect(scenarioGroups, contains(s.group));
      }
    });

    test('checklist template has 18 items, 5 of them from the boards', () {
      final items = fireSafetyTemplate['items']! as List;
      expect(items, hasLength(18));
      expect(items.where((i) => (i as Map)['placeholder'] == false), hasLength(5));
    });

    test('every notification routes to an existing inspection', () {
      for (final n in db.notifications()) {
        final id = RegExp(r'/inspections/(INS-\d+)').firstMatch(n['route']! as String)!.group(1)!;
        expect(() => db.getInspection(id), returnsNormally);
      }
    });
  });

  group('auth', () {
    test('signs in with the demo account', () {
      final s = db.signIn(demoEmail, demoPassword);
      expect(s['token'], isA<String>());
      expect((s['user']! as Map)['name'], 'Anna Nowak');
      expect((s['user']! as Map).containsKey('password'), isFalse);
      expect(db.authenticate(s['token']! as String)['email'], demoEmail);
    });

    test('rejects wrong password with 401 and bad input with 422 field errors', () {
      expect(() => db.signIn(demoEmail, 'wrongpass1'), throwsA(isA<MockError>().having((e) => e.status, 'status', 401)));
      expect(
        () => db.signIn('not-an-email', 'short'),
        throwsA(isA<MockError>().having((e) => e.fields, 'fields', {'email': 'invalid', 'password': 'tooShort'})),
      );
    });

    test('sign-up rejects a taken email and weak password', () {
      expect(db.isEmailAvailable(demoEmail.toUpperCase()), isFalse);
      expect(
        () => db.signUp(name: 'X', email: demoEmail, password: 'password'),
        throwsA(isA<MockError>().having((e) => e.fields, 'fields', {'email': 'taken', 'password': 'weak'})),
      );
      final s = db.signUp(name: 'Jan Kowalski', email: 'jan@example.com', password: 'abcd1234');
      expect((s['user']! as Map)['initials'], 'JK');
    });

    test('unknown token is unauthorized', () {
      expect(() => db.authenticate('nope'), throwsA(isA<MockError>().having((e) => e.status, 'status', 401)));
    });

    test("only the demo account's tokens are accepted by shape; a signed-up user's must be issued", () {
      expect(db.authenticate('mock-u-anna-1')['email'], demoEmail, reason: 'survives a server restart');
      final s = db.signUp(name: 'Jan Kowalski', email: 'jan@example.com', password: 'abcd1234');
      final id = (s['user']! as Map)['id'];
      expect(db.authenticate(s['token']! as String)['email'], 'jan@example.com');
      expect(() => db.authenticate('mock-$id-0'), throwsA(isA<MockError>().having((e) => e.status, 'status', 401)));
      expect(() => db.authenticate('mock-u-2-0'), throwsA(isA<MockError>().having((e) => e.status, 'status', 401)));
    });

    test("a token from before a restart doesn't sign in the next account that signs up", () {
      final before = db.signUp(name: 'Jan Kowalski', email: 'jan@example.com', password: 'abcd1234');
      final restarted = MockDatabase();
      final after = restarted.signUp(name: 'Ola Nowak', email: 'ola@example.com', password: 'abcd1234');
      expect((after['user']! as Map)['id'], isNot((before['user']! as Map)['id']));
      expect(() => restarted.authenticate(before['token']! as String), throwsA(isA<MockError>()));
    });
  });

  group('inspections list', () {
    test('default sort puts open work first, soonest due', () {
      final ids = (db.listInspections(pageSize: 7)['items']! as List).map((i) => (i as Map)['id']).toList();
      expect(ids.take(5), ['INS-1038', 'INS-1042', 'INS-1043', 'INS-1040', 'INS-1045']);
      expect(ids.skip(5), ['INS-1031', 'INS-1029']);
    });

    test('pages through all 36 inspections', () {
      final p1 = db.listInspections();
      expect(p1['total'], 36);
      expect(p1['hasMore'], isTrue);
      final p2 = db.listInspections(page: 2);
      expect((p2['items']! as List), hasLength(16));
      expect(p2['hasMore'], isFalse);
    });

    test('filters by status, query and due window', () {
      expect(db.listInspections(status: {'overdue'})['total'], 1);
      expect(db.listInspections(q: 'river')['total'], greaterThan(0));
      expect(db.listInspections(q: 'ins-1042')['total'], 1);
      expect(db.listInspections(q: 'boiler')['total'], 0);
      expect(db.listInspections(due: 'today')['total'], 2);
      expect(db.listInspections(due: 'week', status: {'scheduled', 'inProgress', 'draft'})['total'], 4);
    });

    test('rejects a bad sort', () {
      expect(() => db.listInspections(sort: 'x'), throwsA(isA<MockError>()));
    });

    test('rejects unknown statuses and due windows, and pages that could overflow', () {
      Matcher badRequest(String code) => throwsA(isA<MockError>().having((e) => (e.status, e.code), 'error', (400, code)));
      expect(() => db.listInspections(status: {'done'}), badRequest('badStatus'));
      expect(() => db.listInspections(due: 'month'), badRequest('badDue'));
      expect(() => db.listInspections(page: 0), badRequest('badPage'));
      expect(() => db.listInspections(page: 9223372036854775807), badRequest('badPage'));
      expect(() => db.listInspections(pageSize: 101), badRequest('badPage'));
      expect(db.listInspections(page: MockDatabase.maxPage)['items'], isEmpty);
    });
  });

  group('inspection detail and writes', () {
    test('INS-1042 matches the detail board: 12 of 18 answered, 2 failed, 6 photos', () {
      final d = db.getInspection('INS-1042');
      expect(d['checklistSummary'], {'answered': 12, 'total': 18, 'failed': 2});
      expect(d['photos'], hasLength(6));
      expect(d['history'], hasLength(4));
    });

    test('unknown id is 404', () {
      expect(() => db.getInspection('INS-9999'), throwsA(isA<MockError>().having((e) => e.status, 'status', 404)));
    });

    Map<String, Object?> validDraft() => {
      'siteId': 's-riverside-office',
      'type': 'Fire safety, annual',
      'scheduledAt': DateTime(2026, 10, 22, 13).toIso8601String(),
      'durationMin': 90,
      'priority': 'normal',
    };

    test('a create repeated with the same idempotency key returns the first inspection', () {
      final first = db.createInspection(validDraft(), requestKey: 'k1');
      final again = db.createInspection(validDraft(), requestKey: 'k1');
      final other = db.createInspection(validDraft(), requestKey: 'k2');
      expect(again['id'], first['id']);
      expect(other['id'], isNot(first['id']));
      expect(db.createInspection(validDraft())['id'], isNot(other['id']), reason: 'no key, no dedupe');
    });

    test('creates a draft and validates fields', () {
      final created = db.createInspection(validDraft());
      expect(created['id'], 'INS-1046');
      expect(created['status'], 'draft');
      expect(
        () => db.createInspection({...validDraft(), 'durationMin': 5, 'scheduledAt': 'soon'}),
        throwsA(isA<MockError>().having((e) => e.fields.keys, 'fields', containsAll(['durationMin', 'scheduledAt']))),
      );
    });

    test('a create dated before today is accepted (written offline, sent after midnight)', () {
      final created = db.createInspection({...validDraft(), 'scheduledAt': DateTime(2026, 10, 1, 14).toIso8601String()});
      expect(created['scheduledAt'], startsWith('2026-10-01'));
    });

    test('submitting requires every checklist answer and confirmation', () {
      expect(
        () => db.createInspection(validDraft(), submit: true),
        throwsA(isA<MockError>().having((e) => e.fields.keys, 'fields', containsAll(['answers', 'confirmed']))),
      );
      final answers = {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id']: 'pass'};
      final done = db.createInspection({...validDraft(), 'answers': answers, 'confirmed': true}, submit: true);
      expect(done['status'], 'submitted');
    });

    test('uploaded photo metadata becomes stored photo records', () {
      final created = db.createInspection({
        ...validDraft(),
        'photos': [
          {'id': 'a1', 'name': 'IMG_0001.jpg', 'sizeBytes': 1200, 'isPhoto': true, 'forItem': 'c02'},
        ],
      });
      final photo = (created['photos']! as List).single as Map<String, Object?>;
      expect(photo['caption'], 'IMG_0001.jpg');
      expect(DateTime.tryParse(photo['takenAt']! as String), isNotNull);
      expect(photo['forItem'], 'c02');

      // Re-sending a known id (edit flow) keeps the stored record.
      final updated = db.updateInspection(created['id']! as String, {
        'photos': [
          {'id': 'a1', 'name': 'renamed.jpg'},
        ],
      });
      expect(((updated['photos']! as List).single as Map)['caption'], 'IMG_0001.jpg');
    });

    test('archiving hides an inspection from the list', () {
      db.setArchived('INS-1043', true);
      expect(db.listInspections(q: 'INS-1043')['total'], 0);
    });

    Matcher rejects(Map<String, String> fields) => throwsA(
      isA<MockError>()
          .having((e) => e.status, 'status', 422)
          .having((e) => e.fields, 'fields', containsPair(fields.keys.single, fields.values.single)),
    );

    test('an unknown site id is a 422 on site, and nothing is stored', () {
      expect(() => db.createInspection({...validDraft(), 'siteId': 's-nowhere'}), rejects({'site': 'unknown'}));
      expect(db.listInspections()['total'], 36);
      expect(db.createInspection(validDraft())['id'], 'INS-1046', reason: 'the rejected create used no id');
      expect(db.listInspections(q: 'riverside', sort: 'siteAsc')['total'], greaterThan(0));
    });

    test('values of the wrong type are 422 field errors, never a crash', () {
      expect(() => db.createInspection({...validDraft(), 'siteId': 5}), rejects({'site': 'invalid'}));
      expect(() => db.createInspection({...validDraft(), 'scheduledAt': 20261022}), rejects({'scheduledAt': 'invalid'}));
      expect(() => db.createInspection({...validDraft(), 'notes': 42}), rejects({'notes': 'invalid'}));
      expect(
        () => db.createInspection({
          ...validDraft(),
          'answers': ['pass'],
        }),
        rejects({'answers': 'invalid'}),
      );
      expect(
        () => db.createInspection({
          ...validDraft(),
          'answers': {'c01': 'maybe'},
        }),
        rejects({'answers': 'invalid'}),
      );
      expect(
        () => db.createInspection({
          ...validDraft(),
          'answers': {'c99': 'pass'},
        }),
        rejects({'answers': 'invalid'}),
      );
      expect(
        () => db.createInspection({
          ...validDraft(),
          'photos': [1],
        }),
        rejects({'photos': 'invalid'}),
      );
      expect(
        () => db.createInspection({
          ...validDraft(),
          'photos': [
            {'id': 'a'},
            {'id': 'a'},
          ],
        }),
        rejects({'photos': 'invalid'}),
      );
      expect(
        () => db.createInspection({
          ...validDraft(),
          'files': {'id': 'f'},
        }),
        rejects({'files': 'invalid'}),
      );
      expect(
        () => db.createInspection({
          ...validDraft(),
          'failures': {
            'c02': {'severity': 9},
          },
        }),
        rejects({'failures': 'invalid'}),
      );
      expect(
        () => db.createInspection({
          ...validDraft(),
          'checkedInAt': {'lat': 'x'},
        }),
        rejects({'checkedInAt': 'invalid'}),
      );
      expect(() => db.createInspection({...validDraft(), 'confirmed': 'yes'}), rejects({'confirmed': 'invalid'}));
      expect(db.listInspections()['total'], 36);
    });

    test('a PUT only changes client fields and validates before storing anything', () {
      final updated = db.updateInspection('INS-1040', {
        'id': 'INS-1',
        'status': 'submitted',
        'archived': true,
        'inspector': {'name': 'Mallory'},
        'templateId': 'tpl-x',
        'notes': 'Bring a ladder',
      });
      expect(
        (updated['id'], updated['status'], updated['archived'], (updated['inspector']! as Map)['name']),
        ('INS-1040', 'draft', false, 'Anna Nowak'),
      );
      expect((updated['templateId'], updated['notes']), ('tpl-fire-annual-v3', 'Bring a ladder'));

      expect(() => db.updateInspection('INS-1042', {'answers': null}), rejects({'answers': 'invalid'}));
      expect(() => db.updateInspection('INS-1042', {'notes': 'changed', 'durationMin': 5}), rejects({'durationMin': 'range'}));
      expect(() => db.updateInspection('INS-1042', {'siteId': 's-nowhere'}), rejects({'site': 'unknown'}));
      final unchanged = db.getInspection('INS-1042');
      expect((unchanged['notes'], unchanged['site']), ('Access through gate 3. Bring the fire panel key.', 'Warehouse A – loading dock'));
      expect(unchanged['checklistSummary'], {'answered': 12, 'total': 18, 'failed': 2});
    });

    test('a named site becomes a new site that later inspections can reuse', () {
      final created = db.createInspection({
        ...validDraft()..remove('siteId'),
        'site': '  Boiler house  ',
        'address': 'ul. Kotłowa 1',
        'lat': 52.1,
        'lng': 21.1,
      });
      expect((created['siteId'], created['site'], created['address']), ('s-new-INS-1046', 'Boiler house', 'ul. Kotłowa 1'));
      final again = db.createInspection({...validDraft(), 'siteId': 's-new-INS-1046'});
      expect((again['site'], again['lat']), ('Boiler house', 52.1));
      expect(db.listInspections(q: 'boiler', sort: 'siteAsc')['total'], 2);
    });

    test('stored records do not share maps with the request body', () {
      final answers = {'c01': 'pass'};
      final created = db.createInspection({...validDraft(), 'answers': answers});
      answers['c02'] = 'fail';
      expect(db.getInspection(created['id']! as String)['checklistSummary'], {'answered': 1, 'total': 18, 'failed': 0});
    });

    test('failures, files and the location check are stored', () {
      final created = db.createInspection({
        ...validDraft(),
        'answers': {'c02': 'fail'},
        'failures': {
          'c02': {'severity': 4, 'followUp': true, 'note': 'Blocked by pallets'},
        },
        'files': [
          {'id': 'f1', 'name': 'permit.pdf', 'sizeBytes': 2048, 'isPhoto': false, 'forItem': null},
        ],
        'checkedInAt': {'lat': 52.24, 'lng': 21.03, 'accuracy': null},
      });
      expect(((created['failures']! as Map)['c02'] as Map)['severity'], 4);
      expect(((created['files']! as List).single as Map)['name'], 'permit.pdf');
      expect((created['checkedInAt']! as Map)['lat'], 52.24);
    });
  });

  test('site search puts prefix matches first', () {
    final names = db.searchSites('River').map((s) => s['name']).toList();
    expect(names.first, 'River pumping station');
    expect(names, containsAll(['Riverside office, floor 4', 'Riverside warehouse']));
    expect(db.searchSites('  '), isEmpty);
  });

  test('notes are limited by characters, like the app field counts them', () {
    final db = MockDatabase();
    Map<String, Object?> draft(String notes) => {
      'siteId': 's-riverside-office',
      'type': 'Fire safety, annual',
      'scheduledAt': DateTime(2026, 10, 30, 13).toIso8601String(),
      'durationMin': 90,
      'notes': notes,
    };
    expect(db.createInspection(draft('😀' * 500))['id'], isNotNull, reason: '500 characters, 1000 UTF-16 units');
    expect(() => db.createInspection(draft('😀' * 501)), throwsA(isA<MockError>()));
  });
}
