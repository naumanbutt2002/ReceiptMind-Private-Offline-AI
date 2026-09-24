import 'package:intl/intl.dart';

import '../date/local_date.dart';

/// Defaults derived from the device locale, used until the user changes them.
///
/// Requires `initializeDateFormatting()` to have run for [dateOrderFor].
abstract final class LocaleDefaults {
  static const fallbackCurrency = 'USD';

  /// The home currency of the locale's region: `en_AU` → AUD, `ur_PK` → PKR,
  /// `de_DE` → EUR. The region decides, not the language, and it works even
  /// for locales intl has no data for (e.g. `en_PK`).
  static String currencyFor(String locale) {
    final region = regionOf(locale);
    final byRegion = region == null ? null : _regionCurrency[region];
    if (byRegion != null) return byRegion;
    try {
      final code = NumberFormat.simpleCurrency(locale: numberLocaleFor(locale))
          .currencyName;
      if (region == null && code != null && code.length == 3) return code;
    } on ArgumentError {
      // Fall through to the fallback.
    }
    return fallbackCurrency;
  }

  /// Order of day, month and year for the locale. Uses intl's short date
  /// pattern when intl knows the locale (`en_CA` y-MM-dd → YMD), otherwise the
  /// region's convention, otherwise DMY (the most common worldwide).
  static DateOrder dateOrderFor(String locale) {
    final cleaned = _clean(locale);
    if (cleaned.isNotEmpty && DateFormat.localeExists(cleaned)) {
      final order = _orderFromPattern(DateFormat.yMd(cleaned).pattern);
      if (order != null) return order;
    }
    final region = regionOf(locale);
    if (region != null) {
      if (_mdyRegions.contains(region)) return DateOrder.mdy;
      if (_ymdRegions.contains(region)) return DateOrder.ymd;
      return DateOrder.dmy;
    }
    return DateOrder.dmy;
  }

  /// A locale intl can format numbers for: the locale itself, its language,
  /// or `en`.
  static String numberLocaleFor(String locale) => Intl.verifiedLocale(
    _clean(locale),
    NumberFormat.localeExists,
    onFailure: (_) => 'en',
  )!;

  /// The two-letter region of a locale such as `en_AU`, `zh_Hant_TW` or
  /// `en-AU`, or `null` for language-only locales.
  static String? regionOf(String locale) {
    final parts = _clean(locale).split('_');
    for (final part in parts.skip(1)) {
      if (RegExp(r'^[A-Z]{2}$').hasMatch(part)) return part;
    }
    return null;
  }

  static String _clean(String locale) =>
      locale.split('.').first.split('@').first.replaceAll('-', '_');

  static DateOrder? _orderFromPattern(String? pattern) {
    if (pattern == null) return null;
    final y = pattern.indexOf('y');
    final m = pattern.indexOf('M');
    final d = pattern.indexOf('d');
    if (y < 0 || m < 0 || d < 0) return null;
    if (y < m && m < d) return DateOrder.ymd;
    if (m < d) return DateOrder.mdy;
    return DateOrder.dmy;
  }

  static const _mdyRegions = {
    'US',
    'PR',
    'PH',
    'FM',
    'MH',
    'PW',
    'GU',
    'AS',
    'MP',
    'VI',
    'UM',
  };

  static const _ymdRegions = {'CN', 'JP', 'KR', 'KP', 'TW', 'HU', 'MN', 'LT'};

  static const _regionCurrency = {
    'AE': 'AED',
    'AR': 'ARS',
    'AT': 'EUR',
    'AU': 'AUD',
    'BD': 'BDT',
    'BE': 'EUR',
    'BH': 'BHD',
    'BR': 'BRL',
    'CA': 'CAD',
    'CH': 'CHF',
    'CL': 'CLP',
    'CN': 'CNY',
    'CO': 'COP',
    'CY': 'EUR',
    'CZ': 'CZK',
    'DE': 'EUR',
    'DK': 'DKK',
    'EE': 'EUR',
    'EG': 'EGP',
    'ES': 'EUR',
    'FI': 'EUR',
    'FR': 'EUR',
    'GB': 'GBP',
    'GR': 'EUR',
    'HK': 'HKD',
    'HR': 'EUR',
    'HU': 'HUF',
    'ID': 'IDR',
    'IE': 'EUR',
    'IL': 'ILS',
    'IN': 'INR',
    'IS': 'ISK',
    'IT': 'EUR',
    'JO': 'JOD',
    'JP': 'JPY',
    'KE': 'KES',
    'KR': 'KRW',
    'KW': 'KWD',
    'LI': 'CHF',
    'LK': 'LKR',
    'LT': 'EUR',
    'LU': 'EUR',
    'LV': 'EUR',
    'MT': 'EUR',
    'MX': 'MXN',
    'MY': 'MYR',
    'NG': 'NGN',
    'NL': 'EUR',
    'NO': 'NOK',
    'NZ': 'NZD',
    'OM': 'OMR',
    'PH': 'PHP',
    'PK': 'PKR',
    'PL': 'PLN',
    'PT': 'EUR',
    'QA': 'QAR',
    'RO': 'RON',
    'SA': 'SAR',
    'SE': 'SEK',
    'SG': 'SGD',
    'SI': 'EUR',
    'SK': 'EUR',
    'TH': 'THB',
    'TR': 'TRY',
    'TW': 'TWD',
    'UA': 'UAH',
    'US': 'USD',
    'VN': 'VND',
    'ZA': 'ZAR',
  };
}
