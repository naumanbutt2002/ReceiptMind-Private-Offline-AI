/// Rule-based receipt parser for OCR text.
///
/// Pure Dart: no Flutter or plugin imports, so it can be tested with
/// `dart test` and reused by any OCR engine. The parser itself is still in
/// progress; the shared value types below are used by the app too.
library;

export 'src/model/date_order.dart';
export 'src/model/local_date.dart';
export 'src/money/amount_parser.dart';
export 'src/money/currency.dart';

/// Version of the parser package, reported in the app's OCR debug screen.
const receiptParserVersion = '0.1.0';
