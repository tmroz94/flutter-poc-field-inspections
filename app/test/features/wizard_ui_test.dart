import 'package:field_inspections/data/api/api_exception.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/repositories/inspections_repository.dart';
import 'package:field_inspections/features/home/home_screen.dart';
import 'package:field_inspections/features/wizard/submitted_screen.dart';
import 'package:field_inspections/features/wizard/wizard_controller.dart';
import 'package:field_inspections/features/wizard/wizard_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/test_app.dart';

class _OfflineSave extends FakeInspectionsRepository {
  _OfflineSave(super.db) : super(latency: Duration.zero);

  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false}) async => throw const ApiException('network');
}

Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
}

final _allPass = {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass};

InspectionDraft _ready() => InspectionDraft(
  siteId: 's-riverside-office',
  siteName: 'Riverside office, floor 4',
  siteAddress: 'ul. Wybrzeże 2, Warsaw',
  type: 'Fire safety, annual',
  date: DateTime.now().add(const Duration(days: 1)),
  startMinutes: 13 * 60,
  duration: '90',
  answers: _allPass,
  lastStep: 5,
);

void main() {
  testWidgets('step 1: Next needs a site; autocomplete picks one', (tester) async {
    await pumpApp(tester, initialLocation: '/inspections/new?step=1', store: signedInStore());
    expect(find.text('Step 1 of 5'), findsOneWidget);
    await tapNext(tester);
    expect(find.text('Required'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'River');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Add “River” as a new site'), findsOneWidget);
    await tester.tap(find.textContaining('office, floor 4').last);
    await tester.pumpAndSettle();
    expect(find.text('ul. Wybrzeże 2, Warsaw'), findsOneWidget);
    await tapNext(tester);
    expect(find.text('Step 2 of 5'), findsOneWidget);
  });

  // Regression: entry points used to push the wizard; the first step change
  // (go) then removed the pushed page and showed the leave dialog.
  testWidgets('opened from Home, Next goes to step 2 without the leave dialog', (tester) async {
    final app = await pumpApp(tester, store: signedInStore());
    await tester.tap(find.text('New inspection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'River');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('office, floor 4').last);
    await tester.pumpAndSettle();
    await tapNext(tester);
    expect(find.text('Leave'), findsNothing);
    expect(app.location, '/inspections/new?step=2&from=%2Fhome');
  });

  testWidgets('rail New inspection from the Map tab: Close returns to the map', (tester) async {
    final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/map', size: tabletSize);
    await tester.tap(find.byTooltip('New inspection'));
    await tester.pumpAndSettle();
    expect(app.location, '/inspections/new?step=1&from=%2Fmap');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(app.location, '/map');
  });

  testWidgets('opened from a detail (Continue), steps move without the leave dialog', (tester) async {
    final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/inspections/INS-1042');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(app.location, '/inspections/INS-1042/edit?step=3');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
    await tester.pumpAndSettle();
    expect(find.text('Leave'), findsNothing);
    expect(app.location, '/inspections/INS-1042/edit?step=2');
  });

  testWidgets('site suggestions: inline list; arrows move, Enter picks, Escape closes', (tester) async {
    await pumpApp(tester, initialLocation: '/inspections/new?step=1', store: signedInStore());
    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'River');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final options = find.byWidgetPredicate(
      (w) => w is ListTile && w.onTap != null && w.subtitle != null,
    ); // existing sites show their address
    expect(options, findsWidgets, reason: 'existing sites are listed under the field');
    expect(tester.widget<ListTile>(options.first).selected, isTrue, reason: 'the first one is highlighted');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Add “River” as a new site'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'Rive');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Add “Rive” as a new site'), findsNothing, reason: 'the list closed after picking');
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == Symbols.check_circle),
      findsOneWidget,
      reason: 'an existing site was picked',
    );
    await tester.pump(const Duration(milliseconds: 500)); // let the draft autosave run
  });

  testWidgets('step 2: duration must be 15–480; pickers fill date and time', (tester) async {
    final store = MemoryLocalStore()
      ..drafts['new'] = const InspectionDraft(siteId: 's-solar-farm', siteName: 'Solar farm, inverter row B', lastStep: 2);
    await pumpApp(tester, initialLocation: '/inspections/new?step=2', store: signedInStore(), localStore: store);
    expect(find.text('Step 2 of 5'), findsOneWidget);

    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fire safety, annual').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open time picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Estimated duration (minutes)'), '5');
    await tapNext(tester);
    expect(find.text('Enter a number from 15 to 480'), findsWidgets);
    expect(find.text('Step 2 of 5'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Estimated duration (minutes)'), '90');
    await tapNext(tester);
    expect(find.text('Step 3 of 5'), findsOneWidget);
  });

  testWidgets('step 3: a Fail needs a note or photo; failure details expand', (tester) async {
    final answers = {..._allPass}..remove('c02');
    final store = MemoryLocalStore()..drafts['new'] = _ready().copyWith(answers: answers, lastStep: 3);
    final app = await pumpApp(tester, initialLocation: '/inspections/new?step=3', store: signedInStore(), localStore: store);
    expect(find.text('Fire safety, annual · 17 of 18 answered'), findsOneWidget);

    await tapNext(tester);
    expect(find.text('1 item needs attention'), findsOneWidget);

    final card = find.ancestor(of: find.text('Emergency exit clear'), matching: find.byType(Card));
    await tester.tap(find.descendant(of: card, matching: find.text('Fail')));
    await tester.pumpAndSettle();
    expect(find.text('Requires follow-up visit'), findsOneWidget);
    expect(find.text('3 · Major'), findsOneWidget);
    expect(find.text('Add a note or a photo for this failure'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'What is wrong?'), 'Blocked by pallets');
    await tester.pumpAndSettle();
    await tapNext(tester);
    expect(app.location, '/inspections/new?step=4');
  });

  testWidgets('step 4: a photo is required after a failure; added with animation', (tester) async {
    final store = MemoryLocalStore()
      ..drafts['new'] = _ready().copyWith(
        answers: {..._allPass, 'c02': Answer.fail},
        failures: {'c02': const FailDetail(note: 'x')},
        lastStep: 4,
      );
    await pumpApp(tester, initialLocation: '/inspections/new?step=4', store: signedInStore(), localStore: store);
    await tapNext(tester);
    expect(find.text('Add at least one photo of the failed items'), findsWidgets);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photos · 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove photo 1'));
    await tester.pumpAndSettle();
    expect(find.text('Photos · 0'), findsOneWidget);
  });

  testWidgets('step 5: submit needs confirmation, then shows the success screen', (tester) async {
    final store = MemoryLocalStore()..drafts['new'] = _ready();
    final app = await pumpApp(tester, initialLocation: '/inspections/new?step=5', store: signedInStore(), localStore: store);
    final submit = find.widgetWithText(FilledButton, 'Submit');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(find.text('I confirm the findings are accurate'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byType(SubmittedScreen), findsOneWidget);
    expect(find.text('Report submitted'), findsOneWidget);
    expect(app.location, startsWith('/inspections/INS-1046/submitted'));
    expect(store.drafts, isEmpty);
  });

  // Regression: the backend kept the draft's attachment metadata as photo
  // records, so a new inspection with photos couldn't be read back.
  testWidgets('submit with photos, then View inspection shows them', (tester) async {
    final store = MemoryLocalStore()
      ..drafts['new'] = _ready().copyWith(
        confirmed: true,
        attachments: const [DraftAttachment(id: 'a1', name: 'IMG_0001.png', sizeBytes: 1200)],
      );
    final app = await pumpApp(tester, initialLocation: '/inspections/new?step=5', store: signedInStore(), localStore: store);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Submit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Report submitted'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('View inspection'));
    await tester.pumpAndSettle();
    expect(app.location, '/inspections/INS-1046');
    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Open photo 1 of 1'), findsOneWidget);
  });

  testWidgets('offline submit is queued and shown on Home', (tester) async {
    final store = MemoryLocalStore()..drafts['new'] = _ready().copyWith(confirmed: true);
    final app = await pumpApp(
      tester,
      initialLocation: '/inspections/new?step=5',
      store: signedInStore(),
      localStore: store,
      inspections: _OfflineSave.new,
      online: false,
    );
    expect(find.textContaining("You're offline. The report is saved"), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Submit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Report saved and queued'), findsOneWidget);
    expect(store.entries, hasLength(1));

    await app.go('/home');
    expect(find.text('Waiting to send'), findsOneWidget);
    expect(find.textContaining('Riverside office, floor 4'), findsWidgets);
  });

  testWidgets('step guard: deep link past an invalid step lands on that step', (tester) async {
    final store = MemoryLocalStore()..drafts['new'] = const InspectionDraft(siteName: 'Depot north', lastStep: 2);
    final app = await pumpApp(tester, initialLocation: '/inspections/new?step=4', store: signedInStore(), localStore: store);
    expect(app.location, '/inspections/new?step=2');
    expect(find.text('Complete “Details” first'), findsOneWidget);
  });

  testWidgets('close with a draft asks first; Leave keeps the draft on Home', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/home', store: signedInStore());
    await tester.tap(find.text('New inspection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Site'), 'Depot north');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without submitting?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(WizardScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Drafts on this device'), findsOneWidget);
    expect(find.text('Depot north'), findsOneWidget);

    await tester.tap(find.text('Depot north'));
    await tester.pumpAndSettle();
    expect(app.location, '/inspections/new?step=1&from=%2Fhome', reason: 'Close returns to Home');
    expect(find.widgetWithText(TextFormField, 'Depot north'), findsOneWidget);
  });

  testWidgets('Discard draft deletes it', (tester) async {
    final store = MemoryLocalStore()..drafts['new'] = const InspectionDraft(siteName: 'Depot north');
    await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), localStore: store);
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(store.drafts, isEmpty);
  });

  testWidgets('system back goes to the previous step', (tester) async {
    final store = MemoryLocalStore()..drafts['new'] = _ready().copyWith(lastStep: 3);
    final app = await pumpApp(tester, initialLocation: '/inspections/new?step=3', store: signedInStore(), localStore: store);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(app.location, '/inspections/new?step=2');
  });

  testWidgets('edit prefills from the inspection (INS-1042)', (tester) async {
    await pumpApp(tester, initialLocation: '/inspections/INS-1042/edit?step=2', store: signedInStore());
    expect(find.text('Edit INS-1042'), findsOneWidget);
    expect(find.widgetWithText(TextField, '90'), findsOneWidget);
    expect(find.text('Access through gate 3. Bring the fire panel key.'), findsOneWidget);
  });

  testWidgets('tablet shows the vertical step list (T02), desktop the stepper (D04)', (tester) async {
    final store = MemoryLocalStore()..drafts['new'] = _ready().copyWith(lastStep: 2);
    await pumpApp(tester, initialLocation: '/inspections/new?step=2', store: signedInStore(), localStore: store, size: tabletSize);
    expect(find.text('Next: Checklist'), findsOneWidget);
    expect(find.text('Riverside office, floor 4'), findsOneWidget, reason: 'site hint in the step list');
  });

  testWidgets('desktop stepper', (tester) async {
    final store = MemoryLocalStore()..drafts['new'] = _ready().copyWith(lastStep: 4);
    await pumpApp(tester, initialLocation: '/inspections/new?step=4', store: signedInStore(), localStore: store, size: desktopSize);
    expect(find.text('Photos and files'), findsNWidgets(2), reason: 'stepper label and page title');
    expect(find.text('Next: Review and submit'), findsOneWidget);
  });

  test('wizard keys', () {
    expect(wizardKey(null), 'new');
    expect(wizardKey('INS-1'), 'INS-1');
  });
}
