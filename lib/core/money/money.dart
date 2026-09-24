import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:receipt_parser/receipt_parser.dart';

import '../locale/locale_defaults.dart';

export 'package:receipt_parser/receipt_parser.dart'
    show Currencies, Currency, parseMinorUnits;

/// An exact amount of money: integer minor units (cents, fils, yen) plus an
/// ISO 4217 currency code. Never stored or summed as `double`.
final class Money implements Comparable<Money> {
  const Money(this.minor, this.currency);

  const Money.zero(this.currency) : minor = 0;

  final int minor;
  final String currency;

  Currency get currencyInfo => Currencies.of(currency);

  bool get isNegative => minor < 0;
  bool get isZero => minor == 0;

  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _checkSameCurrency(other);
    return Money(minor - other.minor, currency);
  }

  Money operator -() => Money(-minor, currency);

  /// Plain decimal text for CSV and fixtures: `12.50`, `-0.05`, `1500` (JPY).
  String toDecimalString() {
    final digits = currencyInfo.minorDigits;
    final abs = minor.abs().toString();
    final sign = minor < 0 ? '-' : '';
    if (digits == 0) return '$sign$abs';
    final padded = abs.padLeft(digits + 1, '0');
    final split = padded.length - digits;
    return '$sign${padded.substring(0, split)}.${padded.substring(split)}';
  }

  /// Localised display text, e.g. `$45.60` for AUD in en_AU, `A$45.60` for
  /// AUD in en_US, `12,50 €` in de_DE. Works for any device locale.
  String format(String locale) {
    final info = currencyInfo;
    final numberLocale = LocaleDefaults.numberLocaleFor(locale);
    final formatter = NumberFormat.currency(
      locale: numberLocale,
      name: info.code,
      symbol: _displaySymbol(info, locale, numberLocale),
      decimalDigits: info.minorDigits,
    );
    return formatter.format(minor / math.pow(10, info.minorDigits));
  }

  void _checkSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Cannot combine $currency and ${other.currency} amounts',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _checkSameCurrency(other);
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => '${toDecimalString()} $currency';
}

/// The local symbol for the region's own currency (`$` for AUD in Australia),
/// and an unambiguous one for foreign currencies (`A$`, `US$`, `CA$`).
String _displaySymbol(Currency currency, String locale, String numberLocale) {
  if (currency.code == LocaleDefaults.currencyFor(locale)) {
    return NumberFormat.simpleCurrency(
      locale: numberLocale,
      name: currency.code,
    ).currencySymbol;
  }
  return _internationalSymbols[currency.code] ?? currency.symbol;
}

const _internationalSymbols = {
  'ARS': r'AR$',
  'AUD': r'A$',
  'BRL': r'R$',
  'CAD': r'CA$',
  'CLP': r'CL$',
  'CNY': 'CN¥',
  'COP': r'CO$',
  'HKD': r'HK$',
  'MXN': r'MX$',
  'NZD': r'NZ$',
  'SGD': r'S$',
  'TWD': r'NT$',
  'USD': r'US$',
};
