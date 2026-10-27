// UI flows on a real device: pickers, selection controls, keyboard actions,
// list gestures, page and Hero transitions, the animated photo grid and
// reduced motion. Frame timings for the animated parts are printed (debug
// builds are slower than release; compare runs, not absolute numbers).
//   fvm flutter test integration_test/ui_flows_test.dart -d emulator-5554
import 'dart:ui' as ui;

import 'package:field_inspections/core/platform/capabilities.dart';
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:field_inspections/core/router/router.dart';
import 'package:field_inspections/core/theme/theme_settings.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/features/inspections/inspection_detail_screen.dart';
import 'package:field_inspections/features/inspections/inspection_list_screen.dart';
import 'package:field_inspections/features/inspections/photo_viewer_screen.dart';
import 'package:field_inspections/features/wizard/submitted_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

/// A fake camera that returns a real, decodable PNG (the unit-test fake's
/// 1×1 image isn't meant to be drawn).
// Self-contained (no import from test/): web builds only serve integration_test/.
class _Camera extends MediaService {
  Uint8List? _png;
  int photos = 0;

  @override
  Future<PickedFile?> photo({required bool camera}) async {
    photos++;
    return PickedFile(name: 'IMG_000$photos.png', bytes: _png ??= await _paint(), mime: 'image/png');
  }

  static Future<Uint8List> _paint() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()..color = const Color(0xFF6750A4));
    final image = await recorder.endRecording().toImage(64, 64);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}

/// Where the flows run: phones use touch gestures and the camera; the web and
/// desktop apps use the mouse paths (buttons, menus) and, on desktop, files.
final _caps = Capabilities.current();
final _addPhoto = _caps.isWeb ? 'Use camera' : (_caps.camera ? 'Take photo' : 'Gallery');

/// The wizard step in the URL (the "Step N of 5" header is phone-only).
int _step(ProviderContainer c) => int.parse(c.read(routerProvider).state.uri.queryParameters['step'] ?? '0');

/// The footer's Next button: "Next" on phones, "Next: Details" (etc.) on wide screens.
Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.ancestor(of: find.textContaining(RegExp(r'^Next')), matching: find.byWidgetPredicate((w) => w is FilledButton)));
  await tester.pumpAndSettle();
}

