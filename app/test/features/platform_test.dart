import 'dart:async';
import 'dart:convert';

import 'package:field_inspections/core/platform/capabilities.dart';
import 'package:field_inspections/core/platform/desktop_links.dart';
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/features/auth/lock_controller.dart';
import 'package:field_inspections/features/inspections/inspection_detail_screen.dart';
import 'package:field_inspections/features/inspections/report_pdf.dart';
import 'package:field_inspections/features/notifications/reminders.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

const ios = Capabilities(isWeb: false, platform: TargetPlatform.iOS);

void main() {
  group('inspection actions (P06)', () {
    testWidgets('directions open Google Maps on Android, Apple Maps on iOS', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore());
      await tester.tap(find.text('Directions'));
      await tester.pump();
      expect(app.fakes.launcher.opened.single.toString(), 'https://www.google.com/maps/dir/?api=1&destination=52.255,21.04');
    });

    testWidgets('iOS uses the maps: scheme', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore(), capabilities: ios);
      await tester.tap(find.text('Directions'));
      await tester.pump();
      expect(app.fakes.launcher.opened.single.scheme, 'maps');
    });

    testWidgets('call site dials the site manager', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore());
      await tester.tap(find.text('Call site'));
      await tester.pump();
      expect(app.fakes.launcher.opened.single.toString(), 'tel:+48600000000');
    });

    /// The PDF is built with real async work (fonts, compression): wait for it
    /// in real time, polling, rather than for a fixed delay.
    Future<void> waitForShare(WidgetTester tester, TestApp app) async {
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (app.fakes.share.files.isEmpty && DateTime.now().isBefore(end)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('export PDF shares (mobile) the generated report', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore());
      await tester.tap(find.text('Export PDF'));
      await waitForShare(tester, app);
      expect(app.fakes.share.files, ['inspection-INS-1042.pdf']);
    });

    testWidgets('export PDF on desktop saves the report through a Save dialog', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore(), capabilities: macos);
      await tester.tap(find.text('Export PDF'));
      await waitForShare(tester, app);
      expect(app.fakes.share.files, ['inspection-INS-1042.pdf']);
      expect(find.text('Report saved: inspection-INS-1042.pdf'), findsOneWidget);
    });

    testWidgets('share report: custom-scheme link on mobile keeps the tab', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=checklist', store: signedInStore());
      await tester.tap(find.byTooltip('Share report'));
      await tester.pump();
      expect(app.fakes.share.links.single.toString(), 'fieldinspections://app/inspections/INS-1042?tab=checklist');
    });
  });

  test('PDF report renders, with Polish letters transliterated', () async {
    final db = MockDatabase();
    final d = InspectionDetail.fromJson(db.getInspection('INS-1042'));
    final items = [for (final i in fireSafetyTemplate['items']! as List) ChecklistItem.fromJson((i as Map).cast<String, Object?>())];
    final bytes = await buildInspectionReport(d, items, now: DateTime(2026, 10, 24));
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));
  });

  group('map (P18)', () {
    testWidgets('?site= selects a pin and shows its sheet; my location adds the distance', (tester) async {
      await pumpApp(tester, initialLocation: '/map?site=s-riverside-office', store: signedInStore());
      // The map must fill the body (it once laid out at 0×0 inside a Stack).
      expect(tester.getSize(find.byType(FlutterMap)).width, phoneSize.width);
      expect(find.text('Riverside office, floor 4'), findsOneWidget);
      expect(find.text('Open inspection'), findsOneWidget);
      await tester.tap(find.byTooltip('Show my location'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Your location'), findsOneWidget);
      expect(find.textContaining('m away'), findsOneWidget);
    });

    testWidgets('tapping a pin updates the URL; Open inspection goes to the detail', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/map', store: signedInStore());
      await tester.tap(find.bySemanticsLabel('Substation 12, Overdue'));
      await tester.pumpAndSettle();
      expect(app.location, '/map?site=s-substation-12');
      await tester.tap(find.text('Open inspection'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1038');
    });

    testWidgets('denied location shows why, with a settings shortcut on mobile', (tester) async {
      final fakes = Fakes()..location.fix = const LocationFix(LocationStatus.deniedForever);
      await pumpApp(tester, initialLocation: '/map', store: signedInStore(), fakes: fakes);
      await tester.tap(find.byTooltip('Show my location'));
      await tester.pumpAndSettle();
      expect(find.text('Location is blocked for this app. Turn it on in settings.'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Open settings'));
      expect(fakes.permissions.settingsOpened, 1);
    });

    testWidgets('search moves to a matching site', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/map', store: signedInStore());
      await tester.enterText(find.byType(TextField).first, 'parking');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(app.location, '/map?site=s-parking-garage');
    });
  });

  group('notifications (P17)', () {
    testWidgets('groups today and earlier; tapping opens the route and marks read', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/notifications', store: signedInStore());
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      await tester.tap(find.text('Substation 12 is overdue'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1038');
    });

    testWidgets('swipe dismisses with undo', (tester) async {
      await pumpApp(tester, initialLocation: '/notifications', store: signedInStore());
      await tester.drag(find.text('Draft synced'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Draft synced'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Draft synced'), findsOneWidget);
    });

    testWidgets('Turn on enables reminders and schedules one per upcoming inspection', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/notifications', store: signedInStore());
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(app.container.read(remindersProvider), isTrue);
      final routes = app.fakes.notifications.scheduled.map((s) => s.$2).toSet();
      expect(routes, containsAll(['/inspections/INS-1040', '/inspections/INS-1045']));
      for (final (at, _) in app.fakes.notifications.scheduled) {
        expect(at.isAfter(DateTime.now()), isTrue);
      }
      expect(find.text('Reminders are off on this device'), findsNothing);
    });

    testWidgets('web explains it cannot schedule', (tester) async {
      await pumpApp(tester, initialLocation: '/notifications', store: signedInStore(), capabilities: web);
      expect(find.textContaining('Browsers show notifications only while the app is open'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Browsers can’t schedule notifications'), findsOneWidget);
    });

    testWidgets('Linux explains it cannot schedule either', (tester) async {
      await pumpApp(tester, initialLocation: '/notifications', store: signedInStore(), capabilities: linux);
      expect(find.textContaining('Linux shows notifications only while the app is open'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Linux can’t schedule notifications'), findsOneWidget);
    });

    testWidgets('a notification tap anywhere opens its route (custom scheme payload too)', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      app.fakes.notifications.debugTap('fieldinspections://app/inspections/INS-1042?tab=photos');
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1042?tab=photos');
      app.fakes.notifications.debugTap('https://evil.example/home');
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1042?tab=photos', reason: 'foreign payloads are ignored');
    });

    testWidgets('a second tap for the same route opens it again', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      app.fakes.notifications.debugTap('/inspections/INS-1042');
      await tester.pumpAndSettle();
      await app.go('/map');
      app.fakes.notifications.debugTap('/inspections/INS-1042');
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1042');
    });

    testWidgets('a desktop link for the same route opens it again', (tester) async {
      final links = StreamController<String>.broadcast();
      addTearDown(links.close);
      final app = await pumpApp(
        tester,
        store: signedInStore(),
        capabilities: macos,
        overrides: [
          desktopLinksProvider.overrideWithValue(DesktopLinks(enabled: true, initialLink: () async => null, links: () => links.stream)),
        ],
      );
      links.add('fieldinspections://app/map');
      await tester.pumpAndSettle();
      expect(app.location, '/map');
      await app.go('/home');
      links.add('fieldinspections://app/map');
      await tester.pumpAndSettle();
      expect(app.location, '/map');
    });
  });

  group('deep-link tester', () {
    testWidgets('mobile schedules a test notification for the route', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/settings/poc/deep-links', store: signedInStore());
      await tester.scrollUntilVisible(find.byTooltip('Notification for Map'), 200);
      await tester.tap(find.byTooltip('Notification for Map'));
      await tester.pumpAndSettle();
      expect(app.fakes.notifications.scheduled.single.$2, '/map?site=s-riverside-office');
      expect(find.textContaining('Notification in 15 s'), findsOneWidget, reason: 'time to close the app first');
    });

    testWidgets('it names the Android channel in the app language, like the reminders it shares it with', (tester) async {
      final app = await pumpApp(
        tester,
        initialLocation: '/settings/poc/deep-links',
        store: {...signedInStore(), 'theme_settings': '{"locale":"pl"}'},
      );
      await tester.scrollUntilVisible(find.byTooltip('Notification for Map'), 200);
      await tester.tap(find.byTooltip('Notification for Map'));
      await tester.pumpAndSettle();
      expect(app.fakes.notifications.channels, ['Przypomnienia o inspekcjach']);
    });

    testWidgets('web shows it from a timer instead', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/settings/poc/deep-links', store: signedInStore(), capabilities: web);
      await tester.scrollUntilVisible(find.byTooltip('Notification for Map'), 200);
      await tester.tap(find.byTooltip('Notification for Map'));
      await tester.pump();
      expect(find.textContaining('Keep this tab open'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(app.fakes.notifications.shown, ['/map?site=s-riverside-office']);
    });

    testWidgets('macOS schedules it like mobile', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/settings/poc/deep-links', store: signedInStore(), capabilities: macos);
      await tester.scrollUntilVisible(find.byTooltip('Notification for Map'), 200);
      await tester.tap(find.byTooltip('Notification for Map'));
      await tester.pumpAndSettle();
      expect(app.fakes.notifications.scheduled.single.$2, '/map?site=s-riverside-office');
    });

    testWidgets('Linux shows it from a timer like the web', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/settings/poc/deep-links', store: signedInStore(), capabilities: linux);
      await tester.scrollUntilVisible(find.byTooltip('Notification for Map'), 200);
      await tester.tap(find.byTooltip('Notification for Map'));
      await tester.pump();
      expect(find.textContaining('Keep the app open'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(app.fakes.notifications.shown, ['/map?site=s-riverside-office']);
      expect(app.fakes.notifications.scheduled, isEmpty);
    });
  });

  group('settings (P19)', () {
    testWidgets('turning biometric unlock on asks for biometrics first', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/settings', store: signedInStore());
      await tester.tap(find.text('Biometric unlock'));
      await tester.pumpAndSettle();
      expect(app.fakes.biometrics.calls, 1);
      expect(app.container.read(lockControllerProvider).enabled, isTrue);
    });

    testWidgets('web hides biometric unlock and disables reminders', (tester) async {
      await pumpApp(tester, initialLocation: '/settings', store: signedInStore(), capabilities: web);
      expect(find.text('Biometric unlock'), findsNothing);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Inspection reminders')).onChanged, isNull);
    });

    testWidgets('macOS: Touch ID lock and reminders', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/settings', store: signedInStore(), capabilities: macos);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Inspection reminders')).onChanged, isNotNull);
      await tester.tap(find.text('Biometric unlock'));
      await tester.pumpAndSettle();
      expect(app.fakes.biometrics.calls, 1);
      expect(app.container.read(lockControllerProvider).enabled, isTrue);
    });

    testWidgets('Windows offers the lock (Windows Hello); Linux has neither lock nor reminders', (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/settings',
        store: signedInStore(),
        capabilities: const Capabilities(isWeb: false, platform: TargetPlatform.windows),
      );
      expect(find.text('Biometric unlock'), findsOneWidget);

      await pumpApp(tester, initialLocation: '/settings', store: signedInStore(), capabilities: linux);
      expect(find.text('Biometric unlock'), findsNothing);
      expect(find.text('Not available on Linux'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Inspection reminders')).onChanged, isNull);
    });
  });

  group('wizard platform features', () {
    InspectionDraft site({int lastStep = 1}) => InspectionDraft(
      siteId: 's-riverside-office',
      siteName: 'Riverside office, floor 4',
      siteLat: 52.24,
      siteLng: 21.03,
      lastStep: lastStep,
    );

    testWidgets('location check shows accuracy and distance; warns when far', (tester) async {
      final store = MemoryLocalStore()..drafts['new'] = site();
      final fakes = Fakes();
      await pumpApp(tester, initialLocation: '/inspections/new?step=1', store: signedInStore(), localStore: store, fakes: fakes);
      await tester.tap(find.text('Check location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Accuracy ±8 m'), findsOneWidget);
      expect(find.textContaining('m from the site'), findsOneWidget);
      expect(find.textContaining('more than 200 m'), findsNothing);

      fakes.location.fix = const LocationFix(LocationStatus.ok, lat: 52.30, lng: 21.03, accuracy: 20);
      await tester.tap(find.text('Update location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('km from the site'), findsOneWidget);
      expect(find.text('You seem to be more than 200 m from the site address.'), findsOneWidget);
    });

    testWidgets('step 4: camera, gallery and files on mobile', (tester) async {
      final ready = site(lastStep: 4).copyWith(
        type: () => 'Fire safety, annual',
        date: () => DateTime.now().add(const Duration(days: 1)),
        startMinutes: () => 600,
        duration: '60',
        answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
      );
      final store = MemoryLocalStore()..drafts['new'] = ready;
      final fakes = Fakes();
      fakes.media.nextFiles = [
        PickedFile(name: 'plan.pdf', bytes: tinyPng, mime: 'application/pdf'),
        PickedFile(name: 'notes.docx', bytes: tinyPng, mime: 'application/octet-stream'),
      ];
      await pumpApp(tester, initialLocation: '/inspections/new?step=4', store: signedInStore(), localStore: store, fakes: fakes);

      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      expect(find.text('Photos · 1'), findsOneWidget);
      expect(store.blobs, hasLength(1));
      expect(find.byType(Image), findsWidgets, reason: 'the stored bytes are shown, not a placeholder');

      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Photos · 2'), findsOneWidget);

      await tester.tap(find.text('Attach file'));
      await tester.pumpAndSettle();
      expect(find.text('Files · 1'), findsOneWidget);
      expect(find.text('notes.docx: use JPG, PNG, HEIC or PDF up to 20 MB.'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove photo 1'));
      await tester.pumpAndSettle();
      expect(find.text('Photos · 1'), findsOneWidget);
      expect(store.blobs, hasLength(2), reason: 'one photo and the PDF remain');
    });

    testWidgets('camera denied (iOS) shows the P12 banner and keeps the gallery', (tester) async {
      final store = MemoryLocalStore()
        ..drafts['new'] = site(lastStep: 4).copyWith(
          type: () => 'Fire safety, annual',
          date: () => DateTime.now().add(const Duration(days: 1)),
          startMinutes: () => 600,
          duration: '60',
          answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
        );
      final fakes = Fakes(capabilities: ios)..media.deniedCamera = true;
      await pumpApp(
        tester,
        initialLocation: '/inspections/new?step=4',
        store: signedInStore(),
        localStore: store,
        fakes: fakes,
        capabilities: ios,
      );
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      expect(find.text('Camera access is off. You can still choose photos from the gallery.'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      expect(fakes.permissions.settingsOpened, 1);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Take photo')).onPressed, isNull);

      // Camera turned on in Settings, then back to the app: the banner goes.
      fakes.media.deniedCamera = false;
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Camera access is off. You can still choose photos from the gallery.'), findsNothing);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Take photo')).onPressed, isNotNull);
    });

    testWidgets('camera still off after Settings keeps the banner', (tester) async {
      final store = MemoryLocalStore()
        ..drafts['new'] = site(lastStep: 4).copyWith(
          type: () => 'Fire safety, annual',
          date: () => DateTime.now().add(const Duration(days: 1)),
          startMinutes: () => 600,
          duration: '60',
          answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
        );
      final fakes = Fakes(capabilities: ios)..media.deniedCamera = true;
      fakes.permissions.states[AppPermission.camera] = PermissionState.permanentlyDenied;
      await pumpApp(
        tester,
        initialLocation: '/inspections/new?step=4',
        store: signedInStore(),
        localStore: store,
        fakes: fakes,
        capabilities: ios,
      );
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Camera access is off. You can still choose photos from the gallery.'), findsOneWidget);
    });

    testWidgets('a denied photo library says so, without blaming the camera', (tester) async {
      final store = MemoryLocalStore()
        ..drafts['new'] = site(lastStep: 4).copyWith(
          type: () => 'Fire safety, annual',
          date: () => DateTime.now().add(const Duration(days: 1)),
          startMinutes: () => 600,
          duration: '60',
          answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
        );
      final fakes = Fakes(capabilities: ios)..media.deniedGallery = true;
      await pumpApp(
        tester,
        initialLocation: '/inspections/new?step=4',
        store: signedInStore(),
        localStore: store,
        fakes: fakes,
        capabilities: ios,
      );
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Photo library access is off. You can turn it on in Settings.'), findsOneWidget);
      expect(find.text('Camera access is off. You can still choose photos from the gallery.'), findsNothing);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Take photo')).onPressed, isNotNull);
      await tester.tap(find.text('Open settings'));
      expect(fakes.permissions.settingsOpened, 1);
    });

    testWidgets("a checklist failure's Add photo with the camera off says so", (tester) async {
      final store = MemoryLocalStore()
        ..drafts['new'] = site(lastStep: 3).copyWith(
          type: () => 'Fire safety, annual',
          date: () => DateTime.now().add(const Duration(days: 1)),
          startMinutes: () => 600,
          duration: '60',
          answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass, 'c02': Answer.fail},
        );
      final fakes = Fakes(capabilities: ios)..media.deniedCamera = true;
      await pumpApp(
        tester,
        initialLocation: '/inspections/new?step=3',
        store: signedInStore(),
        localStore: store,
        fakes: fakes,
        capabilities: ios,
      );
      await tester.scrollUntilVisible(find.text('Add photo'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      expect(find.text('Camera access is off. You can still choose photos from the gallery.'), findsOneWidget);
    });

    testWidgets('web and desktop get a drop zone (D04)', (tester) async {
      final store = MemoryLocalStore()
        ..drafts['new'] = site(lastStep: 4).copyWith(
          type: () => 'Fire safety, annual',
          date: () => DateTime.now().add(const Duration(days: 1)),
          startMinutes: () => 600,
          duration: '60',
          answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
        );
      await pumpApp(
        tester,
        initialLocation: '/inspections/new?step=4',
        store: signedInStore(),
        localStore: store,
        capabilities: web,
        size: desktopSize,
      );
      expect(find.text('Drag files here, or paste an image'), findsOneWidget);
      expect(find.text('Use camera'), findsOneWidget);
    });

    testWidgets('desktop apps: drop zone and gallery, no camera or paste', (tester) async {
      final store = MemoryLocalStore()
        ..drafts['new'] = site(lastStep: 4).copyWith(
          type: () => 'Fire safety, annual',
          date: () => DateTime.now().add(const Duration(days: 1)),
          startMinutes: () => 600,
          duration: '60',
          answers: {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass},
        );
      await pumpApp(
        tester,
        initialLocation: '/inspections/new?step=4',
        store: signedInStore(),
        localStore: store,
        capabilities: macos,
        size: desktopSize,
      );
      expect(find.text('Drag files here'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Take photo'), findsNothing);
      expect(find.text('Use camera'), findsNothing);
    });

    testWidgets('answering a checklist item gives haptic feedback on mobile only', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final store = MemoryLocalStore()
        ..drafts['new'] = site(lastStep: 3).copyWith(
          type: () => 'Fire safety, annual',
          date: () => DateTime.now().add(const Duration(days: 1)),
          startMinutes: () => 600,
          duration: '60',
        );
      await pumpApp(tester, initialLocation: '/inspections/new?step=3', store: signedInStore(), localStore: store);
      final card = find.ancestor(of: find.text('Exit signs lit'), matching: find.byType(Card));
      await tester.ensureVisible(card);
      await tester.tap(find.descendant(of: card, matching: find.text('Pass')));
      await tester.pumpAndSettle();
      expect(calls, ['HapticFeedbackType.selectionClick']);
    });
  });

  test('detail tab enum is unchanged', () => expect(DetailTab.values, hasLength(4)));
}
