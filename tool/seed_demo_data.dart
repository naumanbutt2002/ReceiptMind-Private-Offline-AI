// Development only: explains how to fill the app's database with demo receipts.
//
//   dart run tool/seed_demo_data.dart
//
// The receipts can't be written from here. The app's database lives on the
// device, and the database code (`lib/core/db/app_database.dart`) imports
// drift_flutter and path_provider, which need `dart:ui`, so a plain Dart CLI
// can't load it. The generator itself is `lib/dev/demo_data.dart`; the
// integration test below runs it inside the app on the device and writes the
// receipts into the real database.
import 'dart:io';

void main(List<String> args) {
  final count = args.isEmpty ? 1000 : int.tryParse(args.first);
  if (count == null || count <= 0) {
    stderr.writeln('Usage: dart run tool/seed_demo_data.dart [count]');
    exitCode = 64;
    return;
  }
  stdout.writeln('''
Seed $count demo receipts into the app on a running emulator or device:

  flutter test integration_test/seed_demo_data_test.dart \\
      -d emulator-5554 --no-uninstall --dart-define=DEMO_COUNT=$count

--no-uninstall keeps the app (and its database) installed after the test.
Each run adds another $count receipts. Then start the app to check scrolling:

  flutter run --profile -d emulator-5554

To start over, clear the app's data:

  adb shell pm clear io.github.naumanbutt2002.receiptmind
''');
}