/// Records engine frame timings while [body] runs and prints a summary.
Future<void> frames(String name, Future<void> Function() body) async {
  final timings = <FrameTiming>[];
  void record(List<FrameTiming> t) => timings.addAll(t);
  SchedulerBinding.instance.addTimingsCallback(record);
  await body();
  SchedulerBinding.instance.removeTimingsCallback(record);
  if (timings.isEmpty) return;
  final total = [for (final t in timings) t.buildDuration + t.rasterDuration];
  final avg = total.fold(Duration.zero, (a, b) => a + b).inMicroseconds / total.length / 1000;
  final slow = total.where((d) => d > const Duration(microseconds: 16667)).length;
  debugPrint('FRAMES $name: ${timings.length} frames, avg ${avg.toStringAsFixed(1)} ms, ${slow * 100 ~/ timings.length}% over 16 ms');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearDeviceData);

  testWidgets('wizard end to end: autocomplete, keyboard, pickers, segmented answers, animated photo grid, success animation', (
    tester,
  ) async {
    // The photo step uses a fake camera here: the system camera app is native
    // UI that integration_test can't drive (Patrol can).
    final c = await launch(tester, overrides: [mediaServiceProvider.overrideWithValue(_Camera())]);
    await signIn(tester);

    await tapNewInspection(tester);

    // Step 1: autocomplete with the keyboard (arrow down + Enter). The keys
    // work on every platform since the inline suggestions (decision 83).
    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'River');
    await waitFor(tester, () => find.text('Add “River” as a new site').evaluate().isNotEmpty, reason: 'suggestions');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Add “River” as a new site'), findsNothing, reason: 'Enter picked a suggestion and closed the list');
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == Symbols.check_circle),
      findsOneWidget,
      reason: 'the second suggestion, an existing site, was picked',
    );
    await _next(tester);
    expect(_step(c), 2);

    // Step 2: dropdown, date and time pickers, segmented priority, number field.
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fire safety, annual').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open time picker'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Estimated duration (minutes)'), '90');
    // The keyboard's Done/Next action must not break anything.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await _next(tester);
    expect(_step(c), 3);

    // Step 3: answer all 18 items with the segmented buttons, scrolling as needed.
    for (var guard = 0; guard < 60 && find.textContaining('18 of 18 answered').evaluate().isEmpty; guard++) {
      final open = find.byWidgetPredicate((w) => w is SegmentedButton<Answer> && w.selected.isEmpty).hitTestable();
      if (open.evaluate().isNotEmpty) {
        await tester.tap(find.descendant(of: open.first, matching: find.text('Pass')));
        await tester.pumpAndSettle();
      } else {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
    }
    // The checklist's own header; from 840 to 1199 the side steps repeat the count.
    expect(find.text('Fire safety, annual · 18 of 18 answered'), findsOneWidget);
    await _next(tester);
    expect(_step(c), 4);

    // Step 4: the photo grid animates items in and out.
    await frames('photo grid insert/remove', () async {
      await tester.tap(find.text(_addPhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_addPhoto));
      await tester.pumpAndSettle();
      expect(find.text('Photos · 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove photo 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final shrinking = find.byWidgetPredicate((w) => w is ScaleTransition && w.scale.value > 0 && w.scale.value < 1);
      expect(shrinking, findsOneWidget, reason: 'the removed photo scales out');
      await tester.pumpAndSettle();
      expect(find.text('Photos · 1'), findsOneWidget);
    });
    await _next(tester);

    // Step 5: checkbox gate, then the success animation.
    final submit = find.widgetWithText(FilledButton, 'Submit');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(find.text('I confirm the findings are accurate'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await frames('submit + success animation', () async {
      await tester.tap(submit);
      await tester.pumpAndSettle();
    });
    expect(find.byType(SubmittedScreen), findsOneWidget);
    expect(find.text('Report submitted'), findsOneWidget);
    await quit(tester, c);
  });

  testWidgets('list: next page, refresh, archive and undo (touch gestures on phones, buttons and menus on the web and desktop)', (
    tester,
  ) async {
    final c = await launch(tester, initialLocation: '/inspections');
    await signIn(tester);
    expect(find.byType(InspectionsScreen), findsOneWidget);

    // The vertical scroll view that actually scrolls (lists and the table nest several).
    Finder mainList() {
      final all = tester.stateList<ScrollableState>(find.byType(Scrollable)).toList();
      final best = all
          .where((st) => st.widget.axisDirection == AxisDirection.down)
          .reduce((a, b) => a.position.maxScrollExtent >= b.position.maxScrollExtent ? a : b);
      return find.byWidget(best.widget);
    }

    await frames('list to page 2', () async {
      for (var i = 0; i < 20 && find.textContaining('INS-1000').evaluate().isEmpty; i++) {
        final loadMore = find.text('Load more').hitTestable();
        if (loadMore.evaluate().isNotEmpty) {
          await tester.tap(loadMore); // desktop table (D03)
        } else {
          await tester.fling(mainList(), const Offset(0, -800), 3000);
        }
        await settle(tester, const Duration(milliseconds: 600));
      }
    });
    final diag = [
      for (final st in tester.stateList<ScrollableState>(find.byType(Scrollable)))
        '${st.widget.axisDirection} ${st.position.pixels.round()}/${st.position.maxScrollExtent.round()}',
      ...find.byType(Text).hitTestable().evaluate().map((e) => (e.widget as Text).data).whereType<String>().take(40),
    ].join(' | ');
    expect(find.textContaining('INS-1000'), findsWidgets, reason: 'the next page loaded. $diag');

    final list = mainList();
    for (var i = 0; i < 30 && tester.state<ScrollableState>(list).position.pixels > 0; i++) {
      await tester.fling(list, const Offset(0, 800), 3000);
      await settle(tester, const Duration(milliseconds: 300));
    }
    if (!_caps.isMobile) {
      // No pull gesture with a mouse: the app bar's Refresh button.
      await tester.tap(find.byTooltip('Refresh list'));
      await settle(tester, const Duration(seconds: 2));
      expect(find.textContaining('INS-1000'), findsNothing, reason: 'the refresh reloaded page 1');
    } else {
      await tester.fling(list, const Offset(0, 500), 1000);
      var refreshed = false;
      for (var i = 0; i < 60 && !refreshed; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        refreshed = find.byType(RefreshProgressIndicator).evaluate().isNotEmpty;
      }
      expect(refreshed, isTrue, reason: 'pull to refresh started a reload');
      await settle(tester, const Duration(seconds: 2));
    }

    // "Substation 12" also names an older inspection further down (INS-1026).
    if (!_caps.isMobile) {
      await tester.tap(find.byTooltip('Actions for INS-1038'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
    } else {
      await tester.drag(find.textContaining('INS-1038'), const Offset(-600, 0));
    }
    await tester.pumpAndSettle();
    // The row is gone; the snackbar may already say "INS-1038 archived" (it's quicker on desktop).
    expect(find.textContaining(RegExp(r'INS-1038(?! archived)')), findsNothing);
    await waitFor(tester, () => find.text('INS-1038 archived').evaluate().isNotEmpty, reason: 'archive snackbar');
    await tester.pumpAndSettle(); // let the snackbar finish sliding in
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('INS-1038'), findsWidgets);
    await quit(tester, c);
  });

  testWidgets('page and Hero transitions animate; reduced motion removes them', (tester) async {
    final c = await launch(tester, initialLocation: '/inspections/INS-1042?tab=photos');
    await signIn(tester);
    expect(find.byType(InspectionDetailScreen), findsOneWidget);

    // Photo → viewer: a Hero flight, both routes on screen mid-transition.
    await tester.ensureVisible(find.bySemanticsLabel('Open photo 3 of 6'));
    await tester.pumpAndSettle();
    await frames('photo Hero open', () async {
      await tester.tap(find.bySemanticsLabel('Open photo 3 of 6'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.byType(InspectionDetailScreen), findsOneWidget, reason: 'both routes on screen mid-transition');
      await tester.pumpAndSettle();
    });
    expect(find.byType(InspectionDetailScreen), findsNothing, reason: 'covered once the transition ends');
    await tester.binding.handlePopRoute(); // Android system back
    await tester.pumpAndSettle();

    // Reduced motion (Appearance › Reduce motion): page changes without movement.
    c.read(themeSettingsProvider.notifier).update((s) => s.copyWith(reduceMotion: true));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('Open photo 3 of 6'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Open photo 3 of 6'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.byType(InspectionDetailScreen), findsNothing, reason: 'no transition: the detail is covered at once');
    await tester.pumpAndSettle();
    c.read(themeSettingsProvider.notifier).update((s) => s.copyWith(reduceMotion: false));
    await tester.pumpAndSettle();
    await quit(tester, c);
  });

  testWidgets('keyboard: Next moves focus, Done submits; filter sheet selection controls', (tester) async {
    final c = await launch(tester, initialLocation: '/inspections');
    expect(find.text('Sign in'), findsWidgets);

    await tester.tap(find.widgetWithText(TextFormField, 'Email'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'anna.nowak@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused, isNotNull);
    expect(find.ancestor(of: find.byWidget(focused!.widget), matching: find.widgetWithText(TextFormField, 'Password')), findsWidgets);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'inspect123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, const Duration(seconds: 1));
    expect(find.byType(InspectionsScreen), findsOneWidget, reason: 'Done on the password field signs in and returns to the target');

    // Filter sheet: checkboxes, segmented due window, radio sort.
    await tester.tap(find.byTooltip('Filter and sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Submitted'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Site name, A to Z'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^Show')));
    await tester.pumpAndSettle();
    expect(find.byType(InspectionsScreen), findsOneWidget);
    final query = c.read(routerProvider).state.uri.queryParameters;
    expect((query['status'], query['due'], query['sort']), ('inProgress,overdue,scheduled', 'week', 'siteAsc'));
    // Fixtures within this week: the draft INS-1040 (in 2 days) and the
    // scheduled INS-1045 (in 4). Only the status filter can hide the draft.
    await waitFor(tester, () => find.textContaining('INS-1045').evaluate().isNotEmpty, reason: 'the filtered list');
    expect(find.textContaining('INS-1040'), findsNothing, reason: 'drafts are filtered out');
    await quit(tester, c);
  });
}
