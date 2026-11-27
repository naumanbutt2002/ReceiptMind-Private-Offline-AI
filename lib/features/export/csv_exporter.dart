import 'dart:convert';

import 'package:csv/csv.dart';

import '../../core/db/app_database.dart';
import '../../core/money/money.dart';

/// Turns receipts into a CSV file that spreadsheets open correctly.
///
/// - UTF-8 with a byte order mark, so Excel detects the encoding.
/// - RFC 4180 quoting (commas, quotes and line breaks), CRLF line endings.
/// - Amounts are plain decimals in the receipt's currency (`12.50`, `1500`
///   for JPY, `1.250` for KWD), never formatted or converted.
/// - CSV-injection guard: a text cell that starts with `=`, `+`, `-`, `@`,
///   tab or carriage return gets a leading `'`, so a spreadsheet shows it as
///   text instead of running it as a formula. Amount and date columns are
///   exempt, so negative amounts stay numbers.
abstract final class CsvExporter {
  static const columns = [
    'id',
    'date',
    'merchant',
    'category',
    'total',
    'subtotal',
    'tax',
    'tip',
    'currency',
    'payment_method',
    'notes',
    'extraction_method',
    'created_at',
  ];

  static const _lineDelimiter = '\r\n';
  static const _bom = '﻿';

  /// The CSV text, starting with a BOM and ending with a line break.
  /// [categoryNames] maps category IDs to names; receipts without a category
  /// (or with an unknown one) get an empty cell.
  static String toCsv(
    List<ReceiptRow> receipts, {
    required Map<int, String> categoryNames,
  }) {
    final rows = <List<String?>>[
      columns,
      for (final receipt in receipts) _row(receipt, categoryNames),
    ];
    final body = Csv(lineDelimiter: _lineDelimiter).encode(rows);
    return '$_bom$body$_lineDelimiter';
  }

  /// [toCsv] as UTF-8 bytes (the BOM becomes `EF BB BF`).
  static List<int> toBytes(
    List<ReceiptRow> receipts, {
    required Map<int, String> categoryNames,
  }) => utf8.encode(toCsv(receipts, categoryNames: categoryNames));

  static List<String?> _row(ReceiptRow r, Map<int, String> categoryNames) {
    String? amount(int? minor) =>
        minor == null ? null : Money(minor, r.currency).toDecimalString();
    final category = r.categoryId == null ? null : categoryNames[r.categoryId];
    return [
      _text(r.id),
      r.purchaseDate.toIso(),
      _text(r.merchant),
      _text(category),
      amount(r.totalMinor),
      amount(r.subtotalMinor),
      amount(r.taxMinor),
      amount(r.tipMinor),
      _text(r.currency),
      _text(r.paymentMethod?.name),
      _text(r.notes),
      _text(r.extractionMethod.name),
      _utcTimestamp(r.createdAt),
    ];
  }

  /// Escapes text that a spreadsheet would read as a formula.
  static String? _text(String? value) {
    if (value == null || value.isEmpty) return value;
    return _formulaStarts.contains(value[0]) ? "'$value" : value;
  }

  static const _formulaStarts = {'=', '+', '-', '@', '\t', '\r'};

  /// ISO 8601 in UTC to the second, e.g. `2026-11-16T09:30:00Z`.
  static String _utcTimestamp(DateTime time) {
    final utc = time.toUtc();
    final seconds = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
    return seconds.toIso8601String().replaceFirst('.000Z', 'Z');
  }
}
