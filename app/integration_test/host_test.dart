// Flows that need the host to change the device: network on/off and the GPS
// position. Run through the host helper, which watches for `HOST>` lines and
// runs the matching adb command (see tool/android_device_tests.dart):
//   fvm dart tool/android_device_tests.dart
// Run directly (without the helper) these tests are skipped.
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:field_inspections/core/router/router.dart';
import 'package:field_inspections/data/api/backend_config.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

const _withHost = bool.fromEnvironment('HOST_HELPER');

/// Asks the host helper to run a command, e.g. `airplane on`. Plain `print`:
/// the helper reads these lines from the test output.
// ignore: avoid_print
void host(String command) => print('HOST> $command');

/// Pumps until [condition] completes with true (async checks such as storage).
Future<void> waitForAsync(WidgetTester tester, Future<bool> Function() condition, {required String reason, int seconds = 60}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!await condition()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for $reason');
    await tester.pump(const Duration(milliseconds: 500));
  }
}

InspectionDraft _site({int lastStep = 1}) => const InspectionDraft(
  siteId: 's-riverside-office',
  siteName: 'Riverside office, floor 4',
  siteLat: 52.24,
  siteLng: 21.03,
).copyWith(lastStep: lastStep);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferencesAsync().clear());
  tearDown(() => host('airplane off'));

  testWidgets('offline: the list explains it, a submit is queued, and it syncs once the network is back', skip: !_withHost, (tester) async {
    // The mock server on the host (10.0.2.2), so airplane mode really cuts it off.
    final c = await launch(
      tester,
      backend: const BackendConfig(mode: BackendMode.http, baseUrl: 'http://10.0.2.2:8080/api'),
    );
    await signIn(tester);
    final store = c.read(localStoreProvider);
    for (final e in await store.outbox()) {
      await store.removeFromOutbox(e.id);
    }

    host('airplane on');
    await waitFor(tester, () => c.read(connectivityProvider).value == false, reason: 'the app to see it is offline');
    c.read(routerProvider).go('/inspections');
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsWidgets);

    final items = [for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String];
    await store.saveDraft(
      'new',
      _site(lastStep: 5).copyWith(
        siteAddress: 'ul. Wybrzeże 2, Warsaw',
        type: () => 'Fire safety, annual',
        date: () => DateTime.now().add(const Duration(days: 1)),
        startMinutes: () => 13 * 60,
        duration: '90',
        answers: {for (final id in items) id: Answer.pass},
        confirmed: true,
      ),
    );
    c.read(routerProvider).go('/inspections/new?step=5');
    await settle(tester, const Duration(seconds: 1));
    final submit = find.widgetWithText(FilledButton, 'Submit');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await waitFor(tester, () => find.text('Report saved and queued').evaluate().isNotEmpty, reason: 'the queued screen');
    expect(await store.outbox(), hasLength(1));

    host('airplane off');
    await waitForAsync(tester, () async => (await store.outbox()).isEmpty, reason: 'the outbox to sync');
    c.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Waiting to send'), findsNothing);
    await quit(tester, c);
  });

  testWidgets('real GPS: distance to the site, and the far-away warning', skip: !_withHost, (tester) async {
    host('location grant');
    final c = await launch(tester, overrides: [locationServiceProvider.overrideWithValue(const LocationService(useLocationManager: true))]);
    await signIn(tester);
    await c.read(localStoreProvider).saveDraft('new', _site());
    c.read(routerProvider).go('/inspections/new?step=1');
    await tester.pumpAndSettle();

    // `geo fix` sends one fix when it arrives, so send it again while the app
    // is waiting for a position, and retry until the expected result shows.
    Future<void> checkAt(String lat, String lng, Finder expected, String reason) async {
      for (var i = 0; i < 6 && expected.evaluate().isEmpty; i++) {
        await tester.tap(find.textContaining(RegExp('^(Check|Update) location')));
        await tester.pump();
        for (var j = 0; j < 4; j++) {
          host('geo $lat $lng');
          await settle(tester, const Duration(seconds: 1));
        }
        await waitFor(tester, () => find.byType(CircularProgressIndicator).evaluate().isEmpty, reason: 'location request');
      }
      expect(expected, findsOneWidget, reason: reason);
    }

    await checkAt('52.2401', '21.0301', find.textContaining(RegExp(r'\d+ m from the site')), 'GPS fix next to the site');
    expect(find.textContaining('more than 200 m'), findsNothing);

    await checkAt('52.30', '21.03', find.text('You seem to be more than 200 m from the site address.'), 'GPS fix ~7 km away');
    expect(find.textContaining('km from the site'), findsOneWidget);
    await quit(tester, c);
  });
}
