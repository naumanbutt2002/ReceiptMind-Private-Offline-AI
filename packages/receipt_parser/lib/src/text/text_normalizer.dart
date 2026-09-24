/// Cleans OCR text before amounts and keywords are read from it.
///
/// It unifies look-alike characters (dashes, spaces, full-width digits),
/// removes stray `|` bars, joins decimals split by a space (`12. 50`) and
/// fixes letter/digit confusions, but only inside numeric tokens
/// (`1O.5O` → `10.50`, `1S.99` → `15.99`), so words are left alone.
final class TextNormalizer {
  const TextNormalizer();

  String normalize(String text) {
    var s = text;
    s = s.replaceAll(RegExp('[    　]'), ' ');
    s = s.replaceAll('\t', '  ');
    s = s.replaceAll(RegExp('[‐-―−﹣－]'), '-');
    s = s.replaceAll('＄', r'$').replaceAll('‚', ',');
    s = s.replaceAllMapped(
      RegExp('[０-９]'),
      (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFF10 + 0x30),
    );
    // Stray table borders and separators read as `|`.
    s = s.replaceAll(RegExp(r'(^|\s)\|+(?=\s|$)'), ' ');
    s = s.replaceAll(RegExp(r'(?<=\s|^)\|+(?=\d)'), '');
    // `12. 50` / `12 ,50` → `12.50`.
    s = s.replaceAllMapped(
      RegExp(r'(\d)([.,]) (\d{2})(?!\d)'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\d) ([.,])(\d{2})(?!\d)'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );
    // `S12.50` is a misread `$12.50`.
    s = s.replaceAll(
      RegExp(
        r'(?<![\p{L}\p{N}])S(?=\d{1,3}(?:[.,]\d{3})*[.,]\d{2}(?!\d))',
        unicode: true,
      ),
      r'$',
    );
    s = s.replaceAllMapped(_numericToken, (m) => _fixDigits(m[0]!));
    return s.trim();
  }

  /// A run of digits, separators and digit look-alikes that is not part of a
  /// word.
  static final _numericToken = RegExp(
    r'(?<![\p{L}\p{N}])[0-9OoIlS|][0-9OoIlS|.,]*[0-9OoIlS|](?![\p{L}\p{N}])',
    unicode: true,
  );

  static String _fixDigits(String token) {
    final realDigits = RegExp('[0-9]').allMatches(token).length;
    if (realDigits < 2 || !token.contains(RegExp('[.,]'))) return token;
    if (!token.contains(RegExp('[OoIlS|]'))) return token;
    // A leading S is more often a misread `$` than a 5; leave it.
    if (token.startsWith('S')) return token;
    final fixed = token
        .replaceAll(RegExp('[Oo]'), '0')
        .replaceAll(RegExp('[Il|]'), '1')
        .replaceAll('S', '5');
    final looksLikeAmount = RegExp(
      r'^\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,3})?$|^\d+(?:[.,]\d{1,3})?$',
    ).hasMatch(fixed);
    return looksLikeAmount ? fixed : token;
  }
}

/// Lower-cases [text] and removes accents (`ü` → `u`, `ß` → `ss`), keeping
/// digits and punctuation. Used to find month names next to numbers.
String foldAccents(String text) => text.toLowerCase().replaceAllMapped(
  RegExp('[äöüßàáâãåèéêëìíîïòóôõùúûñç]'),
  (m) => _accentFolds[m[0]!] ?? m[0]!,
);

/// Lower-cases [text] and folds it for keyword matching: accents removed
/// (`ü` → `u`, `ß` → `ss`), punctuation turned into spaces, and digits that
/// OCR put inside words turned back into letters (`T0TAL` → `total`).
String foldForKeywords(String text) {
  var s = foldAccents(text);
  s = s.replaceAllMapped(RegExp(r'[\p{L}\p{N}]+', unicode: true), (m) {
    final word = m[0]!;
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(word).length;
    if (letters < 2 || !word.contains(RegExp('[015]'))) return word;
    return word.replaceAll('0', 'o').replaceAll('1', 'l').replaceAll('5', 's');
  });
  s = s.replaceAll(RegExp(r'[^\p{L}\p{N}%$€£]+', unicode: true), ' ');
  return s.trim();
}

const _accentFolds = {
  'ä': 'a',
  'ö': 'o',
  'ü': 'u',
  'ß': 'ss',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};
