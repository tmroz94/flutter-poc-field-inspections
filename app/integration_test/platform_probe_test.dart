// Asks the platform plugins on this device what they can do, without anything
// that shows a system prompt, and loads real map tiles. Run it on any target
// (most useful on the desktop apps, where the other flows use fakes):
//   fvm flutter test integration_test/platform_probe_test.dart -d macos
// Each check prints a PROBE line; failures mean a plugin is missing or broken,
// not that a permission is off.
import 'package:field_inspections/core/platform/capabilities.dart';
import 'package:field_inspections/core/platform/device_summary.dart';
import 'package:field_inspections/core/platform/notification_service.dart';
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

final _caps = Capabilities.current();

void _probe(String what, Object? result) => debugPrint('PROBE $what: $result');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearDeviceData);

  testWidgets('device and app info', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final summary = await container.read(deviceSummaryProvider.future);
    _probe('device', summary.device);
    _probe('version', '${summary.version} (${summary.build})');
    expect(summary.device, isNot('Unknown'));
  });

  testWidgets('notifications: the plugin starts and reports a permission state', (tester) async {
    final n = NotificationService();
    await n.init();
    final state = await n.permission();
    _probe('notifications', state.name);
    expect(state, isNot(PermissionState.unsupported), reason: 'the notification plugin failed to start');
  });

  testWidgets('location: service and permission state (no prompt)', (tester) async {
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      _probe('location', 'service ${service ? 'on' : 'off'}, permission ${permission.name}');
    } on MissingPluginException {
      _probe('location', 'no plugin on this platform');
      expect(_caps.platform, TargetPlatform.linux, reason: 'only Linux lacks a geolocator plugin');
    }
  });

  testWidgets('biometrics: what the lock could use (no prompt)', (tester) async {
    if (!_caps.biometricLock) {
      _probe('biometrics', 'not offered on this platform');
      return;
    }
    final auth = LocalAuthentication();
    final supported = await auth.isDeviceSupported();
    final kinds = await auth.getAvailableBiometrics();
    _probe('biometrics', 'device supported: $supported, enrolled: ${kinds.map((k) => k.name).join(', ')}');
    expect(await BiometricService().available(), supported);
  });

  testWidgets('map tiles load over the network', (tester) async {
    final c = await launch(tester, initialLocation: '/map');
    await signIn(tester);
    bool loaded() =>
        find.byType(RawImage).evaluate().where((e) => (e.widget as RawImage).image != null).isNotEmpty &&
        find.byType(FlutterMap).evaluate().isNotEmpty;
    await waitFor(tester, loaded, timeout: const Duration(seconds: 30), reason: 'map tiles from tile.openstreetmap.org');
    final tiles = find.byType(RawImage).evaluate().where((e) => (e.widget as RawImage).image != null).length;
    _probe('map tiles', '$tiles drawn');
    await quit(tester, c);
  });
}
