import 'model/local_date.dart';
import 'model/parse_options.dart';
import 'model/parsed_receipt.dart';
import 'model/validation_issue.dart';
import 'money/currency.dart';

/// Checks a parsed receipt for values that don't add up. The review screen
/// shows the issues next to the fields.
final class ReceiptValidator {
  const ReceiptValidator();

  /// Fields below this confidence get a [IssueCode.lowConfidence] issue.
  static const lowConfidence = 0.6;

  /// Allowed rounding difference between the total and its parts.
  static const toleranceMinor = 2;

  List<ValidationIssue> validate(ParsedReceipt receipt, ParseOptions options) {
    final issues = <ValidationIssue>[];
    void add(ReceiptField field, IssueCode code, IssueSeverity severity) =>
        issues.add(ValidationIssue(field, code, severity));

    final total = receipt.total?.value;
    if (total == null) {
      add(ReceiptField.total, IssueCode.missingTotal, IssueSeverity.error);
    } else if (total <= 0) {
      add(ReceiptField.total, IssueCode.nonPositiveTotal, IssueSeverity.error);
    } else {
      final subtotal = receipt.subtotal?.value;
      final tax = receipt.tax?.value ?? 0;
      final tip = receipt.tip?.value ?? 0;
      if (subtotal != null && !receipt.taxIncluded) {
        final exclusive = (total - (subtotal + tax + tip)).abs();
        final inclusive = (total - (subtotal + tip)).abs();
        if (exclusive > toleranceMinor && inclusive > toleranceMinor) {
          add(
            ReceiptField.total,
            IssueCode.totalMismatch,
            IssueSeverity.warning,
          );
        }
      }
      if (receipt.tax != null && receipt.tax!.value >= total) {
        add(
          ReceiptField.tax,
          IssueCode.taxNotLessThanTotal,
          IssueSeverity.error,
        );
      }
    }

    final date = receipt.date?.value;
    if (date == null) {
      add(ReceiptField.date, IssueCode.missingDate, IssueSeverity.warning);
    } else if (date.isAfter(options.today)) {
      add(ReceiptField.date, IssueCode.futureDate, IssueSeverity.error);
    } else if (date.isBefore(_yearsBefore(options.today, 2))) {
      add(ReceiptField.date, IssueCode.oldDate, IssueSeverity.warning);
    }

    if (!Currencies.isKnown(receipt.currency.value)) {
      add(
        ReceiptField.currency,
        IssueCode.unknownCurrency,
        IssueSeverity.warning,
      );
    }

    final fields = <ReceiptField, ParsedField<Object>?>{
      ReceiptField.merchant: receipt.merchant,
      ReceiptField.date: receipt.date,
      ReceiptField.total: receipt.total,
      ReceiptField.subtotal: receipt.subtotal,
      ReceiptField.tax: receipt.tax,
      ReceiptField.tip: receipt.tip,
      ReceiptField.currency: receipt.currency,
      ReceiptField.paymentMethod: receipt.paymentMethod,
    };
    fields.forEach((field, value) {
      if (value != null && value.confidence < lowConfidence) {
        add(field, IssueCode.lowConfidence, IssueSeverity.info);
      }
    });
    return issues;
  }

  static LocalDate _yearsBefore(LocalDate date, int years) {
    final day = date.month == 2 && date.day == 29 ? 28 : date.day;
    return LocalDate(date.year - years, date.month, day);
  }
}
