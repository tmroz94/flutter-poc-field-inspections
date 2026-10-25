import 'package:field_inspections/core/platform/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: on Android a tap that relaunches a killed app arrives as a new
  // intent during start-up, before the app listens; it used to be dropped.
  test('a tap before anyone listens is delivered to the first listener', () async {
    final n = NotificationService(isWeb: false)..debugTap('fieldinspections://app/inspections/INS-1042?tab=checklist');
    expect(await n.taps.first, '/inspections/INS-1042?tab=checklist');
  });

  test('taps while listening arrive in order, and only once', () async {
    final n = NotificationService(isWeb: false);
    final got = <String>[];
    final sub = n.taps.listen(got.add);
    n
      ..debugTap('/inspections/INS-1040')
      ..debugTap('/map');
    await pumpEventQueue();
    expect(got, ['/inspections/INS-1040', '/map']);
    await sub.cancel();

    final again = <String>[];
    final sub2 = n.taps.listen(again.add);
    await pumpEventQueue();
    expect(again, isEmpty, reason: 'nothing pending is replayed');
    await sub2.cancel();
  });
}
