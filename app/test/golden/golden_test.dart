@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:field_inspections/app.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// Goldens are rendered on Windows (the reference images live in
/// test/golden/goldens). Font rasterisation differs per OS, so other hosts skip
/// them; regenerate with `fvm flutter test --update-goldens test/golden`.
final _skip = !Platform.isWindows;

/// A fixed Tuesday morning so dates, greetings and "overdue" labels are stable.
final _now = DateTime(2026, 10, 20, 9, 30);

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT']!;
  final fonts = '$sdk/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final w in ['regular', 'medium', 'bold', 'light', 'italic']) {
    roboto.addFont(File('$fonts/roboto-$w.ttf').readAsBytes().then(ByteData.sublistView));
  }
  await roboto.load();
  // The SDK ships no monospace font; Roboto stands in so IDs aren't drawn as boxes.
  final mono = FontLoader('monospace')..addFont(File('$fonts/roboto-regular.ttf').readAsBytes().then(ByteData.sublistView));
  await mono.load();
  final icons = FontLoader('MaterialIcons')..addFont(File('$fonts/materialicons-regular.otf').readAsBytes().then(ByteData.sublistView));
  await icons.load();
  final symbols = FontLoader('packages/material_symbols_icons/MaterialSymbolsOutlined')
    ..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsOutlined.ttf'));
  await symbols.load();
}

enum _Look { light, dark, high }

Map<String, String> _store(_Look look, {bool signedIn = true}) => {
  if (signedIn) ...signedInStore(),
  'theme_settings': jsonEncode({'mode': look == _Look.dark ? 'dark' : 'light', 'contrast': look == _Look.high ? 'high' : 'standard'}),
};

/// flutter_test draws elevation as a black outline by default; goldens should
/// show the real shadows. The flag must be restored before the test ends.
Future<void> _withShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  setUpAll(_loadFonts);

  const phoneScreens = {
    'sign_in': '/sign-in',
    'home': '/home',
    'inspections': '/inspections',
    'detail': '/inspections/INS-1042',
    // Step 2 before step 1 is valid: the guard sends the user back with a notice.
    'wizard_guard': '/inspections/new?step=2',
    'settings': '/settings',
    'results': '/settings/poc/results',
  };
  for (final MapEntry(key: name, value: location) in phoneScreens.entries) {
    for (final look in _Look.values) {
      testWidgets('phone $name ${look.name}', skip: _skip, (tester) async {
        await _withShadows(() async {
          await pumpApp(
            tester,
            initialLocation: location,
            store: _store(look, signedIn: name != 'sign_in'),
            now: _now,
          );
          await expectLater(find.byType(FieldInspectionsApp), matchesGoldenFile('goldens/phone_${name}_${look.name}.png'));
        });
      });
    }
  }

  const desktopScreens = {'sign_in': '/sign-in', 'home': '/home', 'inspections': '/inspections', 'detail': '/inspections/INS-1042'};
  for (final MapEntry(key: name, value: location) in desktopScreens.entries) {
    for (final look in [_Look.light, _Look.dark]) {
      testWidgets('desktop $name ${look.name}', skip: _skip, (tester) async {
        await _withShadows(() async {
          await pumpApp(
            tester,
            initialLocation: location,
            store: _store(look, signedIn: name != 'sign_in'),
            now: _now,
            size: desktopSize,
            capabilities: web,
          );
          await expectLater(find.byType(FieldInspectionsApp), matchesGoldenFile('goldens/desktop_${name}_${look.name}.png'));
        });
      });
    }
  }
}
