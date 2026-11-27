import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/features/export/csv_exporter.dart';

ReceiptRow receipt({
  String id = 'r1',
  String merchant = 'Coles',
  LocalDate? date,
  int total = 1250,
  int? subtotal,
  int? tax,
  int? tip,
  String currency = 'AUD',
  PaymentMethod? payment,
  int? categoryId,
  String? notes,
  ExtractionMethod method = ExtractionMethod.rules,
  DateTime? createdAt,
}) => ReceiptRow(
  id: id,
  merchant: merchant,
  purchaseDate: date ?? LocalDate(2026, 11, 3),
  totalMinor: total,
  subtotalMinor: subtotal,
  taxMinor: tax,
  tipMinor: tip,
  currency: currency,
  paymentMethod: payment,
  categoryId: categoryId,
  notes: notes,
  extractionMethod: method,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 3, 9, 30, 5, 123),
  updatedAt: DateTime.utc(2026, 11, 3, 9, 30, 5),
);

const header =
    'id,date,merchant,category,total,subtotal,tax,tip,currency,'
    'payment_method,notes,extraction_method,created_at';

String export(
  List<ReceiptRow> rows, [
  Map<int, String> categories = const {},
]) => CsvExporter.toCsv(rows, categoryNames: categories);

/// Data lines after the BOM and header, split on CRLF.
List<String> lines(String csv) {
  final all = csv.substring(1).split('\r\n');
  expect(all.last, isEmpty, reason: 'ends with a line break');
  return all.sublist(1, all.length - 1);
}

/// Parses the CSV back (without the BOM) into cells.
List<List<dynamic>> parse(String csv) =>
    Csv(autoDetect: false).decode(csv.substring(1));

void main() {
  test('starts with a UTF-8 BOM and the exact header', () {
    final csv = export([]);
    expect(csv, '﻿$header\r\n');

    final bytes = CsvExporter.toBytes([], categoryNames: const {});
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(bytes.skip(3).toList()), '$header\r\n');
  });

  test('writes a full row with plain decimals, ISO date and UTC time', () {
    final csv = export(
      [
        receipt(
          subtotal: 1100,
          tax: 110,
          tip: 40,
          payment: PaymentMethod.card,
          categoryId: 2,
          notes: 'Weekly shop',
          createdAt: DateTime.utc(2026, 11, 3, 9, 30, 5, 123),
        ),
      ],
      {2: 'Groceries'},
    );
    expect(lines(csv), [
      'r1,2026-11-03,Coles,Groceries,12.50,11.00,1.10,0.40,AUD,card,'
          'Weekly shop,rules,2026-11-03T09:30:05Z',
    ]);
  });

  test('converts local creation times to UTC', () {
    final local = DateTime(2026, 11, 3, 23, 15);
    final csv = export([receipt(createdAt: local)]);
    final cells = parse(csv)[1];
    expect(cells[12], endsWith('Z'));
    expect(DateTime.parse(cells[12] as String), local.toUtc());
  });

  test('null optional fields are empty cells', () {
    final csv = export([receipt()]);
    expect(lines(csv), [
      'r1,2026-11-03,Coles,,12.50,,,,AUD,,,rules,2026-11-03T09:30:05Z',
    ]);
  });

  test('looks up category names; uncategorised and unknown are empty', () {
    final csv = export(
      [
        receipt(id: 'a', categoryId: 1),
        receipt(id: 'b'),
        receipt(id: 'c', categoryId: 99),
      ],
      {1: 'Dining'},
    );
    final rows = parse(csv);
    expect(rows[1][3], 'Dining');
    expect(rows[2][3], '');
    expect(rows[3][3], '');
  });

  test('uses each currency\'s minor digits', () {
    final csv = export([
      receipt(id: 'jpy', total: 1500, tax: 136, currency: 'JPY'),
      receipt(id: 'kwd', total: 1250, subtotal: 5, currency: 'KWD'),
      receipt(id: 'usd', total: 5, currency: 'USD'),
    ]);
    final rows = parse(csv);
    expect(rows[1].sublist(4, 7), ['1500', '', '136']);
    expect(rows[2].sublist(4, 6), ['1.250', '0.005']);
    expect(rows[3][4], '0.05');
  });

  test('negative amounts stay plain numbers (no guard, no quotes)', () {
    final csv = export([receipt(total: -320, tax: -5)]);
    expect(lines(csv).single, contains(',-3.20,,-0.05,'));
  });

  test('quotes commas, quotes and line breaks (RFC 4180)', () {
    final csv = export([
      receipt(
        merchant: 'Smith, Jones & Co',
        notes: 'Said "thanks"\nsecond line\r\nthird',
      ),
    ]);
    final data = csv.substring(1);
    expect(data, contains(',"Smith, Jones & Co",'));
    expect(data, contains(',"Said ""thanks""\nsecond line\r\nthird",'));

    final cells = parse(csv)[1];
    expect(cells[2], 'Smith, Jones & Co');
    expect(cells[10], 'Said "thanks"\nsecond line\r\nthird');
  });

  test('keeps non-ASCII text intact', () {
    final csv = export([receipt(merchant: 'Café Zürich ☕', notes: 'مطعم')]);
    final cells = parse(csv)[1];
    expect(cells[2], 'Café Zürich ☕');
    expect(cells[10], 'مطعم');
  });

  group('CSV-injection guard', () {
    String merchantCell(String merchant) =>
        parse(export([receipt(merchant: merchant)]))[1][2] as String;

    for (final (input, expected) in [
      ('=SUM(1)', "'=SUM(1)"),
      ('+1', "'+1"),
      ('-x', "'-x"),
      ('@a', "'@a"),
      ('\tTab', "'\tTab"),
      ('\rCR', "'\rCR"),
      ('=HYPERLINK("http://x","y")', '\'=HYPERLINK("http://x","y")'),
    ]) {
      test('escapes ${jsonEncode(input)}', () {
        expect(merchantCell(input), expected);
      });
    }

    test('leaves ordinary text alone, including inner formula characters', () {
      expect(merchantCell('A=B'), 'A=B');
      expect(merchantCell('Shop @ Mall'), 'Shop @ Mall');
      expect(merchantCell("'quoted"), "'quoted");
    });

    test('guards notes and category names too', () {
      final cells = parse(
        export([receipt(categoryId: 1, notes: '=1+1')], {1: '-Misc'}),
      )[1];
      expect(cells[3], "'-Misc");
      expect(cells[10], "'=1+1");
    });

    test('a CR-led cell is quoted as well as escaped', () {
      final csv = export([receipt(merchant: '\rX')]);
      expect(csv, contains(',"\'\rX",'));
    });
  });
}
