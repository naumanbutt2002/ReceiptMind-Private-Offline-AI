import '../model/parse_options.dart';
import '../model/parsed_receipt.dart';
import '../money/currency.dart';

/// Decides the receipt's currency, before amounts are read (the number of
/// decimals depends on it).
///
/// Order of evidence: an ISO code next to an amount, an unambiguous symbol
/// (`€`, `£`, `A$`), a bare `$` (the default currency when that is a dollar
/// currency), and finally the default currency.
final class CurrencyExtractor {
  const CurrencyExtractor();

  ParsedField<String> extract(List<String> rows, ParseOptions options) {
    final defaultCode = options.defaultCurrency;
    final codes = <String, int>{};
    final symbols = <String, int>{};
    var dollars = 0;

    for (final row in rows) {
      for (final m in _codeNearNumber.allMatches(row)) {
        final code = m.namedGroup('a') ?? m.namedGroup('b');
        if (code != null && Currencies.isKnown(code)) {
          codes[code] = (codes[code] ?? 0) + 2;
        }
      }
      for (final m in _standaloneCode.allMatches(row)) {
        final code = m[1]!;
        if (Currencies.isKnown(code) && !_wordLikeCodes.contains(code)) {
          codes[code] = (codes[code] ?? 0) + 1;
        }
      }
      for (final m in _prefixedDollar.allMatches(row)) {
        final code = _dollarPrefixes[m[1]!.toUpperCase()];
        if (code != null) symbols[code] = (symbols[code] ?? 0) + 1;
      }
      for (final entry in _uniqueSymbols.entries) {
        final count = entry.key.allMatches(row).length;
        if (count > 0) {
          final code = entry.value(defaultCode);
          symbols[code] = (symbols[code] ?? 0) + count;
        }
      }
      dollars += _bareDollar.allMatches(row).length;
    }

    final code = _best(codes);
    if (code != null) {
      return ParsedField(code, confidence: 0.95, reason: 'code');
    }
    final symbol = _best(symbols);
    if (symbol != null) {
      return ParsedField(symbol, confidence: 0.9, reason: 'symbol');
    }
    final defaultIsDollar =
        Currencies.isKnown(defaultCode) &&
        Currencies.of(defaultCode).symbol == r'$';
    if (dollars > 0) {
      return defaultIsDollar
          ? ParsedField(defaultCode, confidence: 0.85, reason: 'dollar')
          : const ParsedField('USD', confidence: 0.4, reason: 'dollar');
    }
    // No symbol at all usually means the local currency.
    return ParsedField(defaultCode, confidence: 0.7, reason: 'default');
  }

  static String? _best(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  static final _codeNearNumber = RegExp(
    r'\b(?<a>[A-Z]{3})\s?[$€£]?\s?-?\d|\d\s?(?<b>[A-Z]{3})\b',
  );
  static final _standaloneCode = RegExp(r'(?<![A-Za-z])([A-Z]{3})(?![A-Za-z])');

  /// Known codes that are also common English words in capitals.
  static const _wordLikeCodes = {'TRY', 'RON', 'PHP', 'ALL', 'TOP', 'CUP'};

  static final _prefixedDollar = RegExp(
    r'(?<![A-Za-z])(A|AU|US|C|CA|NZ|HK|S|SG|R|MX|NT)\$',
  );
  static const _dollarPrefixes = {
    'A': 'AUD',
    'AU': 'AUD',
    'US': 'USD',
    'C': 'CAD',
    'CA': 'CAD',
    'NZ': 'NZD',
    'HK': 'HKD',
    'S': 'SGD',
    'SG': 'SGD',
    'R': 'BRL',
    'MX': 'MXN',
    'NT': 'TWD',
  };
  static final _bareDollar = RegExp(r'(?<![A-Za-z])\$');

  static final Map<RegExp, String Function(String defaultCode)> _uniqueSymbols =
      {
        RegExp('€'): (_) => 'EUR',
        RegExp('£'): (_) => 'GBP',
        RegExp('₹'): (_) => 'INR',
        RegExp('₪'): (_) => 'ILS',
        RegExp('₩'): (_) => 'KRW',
        RegExp('₱'): (_) => 'PHP',
        RegExp('฿'): (_) => 'THB',
        RegExp('₺'): (_) => 'TRY',
        RegExp('₫'): (_) => 'VND',
        RegExp('₦'): (_) => 'NGN',
        RegExp('¥'): (d) => d == 'CNY' ? 'CNY' : 'JPY',
        RegExp(r'₨|(?<![A-Za-z])Rs\.?(?=\s?\d)'): (d) =>
            const {'INR', 'PKR', 'LKR'}.contains(d) ? d : 'PKR',
      };
}
