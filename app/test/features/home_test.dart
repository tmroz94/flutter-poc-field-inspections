import 'dart:typed_data';

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

    testWidgets('field errors use the wizard\'s field names and messages, in the app language', (tester) async {
      final store = MemoryLocalStore();
      final id = await store.enqueue(kind: 'create', site: draft.siteName, body: draft.toApiBody(), draft: draft);
      await store.markFailed(id, 'scheduledAt: past, durationMin: range');
      await pumpApp(tester, store: {...signedInStore(), 'theme_settings': '{"locale":"pl"}'}, localStore: store, now: now);
      expect(
        find.text(
          'Odrzucony przez serwer: Data (Wybierz dzisiejszą lub późniejszą datę), Szacowany czas (minuty) (Podaj liczbę od 15 do 480)',
        ),
        findsOneWidget,
      );
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

    testWidgets('can be deleted after confirming, with its photos', (tester) async {
      final store = MemoryLocalStore();
      final withPhoto = draft.copyWith(
        attachments: [const DraftAttachment(id: 'ph-1', name: 'a.png', sizeBytes: 3, isPhoto: true)],
      );
      await store.putBlob('ph-1', Uint8List.fromList([1, 2, 3]), 'image/png');
      await store.putBlob('ph-other', Uint8List.fromList([4]), 'image/png');
      final id = await store.enqueue(kind: 'create', site: draft.siteName, body: withPhoto.toApiBody(), draft: withPhoto);
      await store.markFailed(id, 'server');
      await pumpApp(tester, store: signedInStore(), localStore: store, now: now);
      await openMenu(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this report?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
      expect(store.blobs.keys, ['ph-other'], reason: "the report's photo goes, others stay");
    });
  });

  testWidgets('desktop uses a card grid instead of a horizontal list (D02)', (tester) async {
    await pumpApp(tester, store: signedInStore(), size: desktopSize);
    expect(find.byType(Wrap), findsWidgets);
    expect(find.widgetWithText(FloatingActionButton, 'New inspection'), findsOneWidget, reason: 'in the extended rail');
  });
}
