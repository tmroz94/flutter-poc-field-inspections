import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoActivityIndicator, CupertinoAlertDialog, CupertinoButton, CupertinoDatePicker;
import 'package:field_inspections/core/platform/capabilities.dart';
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

const ios = Capabilities(isWeb: false, platform: TargetPlatform.iOS);

/// Tall enough that the lazy list builds every row.
const _tall = Size(390, 1400);

void main() {
  group('Adaptive widgets (P23)', () {
    testWidgets('defaults to Material on Android and switches to Cupertino', (tester) async {
      await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/adaptive');
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.text('Cupertino'));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CupertinoButton), findsWidgets);
    });

    testWidgets('defaults to Cupertino on iOS; dialog is a CupertinoAlertDialog', (tester) async {
      await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/adaptive', capabilities: ios);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      await tester.ensureVisible(find.text('Show dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Deleted'), findsOneWidget);
    });

    testWidgets('Material dialog and date picker', (tester) async {
      await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/adaptive', size: _tall);
      await tester.ensureVisible(find.text('Show dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Delete photo?'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsOneWidget);

      await tester.tap(find.text('Cupertino'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.calendar_month));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });
  });

  group('Diagnostics (P24)', () {
    testWidgets('shows app, device, data and permission facts', (tester) async {
      await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/diagnostics', size: _tall);
      expect(find.text('0.1.0 (build 1)'), findsOneWidget);
      expect(find.text('Test device'), findsOneWidget);
      expect(find.text('390 × 1400 · Compact'), findsOneWidget);
      expect(find.text('Debug'), findsOneWidget);
      expect(find.text('Impeller'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.textContaining('% ('), findsOneWidget);
      expect(find.text('Granted'), findsNWidgets(4));
      expect(find.text('System settings'), findsOneWidget);
    });

    testWidgets('web: CanvasKit renderer, no system settings button', (tester) async {
      await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/diagnostics', size: _tall, capabilities: web);
      expect(find.text('CanvasKit (JavaScript)'), findsOneWidget);
      expect(find.text('SQLite WASM (IndexedDB)'), findsOneWidget);
      expect(find.text('System settings'), findsNothing);
    });

    testWidgets('copy report puts every row on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/diagnostics', size: _tall);
      await tester.tap(find.byTooltip('Copy report'));
      await tester.pumpAndSettle();
      expect(find.text('Report copied to clipboard'), findsOneWidget);
      expect(copied, contains('## Permissions'));
      expect(copied, contains('Platform: Test device'));
    });

    testWidgets('offline and denied notifications are shown as problems', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/diagnostics', size: _tall, online: false);
      expect(find.text('Offline'), findsOneWidget);
      app.fakes.notifications.granted = false;
      await tester.tap(find.text('Ask for notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Not granted'), findsOneWidget);
    });

    testWidgets('permission states are read again when the app resumes (after a prompt or Settings)', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/diagnostics', size: _tall);
      expect(find.text('Granted'), findsNWidgets(4));

      app.fakes.permissions.states[AppPermission.camera] = PermissionState.permanentlyDenied;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('Granted'), findsNWidgets(4)); // not yet: still inactive

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Denied'), findsOneWidget);
      expect(find.text('Granted'), findsNWidgets(3));
    });
  });
}
