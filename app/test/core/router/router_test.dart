import 'dart:async';

import 'package:field_inspections/core/platform/capabilities.dart';
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:field_inspections/core/router/routes.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/features/auth/auth_controller.dart';
import 'package:field_inspections/features/auth/auth_screens.dart';
import 'package:field_inspections/features/auth/lock_controller.dart';
import 'package:field_inspections/features/home/home_screen.dart';
import 'package:field_inspections/features/inspections/inspection_screens.dart';
import 'package:field_inspections/features/map/map_screen.dart';
import 'package:field_inspections/features/not_found/not_found_screen.dart';
import 'package:field_inspections/features/notifications/notifications_screen.dart';
import 'package:field_inspections/features/poc/adaptive_screen.dart';
import 'package:field_inspections/features/poc/diagnostics_screen.dart';
import 'package:field_inspections/features/poc/results_screens.dart';
import 'package:field_inspections/features/settings/appearance_screen.dart';
import 'package:field_inspections/features/settings/settings_screens.dart';
import 'package:field_inspections/features/wizard/submitted_screen.dart';
import 'package:field_inspections/features/wizard/wizard_controller.dart';
import 'package:field_inspections/features/wizard/wizard_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  group('signed in: every route opens its screen', () {
    final cases = <String, Type>{
      '/home': HomeScreen,
      '/notifications': NotificationsScreen,
      '/inspections?status=overdue': InspectionsScreen,
      '/inspections/filter?status=draft': FilterSheet,
      '/inspections/new?step=1': WizardScreen,
      '/inspections/INS-1042?tab=photos': InspectionDetailScreen,
      '/inspections/INS-1040/edit?step=2': WizardScreen,
      '/inspections/INS-1042/photos/p3': PhotoViewerScreen,
      '/inspections/INS-1042/submitted': SubmittedScreen,
      '/map?site=s-solar-farm': MapScreen,
      '/settings': SettingsScreen,
      '/settings/appearance': AppearanceScreen,
      '/settings/poc/results': ResultsScreen,
      '/settings/poc/results/back-navigation': ResultSheet,
      '/settings/poc/adaptive': AdaptiveWidgetsScreen,
      '/settings/poc/diagnostics': DiagnosticsScreen,
      '/settings/poc/deep-links': DeepLinksScreen,
    };
    for (final MapEntry(key: location, value: screen) in cases.entries) {
      testWidgets(location, (tester) async {
        final app = await pumpApp(tester, store: signedInStore());
        await app.go(location);
        expect(find.byType(screen), findsOneWidget);
        expect(app.location, location);
      });
    }
  });

  testWidgets('every route-table example opens at its own path (no 404, no redirect)', (tester) async {
    final app = await pumpApp(tester, store: signedInStore());
    for (final r in RouteTable.all.where((r) => !r.public && r.pattern != Routes.unlock)) {
      await app.go(r.example);
      expect(find.byType(NotFoundScreen), findsNothing, reason: r.example);
      expect(app.router.state.uri.path, Uri.parse(r.example).path, reason: r.example);
    }
  });

  testWidgets('route parameters reach the screen', (tester) async {
    final app = await pumpApp(tester, store: signedInStore());
    await app.go('/inspections/INS-1038?tab=history');
    final detail = tester.widget<InspectionDetailScreen>(find.byType(InspectionDetailScreen));
    expect(detail.id, 'INS-1038');
    expect(detail.tab, DetailTab.history);

    await app.go('/inspections/INS-1038?tab=bogus');
    expect(tester.widget<InspectionDetailScreen>(find.byType(InspectionDetailScreen)).tab, DetailTab.overview);

    await app.go('/inspections?status=overdue,draft&q=sub');
    expect(tester.widget<InspectionsScreen>(find.byType(InspectionsScreen)).query, {'status': 'overdue,draft', 'q': 'sub'});
  });

  group('wizard step guard', () {
    for (final bad in ['/inspections/new', '/inspections/new?step=0', '/inspections/new?step=9', '/inspections/new?step=x']) {
      testWidgets('$bad starts at step 1', (tester) async {
        final app = await pumpApp(tester, store: signedInStore());
        await app.go(bad);
        expect(tester.widget<WizardScreen>(find.byType(WizardScreen)).step, 1);
        expect(app.location, '/inspections/new?step=1');
      });
    }
    testWidgets('edit keeps the inspection id', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      await app.go('/inspections/INS-1040/edit');
      final w = tester.widget<WizardScreen>(find.byType(WizardScreen));
      expect((w.inspectionId, w.step), ('INS-1040', 1));
    });
  });

  group('auth guard end to end', () {
    testWidgets('cold-start deep link while signed out → sign-in → lands on the target', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042?tab=checklist');
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(app.location, '/sign-in?from=%2Finspections%2FINS-1042%3Ftab%3Dchecklist');

      await tester.tap(find.text('Use demo account'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1042?tab=checklist');
      expect(find.byType(InspectionDetailScreen), findsOneWidget);
    });

    testWidgets('cold-start deep link with a stored session opens directly', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/settings/poc/diagnostics', store: signedInStore());
      expect(app.location, '/settings/poc/diagnostics');
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
    });

    testWidgets('signed-in users cannot open sign-in or sign-up', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      await app.go('/sign-up');
      expect(app.location, '/home');
      await app.go('/sign-in');
      expect(app.location, '/home');
    });

    testWidgets('sign-out from anywhere goes to sign-in', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      await app.go('/settings');
      await tester.scrollUntilVisible(find.text('Sign out'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'), warnIfMissed: true);
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('public pages work signed out', (tester) async {
      final app = await pumpApp(tester);
      await app.go('/sign-up');
      expect(find.byType(SignUpScreen), findsOneWidget);
      await app.go('/forgot-password');
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });
  });

  group('browser history (web)', () {
    testWidgets('sign-in replaces its own history entry: no back-button trap', (tester) async {
      final reports = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, (call) async {
        if (call.method == 'routeInformationUpdated') reports.add(call.arguments as Map<Object?, Object?>);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, null));

      await pumpApp(tester, initialLocation: '/map?site=s-1');
      expect(reports.last['uri'], '/sign-in?from=%2Fmap%3Fsite%3Ds-1');
      await tester.tap(find.text('Use demo account'));
      await tester.pumpAndSettle();
      expect(reports.last['uri'], '/map?site=s-1');
      expect(reports.last['replace'], isTrue, reason: 'the /sign-in entry is replaced, not stacked under the target');
    });

    testWidgets('a platform link that arrives during the splash is not lost (Android cold start)', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), authLatency: const Duration(milliseconds: 500), settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.binding.handlePushRoute('fieldinspections://app/inspections/INS-1038?tab=history');
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1038?tab=history');
      expect(find.byType(InspectionDetailScreen), findsOneWidget);
    });

    testWidgets('a cold start never reports the splash URL', (tester) async {
      final uris = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, (call) async {
        if (call.method == 'routeInformationUpdated') uris.add((call.arguments as Map<Object?, Object?>)['uri']);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, null));
      await pumpApp(tester, initialLocation: '/inspections/new?step=1', store: signedInStore());
      expect(uris.where((u) => '$u'.startsWith('/splash')), isEmpty);
      expect(uris.last, '/inspections/new?step=1');
    });
  });

  group('biometric lock guard', () {
    testWidgets('cold start with lock on (Android) goes to unlock, then to the target', (tester) async {
      final fakes = Fakes()..biometrics.ok = false;
      final app = await pumpApp(tester, initialLocation: '/notifications', store: signedInStore(biometricLock: true), fakes: fakes);
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(app.location, '/unlock?from=%2Fnotifications');
      expect(find.textContaining('Not recognised'), findsOneWidget, reason: 'the screen prompted on open');

      fakes.biometrics.ok = true;
      await tester.tap(find.byTooltip('Unlock with biometrics'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(fakes.biometrics.calls, 2);
    });

    testWidgets('locks after 5 minutes in the background', (tester) async {
      final fakes = Fakes();
      final app = await pumpApp(tester, store: signedInStore(biometricLock: true), fakes: fakes);
      expect(app.location, '/home', reason: 'biometrics passed on open');
      await app.go('/map');
      fakes.biometrics.ok = false;

      final lock = app.container.read(lockControllerProvider.notifier);
      var now = DateTime(2026, 10, 24, 12);
      lock.clock = () => now;
      lock.onHidden();
      now = now.add(const Duration(minutes: 4));
      lock.onShown();
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsOneWidget, reason: 'under the timeout');

      lock.onHidden();
      now = now.add(const Duration(minutes: 5));
      lock.onShown();
      await tester.pumpAndSettle();
      expect(app.location, '/unlock?from=%2Fmap');
    });

    testWidgets('locking in the wizard with a draft goes to unlock without asking, and keeps the draft', (tester) async {
      final fakes = Fakes();
      final app = await pumpApp(tester, store: signedInStore(biometricLock: true), fakes: fakes);
      await app.go('/inspections/new?step=1');
      app.container.read(wizardControllerProvider('new').notifier).update((d) => d.copyWith(siteName: 'Riverside'));
      await tester.pumpAndSettle();
      fakes.biometrics.ok = false;

      final lock = app.container.read(lockControllerProvider.notifier);
      var now = DateTime(2026, 10, 24, 12);
      lock.clock = () => now;
      lock.onHidden();
      now = now.add(const Duration(minutes: 6));
      lock.onShown();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing, reason: 'no "Leave?" dialog whose Stay could cancel the lock');
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(find.byType(WizardScreen), findsNothing);
      expect(app.location, startsWith('/unlock'));
      expect((await app.container.read(localStoreProvider).draft('new'))?.siteName, 'Riverside');
    });

    testWidgets('a rejected session in the wizard goes to sign-in without asking', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      await app.go('/inspections/new?step=1');
      app.container.read(wizardControllerProvider('new').notifier).update((d) => d.copyWith(siteName: 'Riverside'));
      await tester.pumpAndSettle();

      await app.container.read(authControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    for (final (platform, kind, prompt) in [
      (TargetPlatform.iOS, BiometricKind.face, 'Use Face ID to unlock'),
      (TargetPlatform.iOS, BiometricKind.fingerprint, 'Use Touch ID to unlock'),
      (TargetPlatform.android, BiometricKind.face, 'Use your face to unlock'),
      (TargetPlatform.android, BiometricKind.fingerprint, 'Use your fingerprint to unlock'),
      (TargetPlatform.android, BiometricKind.other, 'Use your fingerprint or face to unlock'),
    ]) {
      testWidgets('the unlock screen names what the device uses: ${platform.name}, ${kind.name}', (tester) async {
        final capabilities = Capabilities(isWeb: false, platform: platform);
        final fakes = Fakes(capabilities: capabilities)
          ..biometrics.enrolled = kind
          ..biometrics.hold = Completer<void>();
        await pumpApp(tester, store: signedInStore(biometricLock: true), fakes: fakes, capabilities: capabilities);
        // The system prompt is open; the screen says what it waits for.
        expect(find.byType(UnlockScreen), findsOneWidget);
        expect(find.text(prompt), findsOneWidget);
        expect(find.byIcon(kind == BiometricKind.face ? Symbols.face : Symbols.fingerprint), findsOneWidget);
        fakes.biometrics.hold!.complete();
        await tester.pumpAndSettle();
      });
    }

    testWidgets('web never locks, even with the setting stored', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/map', store: signedInStore(biometricLock: true), capabilities: web);
      expect(app.location, '/map');
      expect(app.container.read(lockControllerProvider).enabled, isFalse);
    });
  });

  group('not found', () {
    testWidgets('unknown path shows the 404 with the path, signed in or out', (tester) async {
      final app = await pumpApp(tester);
      await app.go('/inspections/INS-9999/report');
      expect(find.byType(NotFoundScreen), findsOneWidget);
      expect(find.text('/inspections/INS-9999/report'), findsOneWidget);
    });
  });

  group('back stack', () {
    testWidgets('deep link to a detail on a phone pops back to the list', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042', store: signedInStore());
      expect(find.byType(InspectionDetailScreen), findsOneWidget);
      expect(app.router.canPop(), isTrue);
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.location, '/inspections');
      expect(find.byType(InspectionsScreen), findsOneWidget);
    });

    testWidgets('a direct link with a foreign query key gets a clean list URL', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      await app.go('/inspections?tab=photos&status=draft');
      expect(app.location, '/inspections?status=draft');
    });

    testWidgets('popping a pushed detail returns to the list URL with its filters', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      await app.go('/inspections?status=overdue');
      unawaited(app.router.push('/inspections/INS-1038?tab=photos'));
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.location, '/inspections?status=overdue');
    });

    testWidgets('the photo viewer covers the shell and pops to the detail', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042/photos/p3', store: signedInStore());
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1042');
    });

    testWidgets('the filter sheet opens over the list and closes back to it', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/filter', store: signedInStore());
      expect(find.byType(FilterSheet), findsOneWidget);
      expect(find.byType(InspectionsScreen), findsOneWidget, reason: 'list stays underneath');
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.location, '/inspections');
      expect(find.byType(FilterSheet), findsNothing);
    });

    testWidgets('each tab keeps its own stack', (tester) async {
      final app = await pumpApp(tester, store: signedInStore());
      await app.go('/inspections/INS-1042');
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(app.location, '/settings');
      await tester.tap(find.text('Inspections'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections/INS-1042');
      // Re-selecting the current tab pops to its root.
      await tester.tap(find.text('Inspections'));
      await tester.pumpAndSettle();
      expect(app.location, '/inspections');
    });
  });

  group('adaptive navigation', () {
    testWidgets('phone: navigation bar', (tester) async {
      await pumpApp(tester, store: signedInStore());
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('tablet: collapsed rail with labels', (tester) async {
      await pumpApp(tester, store: signedInStore(), size: tabletSize);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('desktop: extended rail with PoC results link', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), size: desktopSize);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isTrue);
      await tester.tap(find.text('PoC results'));
      await tester.pumpAndSettle();
      expect(app.location, '/settings/poc/results');
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 4);
    });

    testWidgets('resizing switches bar → rail live', (tester) async {
      await pumpApp(tester, store: signedInStore());
      expect(find.byType(NavigationBar), findsOneWidget);
      tester.view.physicalSize = desktopSize;
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });
}
