import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// Key screens checked against Flutter's accessibility guidelines:
/// 48 dp (Android) / 44 pt (iOS) tap targets, labelled tap targets and
/// WCAG text contrast.
const _screens = [
  '/home',
  '/inspections',
  '/inspections/filter',
  '/inspections/INS-1042',
  '/inspections/INS-1042?tab=checklist',
  '/inspections/new?step=1',
  '/inspections/new?step=2',
  '/notifications',
  '/settings',
  '/settings/appearance',
  '/settings/poc/results',
  '/settings/poc/results/hero',
  '/settings/poc/adaptive',
  '/settings/poc/diagnostics',
  '/settings/poc/deep-links',
];

void main() {
  for (final location in _screens) {
    testWidgets('a11y guidelines: $location', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, store: signedInStore(), initialLocation: location);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  // WCAG 1.4.4: text resizes to 200% without loss of content. Overflow errors
  // would surface as exceptions.
  for (final location in _screens) {
    testWidgets('200% text: $location', (tester) async {
      await pumpApp(tester, store: signedInStore(), initialLocation: location, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a11y guidelines: sign in', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, initialLocation: '/sign-in');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
