// Driver for the screenshot integration test. Screenshots themselves are
// captured externally via `xcrun simctl io booted screenshot` keyed off the
// `SHOT:<name>` markers the test prints (more reliable on the iOS Simulator
// than VM-service screenshots), so this driver just runs the test.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
