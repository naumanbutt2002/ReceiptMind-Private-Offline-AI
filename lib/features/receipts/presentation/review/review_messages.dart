import 'dart:io';

import 'package:intl/intl.dart';
import 'package:receipt_parser/receipt_parser.dart' show IssueCode;

import '../../../../core/locale/locale_defaults.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_input.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The most useful issues first: a concrete problem beats "check this".
const _issuePriority = [
  IssueCode.totalMismatch,
  IssueCode.taxNotLessThanTotal,
  IssueCode.nonPositiveTotal,
  IssueCode.missingTotal,
  IssueCode.missingDate,
  IssueCode.futureDate,
  IssueCode.oldDate,
  IssueCode.unknownCurrency,
  IssueCode.lowConfidence,
];

/// Helper text for a field flagged with [codes], or `null` if there are none.
String? reviewWarningText(AppLocalizations l10n, List<IssueCode> codes) {
  if (codes.isEmpty) return null;
  final code = _issuePriority.firstWhere(
    codes.contains,
    orElse: () => codes.first,
  );
  return switch (code) {
    IssueCode.totalMismatch => l10n.fieldWarningTotalMismatch,
    IssueCode.taxNotLessThanTotal => l10n.fieldWarningTaxTooHigh,
    IssueCode.nonPositiveTotal => l10n.fieldWarningNonPositiveTotal,
    IssueCode.missingTotal => l10n.fieldWarningMissingTotal,
    IssueCode.missingDate => l10n.fieldWarningMissingDate,
    IssueCode.futureDate => l10n.fieldWarningFutureDate,
    IssueCode.oldDate => l10n.fieldWarningOldDate,
    IssueCode.unknownCurrency => l10n.fieldWarningUnknownCurrency,
    IssueCode.lowConfidence => l10n.fieldWarningCheck,
  };
}

/// Amount text for an editable field: plain digits with the locale's decimal
/// separator and no grouping, so [MoneyInput.parse] reads it back exactly
/// (`12.50` in en_AU, `12,50` in de_DE, `1500` for JPY).
String amountFieldText(int minor, String currency, String locale) {
  final text = Money(minor, currency).toDecimalString();
  final separator = NumberFormat.decimalPattern(
    LocaleDefaults.numberLocaleFor(locale),
  ).symbols.DECIMAL_SEP;
  return separator == '.' ? text : text.replaceFirst('.', separator);
}

/// Parses an amount field: `null` for empty text, [AmountText.invalid] when it
/// can't be read.
AmountText parseAmountField(String text, String currency, String locale) {
  if (text.trim().isEmpty) return const AmountText.empty();
  final money = MoneyInput.parse(text, currency: currency, locale: locale);
  return money == null
      ? const AmountText.invalid()
      : AmountText.value(money.minor);
}

/// The result of [parseAmountField].
final class AmountText {
  const AmountText.empty() : minor = null, isValid = true;
  const AmountText.invalid() : minor = null, isValid = false;
  const AmountText.value(int this.minor) : isValid = true;

  /// Minor units, or `null` when the field is empty or invalid.
  final int? minor;
  final bool isValid;

  bool get isEmpty => isValid && minor == null;
}

/// An example amount for error messages: `12.50`, `12,50`, `12` (JPY) or
/// `12.500` (KWD) in the locale's format.
String amountExample(String currency, String locale) {
  final digits = Currencies.of(currency).minorDigits;
  var minor = 12;
  for (var i = 0; i < digits; i++) {
    minor = minor * 10 + (i == 0 ? 5 : 0);
  }
  return amountFieldText(minor, currency, locale);
}

/// The text of an amount field after the currency changes from [from] to
/// [to], so the value stays the same: `12.500` KWD → `12.50` AUD. Without
/// this, `12.500` would be read as twelve thousand five hundred in a
/// two-decimal currency. Returns `null` (keep the text as typed) when the
/// field is empty or unreadable, or when the value can't be written exactly
/// in [to] (`12.50` → JPY); the field's validator then explains the problem.
String? convertAmountFieldText(
  String text, {
  required String from,
  required String to,
  required String locale,
}) {
  final parsed = parseAmountField(text, from, locale);
  final minor = parsed.minor;
  if (minor == null) return null;
  final fromDigits = Currencies.of(from).minorDigits;
  final toDigits = Currencies.of(to).minorDigits;
  if (fromDigits == toDigits) return null;
  final int converted;
  if (toDigits > fromDigits) {
    converted = minor * _pow10(toDigits - fromDigits);
  } else {
    final factor = _pow10(fromDigits - toDigits);
    if (minor % factor != 0) return null;
    converted = minor ~/ factor;
  }
  return amountFieldText(converted, to, locale);
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}

/// Whether a failed save was caused by a full disk: `ENOSPC` (errno 28 on
/// Android and iOS) from the file system, or SQLite's "database or disk is
/// full".
bool isStorageFullError(Object error) {
  if (error is FileSystemException && error.osError?.errorCode == 28) {
    return true;
  }
  final text = error.toString().toLowerCase();
  return text.contains('no space left') ||
      text.contains('disk is full') ||
      text.contains('sqlite_full');
}
