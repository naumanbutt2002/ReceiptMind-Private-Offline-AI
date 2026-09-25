// Driver for running integration tests in profile or release mode, where
// `flutter test integration_test` isn't available:
//
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//       --target=integration_test/parser_smoke_test.dart -d <device>
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
