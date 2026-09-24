import 'package:drift/drift.dart';
import 'package:receipt_parser/receipt_parser.dart';

export 'package:receipt_parser/receipt_parser.dart' show DateOrder, LocalDate;

/// Stores a [LocalDate] as ISO `YYYY-MM-DD` text, so it sorts correctly and
/// month ranges can be queried with plain string comparisons.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parseIso(fromDb);

  @override
  String toSql(LocalDate value) => value.toIso();
}
