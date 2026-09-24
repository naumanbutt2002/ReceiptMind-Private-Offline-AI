import 'dart:convert';
import 'dart:io';

import '../model/date_order.dart';
import '../model/local_date.dart';
import '../model/ocr_document.dart';
import '../model/parse_options.dart';
import '../model/parsed_receipt.dart';
import '../money/amount_parser.dart';
import '../money/currency.dart';

/// The fields a fixture can check, in report order.
const fixtureFields = [
  'merchant',
  'date',
  'total',
  'subtotal',
  'tax',
  'tip',
  'currency',
  'paymentMethod',
];

/// A receipt with the values a person read from it: an OCR dump (`.txt` or
/// `.ocr.json`) plus a `.expected.json` file next to it.
final class Fixture {
  const Fixture({
    required this.id,
    required this.country,
    required this.inputPath,
    required this.document,
    required this.options,
    required this.expected,
    this.xfail = const {},
    this.source = 'synthetic',
    this.notes = '',
  });

  /// File name without extensions, e.g. `au_supermarket_01`.
  final String id;

  /// Folder name, e.g. `au`.
  final String country;
  final String inputPath;
  final OcrDocument document;
  final ParseOptions options;

  /// Field → expected value as text (`"45.60"`, `"2026-09-12"`, `"card"`).
  final Map<String, String> expected;

  /// Fields the parser is known to get wrong.
  final Set<String> xfail;
  final String source;
  final String notes;

  static Fixture load(File expectedFile) {
    final json =
        jsonDecode(expectedFile.readAsStringSync()) as Map<String, Object?>;
    final base = expectedFile.path.substring(
      0,
      expectedFile.path.length - '.expected.json'.length,
    );
    final layout = File('$base.ocr.json');
    final text = File('$base.txt');
    final OcrDocument document;
    String inputPath;
    if (layout.existsSync()) {
      inputPath = layout.path;
      document = OcrDocument.fromJson(
        jsonDecode(layout.readAsStringSync()) as Map<String, Object?>,
      );
    } else if (text.existsSync()) {
      inputPath = text.path;
      document = OcrDocument.fromPlainText(text.readAsStringSync());
    } else {
      throw StateError('No .txt or .ocr.json next to ${expectedFile.path}');
    }
    final options = json['options']! as Map<String, Object?>;
    final expected = json['expected']! as Map<String, Object?>;
    final segments = expectedFile.uri.pathSegments;
    return Fixture(
      id: segments.last.replaceAll('.expected.json', ''),
      country: segments[segments.length - 2],
      inputPath: inputPath,
      document: document,
      options: parseOptionsFromJson(options),
      expected: {
        for (final e in expected.entries)
          if (e.value != null) e.key: e.value.toString(),
      },
      xfail: {
        for (final f in (json['xfail'] as List<Object?>?) ?? const <Object?>[])
          f.toString(),
      },
      source: (json['source'] as String?) ?? 'synthetic',
      notes: (json['notes'] as String?) ?? '',
    );
  }

  /// Every fixture under [root], sorted by id.
  static List<Fixture> loadAll(Directory root) {
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.expected.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return [for (final f in files) load(f)];
  }

  /// Compares [receipt] with the expected values, one outcome per field.
  List<FieldOutcome> evaluate(ParsedReceipt receipt) => [
    for (final field in fixtureFields)
      if (expected.containsKey(field))
        FieldOutcome(
          field: field,
          expected: expected[field]!,
          actual: fieldText(receipt, field),
          passed: _matches(field, expected[field]!, receipt),
          xfail: xfail.contains(field),
        ),
  ];

  bool _matches(String field, String want, ParsedReceipt receipt) {
    switch (field) {
      case 'merchant':
        final got = receipt.merchant?.value;
        return got != null && _normalizeName(got) == _normalizeName(want);
      case 'total' || 'subtotal' || 'tax' || 'tip':
        final got = _amountField(receipt, field)?.value;
        final digits = Currencies.of(
          expected['currency'] ?? options.defaultCurrency,
        ).minorDigits;
        return got != null && got == parseMinorUnits(want, minorDigits: digits);
      default:
        return fieldText(receipt, field)?.toLowerCase() == want.toLowerCase();
    }
  }

  static String _normalizeName(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// The result of checking one field of one fixture.
final class FieldOutcome {
  const FieldOutcome({
    required this.field,
    required this.expected,
    required this.actual,
    required this.passed,
    required this.xfail,
  });

  final String field;
  final String expected;
  final String? actual;
  final bool passed;
  final bool xfail;
}

ParseOptions parseOptionsFromJson(Map<String, Object?> json) => ParseOptions(
  defaultCurrency: json['defaultCurrency']! as String,
  dateOrder: DateOrder.values.byName(json['dateOrder']! as String),
  today: LocalDate.parseIso(json['today']! as String),
);

Map<String, Object?> parseOptionsToJson(ParseOptions options) => {
  'defaultCurrency': options.defaultCurrency,
  'dateOrder': options.dateOrder.name,
  'today': options.today.toIso(),
};

/// [field] of [receipt] as fixture text, or null when it wasn't found.
String? fieldText(ParsedReceipt receipt, String field) {
  final digits = Currencies.isWellFormed(receipt.currency.value)
      ? Currencies.of(receipt.currency.value).minorDigits
      : 2;
  return switch (field) {
    'merchant' => receipt.merchant?.value,
    'date' => receipt.date?.value.toIso(),
    'total' || 'subtotal' || 'tax' || 'tip' => switch (_amountField(
      receipt,
      field,
    )) {
      final f? => formatMinorUnits(f.value, digits),
      null => null,
    },
    'currency' => receipt.currency.value,
    'paymentMethod' => receipt.paymentMethod?.value.name,
    _ => throw ArgumentError.value(field, 'field'),
  };
}

ParsedField<int>? _amountField(ParsedReceipt receipt, String field) =>
    switch (field) {
      'total' => receipt.total,
      'subtotal' => receipt.subtotal,
      'tax' => receipt.tax,
      'tip' => receipt.tip,
      _ => null,
    };

/// `4560, 2` → `45.60`; `-320, 2` → `-3.20`; `1500, 0` → `1500`.
String formatMinorUnits(int minor, int digits) {
  final sign = minor < 0 ? '-' : '';
  final abs = minor.abs().toString().padLeft(digits + 1, '0');
  if (digits == 0) return '$sign$abs';
  final cut = abs.length - digits;
  return '$sign${abs.substring(0, cut)}.${abs.substring(cut)}';
}
