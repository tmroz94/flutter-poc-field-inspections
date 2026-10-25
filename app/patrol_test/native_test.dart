// Native UI that integration_test can't reach, driven with Patrol: permission
// dialogs, the system camera and photo picker, the share sheet and the
// biometric/device-credential prompt. Run through the host helper, which
// prepares the device (a test photo, a screen-lock PIN) and cleans up:
//   fvm dart tool/android_device_tests.dart --patrol
import 'package:field_inspections/core/router/router.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/features/auth/lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/support.dart';

/// The PIN the host helper sets as the emulator's screen lock (and removes after).
const testPin = String.fromEnvironment('TEST_PIN', defaultValue: '1111');

final _allPass = {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id'] as String: Answer.pass};

/// A draft that is complete up to the photos step.
InspectionDraft _atPhotos() => InspectionDraft(
  siteId: 's-riverside-office',
  siteName: 'Riverside office, floor 4',
  siteAddress: 'ul. Wybrzeże 2, Warsaw',
  siteLat: 52.24,
  siteLng: 21.03,
  type: 'Fire safety, annual',
  date: DateTime.now().add(const Duration(days: 1)),
  startMinutes: 13 * 60,
  duration: '90',
  answers: _allPass,
  lastStep: 4,
);

/// Answers the system's device-credential prompt (no fingerprint is enrolled on
/// the emulator, so local_auth falls back to the screen-lock PIN). Android 17
/// draws it as a PIN pad: tap each digit, then Enter.
Future<void> enterDevicePin(PatrolIntegrationTester $) async {
  const systemUi = 'com.android.systemui';
  await $.platform.android.waitUntilVisible(
    const AndroidSelector(resourceName: '$systemUi:id/key_enter'),
    timeout: const Duration(seconds: 10),
  );
  for (final digit in testPin.split('')) {
    await $.platform.android.tap(AndroidSelector(text: digit, applicationPackage: systemUi));
  }
  await $.platform.android.tap(const AndroidSelector(resourceName: '$systemUi:id/key_enter'));
}

void main() {
  patrolTest('location permission: Deny explains the check is optional', ($) async {
    final c = await launch($.tester);
    await signIn($.tester);
    await c.read(localStoreProvider).saveDraft('new', _atPhotos().copyWith(lastStep: 1));
    c.read(routerProvider).go('/inspections/new?step=1');
    await $.pumpAndSettle();

    await $('Check location').tap();
    expect(await $.platform.mobile.isPermissionDialogVisible(timeout: const Duration(seconds: 10)), isTrue);
    await $.platform.mobile.denyPermission();
    await waitFor($.tester, () => find.text('Location permission was not given. The check is optional.').evaluate().isNotEmpty);
    await quit($.tester, c);
  });

  patrolTest('camera: a photo from the system camera app lands in the grid', ($) async {
    final c = await launch($.tester);
    await signIn($.tester);
    await c.read(localStoreProvider).saveDraft('new', _atPhotos());
    c.read(routerProvider).go('/inspections/new?step=4');
    await $.pumpAndSettle();

    await $('Take photo').tap();
    await $.platform.android.takeCameraPhoto(timeout: const Duration(seconds: 20));
    await waitFor($.tester, () => find.text('Photos · 1').evaluate().isNotEmpty, reason: 'the camera photo in the draft');
    await quit($.tester, c);
  });

  patrolTest('gallery: a photo picked in the system photo picker lands in the grid', ($) async {
    final c = await launch($.tester);
    await signIn($.tester);
    await c.read(localStoreProvider).saveDraft('new', _atPhotos());
    c.read(routerProvider).go('/inspections/new?step=4');
    await $.pumpAndSettle();

    await $('Gallery').tap();
    await $.platform.android.pickImageFromGallery(index: 0, timeout: const Duration(seconds: 20));
    await waitFor($.tester, () => find.text('Photos · 1').evaluate().isNotEmpty, reason: 'the gallery photo in the draft');
    await quit($.tester, c);
  });

  patrolTest('export PDF opens the system share sheet', ($) async {
    final c = await launch($.tester, initialLocation: '/inspections/INS-1042');
    await signIn($.tester);
    await $('Export PDF').tap();
    await $.platform.android.waitUntilVisible(
      const AndroidSelector(textContains: 'inspection-INS-1042'),
      timeout: const Duration(seconds: 20),
    );
    await $.platform.android.pressBack();
    await $.pumpAndSettle();
    expect($('Export PDF'), findsOneWidget, reason: 'back in the app after closing the sheet');
    await quit($.tester, c);
  });

  patrolTest('biometric unlock: turning it on and unlocking go through the system prompt', ($) async {
    final c = await launch($.tester, initialLocation: '/settings');
    await signIn($.tester);

    await $('Biometric unlock').tap();
    await enterDevicePin($);
    await waitFor($.tester, () => c.read(lockControllerProvider).enabled, reason: 'the setting to turn on');

    // Five minutes in the background lock the app: move the lock's clock on,
    // leave the app and come back.
    final lock = c.read(lockControllerProvider.notifier);
    await $.platform.mobile.pressHome();
    // Move the clock only once the app is hidden (inactive comes first).
    await waitFor(
      $.tester,
      () => const [AppLifecycleState.hidden, AppLifecycleState.paused].contains(WidgetsBinding.instance.lifecycleState),
      reason: 'the app to be hidden',
    );
    lock.clock = () => DateTime.now().add(LockController.timeout + const Duration(minutes: 1));
    await $.platform.mobile.openApp();
    await waitFor($.tester, () => find.byTooltip('Unlock with biometrics').evaluate().isNotEmpty, reason: 'the unlock screen');

    await $.tester.tap(find.byTooltip('Unlock with biometrics'));
    await $.tester.pump();
    await enterDevicePin($);
    await waitFor($.tester, () => !c.read(lockControllerProvider).locked, reason: 'unlock');
    await $.pumpAndSettle();
    expect($('Biometric unlock'), findsOneWidget, reason: 'back on Settings');
    await quit($.tester, c);
  });
  // Last on purpose: clearing app data before the next test resets the
  // granted permission, and Android then kills the app's processes, which
  // crashed the following test's instrumentation.
  patrolTest('location permission: Allow gets past the prompt', ($) async {
    final c = await launch($.tester);
    await signIn($.tester);
    await c.read(localStoreProvider).saveDraft('new', _atPhotos().copyWith(lastStep: 1));
    c.read(routerProvider).go('/inspections/new?step=1');
    await $.pumpAndSettle();

    await $('Check location').tap();
    expect(await $.platform.mobile.isPermissionDialogVisible(timeout: const Duration(seconds: 10)), isTrue);
    await $.platform.mobile.grantPermissionWhenInUse();
    // Whatever the emulator's GPS returns, the permission problem is gone.
    await waitFor($.tester, () => find.byType(CircularProgressIndicator).evaluate().isEmpty, timeout: const Duration(seconds: 30));
    expect(find.textContaining('permission was not given'), findsNothing);
    expect(find.textContaining('blocked for this app'), findsNothing);
    await quit($.tester, c);
  });
}
