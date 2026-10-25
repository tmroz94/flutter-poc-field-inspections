import 'dart:typed_data';

import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/data/api/api_exception.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/providers.dart';
import 'package:field_inspections/data/sync/sync_service.dart';
import 'package:field_inspections/features/auth/auth_controller.dart';
import 'package:field_inspections/features/auth/auth_models.dart';
import 'package:field_inspections/features/auth/auth_repository.dart';
import 'package:field_inspections/features/notifications/reminders.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/test_app.dart';

/// The session check (`/me`) answers with [error] instead of the user.
class _FailingMe extends FakeAuthRepository {
  _FailingMe(super.db, this.error) : super(latency: Duration.zero);

  final Object error;

  @override
  Future<AppUser> me(String token) async => throw error;
}

void main() {
  late MockDatabase db;
  late MemoryLocalStore local;
  late MemoryStore kv;

  setUp(() {
    db = MockDatabase();
    local = MemoryLocalStore();
    kv = MemoryStore(signedInStore());
  });

  Future<ProviderContainer> start({AuthRepository Function(Ref ref)? auth}) async {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(kv),
        mockDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWith(auth ?? (ref) => FakeAuthRepository(db, latency: Duration.zero)),
        localStoreProvider.overrideWithValue(local),
        connectivityProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(authControllerProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return c;
  }

  group('session restore', () {
    test('a network error keeps the cached session (offline-first)', () async {
      final c = await start(auth: (ref) => _FailingMe(db, const ApiException('network')));
      expect(c.read(authControllerProvider).status, AuthStatus.signedIn);
      expect(c.read(authControllerProvider).user?.email, demoEmail);
    });

    test('a rejected token signs out and forgets the session', () async {
      final c = await start(auth: (ref) => _FailingMe(db, const ApiException('unauthorized', status: 401)));
      expect(c.read(authControllerProvider).status, AuthStatus.signedOut);
      expect(kv.getString('session'), isNull);
    });

    test('an unreadable answer (e.g. a captive portal page) keeps the cached session instead of the splash', () async {
      final c = await start(auth: (ref) => _FailingMe(db, TypeError()));
      expect(c.read(authControllerProvider).status, AuthStatus.signedIn);
    });

    test('a corrupt stored session signs out', () async {
      kv = MemoryStore({'session': '{not json'});
      final c = await start();
      expect(c.read(authControllerProvider).status, AuthStatus.signedOut);
      expect(kv.getString('session'), isNull);
    });
  });

  group('local data belongs to one account', () {
    Future<void> addLocalWork() async {
      await local.saveDraft('new', const InspectionDraft(siteName: 'Depot', notes: 'n'));
      await local.enqueue(kind: 'create', site: 'Depot', body: {'site': 'Depot'});
      await local.putBlob('ph-1', Uint8List.fromList([1, 2, 3]), 'image/png');
    }

    test('signing out from Settings deletes drafts, outbox, files and turns reminders off', () async {
      final c = await start();
      await addLocalWork();
      await kv.setString('reminders', 'true');
      await c.read(authControllerProvider.notifier).signOut(clearLocalData: true);
      expect(local.drafts, isEmpty);
      expect(local.entries, isEmpty);
      expect(local.blobs, isEmpty);
      expect(c.read(remindersProvider), isFalse);
      expect(c.read(authControllerProvider).status, AuthStatus.signedOut);
    });

    test('a forced sign-out keeps them for the same user', () async {
      final c = await start();
      await addLocalWork();
      await c.read(authControllerProvider.notifier).signOut();
      await c.read(authControllerProvider.notifier).signIn(demoEmail, demoPassword);
      expect(local.drafts, hasLength(1));
      expect(local.entries, hasLength(1));
    });

    test('another account signing in after a forced sign-out starts empty', () async {
      final c = await start();
      await addLocalWork();
      await c.read(authControllerProvider.notifier).signOut();
      await c.read(authControllerProvider.notifier).signUp(name: 'Ola Test', email: 'ola@example.com', password: 'secret123');
      expect(c.read(authControllerProvider).user?.email, 'ola@example.com');
      expect(local.drafts, isEmpty);
      expect(local.entries, isEmpty, reason: "Anna's queue must not be sent under Ola's account");
      expect(local.blobs, isEmpty);
    });
  });
}
