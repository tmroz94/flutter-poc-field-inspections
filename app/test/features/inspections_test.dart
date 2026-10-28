import 'dart:async';
import 'dart:math' as math;

import 'package:field_inspections/core/theme/color_schemes.dart';
import 'package:field_inspections/core/widgets/inspection_widgets.dart';
import 'package:field_inspections/data/api/api_exception.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/models/list_query.dart';
import 'package:field_inspections/data/models/notification.dart';
import 'package:field_inspections/data/providers.dart';
import 'package:field_inspections/data/repositories/inspections_repository.dart';
import 'package:field_inspections/features/inspections/inspection_screens.dart';
import 'package:field_inspections/features/inspections/inspections_controller.dart';
import 'package:field_inspections/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
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
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false, String? requestKey}) async => _fail();
}

/// The list answers only when [answer] completes.
class _SlowList extends FakeInspectionsRepository {
  _SlowList(super.db) : super(latency: Duration.zero);

  final answer = Completer<void>();

  @override
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20}) async {
    await answer.future;
    return super.list(query, page: page, pageSize: pageSize);
  }
}

/// A list answer that isn't the API's (e.g. a cast failing on a portal page).
class _Unreadable extends FakeInspectionsRepository {
  _Unreadable(super.db) : super(latency: Duration.zero);

  @override
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20}) async => throw TypeError();
}

/// The fake backend, with pages after the first failing while [pagesDown].
class _FlakyPages extends FakeInspectionsRepository {
  _FlakyPages(super.db) : super(latency: Duration.zero);

  bool pagesDown = true;
  int laterPageCalls = 0;

