import '../amount/amount_scanner.dart';
import '../layout/row_builder.dart';
import '../lexicon/vocabulary.dart';
import '../model/ocr_document.dart';
import '../model/parse_options.dart';
import '../model/parsed_receipt.dart';
import '../money/currency.dart';
import '../text/text_normalizer.dart';
import 'currency_extractor.dart';

/// One receipt row prepared for the extractors.
final class ReceiptLine {
  ReceiptLine({
    required this.index,
    required this.text,
    required this.folded,
    required this.amounts,
    this.height,
  });

  final int index;

  /// Normalized text (digits and punctuation intact).
  final String text;

  /// Text folded for keyword matching.
  final String folded;

  /// Money amounts on the row, left to right.
  final List<AmountToken> amounts;

  final double? height;

  /// Amounts that are line amounts, not unit prices.
  Iterable<AmountToken> get lineAmounts => amounts.where((a) => !a.isUnitPrice);

  /// The right-most line amount: on receipts the value column is on the right.
  AmountToken? get lastAmount {
    final list = lineAmounts.toList();
    return list.isEmpty ? null : list.last;
  }

  bool get hasLetters => RegExp(r'\p{L}{2,}', unicode: true).hasMatch(folded);

  @override
  String toString() => '$index: $text';
}

/// Everything the extractors share during one parse.
final class ParseContext {
  ParseContext({
    required this.lines,
    required this.rows,
    required this.options,
    required this.vocabulary,
    required this.currencyField,
    required this.currency,
  }) : medianHeight = _median([
         for (final l in lines)
           if (l.height != null) l.height!,
       ]);

  /// Rebuilds rows, normalizes their text, decides the currency and scans
  /// amounts: the shared first half of every parse.
  factory ParseContext.build(OcrDocument document, ParseOptions options) {
    final rows = const RowBuilder().build(document);
    const normalizer = TextNormalizer();
    final texts = [for (final r in rows) normalizer.normalize(r.text)];
    final currencyField = const CurrencyExtractor().extract(texts, options);
    final currency = Currencies.isWellFormed(currencyField.value)
        ? Currencies.of(currencyField.value)
        : Currencies.of(options.defaultCurrency);
    const scanner = AmountScanner();
    return ParseContext(
      lines: [
        for (final (i, row) in rows.indexed)
          ReceiptLine(
            index: i,
            text: texts[i],
            folded: foldForKeywords(texts[i]),
            amounts: scanner.scan(texts[i], currency),
            height: row.height,
          ),
      ],
      rows: rows,
      options: options,
      vocabulary: Vocabulary.of(options.lexicons),
      currencyField: currencyField,
      currency: currency,
    )..note('currency: ${currencyField.value} (${currencyField.reason})');
  }

  final List<ReceiptLine> lines;
  final List<ReceiptRowText> rows;
  final ParseOptions options;
  final Vocabulary vocabulary;

  /// The detected currency with its confidence.
  final ParsedField<String> currencyField;

  /// The currency amounts are read in.
  final Currency currency;

  /// Median text height, when the OCR engine reported boxes.
  final double? medianHeight;

  final List<String> trace = [];

  /// Whether [line] is printed noticeably larger than most rows.
  bool isTall(ReceiptLine line, {double factor = 1.3}) {
    final h = line.height;
    final median = medianHeight;
    return h != null && median != null && median > 0 && h >= median * factor;
  }

  /// Index of the first row that ends the item list: a subtotal, total or
  /// tax row with an amount. Null when there is none.
  late final int? itemsEnd = () {
    final v = vocabulary;
    for (final line in lines) {
      if (line.lastAmount == null) continue;
      final f = line.folded;
      if (v.subtotal.hasMatch(f) ||
          v.totalStrong.hasMatch(f) ||
          v.tax.hasMatch(f)) {
        return line.index;
      }
    }
    return null;
  }();

  /// Whether [line] comes after the item list (or, without a recognisable
  /// end of the item list, in the lower half of the receipt).
  bool isAfterItems(ReceiptLine line) {
    final end = itemsEnd;
    return end == null ? position(line) >= 0.5 : line.index >= end;
  }

  /// 0 at the top of the receipt, 1 at the bottom.
  double position(ReceiptLine line) =>
      lines.length <= 1 ? 0 : line.index / (lines.length - 1);

  void note(String message) => trace.add(message);

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    values.sort();
    return values[values.length ~/ 2];
  }
}
