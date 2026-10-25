import 'package:field_inspections/core/platform/notification_service.dart';
import 'package:field_inspections/core/router/routes.dart';
import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/data/api/api_exception.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/models/list_query.dart';
import 'package:field_inspections/data/models/notification.dart';
import 'package:field_inspections/data/providers.dart';
import 'package:field_inspections/data/repositories/inspections_repository.dart';
import 'package:field_inspections/data/sync/sync_service.dart';
import 'package:field_inspections/features/auth/auth_controller.dart';
import 'package:field_inspections/features/auth/auth_repository.dart';
import 'package:field_inspections/features/inspections/inspections_controller.dart';
import 'package:field_inspections/features/notifications/reminders.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

/// The fake backend with switchable failures.
class _Repo extends FakeInspectionsRepository {
  _Repo(super.db) : super(latency: Duration.zero);

  bool listDown = false;
  bool notificationsDown = false;
  bool markReadDown = false;

  @override
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20}) {
    if (listDown) throw const ApiException('network');
    return super.list(query, page: page, pageSize: pageSize);
  }

  @override
  Future<List<AppNotification>> notifications() {
    if (notificationsDown) throw const ApiException('network');
    return super.notifications();
  }

  @override
  Future<void> markNotificationsRead({String? id}) {
    if (markReadDown) throw const ApiException('network');
    return super.markNotificationsRead(id: id);
  }
}

void main() {
  group('notifications (P17)', () {
    testWidgets('dismissing and leaving at once still deletes it (and updates the bell)', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/notifications', store: signedInStore());
      final db = app.container.read(mockDatabaseProvider);
      await tester.drag(find.text('Draft synced'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await app.go('/home');
      // The snackbar follows the user to Home and times out there; the
      // notifications screen is gone by then.
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(db.notifications().map((n) => n['title']), isNot(contains('Draft synced')));
    });

    testWidgets('a failed load says so instead of "all caught up"', (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/notifications',
        store: signedInStore(),
        inspections: (db) => _Repo(db)..notificationsDown = true,
      );
      expect(find.text("Couldn't load notifications."), findsOneWidget);
      expect(find.text("You're all caught up."), findsNothing);
    });

    testWidgets('opening a notification works even when marking it read fails', (tester) async {
      final app = await pumpApp(
        tester,
        initialLocation: '/notifications',
        store: signedInStore(),
        inspections: (db) => _Repo(db)..markReadDown = true,
      );
      await tester.tap(find.text('Substation 12 is overdue'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1038');
    });

    testWidgets('blocked notifications get an Open settings button', (tester) async {
      final fakes = Fakes();
      fakes.notifications
        ..granted = false
        ..permanentlyDenied = true;
      await pumpApp(tester, initialLocation: '/notifications', store: signedInStore(), fakes: fakes);
      await tester.tap(find.widgetWithText(FilledButton, 'Open settings'));
      await tester.pumpAndSettle();
      expect(fakes.permissions.settingsOpened, 1);
    });
  });

  group('map (P18)', () {
    testWidgets('every pin has a 48 dp tap target', (tester) async {
      await pumpApp(tester, initialLocation: '/map', store: signedInStore());
      expect(tester.getSize(find.bySemanticsLabel(RegExp('^Substation 12'))), const Size(48, 48));
    });

    testWidgets('"Show on map" for a second site moves the map there', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/map?site=s-riverside-office', store: signedInStore());
      final site = sites.firstWhere((s) => s['id'] == 's-substation-12');
      await app.go('/map?site=s-substation-12');
      await tester.pumpAndSettle();
      final camera = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera.center;
      expect(camera.latitude, closeTo((site['lat']! as num).toDouble(), 0.001));
      expect(camera.longitude, closeTo((site['lng']! as num).toDouble(), 0.001));
    });

    testWidgets('offline: the map says it could not load the pins', (tester) async {
      await pumpApp(tester, initialLocation: '/map', store: signedInStore(), inspections: (db) => _Repo(db)..listDown = true);
      expect(find.text("Couldn't load the inspections for the map."), findsOneWidget);
    });
  });

  testWidgets('desktop: Settings in the rail leaves the results tracker', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/settings/poc/results', store: signedInStore(), size: desktopSize);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    expect(app.location, '/settings');
  });

  group('reminders follow the data', () {
    late MockDatabase db;
    late _Repo repo;
    late FakeNotifications notifications;
    late MemoryStore kv;

    setUp(() {
      db = MockDatabase();
      repo = _Repo(db);
      notifications = FakeNotifications();
      kv = MemoryStore({...signedInStore(), 'reminders': 'true'});
    });

    Future<ProviderContainer> start() async {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv),
          mockDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(db, latency: Duration.zero)),
          inspectionsRepositoryProvider.overrideWithValue(repo),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          notificationServiceProvider.overrideWithValue(notifications),
          connectivityProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(c.dispose);
      c
        ..listen(authControllerProvider, (_, _) {})
        ..listen(remindersProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return c;
    }

    test('scheduled on sign-in, and again when this app changes inspections', () async {
      final c = await start();
      final first = notifications.scheduled.map((s) => s.$2).toSet();
      expect(first, isNotEmpty, reason: 'scheduled after the session restored');

      final open = db.listInspections(status: {'scheduled'}, pageSize: 1)['items']! as List;
      final id = (open.first as Map)['id']! as String;
      db.setArchived(id, true);
      c.read(inspectionsRevisionProvider.notifier).changed();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifications.scheduled.map((s) => s.$2), isNot(contains(Routes.inspection(id))));
    });

    test('a failed load keeps the reminders already scheduled', () async {
      final c = await start();
      final before = List.of(notifications.scheduled);
      expect(before, isNotEmpty);
      repo.listDown = true;
      c.read(inspectionsRevisionProvider.notifier).changed();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifications.scheduled, before);
    });

    test('reminder text follows the app language', () async {
      await kv.setString('theme_settings', '{"locale":"pl"}');
      await start();
      expect(notifications.scheduledTitles.first, contains(' o '));
    });
  });
}
