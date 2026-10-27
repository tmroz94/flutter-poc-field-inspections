import 'package:field_inspections/app.dart';
import 'package:field_inspections/core/router/router.dart';
import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/data/api/backend_config.dart';
import 'package:field_inspections/data/local/app_database.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A clean device for each test: preferences, and the drafts, outbox and files
/// in SQLite (an earlier test or a crashed run can leave them behind).
Future<void> clearDeviceData() async {
  await SharedPreferencesAsync().clear();
  final db = AppDatabase();
  try {
    await DriftLocalStore(db).clearAll();
  } finally {
    await db.close();
  }
}

/// Starts the app the way `main` does (real shared_preferences and SQLite),
/// minus notifications and the backend probe. Returns the provider container
/// so tests can seed storage or wait on state.
Future<ProviderContainer> launch(
  WidgetTester tester, {
  String initialLocation = '/home',
  BackendConfig backend = const BackendConfig(mode: BackendMode.fake, baseUrl: ''),
  List<Override> overrides = const [],
}) async {
  final store = await PrefsStore.create();
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      backendConfigProvider.overrideWithValue(backend),
      initialLocationProvider.overrideWithValue(initialLocation),
      ...overrides,
    ],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const FieldInspectionsApp()));
  await tester.pumpAndSettle();
  return container;
}

/// Disposes the app (closing the database), like quitting it.
Future<void> quit(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  container.dispose();
}

/// Signs in straight away with the fixture account.
Future<void> signIn(WidgetTester tester) async {
  await tester.tap(find.text('Use demo account'));
  await waitFor(tester, () => find.text('Use demo account').evaluate().isEmpty, reason: 'sign-in to finish');
  await tester.pumpAndSettle();
}

/// Opens the wizard with the New inspection button. Its label shows on Home
/// under 600 and on the extended rail from 1200; in between the rail button
/// is an icon with the label as its tooltip (CI desktop runners land there).
Future<void> tapNewInspection(WidgetTester tester) async {
  final label = find.text('New inspection');
  await tester.tap(label.evaluate().isNotEmpty ? label : find.byTooltip('New inspection'));
  await tester.pumpAndSettle();
}

/// Pumps for a while without requiring the tree to settle (spinners, network).
Future<void> settle(WidgetTester tester, [Duration d = const Duration(milliseconds: 500)]) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps until [condition] holds, failing after [timeout].
Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for ${reason ?? 'condition'}');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Prints the visible text on screen (for diagnosing failures on a device).
void dumpTexts(String label) {
  final texts = find.byType(Text).hitTestable().evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
  debugPrint('SCREEN $label: ${texts.join(' | ')}');
}
