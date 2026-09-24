import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';
import 'daos/categories_dao.dart';
import 'daos/receipts_dao.dart';

part 'db_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
ReceiptsDao receiptsDao(Ref ref) => ref.watch(appDatabaseProvider).receiptsDao;

@Riverpod(keepAlive: true)
CategoriesDao categoriesDao(Ref ref) =>
    ref.watch(appDatabaseProvider).categoriesDao;

/// Number of categories, shown in Settings.
@riverpod
Stream<int> categoryCount(Ref ref) =>
    ref.watch(categoriesDaoProvider).watchCount();
