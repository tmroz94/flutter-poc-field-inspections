// End-to-end flows on a real device or emulator, with the real stores
// (shared_preferences, SQLite via drift) and the in-app fake backend:
//   fvm flutter test integration_test -d emulator-5554
import 'package:field_inspections/app.dart';
import 'package:field_inspections/core/router/router.dart';
import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/data/api/backend_config.dart';
import 'package:field_inspections/features/inspections/inspection_detail_screen.dart';
import 'package:field_inspections/features/inspections/inspection_list_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the app the way `main` does, minus notifications and the backend probe.
Future<void> _launch(WidgetTester tester, {String initialLocation = '/home'}) async {
  final store = await PrefsStore.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        backendConfigProvider.overrideWithValue(const BackendConfig(mode: BackendMode.fake, baseUrl: '')),
        initialLocationProvider.overrideWithValue(initialLocation),
      ],
      child: const FieldInspectionsApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Disposes the ProviderScope (closing the database), like an app restart.
Future<void> _quit(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  // Signs in straight away with the fixture account.
  await tester.tap(find.text('Use demo account'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferencesAsync().clear());

  testWidgets('deep link while signed out → sign in → lands on the detail; back → list', (tester) async {
    await _launch(tester, initialLocation: '/inspections/INS-1042?tab=checklist');
    expect(find.text('Sign in'), findsWidgets);

    await _signIn(tester);
    expect(find.byType(InspectionDetailScreen), findsOneWidget);
    expect(find.text('Warehouse A – loading dock'), findsWidgets);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(InspectionsScreen), findsOneWidget);
    await _quit(tester);
  });

  testWidgets('the session and a wizard draft survive a restart (SQLite)', (tester) async {
    await _launch(tester);
    await _signIn(tester);
    await tester.tap(find.text('New inspection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'Integration depot');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Integration depot'), findsOneWidget);
    await _quit(tester);

    // Restart: still signed in, draft restored from the database.
    await _launch(tester);
    expect(find.text('Integration depot'), findsOneWidget);
    await tester.tap(find.text('Integration depot'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(find.text('Integration depot'), findsNothing);
    await _quit(tester);
  });

  testWidgets('settings re-theme and switch language live', (tester) async {
    await _launch(tester, initialLocation: '/settings/appearance');
    await _signIn(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Theme'))).brightness, Brightness.dark);

    await tester.scrollUntilVisible(find.text('Polski'), 200);
    await tester.tap(find.text('Polski'));
    await tester.pumpAndSettle();
    expect(find.text('Motyw'), findsOneWidget);
    await _quit(tester);
  });
}
