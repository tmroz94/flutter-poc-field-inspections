import 'dart:convert';

import 'package:field_inspections/app.dart';
import 'package:field_inspections/core/platform/capabilities.dart';
import 'package:field_inspections/core/platform/notification_service.dart';
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:field_inspections/core/router/router.dart';
import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/providers.dart';
import 'package:field_inspections/data/repositories/inspections_repository.dart';
import 'package:field_inspections/data/sync/sync_service.dart';
import 'package:field_inspections/features/auth/auth_repository.dart';
import 'package:field_inspections/features/map/map_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart';

import 'fakes.dart';

/// Phone, tablet landscape and desktop sizes from the design boards.
const phoneSize = Size(390, 844);
const tabletSize = Size(1194, 834);
const desktopSize = Size(1440, 1000);

const android = Capabilities(isWeb: false, platform: TargetPlatform.android);
const web = Capabilities(isWeb: true, platform: TargetPlatform.android);

/// A stored session for the demo user; the mock backend accepts its token.
Map<String, String> signedInStore({bool biometricLock = false}) => {
  'session': jsonEncode({
    'token': 'mock-u-anna-1',
    'user': {'id': 'u-anna', 'name': 'Anna Nowak', 'email': demoEmail, 'initials': 'AN'},
  }),
  if (biometricLock) 'biometric_lock': 'true',
};

class TestApp {
  TestApp(this.tester, this.container, this.fakes);

  final WidgetTester tester;
  final ProviderContainer container;
  final Fakes fakes;

  GoRouter get router => container.read(routerProvider);

  /// Current location including imperative push/replace (what the browser shows).
  String get location => router.state.uri.toString();

  Future<void> go(String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }
}

/// Pumps the full app with an in-memory store and a zero-latency fake backend.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  String initialLocation = '/home',
  Map<String, String>? store,
  Size size = phoneSize,
  Capabilities capabilities = android,
  InspectionsRepository Function(MockDatabase db)? inspections,
  double? textScale,
  LocalStore? localStore,
  bool online = true,
  Duration authLatency = Duration.zero,
  bool settle = true,
  Fakes? fakes,
}) async {
  final f = fakes ?? Fakes(capabilities: capabilities);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (textScale != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryStore(store)),
      authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(ref.watch(mockDatabaseProvider), latency: authLatency)),
      inspectionsRepositoryProvider.overrideWith(
        (ref) => (inspections ?? (db) => FakeInspectionsRepository(db, latency: Duration.zero))(ref.watch(mockDatabaseProvider)),
      ),
      capabilitiesProvider.overrideWithValue(capabilities),
      initialLocationProvider.overrideWithValue(initialLocation),
      localStoreProvider.overrideWithValue(localStore ?? MemoryLocalStore()),
      connectivityProvider.overrideWith((ref) => Stream.value(online)),
      mapTilesEnabledProvider.overrideWithValue(false),
      biometricServiceProvider.overrideWithValue(f.biometrics),
      locationServiceProvider.overrideWithValue(f.location),
      mediaServiceProvider.overrideWithValue(f.media),
      shareServiceProvider.overrideWithValue(f.share),
      launcherServiceProvider.overrideWithValue(f.launcher),
      permissionServiceProvider.overrideWithValue(f.permissions),
      notificationServiceProvider.overrideWithValue(f.notifications),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const FieldInspectionsApp()));
  if (settle) await tester.pumpAndSettle();
  return TestApp(tester, container, f);
}
