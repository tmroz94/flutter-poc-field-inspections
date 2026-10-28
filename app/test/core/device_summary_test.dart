import 'package:field_inspections/core/platform/device_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("iOS models the plugin doesn't know fall back to the device's name", () {
    expect(iosModel(modelName: 'iPad Pro 13-Inch (M5)', name: 'iPad Pro 13-inch (M5)'), 'iPad Pro 13-Inch (M5)');
    expect(iosModel(modelName: 'Unknown device', name: 'iPad mini (A17 Pro)'), 'iPad mini (A17 Pro)');
    expect(iosModel(modelName: '', name: 'iPad'), 'iPad');
  });
}