  @override
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20}) {
    if (page > 1) {
      laterPageCalls++;
      if (pagesDown) throw const ApiException('network');
    }
    return super.list(query, page: page, pageSize: pageSize);
  }
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

    // The selected row's highlight is Scheduled's fill (and close to In
    // progress's), so that row's chip is outlined, in the tiles and the table.
    // The status colours themselves fail on it in the medium/high contrast
    // schemes (light medium Submitted: 2.0:1), hence the check below.
    for (final (layout, size) in [('tiles', tabletSize), ('table', desktopSize)]) {
      testWidgets('the selected row outlines its status chip ($layout)', (tester) async {
        await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore(), size: size);
        final chips = tester.widgetList<StatusChip>(find.byType(StatusChip)).toList();
        final outlined = chips.where((c) => c.outlined).toList();
        expect(outlined, hasLength(1));
        expect(outlined.single.status, InspectionStatus.inProgress, reason: 'INS-1042 is in progress');
        expect(chips.length, greaterThan(1), reason: 'the other rows keep their fill');
      });
    }

    testWidgets('no chip is outlined while nothing is selected', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), size: desktopSize);
      expect(tester.widgetList<StatusChip>(find.byType(StatusChip)).where((c) => c.outlined), isEmpty);
    });

    testWidgets('outlined chips stay readable on the selection colour in every scheme', (tester) async {
      double contrast(Color a, Color b) {
        final (la, lb) = (a.computeLuminance(), b.computeLuminance());
        return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
      }

      const schemes = {
        'light': AppColorSchemes.light,
        'light medium': AppColorSchemes.lightMediumContrast,
        'light high': AppColorSchemes.lightHighContrast,
        'dark': AppColorSchemes.dark,
        'dark medium': AppColorSchemes.darkMediumContrast,
        'dark high': AppColorSchemes.darkHighContrast,
      };
      for (final MapEntry(key: name, value: scheme) in schemes.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            // No cross-fade from the previous scheme: the colours read are this one's.
            themeAnimationDuration: Duration.zero,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Material(
              color: scheme.secondaryContainer,
              child: Column(children: [for (final s in InspectionStatus.values) StatusChip(s, outlined: true)]),
            ),
          ),
        );
        for (final s in InspectionStatus.values) {
          final chip = find.byWidgetPredicate((w) => w is StatusChip && w.status == s);
          final text = tester.widget<Text>(find.descendant(of: chip, matching: find.byType(Text)));
          final box = tester.widget<Container>(find.descendant(of: chip, matching: find.byType(Container)));
          final decoration = box.decoration! as BoxDecoration;
          expect(decoration.color, isNull, reason: '$name ${s.name}: no fill');
          // WCAG AA: 4.5:1 for the label, 3:1 for the outline (non-text contrast).
          expect(contrast(text.style!.color!, scheme.secondaryContainer), greaterThanOrEqualTo(4.5), reason: '$name ${s.name} label');
          expect(
            contrast((decoration.border! as Border).top.color, scheme.secondaryContainer),
            greaterThanOrEqualTo(3),
            reason: '$name ${s.name} outline',
          );
        }
      }
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
      await tester.enterText(find.byType(TextField).first, 'cold');
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

    testWidgets("an answer the app can't read shows the error state, not an endless skeleton", (tester) async {
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), inspections: _Unreadable.new);
      expect(find.text("Couldn't load inspections"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    });

    for (final (layout, size, skeleton, other) in [
      ('phone', phoneSize, SkeletonList, SkeletonTable),
      ('desktop', desktopSize, SkeletonTable, SkeletonList),
    ]) {
      testWidgets('$layout: the loading skeleton has the shape of what loads', (tester) async {
        late _SlowList repo;
        await pumpApp(
          tester,
          initialLocation: '/inspections',
          store: signedInStore(),
          size: size,
          inspections: (db) => repo = _SlowList(db),
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(skeleton), findsOneWidget);
        expect(find.byType(other), findsNothing);
        repo.answer.complete();
        await tester.pumpAndSettle();
        expect(find.byType(skeleton), findsNothing);
      });
    }

    testWidgets('infinite scroll loads the second page', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections', store: signedInStore());
      expect(app.container.read(inspectionListProvider(const ListQuery())).page, 1);
      await tester.scrollUntilVisible(find.textContaining('INS-1000 ·'), 400, scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('INS-1000 ·'), findsOneWidget);
      expect(app.container.read(inspectionListProvider(const ListQuery())).page, 2);
    });

    testWidgets('a page that fails shows Retry and stops asking until tapped', (tester) async {
      late _FlakyPages repo;
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), inspections: (db) => repo = _FlakyPages(db));
      await tester.scrollUntilVisible(find.text("Couldn't load more."), 400, scrollable: find.byType(Scrollable).last);
      final calls = repo.laterPageCalls;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repo.laterPageCalls, calls, reason: 'no request per rebuild while offline');

      repo.pagesDown = false;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load more."), findsNothing);
      await tester.scrollUntilVisible(find.textContaining('INS-1000 ·'), 400, scrollable: find.byType(Scrollable).last);
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

    testWidgets('undo after changing the filter still restores the inspection', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections', store: signedInStore());
      await tester.drag(find.text('Substation 12'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      // Another filter: the list the archive came from is gone.
      await tester.tap(find.widgetWithText(FilterChip, 'Scheduled'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(app.container.read(mockDatabaseProvider).getInspection('INS-1038')['archived'], isFalse);
    });

    testWidgets('tablet: searching keeps the open detail and the field focus', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore(), size: tabletSize);
      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.enterText(field, 'ware');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(app.location, '/inspections/INS-1042?q=ware');
      final editable = tester.widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)));
      expect(editable.focusNode.hasFocus, isTrue);
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

    testWidgets('sorting the desktop table keeps the open detail', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=checklist', store: signedInStore(), size: desktopSize);
      expect(find.byType(InspectionDetailScreen), findsOneWidget);
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1042?sort=dueDesc&tab=checklist');
      expect(find.byType(InspectionDetailScreen), findsOneWidget);
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

    for (final (name, from, to) in [
      ('older than the picker allows', '2024-01-01', '2024-02-01'),
      ('end before start', '2026-11-20', '2026-11-10'),
    ]) {
      testWidgets('a link with a custom range $name still opens the date picker', (tester) async {
        // Tablet width: on a phone the picker's own header overflows with the test font.
        await pumpApp(
          tester,
          initialLocation: '/inspections/filter?due=custom&from=$from&to=$to',
          store: signedInStore(),
          size: tabletSize,
        );
        await tester.tap(find.byIcon(Symbols.date_range));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(DateRangePickerDialog), findsOneWidget);
      });
    }

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

    testWidgets('closing the dark photo viewer gives the light detail its dark status bar icons back', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=photos', store: signedInStore());
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
      await tester.ensureVisible(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light, reason: 'the viewer is dark');
      await tester.tap(find.byTooltip('Close viewer'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
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

    testWidgets('reduce motion: the viewer opens with no transition or Hero flight', (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/inspections/INS-1042?tab=photos',
        store: {...signedInStore(), 'theme_settings': '{"reduceMotion":true}'},
      );
      await tester.ensureVisible(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.byType(InspectionDetailScreen), findsNothing, reason: 'covered at once');
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

    testWidgets('Select works without a long-press; Share sends every selected photo', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=photos', store: signedInStore());
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Select'));
      await tester.tap(find.widgetWithText(TextButton, 'Select'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Photo 1'));
      await tester.tap(find.bySemanticsLabel('Photo 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Share selected'));
      await tester.pumpAndSettle();
      final shared = [app.fakes.share.texts.last, app.fakes.share.links.last].join(' ');
      expect(shared, contains('/inspections/INS-1042/photos/p1'));
      expect(shared, contains('/inspections/INS-1042/photos/p3'));
      expect(shared, isNot(contains('/photos/p2')));
    });
  });

  // Found on CI: an Undo whose request finished after the app had closed threw.
  test('an archive or undo that finishes after the app closed changes nothing', () {
    final c = ProviderContainer();
    final revision = c.read(inspectionsRevisionProvider.notifier);
    c.dispose();
    expect(revision.changed, returnsNormally);
  });
}
