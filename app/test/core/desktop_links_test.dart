import 'dart:async';

import 'package:field_inspections/core/platform/desktop_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('off (phones, web): no launch route and no stream', () async {
    final links = DesktopLinks(
      enabled: false,
      initialLink: () async => 'fieldinspections://app/map',
      links: () => Stream.value('fieldinspections://app/map'),
    );
    expect(await links.initialRoute(), isNull);
    expect(await links.routes().toList(), isEmpty);
  });

  test('the launch link becomes the initial route, and its replay is skipped', () async {
    final source = StreamController<String>();
    final links = DesktopLinks(
      enabled: true,
      initialLink: () async => 'fieldinspections://app/inspections/INS-1042?tab=photos',
      links: () => source.stream,
    );
    expect(await links.initialRoute(), '/inspections/INS-1042?tab=photos');

    final routes = <String>[];
    final done = links.routes().listen(routes.add).asFuture<void>();
    source
      ..add('fieldinspections://app/inspections/INS-1042?tab=photos') // app_links' replay
      ..add('fieldinspections://app/map?site=s-riverside-office')
      ..add('https://evil.example/home') // foreign: ignored
      ..add('fieldinspections://app/inspections/INS-1042?tab=photos'); // opened again later: kept
    await source.close();
    await done;
    expect(routes, ['/map?site=s-riverside-office', '/inspections/INS-1042?tab=photos']);
  });

  test('no launch link: every link is routed', () async {
    final links = DesktopLinks(
      enabled: true,
      initialLink: () async => null,
      links: () => Stream.value('fieldinspections://app/notifications'),
    );
    expect(await links.initialRoute(), isNull);
    expect(await links.routes().toList(), ['/notifications']);
  });
}
