import 'dart:convert';

import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/features/poc/results_model.dart';
import 'package:field_inspections/features/poc/results_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart';

import '../helpers/test_app.dart';

ProviderContainer _container([MemoryStore? store]) {
  final c = ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(store ?? MemoryStore())]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ResultsController', () {
    test('starts with our findings on every platform', () {
      final s = _container().read(resultsProvider);
      expect(s.dataset, ResultsDataset.findings);
      expect(s.results, hasLength(scenarioSeed.length));
      for (final p in PocPlatform.values) {
        expect(s.tested(p), greaterThan(10), reason: p.label);
      }
      final android = s.results.firstWhere((r) => r.id == 'data-table').of(PocPlatform.android);
      expect(android.status, ResultStatus.na, reason: 'no Android tablet was tried, so the table is desktop only there');
      final ios = s.results.firstWhere((r) => r.id == 'data-table').of(PocPlatform.ios);
      expect(ios.status, ResultStatus.pass, reason: 'the landscape iPad Pro shows the table');
      expect(ios.device, contains('iPad'));
      final linux = s.results.firstWhere((r) => r.id == 'geolocation').of(PocPlatform.linux);
      expect(linux.status, ResultStatus.na, reason: 'no geolocator plugin on Linux');
      expect(linux.device, contains('WSL 2'));
    });

    test('N/A scenarios are left out of what a platform is tested out of', () {
      final s = _container().read(resultsProvider);
      final na = s.count(PocPlatform.linux, ResultStatus.na);
      expect(na, greaterThan(0));
      expect(s.applicable(PocPlatform.linux), s.results.length - na);
    });

    test('a saved copy of the findings is replaced by the ones in this build', () {
      final store = MemoryStore();
      final c = _container(store);
      c.read(resultsProvider.notifier).load(ResultsDataset.findings);
      // An older build saved this copy, with a result that has changed since.
      final saved = jsonDecode(store.getString('poc_results')!) as Map<String, Object?>;
      final row = (saved['results']! as List).cast<Map<String, Object?>>().firstWhere((r) => r['id'] == 'data-table');
      row['ios'] = {'status': 'notTested'};
      store.values['poc_results'] = jsonEncode(saved);
      final again = _container(store).read(resultsProvider);
      expect(again.dataset, ResultsDataset.findings);
      expect(again.results.firstWhere((r) => r.id == 'data-table').of(PocPlatform.ios).status, ResultStatus.pass);
    });

    test('every findings id exists in the scenario seed', () {
      final ids = {for (final s in scenarioSeed) s.id};
      expect(findings.keys.where((id) => !ids.contains(id)), isEmpty);
      expect(desktopFindings.keys.where((id) => !ids.contains(id)), isEmpty);
      expect(iosFindings.keys.where((id) => !ids.contains(id)), isEmpty);
    });

    test('sample dataset matches the D05 codes', () {
      final c = _container();
      final s = c.read(resultsProvider.notifier).load(ResultsDataset.sample);
      final back = s.results.firstWhere((r) => r.id == 'back-navigation');
      expect(back.of(PocPlatform.web).status, ResultStatus.fail);
      expect(back.of(PocPlatform.ios).status, ResultStatus.pass);
    });

    test('edits persist and survive a new container', () {
      final store = MemoryStore();
      final c = _container(store);
      c
          .read(resultsProvider.notifier)
          .setResult('hero', PocPlatform.ios, const PlatformResult(status: ResultStatus.pass, device: 'iPhone 16, iOS 26'));
      expect(c.read(resultsProvider).dataset, ResultsDataset.custom);

      final again = _container(store).read(resultsProvider);
      expect(again.results.firstWhere((r) => r.id == 'hero').of(PocPlatform.ios).device, 'iPhone 16, iOS 26');
    });

    test('JSON export round-trips through import', () {
      final c = _container();
      c
          .read(resultsProvider.notifier)
          .setResult('maps', PocPlatform.ios, const PlatformResult(status: ResultStatus.fail, device: 'iPad', notes: 'Tiles blank'));
      final json = jsonEncode(ResultsController.toJson(c.read(resultsProvider)));

      final other = _container();
      other.read(resultsProvider.notifier).importJson(json);
      final maps = other.read(resultsProvider).results.firstWhere((r) => r.id == 'maps');
      expect(maps.of(PocPlatform.ios).status, ResultStatus.fail);
      expect(maps.of(PocPlatform.ios).notes, 'Tiles blank');
    });

    test('import rejects files that are not a results export', () {
      final c = _container();
      expect(() => c.read(resultsProvider.notifier).importJson('{"hello": 1}'), throwsFormatException);
      expect(() => c.read(resultsProvider.notifier).importJson('not json'), throwsFormatException);
    });

    test('the running platform maps to its column; exports have one per platform', () {
      expect(PocPlatform.of(web), PocPlatform.web);
      expect(PocPlatform.of(android), PocPlatform.android);
      expect(PocPlatform.of(macos), PocPlatform.macos);
      expect(PocPlatform.of(linux), PocPlatform.linux);
      final header = ResultsController.toCsv(const ResultsState(dataset: ResultsDataset.blank, results: [])).trim();
      expect(header.split(',').where((h) => h.endsWith('_status')), [for (final p in PocPlatform.values) '${p.name}_status']);
    });

    test('CSV quotes commas, quotes and newlines', () {
      final c = _container();
      c
          .read(resultsProvider.notifier)
          .setResult(
            'maps',
            PocPlatform.web,
            const PlatformResult(status: ResultStatus.partial, device: 'Chrome', notes: 'Slow, "laggy"\nzoom'),
          );
      final csv = ResultsController.toCsv(c.read(resultsProvider));
      // UTF-8 byte order mark for Excel, then CRLF lines (RFC 4180).
      expect(csv, startsWith('\uFEFFgroup,scenario,ios_status'));
      expect(csv.split('\r\n').first, isNot(contains('\n')));
      expect(csv, contains('"Slow, ""laggy""\nzoom"'));
    });

    test('CSV keeps spreadsheets from running cells as formulas', () {
      final c = _container();
      c
          .read(resultsProvider.notifier)
          .setResult('maps', PocPlatform.web, const PlatformResult(status: ResultStatus.fail, notes: '=HYPERLINK("x")'));
      expect(ResultsController.toCsv(c.read(resultsProvider)), contains('"\'=HYPERLINK(""x"")"'));
    });

    test('a file with the right format tag but the wrong shape is rejected, not a crash', () {
      final c = _container();
      final notifier = c.read(resultsProvider.notifier);
      for (final bad in [
        '{"format":"field-inspections-poc-results/1","results":{}}',
        '{"format":"field-inspections-poc-results/1","results":[1]}',
        '{"format":"field-inspections-poc-results/1","results":[{"id":"maps","web":"P"}]}',
      ]) {
        expect(() => notifier.importJson(bad), throwsFormatException, reason: bad);
      }
    });

    test('imported notes are cut to the 1000-character limit; wrong field types read as empty', () {
      final c = _container();
      final long = 'x' * 1200;
      c
          .read(resultsProvider.notifier)
          .importJson('{"format":"field-inspections-poc-results/1","results":[{"id":"maps","web":{"s":1,"device":2,"notes":"$long"}}]}');
      final web = c.read(resultsProvider).results.firstWhere((r) => r.id == 'maps').of(PocPlatform.web);
      expect(web.notes, hasLength(1000));
      expect(web.device, '');
      expect(web.status, ResultStatus.notTested);
    });
  });

  group('Results screen', () {
    testWidgets('phone: summary, filter and per-platform icons', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/results');
        expect(find.byType(ResultsScreen), findsOneWidget);
        expect(find.text('Findings so far'), findsOneWidget);
        // iOS (the iPhone and iPad simulators) is the only platform with
        // every scenario tested.
        expect(find.text('44 of 44 tested'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Adaptive shell.*Android: Pass.*Web: Pass', dotAll: true)), findsWidgets);

        // Nested routes pass everywhere tested; the guards are partial on Android.
        expect(find.text('Nested routes and tabs'), findsOneWidget);
        expect(find.text('Auth and lock guards'), findsOneWidget);
        await tester.tap(find.text('Failing'));
        await tester.pumpAndSettle();
        expect(find.text('Nested routes and tabs'), findsNothing);
        expect(find.text('Auth and lock guards'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('row opens the result sheet at its URL; validators guard Save', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/results');
      await tester.ensureVisible(find.text('Back navigation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back navigation'));
      await tester.pumpAndSettle();
      expect(app.location, '/settings/poc/results/back-navigation');
      expect(find.byType(ResultSheet), findsOneWidget);

      // Default platform is Android here; switch to iOS and empty its seeded
      // device and notes.
      await tester.tap(find.text('iOS').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Fail'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Device and version'), '');
      await tester.enterText(find.widgetWithText(TextFormField, 'Notes'), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Which device and version did you test on?'), findsOneWidget);
      expect(find.text('Describe what failed or only partly worked'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Device and version'), 'iPhone 16, iOS 26');
      await tester.enterText(find.widgetWithText(TextFormField, 'Notes'), 'Swipe back skipped the dialog');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(app.location, '/settings/poc/results');
      await tester.dragUntilVisible(find.text('Your results'), find.byType(Scrollable).first, const Offset(0, 300));
      expect(find.text('Your results'), findsOneWidget);
      final row = app.container.read(resultsProvider).results.firstWhere((r) => r.id == 'back-navigation');
      expect(row.of(PocPlatform.ios).status, ResultStatus.fail);
      expect(row.of(PocPlatform.android).status, ResultStatus.pass);
    });

    testWidgets('not tested needs no device or notes', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/results/hero');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Not tested'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(app.location, '/settings/poc/results');
    });

    testWidgets('export CSV and JSON go through the share service; import JSON', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/results');
      await tester.tap(find.byTooltip('Export results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();
      expect(app.fakes.share.files, ['poc-results.csv']);
      expect(utf8.decode(app.fakes.share.contents['poc-results.csv']!), startsWith('group,scenario'));

      await tester.tap(find.byTooltip('Export results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();
      final exported = utf8.decode(app.fakes.share.contents['poc-results.json']!);

      await tester.tap(find.byTooltip('Export results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start blank'));
      await tester.pumpAndSettle();
      expect(find.text('Blank'), findsOneWidget);

      app.fakes.media.nextJson = exported;
      await tester.tap(find.byTooltip('Export results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      expect(find.text('Results imported.'), findsOneWidget);
      expect(app.container.read(resultsProvider).tested(PocPlatform.web), greaterThan(10));
    });

    testWidgets('import of another file shows an error', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/results');
      app.fakes.media.nextJson = '{"format": "something-else"}';
      await tester.tap(find.byTooltip('Export results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      expect(find.text('That file is not a PoC results export.'), findsOneWidget);
    });

    testWidgets('desktop shows the D05 table with notes', (tester) async {
      await pumpApp(tester, store: signedInStore(), initialLocation: '/settings/poc/results', size: desktopSize, capabilities: web);
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Scenario'), findsOneWidget);
      for (final p in PocPlatform.values) {
        expect(find.text(p.label), findsWidgets, reason: '${p.label} column');
      }
      expect(find.textContaining('flutter_map + OSM tiles'), findsOneWidget);
    });

    testWidgets('a result sheet opened on macOS starts on macOS', (tester) async {
      await pumpApp(
        tester,
        store: signedInStore(),
        initialLocation: '/settings/poc/results/back-navigation',
        size: desktopSize,
        capabilities: macos,
      );
      final segments = tester.widget<SegmentedButton<PocPlatform>>(find.byType(SegmentedButton<PocPlatform>));
      expect(segments.selected, {PocPlatform.macos});
    });
  });
}
