import 'package:integration_test/integration_test_driver.dart';

/// Host side of `fvm flutter drive` (Chrome needs chromedriver on port 4444).
Future<void> main() => integrationDriver();
