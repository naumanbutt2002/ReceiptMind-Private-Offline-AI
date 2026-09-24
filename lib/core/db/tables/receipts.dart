import 'package:drift/drift.dart';

import '../../date/local_date.dart';
import 'categories.dart';
import 'enums.dart';

@DataClassName('ReceiptRow')
@TableIndex(name: 'idx_receipts_date', columns: {#purchaseDate})
@TableIndex(name: 'idx_receipts_category', columns: {#categoryId})
class Receipts extends Table {
  /// UUIDv7: sortable by creation and safe to merge across devices.
  TextColumn get id => text()();
  TextColumn get merchant => text().withLength(min: 1, max: 200)();

  /// Calendar date printed on the receipt, stored as `YYYY-MM-DD`.
  TextColumn get purchaseDate => text().map(const LocalDateConverter())();

  // Amounts are integer minor units of [currency].
  IntColumn get totalMinor => integer()();
  IntColumn get subtotalMinor => integer().nullable()();
  IntColumn get taxMinor => integer().nullable()();
  IntColumn get tipMinor => integer().nullable()();

  /// ISO 4217 code.
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get paymentMethod => textEnum<PaymentMethod>().nullable()();
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get notes => text().nullable()();

  /// Relative to the app support directory, e.g. `receipts/<id>.jpg`.
  TextColumn get imagePath => text().nullable()();
  TextColumn get rawOcrText => text().nullable()();
  TextColumn get extractionMethod => textEnum<ExtractionMethod>()();

  /// Overall parser confidence, 0..1.
  RealColumn get confidence => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
