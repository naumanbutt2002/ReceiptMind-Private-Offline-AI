import 'package:receipt_parser/receipt_parser.dart';
import 'package:receipt_parser/src/extract/parse_context.dart';

final today = LocalDate(2026, 9, 24);

ParseOptions options({
  String currency = 'AUD',
  DateOrder dateOrder = DateOrder.dmy,
}) =>
    ParseOptions(defaultCurrency: currency, dateOrder: dateOrder, today: today);

/// A parse context for plain receipt text (one row per line).
ParseContext contextFor(String text, {ParseOptions? opts}) =>
    ParseContext.build(OcrDocument.fromPlainText(text), opts ?? options());

ParsedReceipt parseText(String text, {ParseOptions? opts}) =>
    const RuleReceiptParser().parse(
      OcrDocument.fromPlainText(text),
      opts ?? options(),
    );
