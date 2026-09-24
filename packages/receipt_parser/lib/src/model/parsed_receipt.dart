import 'local_date.dart';

/// How the receipt was paid, when the receipt says so.
enum PaymentMethod { card, cash }

/// One extracted value with how sure the parser is and where it came from.
final class ParsedField<T extends Object> {
  const ParsedField(
    this.value, {
    required this.confidence,
    required this.reason,
    this.rowIndex,
  });

  final T value;

  /// 0–1. The review screen flags fields below 0.6.
  final double confidence;

  /// Index into [ParsedReceipt.rows] of the row the value was read from.
  final int? rowIndex;

  /// Short machine-readable explanation, e.g. `keyword:total`.
  final String reason;

  @override
  String toString() =>
      '$value (${confidence.toStringAsFixed(2)}, $reason'
      '${rowIndex == null ? '' : ', row $rowIndex'})';
}

/// One visual row of the receipt after layout reconstruction.
final class ReceiptRowText {
  const ReceiptRowText(this.index, this.text, {this.height});

  final int index;
  final String text;

  /// Text height in pixels when the OCR engine reported boxes.
  final double? height;

  @override
  String toString() => '$index: $text';
}

/// Everything the rule parser found on a receipt. Amounts are integer minor
/// units in [currency].
final class ParsedReceipt {
  const ParsedReceipt({
    required this.currency,
    required this.rows,
    this.merchant,
    this.date,
    this.total,
    this.subtotal,
    this.tax,
    this.tip,
    this.paymentMethod,
    this.taxIncluded = false,
    this.trace = const [],
  });

  final ParsedField<String>? merchant;
  final ParsedField<LocalDate>? date;
  final ParsedField<int>? total;
  final ParsedField<int>? subtotal;
  final ParsedField<int>? tax;
  final ParsedField<int>? tip;

  /// Always set: falls back to the default currency with low confidence.
  final ParsedField<String> currency;
  final ParsedField<PaymentMethod>? paymentMethod;

  /// Whether the tax is included in the prices ("Total includes GST 4.15"),
  /// so the total is not expected to equal subtotal + tax.
  final bool taxIncluded;

  final List<ReceiptRowText> rows;

  /// Human-readable notes on the decisions made, for the OCR debug screen.
  final List<String> trace;

  /// Mean confidence of the three key fields (total, date, merchant); a
  /// missing field counts as 0.
  double get overallConfidence =>
      ((total?.confidence ?? 0) +
          (date?.confidence ?? 0) +
          (merchant?.confidence ?? 0)) /
      3;
}
