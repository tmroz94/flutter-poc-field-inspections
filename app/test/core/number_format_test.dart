import 'package:field_inspections/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<BuildContext> contextFor(WidgetTester tester, Locale locale) async {
    late BuildContext context;
    await tester.pumpWidget(
      Localizations(
        locale: locale,
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return context;
  }

  testWidgets('coordinates and sizes use the language\'s decimal separator', (tester) async {
    final en = await contextFor(tester, const Locale('en', 'GB'));
    expect(coordinatesText(en, 52.24012, 21.03), '52.2401° N, 21.0300° E');
    expect(megabytesText(en, 1234567), '1.2 MB');

    final pl = await contextFor(tester, const Locale('pl'));
    expect(coordinatesText(pl, 52.24012, 21.03), '52,2401° N, 21,0300° E');
    expect(megabytesText(pl, 1234567), '1,2 MB');
  });

  testWidgets('southern and western coordinates say so instead of a minus sign', (tester) async {
    final en = await contextFor(tester, const Locale('en', 'GB'));
    expect(coordinatesText(en, -33.8688, -70.6693), '33.8688° S, 70.6693° W');
  });

  testWidgets('photo and file counts agree with their number', (tester) async {
    final en = (await contextFor(tester, const Locale('en', 'GB'))).l10n;
    expect(en.wizardHintPhotos(1, 1), '1 photo · 1 file');
    expect(en.wizardHintPhotos(3, 0), '3 photos · 0 files');
    final pl = (await contextFor(tester, const Locale('pl'))).l10n;
    expect(pl.wizardHintPhotos(1, 2), 'Zdjęcia: 1 · pliki: 2');
  });
}
