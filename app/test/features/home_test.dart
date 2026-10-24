import 'package:field_inspections/features/home/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

  testWidgets('desktop uses a card grid instead of a horizontal list (D02)', (tester) async {
    await pumpApp(tester, store: signedInStore(), size: desktopSize);
    expect(find.byType(Wrap), findsWidgets);
    expect(find.widgetWithText(FloatingActionButton, 'New inspection'), findsOneWidget, reason: 'in the extended rail');
  });
}
