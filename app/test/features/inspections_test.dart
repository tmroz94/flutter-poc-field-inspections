import 'package:field_inspections/core/widgets/inspection_widgets.dart';
import 'package:field_inspections/data/api/api_exception.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/models/list_query.dart';
import 'package:field_inspections/data/models/notification.dart';
import 'package:field_inspections/data/repositories/inspections_repository.dart';
import 'package:field_inspections/features/inspections/inspection_screens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

/// A backend that can't be reached.
class _OfflineRepository implements InspectionsRepository {
  Never _fail() => throw const ApiException('network');
  @override
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20}) async => _fail();
  @override
  Future<InspectionDetail> get(String id) async => _fail();
  @override
  Future<void> setArchived(String id, {required bool archived}) async => _fail();
  @override
  Future<List<ChecklistItem>> checklist(String templateId) async => _fail();
  @override
  Future<List<AppNotification>> notifications() async => _fail();
  @override
  Future<void> markNotificationsRead({String? id}) async => _fail();
  @override
  Future<void> deleteNotification(String id) async => _fail();
  @override
  Future<List<SiteOption>> searchSites(String query) async => _fail();
  @override
  Future<List<String>> inspectionTypes() async => _fail();
  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false}) async => _fail();
}

Finder _selectable(String text) => find.byWidgetPredicate((w) => w is SelectableText && w.data == text);

void main() {
  group('list (P03/P04)', () {
    testWidgets('shows open work first with status chips', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore());
      expect(find.text('Substation 12'), findsOneWidget);
      expect(find.text('Warehouse A – loading dock'), findsOneWidget);
      expect(find.widgetWithText(StatusChip, 'Overdue'), findsWidgets);
    });

    testWidgets('a status chip filters through the URL', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections', store: signedInStore());
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Overdue'));
      await tester.tap(find.widgetWithText(FilterChip, 'Overdue'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections?status=overdue');
      expect(find.text('Substation 12'), findsOneWidget);
      expect(find.text('Warehouse A – loading dock'), findsNothing);
    });

    testWidgets('search is debounced into ?q=', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections', store: signedInStore());
      await tester.enterText(find.byType(SearchBar), 'cold');
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.location, '/inspections');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(app.location, '/inspections?q=cold');
      expect(find.text('Cold storage unit 3'), findsWidgets);
      expect(find.text('Substation 12'), findsNothing);
    });

    testWidgets('no match shows the empty state; Clear filters resets the URL', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections?status=overdue&q=boiler', store: signedInStore());
      expect(find.text('No inspections match'), findsOneWidget);
      expect(find.textContaining('“boiler”'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections');
      expect(find.text('Substation 12'), findsOneWidget);
    });

    testWidgets('offline shows the error state with retry', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), inspections: (_) => _OfflineRepository());
      expect(find.text("Couldn't load inspections"), findsOneWidget);
      expect(find.text('Error code: NETWORK_UNREACHABLE'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    });

    testWidgets('infinite scroll loads the second page', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore());
      expect(find.text('INS-1000', findRichText: true), findsNothing);
      await tester.scrollUntilVisible(find.textContaining('INS-1000 ·'), 400, scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('INS-1000 ·'), findsOneWidget);
    });

    testWidgets('swipe archives with undo', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore());
      await tester.drag(find.text('Substation 12'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Substation 12'), findsNothing);
      expect(find.text('INS-1038 archived'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Substation 12'), findsOneWidget);
    });

    testWidgets('web gets a row menu instead of relying on swipe', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), capabilities: web);
      await tester.tap(find.byTooltip('Actions for INS-1038'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Substation 12'), findsNothing);
      expect(find.byTooltip('Refresh list'), findsOneWidget);
    });

    testWidgets('desktop shows the sortable table; sorting goes through the URL', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), size: desktopSize);
      expect(find.text('Select an inspection'), findsOneWidget);
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections?sort=dueDesc');
    });
  });

  group('filter sheet (P05)', () {
    testWidgets('applies status, due and sort to the list URL', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections', store: signedInStore());
      await tester.tap(find.byTooltip('Filter and sort'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/filter');
      for (final s in ['Scheduled', 'In progress', 'Draft', 'Submitted']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, s));
      }
      await tester.tap(find.text('Site name, A to Z'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(find.text('Show 1 result'), findsOneWidget);
      await tester.tap(find.text('Show 1 result'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections?status=overdue&sort=siteAsc');
      expect(find.byType(FilterSheet), findsNothing);
      expect(find.byTooltip('Filter and sort, 2 active'), findsOneWidget);
    });

    testWidgets('at least one status is required', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections/filter', store: signedInStore());
      for (final s in ['Scheduled', 'In progress', 'Draft', 'Overdue', 'Submitted']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, s));
      }
      await tester.pumpAndSettle();
      expect(find.text('Select at least one status'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Show results')).onPressed, isNull);
    });
  });

  group('detail (P06/T04)', () {
    testWidgets('tabs follow and update ?tab= without new history', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=checklist', store: signedInStore());
      expect(find.text('12 of 18 checked'), findsOneWidget);
      expect(find.text('2 failed'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'History'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1042?tab=history');
      expect(find.text('Synced to server'), findsOneWidget);
    });

    testWidgets('unknown id shows a not-found state', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections/INS-9999', store: signedInStore());
      expect(find.text('Inspection not found'), findsOneWidget);
    });

    testWidgets('back keeps the list filters and drops ?tab=', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1038?status=overdue&tab=history', store: signedInStore());
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections?status=overdue');
    });

    testWidgets('tablet: list and detail side by side; selecting swaps the pane', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore(), size: tabletSize);
      expect(find.text('Inspections'), findsWidgets);
      expect(_selectable('/inspections/INS-1042'), findsOneWidget);
      await tester.tap(find.text('Substation 12').first);
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1038');
      expect(_selectable('/inspections/INS-1038'), findsOneWidget);
    });

    testWidgets('photo grid opens the viewer; swiping updates the URL', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=photos', store: signedInStore());
      await tester.ensureVisible(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.text('3 of 6'), findsOneWidget);
      expect(find.text('Emergency exit blocked by pallets'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('4 of 6'), findsOneWidget);
      expect(app.location, '/inspections/INS-1042/photos/p4');
    });

    testWidgets('desktop: opening a row keeps the list filters', (tester) async {
      final app = await pumpApp(
        tester,
        initialLocation: '/inspections?status=overdue,scheduled',
        store: signedInStore(),
        size: desktopSize,
      );
      await tester.tap(find.text('Substation 12'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1038?status=overdue%2Cscheduled');
      expect(find.text('Warehouse A – loading dock'), findsNothing, reason: 'list pane still filtered');
      expect(find.widgetWithText(FilterChip, 'Overdue'), findsOneWidget);
    });

    testWidgets('viewer: arrow keys page, Esc closes (web/desktop keyboards)', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=photos', store: signedInStore());
      await tester.ensureVisible(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('4 of 6'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('2 of 6'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(app.location, '/inspections/INS-1042?tab=photos');
    });

    testWidgets('long-press starts photo multi-select', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=photos', store: signedInStore());
      await tester.ensureVisible(find.bySemanticsLabel('Open photo 2 of 6'));
      await tester.pumpAndSettle();
      await tester.longPress(find.bySemanticsLabel('Open photo 1 of 6'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Photo 2'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
    });
  });
}
