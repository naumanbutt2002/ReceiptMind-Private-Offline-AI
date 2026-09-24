/// Rule-based receipt parser for OCR text.
///
/// Pure Dart: no Flutter or plugin imports, so it can be tested with
/// `dart test` and reused by any OCR engine. Feed it an [OcrDocument] and
/// [ParseOptions]; [RuleReceiptParser] returns a [ParsedReceipt] and
/// [ReceiptValidator] lists what doesn't add up.
library;

export 'src/lexicon/lexicon.dart';
export 'src/model/date_order.dart';
export 'src/model/local_date.dart';
export 'src/model/ocr_document.dart';
export 'src/model/parse_options.dart';
export 'src/model/parsed_receipt.dart';
export 'src/model/validation_issue.dart';
export 'src/money/amount_parser.dart';
export 'src/money/currency.dart';
export 'src/receipt_validator.dart';
export 'src/rule_receipt_parser.dart';

/// Version of the parser package, reported in the app's OCR debug screen.
const receiptParserVersion = '0.1.0';
