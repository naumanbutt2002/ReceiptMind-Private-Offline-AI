import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/db_providers.dart';

part 'categories_providers.g.dart';

// Written by hand: riverpod_generator runs before Drift's generated part
// (app_database.g.dart) exists in the build, so it can't name `CategoryRow`.

/// All categories in sort order, updated live.
final categoryListProvider = StreamProvider.autoDispose<List<CategoryRow>>(
  (ref) => ref.watch(categoriesDaoProvider).watchAll(),
);

/// Number of receipts per category id, updated live. Categories without
/// receipts are missing from the map.
// TODO(lead): move into CategoriesDao as `watchReceiptCounts()`.
@riverpod
Stream<Map<int, int>> categoryReceiptCounts(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final receipts = db.receipts;
  final count = receipts.id.count();
  final query = db.selectOnly(receipts)
    ..addColumns([receipts.categoryId, count])
    ..where(receipts.categoryId.isNotNull())
    ..groupBy([receipts.categoryId]);
  return query.watch().map(
    (rows) => {
      for (final row in rows)
        row.read(receipts.categoryId)!: row.read(count) ?? 0,
    },
  );
}
