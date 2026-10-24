import 'package:field_inspections/core/router/deep_links.dart';
import 'package:field_inspections/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toLocation', () {
    test('accepts in-app paths, the custom scheme and the web host', () {
      expect(DeepLinks.toLocation('/inspections/INS-1042?tab=photos'), '/inspections/INS-1042?tab=photos');
      expect(DeepLinks.toLocation('fieldinspections://app/inspections/INS-1042?tab=photos'), '/inspections/INS-1042?tab=photos');
      expect(DeepLinks.toLocation('https://fieldinspections.example/map?site=s-1'), '/map?site=s-1');
      expect(DeepLinks.toLocation('  /home  '), '/home');
    });
    test('keeps unknown paths so they show the 404', () {
      expect(DeepLinks.toLocation('/does/not/exist'), '/does/not/exist');
    });
    test('rejects foreign or malformed links', () {
      for (final raw in [
        '',
        'https://evil.example/home',
        '//evil.example/home',
        'fieldinspections://other/home',
        'javascript:alert(1)',
        r'/\evil.example',
        'home',
      ]) {
        expect(DeepLinks.toLocation(raw), isNull, reason: raw);
      }
    });
    test('the custom scheme root opens the app root', () {
      expect(DeepLinks.toLocation('fieldinspections://app'), '/');
    });
  });

  group('sanitizeFrom', () {
    test('keeps known in-app routes with their query', () {
      expect(DeepLinks.sanitizeFrom('/inspections?status=overdue'), '/inspections?status=overdue');
      expect(DeepLinks.sanitizeFrom('/settings/poc/results/maps'), '/settings/poc/results/maps');
    });
    test('drops auth routes, unknown routes and off-site targets', () {
      for (final from in [null, '', '/', '/sign-in', '/splash', '/unlock', '/nope', 'https://x.y/home', '//x.y']) {
        expect(DeepLinks.sanitizeFrom(from), isNull, reason: from);
      }
    });
  });

  group('route table', () {
    test('every example location is a known route', () {
      for (final r in RouteTable.all) {
        expect(RouteTable.isKnown(Uri.parse(r.example).path), isTrue, reason: r.example);
        expect(r.matches(Uri.parse(r.example).path), isTrue, reason: r.pattern);
      }
    });
    test('patterns do not match extra segments', () {
      expect(RouteTable.isKnown('/inspections/INS-1/photos'), isFalse);
      expect(RouteTable.isKnown('/settings/poc'), isFalse);
    });
    test('helpers build the documented URLs', () {
      expect(Routes.inspection('INS-1', tab: 'photos'), '/inspections/INS-1?tab=photos');
      expect(Routes.inspection('INS-1'), '/inspections/INS-1');
      expect(Routes.editInspection('INS-1', step: 3), '/inspections/INS-1/edit?step=3');
      expect(Routes.mapSite('s 1'), '/map?site=s+1');
    });
  });
}
