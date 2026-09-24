import '../text/text_normalizer.dart';
import 'lexicon.dart';

/// Matches whole keywords or phrases in text folded by [foldForKeywords].
final class KeywordMatcher {
  KeywordMatcher(Iterable<String> keywords)
    : _pattern = _compile({
        for (final k in keywords)
          if (foldForKeywords(k).isNotEmpty) foldForKeywords(k),
      });

  final RegExp? _pattern;

  static RegExp? _compile(Set<String> words) {
    if (words.isEmpty) return null;
    // Longest first, so `grand total` wins over `total`.
    final sorted = words.toList()..sort((a, b) => b.length - a.length);
    final alternatives = sorted
        .map((w) => RegExp.escape(w).replaceAll(' ', r'\s+'))
        .join('|');
    return RegExp(
      '(?<![\\p{L}\\p{N}])(?:$alternatives)(?![\\p{L}\\p{N}])',
      unicode: true,
    );
  }

  bool hasMatch(String folded) => _pattern?.hasMatch(folded) ?? false;

  /// The matched keyword, or null.
  String? firstMatch(String folded) => _pattern?.firstMatch(folded)?[0];

  Iterable<RegExpMatch> allMatches(String folded) =>
      _pattern?.allMatches(folded) ?? const [];
}

/// All lexicons of a parse compiled into matchers.
final class Vocabulary {
  factory Vocabulary.of(List<Lexicon> lexicons) =>
      _cache[lexicons] ??= Vocabulary._(lexicons);

  Vocabulary._(List<Lexicon> lexicons)
    : totalStrong = _m(lexicons, (l) => l.totalStrong),
      totalWeak = _m(lexicons, (l) => l.totalWeak),
      totalNegative = _m(lexicons, (l) => l.totalNegative),
      subtotal = _m(lexicons, (l) => l.subtotal),
      tax = _m(lexicons, (l) => l.tax),
      taxIncludedStatement = _m(lexicons, (l) => l.taxIncludedStatement),
      taxIncludedTotal = _m(lexicons, (l) => l.taxIncludedTotal),
      tip = _m(lexicons, (l) => l.tip),
      tipSuggestion = _m(lexicons, (l) => l.tipSuggestion),
      dateLabels = _m(lexicons, (l) => l.dateLabels),
      dateNoise = _m(lexicons, (l) => l.dateNoise),
      merchantNoise = _m(lexicons, (l) => l.merchantNoise),
      streetWords = _m(lexicons, (l) => l.streetWords),
      card = _m(lexicons, (l) => l.card),
      cash = _m(lexicons, (l) => l.cash),
      paymentNoise = _m(lexicons, (l) => l.paymentNoise),
      tableNet = _m(lexicons, (l) => l.tableNet),
      tableGross = _m(lexicons, (l) => l.tableGross),
      months = {
        for (final l in lexicons)
          for (final e in l.months.entries) foldForKeywords(e.key): e.value,
      },
      _streetSuffix = _suffixPattern([
        for (final l in lexicons) ...l.streetSuffixes,
      ]);

  static final _cache = Expando<Vocabulary>();

  static KeywordMatcher _m(
    List<Lexicon> lexicons,
    List<String> Function(Lexicon) pick,
  ) => KeywordMatcher([for (final l in lexicons) ...pick(l)]);

  static RegExp? _suffixPattern(List<String> suffixes) {
    if (suffixes.isEmpty) return null;
    final alternatives = suffixes.map(RegExp.escape).join('|');
    return RegExp('\\p{L}{2,}(?:$alternatives)(?![\\p{L}])', unicode: true);
  }

  final KeywordMatcher totalStrong;
  final KeywordMatcher totalWeak;
  final KeywordMatcher totalNegative;
  final KeywordMatcher subtotal;
  final KeywordMatcher tax;
  final KeywordMatcher taxIncludedStatement;
  final KeywordMatcher taxIncludedTotal;
  final KeywordMatcher tip;
  final KeywordMatcher tipSuggestion;
  final KeywordMatcher dateLabels;
  final KeywordMatcher dateNoise;
  final KeywordMatcher merchantNoise;
  final KeywordMatcher streetWords;
  final KeywordMatcher card;
  final KeywordMatcher cash;
  final KeywordMatcher paymentNoise;
  final KeywordMatcher tableNet;
  final KeywordMatcher tableGross;

  /// Folded month name → month number.
  final Map<String, int> months;

  final RegExp? _streetSuffix;

  /// Whether a folded word ends like a street name (`hauptstr`, `bahnhofstrasse`).
  bool hasStreetSuffix(String folded) =>
      _streetSuffix?.hasMatch(folded) ?? false;
}
