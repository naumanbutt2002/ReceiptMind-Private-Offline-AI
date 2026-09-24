import '../model/parsed_receipt.dart';
import '../text/text_normalizer.dart';
import 'parse_context.dart';

/// Finds the store name among the first rows of the receipt.
///
/// Skips header noise (`TAX INVOICE`, `WELCOME`), addresses, phone numbers,
/// URLs, tax IDs and dates, prefers the tallest and earliest text, and
/// title-cases ALL-CAPS names (`WOOLWORTHS METRO` → `Woolworths Metro`).
final class MerchantExtractor {
  const MerchantExtractor();

  static const _headerRows = 8;

  ParsedField<String>? extract(ParseContext context) {
    final candidates = <_Candidate>[];
    for (final line in context.lines.take(_headerRows)) {
      if (line.lineAmounts.isNotEmpty && candidates.isNotEmpty) break;
      final name = _candidateText(line, context);
      if (name == null) continue;
      var score = 0.5;
      final reasons = <String>['header'];
      if (context.isTall(line, factor: 1.2)) {
        score += 0.3;
        reasons.add('tall');
      }
      score += switch (candidates.length) {
        0 => 0.2,
        1 => 0.05,
        _ => 0.0,
      };
      if (name.welcome) {
        score += 0.1;
        reasons.add('welcome');
      }
      candidates.add(_Candidate(name.text, score, line.index, reasons));
    }
    if (candidates.isEmpty) {
      context.note('merchant: none found');
      return null;
    }
    final best = candidates.reduce((a, b) => b.score > a.score ? b : a);
    final name = _joinSplitName(best, candidates);
    if (name.isEmpty) return null;
    context.note('merchant: "$name" from row ${best.row}');
    return ParsedField(
      name,
      confidence: best.score.clamp(0.0, 1.0),
      rowIndex: best.row,
      reason: best.reasons.join('+'),
    );
  }

  /// A name printed over two lines (`TESCO` / `Express`) is joined when a
  /// later header line spells the two together (`Tesco Express Camden Rd`).
  static String _joinSplitName(_Candidate best, List<_Candidate> candidates) {
    final first = _clean(best.text);
    final next = candidates.where((c) => c.row == best.row + 1).firstOrNull;
    if (next == null) return first;
    final second = _clean(next.text);
    final joined = '$first $second';
    final confirmed = candidates.any(
      (c) =>
          c.row > next.row &&
          c.text.toLowerCase().startsWith(joined.toLowerCase()),
    );
    return confirmed ? joined : first;
  }

  ({String text, bool welcome})? _candidateText(
    ReceiptLine line,
    ParseContext context,
  ) {
    final v = context.vocabulary;
    var text = line.text.trim().replaceAll(_storeNumber, '');
    var folded = foldForKeywords(text);
    var welcome = false;

    final greeting = _welcome.firstMatch(text);
    if (greeting != null) {
      text = text.substring(greeting.end).trim();
      folded = folded.replaceFirst(_welcomeFolded, '').trim();
      welcome = true;
      if (text.isEmpty) return null;
    } else if (v.merchantNoise.hasMatch(folded)) {
      return null;
    }

    final letters = RegExp(r'\p{L}', unicode: true).allMatches(text).length;
    final visible = text.replaceAll(RegExp(r'\s'), '').length;
    if (letters < 2 || visible == 0 || letters / visible < 0.6) return null;
    if (RegExp(r'\d').allMatches(text).length >= 6) return null; // phone, IDs
    if (_urlOrEmail.hasMatch(text)) return null;
    if (_postcode.hasMatch(text)) return null;
    final hasDigit = text.contains(RegExp(r'\d'));
    if (hasDigit &&
        (v.streetWords.hasMatch(folded) || v.hasStreetSuffix(folded))) {
      return null;
    }
    if (RegExp(r'^\d+[a-zA-Z]?\s+\p{L}', unicode: true).hasMatch(text)) {
      return null; // "123 Main St"
    }
    if (v.dateLabels.hasMatch(folded) || _dateLike.hasMatch(text)) return null;
    return (text: text, welcome: welcome);
  }

  static String _clean(String text) {
    var s = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s*=\-_.:#|]+|[\s*=\-_.:#|]+$'), '');
    s = s.replaceAll(_storeNumber, '');
    if (s == s.toUpperCase() && s != s.toLowerCase()) s = _titleCase(s);
    return s.trim();
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        if (word.contains(RegExp(r'\d'))) return word;
        // Vowel-less words are usually acronyms: CVS, BP, DM.
        if (!word.toLowerCase().contains(RegExp('[aeiouyäöü]'))) return word;
        final lower = word.toLowerCase();
        return lower.replaceFirstMapped(
          RegExp(r'\p{L}', unicode: true),
          (m) => m[0]!.toUpperCase(),
        );
      })
      .join(' ');

  /// `#1052`, `Store 123`, `Filiale 45` at the end of a name.
  static final _storeNumber = RegExp(
    r'\s+(?:#\s*\d+|(?:store|shop|filiale|nr|no)\.?\s*#?\s*\d+)$',
    caseSensitive: false,
  );

  static final _welcome = RegExp(
    r'^\s*(?:welcome\s+to|willkommen\s+(?:bei|im|in)|herzlich\s+willkommen\s+(?:bei|im|in))\b[\s:,-]*',
    caseSensitive: false,
  );
  static final _welcomeFolded = RegExp(
    r'^(?:welcome to|willkommen (?:bei|im|in)|herzlich willkommen (?:bei|im|in))',
  );
  static final _urlOrEmail = RegExp(
    r'www\.|https?:|@|\.(?:com|net|org|de|co|uk|au|io)\b',
    caseSensitive: false,
  );
  static final _postcode = RegExp(
    r'\b(?:NSW|VIC|QLD|SA|WA|TAS|NT|ACT)\s+\d{4}\b'
    r'|\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b'
    r'|\b[A-Z]{1,2}\d[A-Z\d]?\s+\d[A-Z]{2}\b'
    r'|(?:^|\s)\d{5}\s+\p{Lu}\p{Ll}+',
    unicode: true,
  );
  static final _dateLike = RegExp(
    r'\d{1,2}[./-]\d{1,2}[./-]\d{2,4}|\d{1,2}:\d{2}',
  );
}

final class _Candidate {
  _Candidate(this.text, this.score, this.row, this.reasons);

  final String text;
  final double score;
  final int row;
  final List<String> reasons;
}
