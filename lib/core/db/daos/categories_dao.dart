import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories.dart';
import '../tables/receipts.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, Receipts])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.attachedDatabase);

  Stream<List<CategoryRow>> watchAll() =>
      (select(categories)..orderBy([
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.name),
          ]))
          .watch();

  Stream<int> watchCount() {
    final count = categories.id.count();
    return (selectOnly(
      categories,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  Future<bool> updateCategory(CategoryRow category) =>
      update(categories).replace(category);

  /// Deletes the category; its receipts become uncategorised (FK set null).
  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  /// Number of receipts in the category, shown before deleting it.
  Future<int> countReceipts(int categoryId) {
    final count = receipts.id.count();
    return (selectOnly(receipts)
          ..addColumns([count])
          ..where(receipts.categoryId.equals(categoryId)))
        .map((row) => row.read(count) ?? 0)
        .getSingle();
  }
}
