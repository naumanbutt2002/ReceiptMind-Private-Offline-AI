import 'package:flutter/foundation.dart';

import '../../../core/date/local_date.dart';
import '../../../core/db/app_database.dart';

/// One item of the flat receipt list: a month header or a receipt.
sealed class ReceiptListEntry {
  const ReceiptListEntry();
}

/// Header above the receipts of one month. [month] is its first day.
@immutable
final class MonthHeaderEntry extends ReceiptListEntry {
  const MonthHeaderEntry(this.month);

  final LocalDate month;

  @override
  bool operator ==(Object other) =>
      other is MonthHeaderEntry && other.month == month;

  @override
  int get hashCode => month.hashCode;
}

final class ReceiptEntry extends ReceiptListEntry {
  const ReceiptEntry(this.receipt);

  final ReceiptRow receipt;
}

/// Puts a [MonthHeaderEntry] before each month's receipts. [receipts] must be
/// sorted by purchase date (newest first, as the repository returns them).
List<ReceiptListEntry> groupReceiptsByMonth(Iterable<ReceiptRow> receipts) {
  final entries = <ReceiptListEntry>[];
  LocalDate? current;
  for (final receipt in receipts) {
    final month = receipt.purchaseDate.firstOfMonth;
    if (month != current) {
      entries.add(MonthHeaderEntry(month));
      current = month;
    }
    entries.add(ReceiptEntry(receipt));
  }
  return entries;
}
