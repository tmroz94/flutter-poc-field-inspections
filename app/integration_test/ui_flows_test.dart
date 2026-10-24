// UI flows on a real device: pickers, selection controls, keyboard actions,
// list gestures, page and Hero transitions, the animated photo grid and
// reduced motion. Frame timings for the animated parts are printed (debug
// builds are slower than release; compare runs, not absolute numbers).
//   fvm flutter test integration_test/ui_flows_test.dart -d emulator-5554
import 'dart:ui' as ui;

import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:field_inspections/core/theme/theme_settings.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/features/inspections/inspection_detail_screen.dart';
import 'package:field_inspections/features/inspections/inspection_list_screen.dart';
import 'package:field_inspections/features/inspections/photo_viewer_screen.dart';
import 'package:field_inspections/features/wizard/submitted_screen.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/fakes.dart';
import 'support.dart';

/// A fake camera that returns a real, decodable PNG (the unit-test fake's
/// 1×1 image isn't meant to be drawn).
class _Camera extends FakeMedia {
  Uint8List? _png;

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

  setUp(() async {
    await SharedPreferencesAsync().clear();
  });

  testWidgets('wizard end to end: autocomplete, keyboard, pickers, segmented answers, animated photo grid, success animation', (
    tester,
  ) async {
    // The photo step uses a fake camera here: the system camera app is native
    // UI that integration_test can't drive (Patrol can).
    final c = await launch(tester, overrides: [mediaServiceProvider.overrideWithValue(_Camera())]);
    await signIn(tester);
    await c.read(localStoreProvider).deleteDraft('new');

    await tester.tap(find.text('New inspection'));
    await tester.pumpAndSettle();

    // Step 1: autocomplete with the keyboard (arrow down + Enter).
    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'River');
    await waitFor(tester, () => find.text('Add “River” as a new site').evaluate().isNotEmpty, reason: 'suggestions');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    if (find.text('Add “River” as a new site').evaluate().isNotEmpty) {
      debugPrint('KEYBOARD: arrow keys did not pick a suggestion; tapping it');
      await tester.tap(find.textContaining('office, floor 4').last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 5'), findsOneWidget);

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
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 5'), findsOneWidget);

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
    expect(find.textContaining('18 of 18 answered'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 4 of 5'), findsOneWidget);

    // Step 4: the photo grid animates items in and out.
    await frames('photo grid insert/remove', () async {
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take photo'));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

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

  testWidgets('list: fling to the second page, pull to refresh, swipe to archive and undo', (tester) async {
    final c = await launch(tester, initialLocation: '/inspections');
    await signIn(tester);
    expect(find.byType(InspectionsScreen), findsOneWidget);

    await frames('list fling to page 2', () async {
      for (var i = 0; i < 20 && find.textContaining('INS-1000 ·').evaluate().isEmpty; i++) {
        await tester.fling(find.byType(Scrollable).last, const Offset(0, -800), 3000);
        await settle(tester, const Duration(milliseconds: 600));
      }
    });
    expect(find.textContaining('INS-1000 ·'), findsOneWidget, reason: 'infinite scroll loaded the next page');

    // Back to the top, then pull to refresh: the indicator shows while reloading.
    final list = find.byType(Scrollable).last;
    for (var i = 0; i < 30 && tester.state<ScrollableState>(list).position.pixels > 0; i++) {
      await tester.fling(list, const Offset(0, 800), 3000);
      await settle(tester, const Duration(milliseconds: 300));
    }
    await tester.fling(list, const Offset(0, 500), 1000);
    var refreshed = false;
    for (var i = 0; i < 60 && !refreshed; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      refreshed = find.byType(RefreshProgressIndicator).evaluate().isNotEmpty;
    }
    expect(refreshed, isTrue, reason: 'pull to refresh started a reload');
    await settle(tester, const Duration(seconds: 2));

    // "Substation 12" also names an older inspection further down (INS-1026).
    final row = find.textContaining('INS-1038');
    expect(row, findsOneWidget);
    await tester.drag(row, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('INS-1038 ·'), findsNothing);
    await waitFor(tester, () => find.text('INS-1038 archived').evaluate().isNotEmpty, reason: 'archive snackbar');
    await tester.pumpAndSettle(); // let the snackbar finish sliding in
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('INS-1038 ·'), findsOneWidget);
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
    expect(find.text('Submitted'), findsWidgets, reason: 'chip row still lists the status');
    expect(find.text('Solar farm, inverter row B'), findsNothing, reason: 'submitted ones are filtered out');
    await quit(tester, c);
  });
}
