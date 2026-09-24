import '../money/amount_parser.dart';
import '../money/currency.dart';

/// A money amount found in a row of receipt text.
final class AmountToken {
  const AmountToken({
    required this.minor,
    required this.start,
    required this.end,
    required this.raw,
    this.isUnitPrice = false,
    this.currencyMarker,
  });

  /// Value in minor units; negative for discounts (`-3.20`, `3.20-`).
  final int minor;

  /// Position of the number in the row text.
  final int start;
  final int end;
  final String raw;

  /// A price per unit (`2 x 3.50`, `@ 1.899/L`) rather than a line amount.
  final bool isUnitPrice;

  /// Currency symbol or code printed next to the number (`$`, `A$`, `EUR`).
  final String? currencyMarker;

  @override
  String toString() =>
      'AmountToken($raw → $minor${isUnitPrice ? ', unit' : ''}'
      '${currencyMarker == null ? '' : ', $currencyMarker'})';
}

/// Finds money amounts in one row of normalized receipt text.
///
/// For currencies with decimals, an amount must show exactly the currency's
/// minor digits (`12.50`, `12,50`), which rules out quantities, IDs, phone
/// numbers and most dates. It also rejects times, percentages, amounts with a
/// unit (`42.15L`) and marks unit prices.
final class AmountScanner {
  const AmountScanner();

  List<AmountToken> scan(String row, Currency currency) {
    final tokens = <AmountToken>[];
    for (final m in _number.allMatches(row)) {
      final numeric = m.namedGroup('n')!;
      final start = m.start;
      final end = m.end;
      if (!_hasMinorDigits(numeric, currency.minorDigits)) continue;
      if (numeric.replaceAll(RegExp('[.,]'), '').length > 9) continue;

      final after = row.substring(end);
      final before = row.substring(0, start);
      if (_percentOrUnit.hasMatch(after)) continue;
      if (_maskedBefore.hasMatch(before)) continue;

      final value = parseMinorUnits(numeric, minorDigits: currency.minorDigits);
      if (value == null) continue;

      final negative =
          m.namedGroup('lead') != null ||
          m.namedGroup('trail') != null ||
          _minusBefore.hasMatch(before);
      tokens.add(
        AmountToken(
          minor: negative ? -value : value,
          start: start,
          end: end,
          raw: m[0]!.trim(),
          isUnitPrice:
              _unitBefore.hasMatch(before) || _unitAfter.hasMatch(after),
          currencyMarker: _markerBefore(before) ?? _markerAfter(after),
        ),
      );
    }
    return tokens;
  }

  static bool _hasMinorDigits(String numeric, int minorDigits) {
    if (minorDigits == 0) {
      return RegExp(r'^\d{1,3}(?:[.,]\d{3})*$|^\d+$').hasMatch(numeric);
    }
    return RegExp('[.,]\\d{$minorDigits}\$').hasMatch(numeric);
  }

  static final _number = RegExp(
    r'(?<![\p{L}\p{N}.,/#*])'
    r'(?<lead>\(|-(?=\d))?'
    r'(?<n>\d{1,3}(?:[.,]\d{3})+(?:[.,]\d+)?|\d+(?:[.,]\d+)?)'
    r'(?<trail>\)|-(?![\p{N}]))?'
    r'(?![\p{N}]|[.,]\d|[:/]\d)',
    unicode: true,
  );

  /// `%`, or a unit glued to the number (`42.15L`, `1.5kg`, `500ml`).
  static final _percentOrUnit = RegExp(
    r'^(?:\s*%|(?:l|L|kg|KG|g|ml|ML|lb|LB|oz|OZ|ltr|LTR|lt|Lt)(?![\p{L}])'
    r'|\s+(?:l|L|ltr|LTR|litres?|Liter|kg|KG|lbs?|gal)\b)',
    unicode: true,
  );

  /// Quantity multipliers and `@` right before the number.
  static final _unitBefore = RegExp(
    r'(?:(?:^|[\s\d])[xX×*]|@|\bSt(?:k|ck)?\.?\s*[xX×])\s*[$€£]?\s*$',
  );

  /// `/L`, `/kg`, `each`, `ea` right after the number.
  static final _unitAfter = RegExp(
    r'^\s*(?:/\s*\p{L}+|each\b|ea\b|pro\s+\p{L}+)',
    unicode: true,
  );

  static final _maskedBefore = RegExp(r'(?:[*xX•]{3,}|#)\s*$');
  static final _minusBefore = RegExp(r'(?:^|\s)-\s*[$€£]?\s*$');

  static final _symbolBefore = RegExp(
    r'(?<sym>(?:[A-Z]{1,2})?\$|€|£|¥|₹|₨|Rs\.?)\s*$',
  );
  static final _codeBefore = RegExp(r'\b(?<code>[A-Z]{3})\s*$');
  static final _markerAfterPattern = RegExp(
    r'^\s*(?<sym>€|£|\$)|^\s+(?<code>[A-Z]{3})\b',
  );

  static String? _markerBefore(String before) {
    final sym = _symbolBefore.firstMatch(before)?.namedGroup('sym');
    if (sym != null) return sym.replaceAll('.', '');
    final code = _codeBefore.firstMatch(before)?.namedGroup('code');
    return code != null && Currencies.isKnown(code) ? code : null;
  }

  static String? _markerAfter(String after) {
    final m = _markerAfterPattern.firstMatch(after);
    if (m == null) return null;
    final sym = m.namedGroup('sym');
    if (sym != null) return sym;
    final code = m.namedGroup('code');
    return code != null && Currencies.isKnown(code) ? code : null;
  }
}
