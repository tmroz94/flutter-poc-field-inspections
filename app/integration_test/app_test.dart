// End-to-end flows on a real device or emulator, with the real stores
// (shared_preferences, SQLite via drift) and the in-app fake backend:
//   fvm flutter test integration_test -d emulator-5554
import 'package:field_inspections/core/router/router.dart';
import 'package:field_inspections/features/inspections/inspection_detail_screen.dart';
import 'package:field_inspections/features/inspections/inspection_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearDeviceData);

  testWidgets('deep link while signed out → sign in → lands on the detail; back → list', (tester) async {
    final c = await launch(tester, initialLocation: '/inspections/INS-1042?tab=checklist');
    expect(find.text('Sign in'), findsWidgets);

    await signIn(tester);
    expect(find.byType(InspectionDetailScreen), findsOneWidget);
    expect(find.text('Warehouse A – loading dock'), findsWidgets);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.toString(), '/inspections/INS-1042?tab=history');
    // System back (Android) / browser back: on a phone the list replaces the
    // detail; on wide screens the list stays and the detail pane closes. The
    // list shows in both, so check that the detail is gone.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // The path only: go_router keeps the deep link's query on a pop, so a
    // stale ?tab= can stay; the list ignores it.
    expect(c.read(routerProvider).state.uri.path, '/inspections');
    expect(find.byType(InspectionDetailView), findsNothing);
    expect(find.byType(InspectionsScreen), findsOneWidget);
    await quit(tester, c);
  });

  testWidgets('the session and a wizard draft survive a restart (SQLite)', (tester) async {
    final c = await launch(tester);
    await signIn(tester);
    await tapNewInspection(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'Integration depot');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Integration depot'), findsOneWidget);
    await quit(tester, c);

    // Restart: still signed in, draft restored from the database.
    final restarted = await launch(tester);
    expect(find.text('Integration depot'), findsOneWidget);
    await tester.tap(find.text('Integration depot'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(find.text('Integration depot'), findsNothing);
    await quit(tester, restarted);
  });

  testWidgets('settings re-theme and switch language live', (tester) async {
    final c = await launch(tester, initialLocation: '/settings/appearance');
    await signIn(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Theme').first)).brightness, Brightness.dark);

    await tester.ensureVisible(find.text('Polski')); // one or two scrolling panes, by width
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polski'));
    await tester.pumpAndSettle();
    expect(find.text('Motyw'), findsOneWidget);
    await quit(tester, c);
  });
}
