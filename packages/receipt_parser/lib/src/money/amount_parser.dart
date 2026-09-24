/// Parses a human- or OCR-written amount into integer minor units.
///
/// Handles `12.50`, `12,50`, `1,234.56`, `1.234,56`, `1 234,56`, `1'234.50`,
/// `-3.20` and currency symbols or codes around the number. Returns `null` when
/// the text is not a single well-formed amount for a currency with
/// [minorDigits] decimals.
///
/// A lone `.` or `,` followed by exactly three digits is a grouping separator
/// (`1,234` = 1234), except for three-decimal currencies such as KWD, where it
/// is the decimal separator unless [decimalSeparatorHint] names the other one.
/// Extra zero decimals are accepted (`1500.00` for JPY).
int? parseMinorUnits(
  String text, {
  required int minorDigits,
  String? decimalSeparatorHint,
}) {
  // Spaces and apostrophes can group digits (1 234,56 · 1'234.50).
  var s = _stripEdges(text.replaceAll(RegExp(r"[\s\u00A0\u202F']"), ''));
  if (s.isEmpty) return null;

  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = _stripEdges(s.substring(1, s.length - 1));
  }
  if (s.startsWith('-') || s.startsWith('+')) {
    negative ^= s.startsWith('-');
    s = _stripEdges(s.substring(1));
  }
  if (s.endsWith('-')) {
    // Trailing minus, as printed on many receipts: "12.50-".
    negative = !negative;
    s = s.substring(0, s.length - 1);
  }
  if (!RegExp(r'^[0-9]([0-9.,]*[0-9])?$').hasMatch(s)) return null;

  final decimalIndex = _decimalSeparatorIndex(
    s,
    minorDigits: minorDigits,
    hint: decimalSeparatorHint,
  );
  if (decimalIndex == -2) return null;

  String integerPart;
  var fractionPart = '';
  if (decimalIndex >= 0) {
    integerPart = s.substring(0, decimalIndex);
    fractionPart = s.substring(decimalIndex + 1);
    if (fractionPart.contains(RegExp('[.,]'))) return null;
  } else {
    integerPart = s;
  }
  if (!_validGrouping(integerPart)) return null;
  integerPart = integerPart.replaceAll(RegExp('[.,]'), '');
  if (integerPart.isEmpty) integerPart = '0';

  if (fractionPart.length > minorDigits) {
    final extra = fractionPart.substring(minorDigits);
    if (extra.contains(RegExp('[1-9]'))) return null;
    fractionPart = fractionPart.substring(0, minorDigits);
  }
  fractionPart = fractionPart.padRight(minorDigits, '0');

  final value = int.tryParse(integerPart + fractionPart);
  if (value == null) return null;
  return negative ? -value : value;
}

/// Removes currency symbols, codes and tax-code letters around the number,
/// but keeps signs, parentheses and separators so malformed input still fails.
String _stripEdges(String s) => s
    .replaceAll(RegExp(r'^[^\d(+\-.,]+'), '')
    .replaceAll(RegExp(r'[^\d)\-.,]+$'), '');

/// Index of the decimal separator in [s], -1 if there is none, or -2 if the
/// separators are inconsistent.
int _decimalSeparatorIndex(
  String s, {
  required int minorDigits,
  required String? hint,
}) {
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  if (lastDot < 0 && lastComma < 0) return -1;

  if (lastDot >= 0 && lastComma >= 0) {
    // Both present: the last one is the decimal separator.
    final index = lastDot > lastComma ? lastDot : lastComma;
    final sep = s[index];
    if (_count(s, sep) > 1) return -2;
    return index;
  }

  final sep = lastDot >= 0 ? '.' : ',';
  final index = lastDot >= 0 ? lastDot : lastComma;
  if (_count(s, sep) > 1) return -1; // Repeated: grouping only (1.234.567).
  final digitsAfter = s.length - index - 1;
  if (digitsAfter == 3) {
    final isDecimal = minorDigits == 3 && (hint == null || hint == sep);
    if (!isDecimal) return -1; // 1,234 or 1.234 → grouping.
  }
  return index;
}

/// Grouping separators must split the integer into groups of three digits.
bool _validGrouping(String integerPart) {
  if (!integerPart.contains(RegExp('[.,]'))) return true;
  final groups = integerPart.split(RegExp('[.,]'));
  if (groups.first.isEmpty || groups.first.length > 3) return false;
  return groups.skip(1).every((g) => g.length == 3);
}

int _count(String s, String char) => char.allMatches(s).length;
