// Development only (M5): writes demo receipts into the app's real on-device
// database for the 1,000-receipt scroll performance check.
//
//   flutter test integration_test/seed_demo_data_test.dart \
//       -d emulator-5554 --no-uninstall --dart-define=DEMO_COUNT=1000
//
// --no-uninstall keeps the app and its data installed afterwards; then run
// the app (`flutter run --profile -d emulator-5554`) and scroll the list.
// Each run adds DEMO_COUNT more receipts (ids never collide because the seed
// comes from the clock). `adb shell pm clear <app id>` starts over.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/dev/demo_data.dart';

const _count = int.fromEnvironment('DEMO_COUNT', defaultValue: 1000);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seeds $_count demo receipts into the on-device database', (
    tester,
  ) async {
    final db = AppDatabase.open();
    addTearDown(db.close);

    final categories = await db.categoriesDao.watchAll().first;
    final now = DateTime.now();
    final receipts = demoReceipts(
      count: _count,
      categoryIds: [for (final c in categories) c.id],
      now: now,
      seed: now.microsecondsSinceEpoch,
    );

    final watch = Stopwatch()..start();
    await db.batch((batch) => batch.insertAll(db.receipts, receipts));
    watch.stop();

    final count = db.receipts.id.count();
    final total = await (db.selectOnly(
      db.receipts,
    )..addColumns([count])).map((row) => row.read(count)!).getSingle();
    debugPrint(
      'Seeded ${receipts.length} demo receipts in '
      '${watch.elapsedMilliseconds} ms; the database now has $total.',
    );
    expect(total, greaterThanOrEqualTo(_count));
  });
}
