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

    test('creates a draft and validates fields', () {
      final created = db.createInspection(validDraft());
      expect(created['id'], 'INS-1046');
      expect(created['status'], 'draft');
      expect(
        () => db.createInspection({...validDraft(), 'durationMin': 5, 'scheduledAt': DateTime(2026, 10, 1).toIso8601String()}),
        throwsA(isA<MockError>().having((e) => e.fields.keys, 'fields', containsAll(['durationMin', 'scheduledAt']))),
      );
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
  });

  test('site search puts prefix matches first', () {
    final names = db.searchSites('River').map((s) => s['name']).toList();
    expect(names.first, 'River pumping station');
    expect(names, containsAll(['Riverside office, floor 4', 'Riverside warehouse']));
    expect(db.searchSites('  '), isEmpty);
  });
}
