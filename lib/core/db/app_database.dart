import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../date/local_date.dart';
import 'daos/categories_dao.dart';
import 'daos/receipts_dao.dart';
import 'seed.dart';
import 'tables/categories.dart';
import 'tables/enums.dart';
import 'tables/receipts.dart';

export 'tables/enums.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Receipts, Categories],
  daos: [ReceiptsDao, CategoriesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The on-device database in the app support directory (private, not shown
  /// in the Files app, excluded from Android cloud backup).
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'receipt_mind',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    ),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedDefaultCategories(this);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
