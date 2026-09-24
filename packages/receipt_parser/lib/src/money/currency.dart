/// An ISO 4217 currency with the data the app and parser need.
final class Currency {
  const Currency(this.code, this.minorDigits, this.symbol);

  /// ISO 4217 code, e.g. `AUD`.
  final String code;

  /// Digits after the decimal separator (JPY 0, USD 2, KWD 3).
  final int minorDigits;

  /// Common local symbol, e.g. `$`, `€`, `Rs`. Several currencies share `$`.
  final String symbol;

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

/// The currencies ReceiptMind knows by name. Unknown but well-formed ISO codes
/// still work through [Currencies.of] with 2 minor digits.
abstract final class Currencies {
  static const List<Currency> all = [
    Currency('AED', 2, 'د.إ'),
    Currency('ARS', 2, r'$'),
    Currency('AUD', 2, r'$'),
    Currency('BDT', 2, '৳'),
    Currency('BHD', 3, 'BD'),
    Currency('BRL', 2, r'R$'),
    Currency('CAD', 2, r'$'),
    Currency('CHF', 2, 'CHF'),
    Currency('CLP', 0, r'$'),
    Currency('CNY', 2, '¥'),
    Currency('COP', 2, r'$'),
    Currency('CZK', 2, 'Kč'),
    Currency('DKK', 2, 'kr'),
    Currency('EGP', 2, 'E£'),
    Currency('EUR', 2, '€'),
    Currency('GBP', 2, '£'),
    Currency('HKD', 2, r'$'),
    Currency('HUF', 2, 'Ft'),
    Currency('IDR', 2, 'Rp'),
    Currency('ILS', 2, '₪'),
    Currency('INR', 2, '₹'),
    Currency('ISK', 0, 'kr'),
    Currency('JOD', 3, 'JD'),
    Currency('JPY', 0, '¥'),
    Currency('KES', 2, 'KSh'),
    Currency('KRW', 0, '₩'),
    Currency('KWD', 3, 'KD'),
    Currency('LKR', 2, 'Rs'),
    Currency('MXN', 2, r'$'),
    Currency('MYR', 2, 'RM'),
    Currency('NGN', 2, '₦'),
    Currency('NOK', 2, 'kr'),
    Currency('NZD', 2, r'$'),
    Currency('OMR', 3, 'OMR'),
    Currency('PHP', 2, '₱'),
    Currency('PKR', 2, 'Rs'),
    Currency('PLN', 2, 'zł'),
    Currency('QAR', 2, 'QR'),
    Currency('RON', 2, 'lei'),
    Currency('SAR', 2, 'SR'),
    Currency('SEK', 2, 'kr'),
    Currency('SGD', 2, r'$'),
    Currency('THB', 2, '฿'),
    Currency('TRY', 2, '₺'),
    Currency('TWD', 2, r'$'),
    Currency('UAH', 2, '₴'),
    Currency('USD', 2, r'$'),
    Currency('VND', 0, '₫'),
    Currency('ZAR', 2, 'R'),
  ];

  static final Map<String, Currency> _byCode = {for (final c in all) c.code: c};

  static final _isoCode = RegExp(r'^[A-Z]{3}$');

  /// Whether [code] is a currency in [all].
  static bool isKnown(String code) => _byCode.containsKey(code);

  /// Whether [code] looks like an ISO 4217 code (three capital letters).
  static bool isWellFormed(String code) => _isoCode.hasMatch(code);

  /// The currency for [code]. Unknown well-formed codes get 2 minor digits and
  /// the code as symbol; malformed codes throw [ArgumentError].
  static Currency of(String code) {
    final known = _byCode[code];
    if (known != null) return known;
    if (!isWellFormed(code)) {
      throw ArgumentError.value(code, 'code', 'Not an ISO 4217 code');
    }
    return Currency(code, 2, code);
  }
}
