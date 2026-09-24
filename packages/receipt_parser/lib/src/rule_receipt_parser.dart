import 'extract/date_extractor.dart';
import 'extract/merchant_extractor.dart';
import 'extract/parse_context.dart';
import 'extract/payment_extractor.dart';
import 'extract/tax_extractor.dart';
import 'extract/total_extractor.dart';
import 'model/ocr_document.dart';
import 'model/parse_options.dart';
import 'model/parsed_receipt.dart';

/// Reads merchant, date, amounts, currency and payment method from OCR text
/// with rules. Deterministic and fast; every decision is recorded in
/// [ParsedReceipt.trace].
final class RuleReceiptParser {
  const RuleReceiptParser();

  ParsedReceipt parse(OcrDocument document, ParseOptions options) {
    final context = ParseContext.build(document, options);
    final taxes = const TaxExtractor().extract(context);
    final total = const TotalExtractor().extract(context, taxes);
    final merchant = const MerchantExtractor().extract(context);
    final date = const DateExtractor().extract(context);
    final payment = const PaymentExtractor().extract(context, total?.value);
    return ParsedReceipt(
      currency: context.currencyField,
      rows: context.rows,
      merchant: merchant,
      date: date,
      total: total,
      subtotal: taxes.subtotal,
      tax: taxes.tax,
      tip: taxes.tip,
      taxIncluded: taxes.taxIncluded,
      paymentMethod: payment,
      trace: List.unmodifiable(context.trace),
    );
  }
}
