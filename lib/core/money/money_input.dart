import 'package:intl/intl.dart';

import '../locale/locale_defaults.dart';
import 'money.dart';

/// Parses what a user types into an amount field, using the locale's decimal
/// separator to resolve ambiguous input such as `12,345` for KWD.
abstract final class MoneyInput {
  static Money? parse(
    String text, {
    required String currency,
    required String locale,
  }) {
    final minor = parseMinorUnits(
      text,
      minorDigits: Currencies.of(currency).minorDigits,
      decimalSeparatorHint: _decimalSeparator(locale),
    );
    return minor == null ? null : Money(minor, currency);
  }

  static String _decimalSeparator(String locale) {
    return NumberFormat.decimalPattern(LocaleDefaults.numberLocaleFor(locale))
        .symbols
        .DECIMAL_SEP;
  }
}
