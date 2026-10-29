import 'dart:math' as math;

import 'package:field_inspections/core/theme/color_schemes.dart';
import 'package:field_inspections/core/validation/form_support.dart';
import 'package:field_inspections/core/widgets/inspection_widgets.dart';
import 'package:field_inspections/features/auth/auth_screens.dart';
import 'package:field_inspections/l10n/l10n.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

/// A phone on its side: wide enough for the rail and two-pane layouts, but
/// only ~390 dp tall.
const _landscapePhone = Size(844, 390);

double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('short windows scroll instead of overflowing', () {
    testWidgets('the rail with the keyboard up', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections', store: signedInStore(), size: _landscapePhone);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the unlock screen, keeping "Use password instead" reachable', (tester) async {
      final fakes = Fakes()..biometrics.ok = false;
      await pumpApp(tester, store: signedInStore(biometricLock: true), fakes: fakes, size: _landscapePhone);
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Use password instead'), 100);
      expect(find.text('Use password instead').hitTestable(), findsOneWidget);
    });

    testWidgets('the wizard with its step list', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections/new?step=1', store: signedInStore(), size: _landscapePhone);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the submitted screen', (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/inspections/INS-1042/submitted?site=Warehouse',
        store: signedInStore(),
        size: _landscapePhone,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Back to inspections'), 100);
      expect(find.text('Back to inspections').hitTestable(), findsOneWidget);
    });

    testWidgets('the 404 page at 200% text', (tester) async {
      await pumpApp(tester, initialLocation: '/no-such-page', store: signedInStore(), size: _landscapePhone, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('segmented choices become chips at large text (decision 64)', () {
    testWidgets('filter sheet: Due', (tester) async {
      await pumpApp(tester, initialLocation: '/inspections/filter', store: signedInStore(), textScale: 2);
      expect(find.widgetWithText(ChoiceChip, 'Week'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wizard: priority and checklist answers', (tester) async {
      final app = await pumpApp(tester, initialLocation: '/inspections/INS-1042/edit?step=2', store: signedInStore(), textScale: 2);
      expect(find.widgetWithText(ChoiceChip, 'High'), findsOneWidget);
      await app.go('/inspections/INS-1042/edit?step=3');
      expect(find.widgetWithText(ChoiceChip, 'Pass'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets("the strong offline banner's Retry is readable in every scheme", (tester) async {
    const schemes = {
      'light': AppColorSchemes.light,
      'light medium': AppColorSchemes.lightMediumContrast,
      'light high': AppColorSchemes.lightHighContrast,
      'dark': AppColorSchemes.dark,
      'dark medium': AppColorSchemes.darkMediumContrast,
      'dark high': AppColorSchemes.darkHighContrast,
    };
    for (final MapEntry(key: name, value: scheme) in schemes.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          themeAnimationDuration: Duration.zero,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: OfflineBanner(onRetry: () {}, strong: true, message: 'Offline'),
          ),
        ),
      );
      // The button's text style animates from the previous scheme's colours.
      await tester.pumpAndSettle();
      final retry = tester.widget<Text>(find.descendant(of: find.byType(TextButton), matching: find.byType(Text)));
      final color = DefaultTextStyle.of(tester.element(find.text(retry.data!))).style.color!;
      expect(_contrast(color, scheme.errorContainer), greaterThanOrEqualTo(4.5), reason: name);
    }
  });

  testWidgets('desktop wizard steps keep their tap action for screen readers', (tester) async {
    await pumpApp(tester, initialLocation: '/inspections/new?step=1', store: signedInStore(), size: desktopSize);
    final step = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Site, ')));
    expect(step.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('a busy button still has a name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BusyButton(label: 'Sign in', busy: true, onPressed: () {}),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(FilledButton)).label, contains('Sign in, in progress'));
  });
}
