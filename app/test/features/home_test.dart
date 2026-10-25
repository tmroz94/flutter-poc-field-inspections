import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/features/home/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('greets the user and lists today and this week (P02)', (tester) async {
    await pumpApp(tester, store: signedInStore());
    expect(find.textContaining(', Anna'), findsOneWidget);
    expect(find.text('Warehouse A – loading dock'), findsOneWidget);
    expect(find.text('Riverside office, floor 4'), findsOneWidget);
    expect(find.text('Substation 12'), findsOneWidget);
    expect(find.text('Overdue by 1 day'), findsOneWidget);
    expect(find.byTooltip('Notifications, 3 unread'), findsOneWidget);
  });

  testWidgets('a today card opens its inspection', (tester) async {
    final app = await pumpApp(tester, store: signedInStore());
    await tester.tap(find.text('Warehouse A – loading dock'));
    await tester.pumpAndSettle();
    expect(app.location, '/inspections/INS-1042');
  });

  for (final (name, size) in [('phone', phoneSize), ('tablet', tabletSize), ('desktop', desktopSize)]) {
    testWidgets('no overflow at 200% text on $name', (tester) async {
      await pumpApp(tester, store: signedInStore(), size: size, textScale: 2);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('a report the server rejected', () {
    final now = DateTime(2026, 10, 24, 10);
    final draft = InspectionDraft(
      siteId: 's-riverside-office',
      siteName: 'Riverside office, floor 4',
      type: 'Fire safety, annual',
      date: DateTime(2026, 10, 25),
      startMinutes: 9 * 60,
      duration: '60',
      answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
      confirmed: true,
    );

    Future<MemoryLocalStore> rejected() async {
      final store = MemoryLocalStore();
      final id = await store.enqueue(kind: 'create', site: draft.siteName, body: draft.toApiBody(), draft: draft);
      await store.markFailed(id, 'server');
      return store;
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.byTooltip('Report options'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byTooltip('Report options'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the reason and can be sent again', (tester) async {
      final store = await rejected();
      await pumpApp(tester, store: signedInStore(), localStore: store, now: now);
      expect(find.text('Rejected by the server: server'), findsOneWidget);
      await openMenu(tester);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
    });

    testWidgets('can be reopened in the wizard on its review step', (tester) async {
      final store = await rejected();
      final app = await pumpApp(tester, store: signedInStore(), localStore: store, now: now);
      await openMenu(tester);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(app.location, startsWith('/inspections/new?step=5'));
      expect(store.entries, isEmpty);
      expect(store.drafts['new']?.siteName, 'Riverside office, floor 4');
    });

    testWidgets('can be deleted after confirming', (tester) async {
      final store = await rejected();
      await pumpApp(tester, store: signedInStore(), localStore: store, now: now);
      await openMenu(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this report?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
    });
  });

  testWidgets('desktop uses a card grid instead of a horizontal list (D02)', (tester) async {
    await pumpApp(tester, store: signedInStore(), size: desktopSize);
    expect(find.byType(Wrap), findsWidgets);
    expect(find.widgetWithText(FloatingActionButton, 'New inspection'), findsOneWidget, reason: 'in the extended rail');
  });
}
