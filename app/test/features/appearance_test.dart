import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/core/theme/app_theme.dart';
import 'package:field_inspections/core/theme/theme_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  group('stored settings', () {
    ThemeSettings read(String raw) {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryStore({'theme_settings': raw})),
        ],
      );
      addTearDown(c.dispose);
      return c.read(themeSettingsProvider);
    }

    test('unreadable values fall back to the defaults instead of failing the app', () {
      expect(read('[1, 2]'), const ThemeSettings());
      expect(read('not json'), const ThemeSettings());
      expect(read('{"textScale": "big", "mode": "dark"}').textScale, isNull);
      expect(read('{"textScale": "big", "mode": "dark"}').mode, ThemeMode.dark);
    });
  });

  testWidgets('contrast can go back to following the system', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/settings/appearance', store: signedInStore());
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    expect(app.container.read(themeSettingsProvider).contrast, AppContrast.high);
    // Theme and contrast both offer "System"; the second one is contrast.
    await tester.tap(find.text('System').at(1));
    await tester.pumpAndSettle();
    expect(app.container.read(themeSettingsProvider).contrast, isNull);
  });

  testWidgets('the text size slider saves when released, not on every step', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/settings/appearance', store: signedInStore());
    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(app.container.read(themeSettingsProvider).textScale, isNull, reason: 'not saved while dragging');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(app.container.read(themeSettingsProvider).textScale, isNotNull);
  });
}
