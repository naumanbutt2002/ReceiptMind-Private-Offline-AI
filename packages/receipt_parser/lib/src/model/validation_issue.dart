/// Which field a [ValidationIssue] is about.
enum ReceiptField {
  merchant,
  date,
  total,
  subtotal,
  tax,
  tip,
  currency,
  paymentMethod,
}

/// What is wrong. The app turns these codes into localised messages.
enum IssueCode {
  /// No total was found.
  missingTotal,

  /// The total is zero or negative.
  nonPositiveTotal,

  /// Total ≠ subtotal + tax + tip (and the tax isn't included in prices).
  totalMismatch,

  /// The tax is not smaller than the total.
  taxNotLessThanTotal,

  /// No purchase date was found.
  missingDate,

  /// The purchase date is after today.
  futureDate,

  /// The purchase date is more than two years ago.
  oldDate,

  /// The currency code is not one the app knows.
  unknownCurrency,

  /// The parser isn't sure about this value.
  lowConfidence,
}

enum IssueSeverity { info, warning, error }

final class ValidationIssue {
  const ValidationIssue(this.field, this.code, this.severity);

  final ReceiptField field;
  final IssueCode code;
  final IssueSeverity severity;

  @override
  bool operator ==(Object other) =>
      other is ValidationIssue &&
      other.field == field &&
      other.code == code &&
      other.severity == severity;

  @override
  int get hashCode => Object.hash(field, code, severity);

  @override
  String toString() => '${severity.name}: ${field.name} ${code.name}';
}
