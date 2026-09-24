import 'package:drift/drift.dart';

import '../../date/local_date.dart';
import '../app_database.dart';
import '../tables/receipts.dart';

part 'receipts_dao.g.dart';

@DriftAccessor(tables: [Receipts])
class ReceiptsDao extends DatabaseAccessor<AppDatabase>
    with _$ReceiptsDaoMixin {
  ReceiptsDao(super.attachedDatabase);

  /// Receipts newest first. [query] matches merchant, notes and the recognised
  /// text (case-insensitive for ASCII); [categoryId] filters by category.
  Stream<List<ReceiptRow>> watchReceipts({String? query, int? categoryId}) {
    final select = this.select(receipts);
    final text = query?.trim() ?? '';
    if (text.isNotEmpty) {
      final pattern = '%${_escapeLike(text)}%';
      select.where(
        (r) =>
            r.merchant.like(pattern, escapeChar: r'\') |
            r.notes.like(pattern, escapeChar: r'\') |
            r.rawOcrText.like(pattern, escapeChar: r'\'),
      );
    }
    if (categoryId != null) {
      select.where((r) => r.categoryId.equals(categoryId));
    }
    select.orderBy([
      (r) => OrderingTerm.desc(r.purchaseDate),
      (r) => OrderingTerm.desc(r.createdAt),
    ]);
    return select.watch();
  }

  /// Sum of receipt totals per currency for the month containing [month].
  Stream<Map<String, int>> watchMonthTotals(LocalDate month) {
    final sum = receipts.totalMinor.sum();
    final query = selectOnly(receipts)
      ..addColumns([receipts.currency, sum])
      ..where(
        receipts.purchaseDate.isBiggerOrEqualValue(month.firstOfMonth.toIso()) &
            receipts.purchaseDate.isSmallerThanValue(
              month.firstOfNextMonth.toIso(),
            ),
      )
      ..groupBy([receipts.currency]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(receipts.currency)!: row.read(sum) ?? 0,
      },
    );
  }

  Future<ReceiptRow?> getReceipt(String id) =>
      (select(receipts)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<void> insertReceipt(ReceiptsCompanion receipt) =>
      into(receipts).insert(receipt);

  /// Re-inserts a deleted row unchanged (used by "Undo").
  Future<void> restoreReceipt(ReceiptRow row) =>
      into(receipts).insert(row, mode: InsertMode.insertOrReplace);

  Future<bool> updateReceipt(ReceiptRow row) => update(receipts).replace(row);

  /// Deletes the receipt and returns it, or `null` if it did not exist.
  Future<ReceiptRow?> deleteReceipt(String id) => transaction(() async {
    final row = await getReceipt(id);
    if (row != null) {
      await (delete(receipts)..where((r) => r.id.equals(id))).go();
    }
    return row;
  });

  /// Every stored image path, for orphan-file cleanup.
  Future<Set<String>> allImagePaths() async {
    final query = selectOnly(receipts)
      ..addColumns([receipts.imagePath])
      ..where(receipts.imagePath.isNotNull());
    final rows = await query.get();
    return {for (final row in rows) row.read(receipts.imagePath)!};
  }

  static String _escapeLike(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
