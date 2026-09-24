import 'de.dart';
import 'en.dart';

/// The words the parser looks for, for one language. Lexicons are plain data:
/// adding a language means adding a file like `en.dart` and listing it in
/// [Lexicon.all].
///
/// Write keywords in lower case. Accents are folded before matching (`ä` → `a`,
/// `ß` → `ss`) and `-`/`.` count as spaces, so `Rückgeld`, `RUCKGELD` and
/// `ec-Karte` match the entries `ruckgeld` and `ec karte`.
final class Lexicon {
  const Lexicon({
    required this.languageCode,
    this.totalStrong = const [],
    this.totalWeak = const [],
    this.totalNegative = const [],
    this.subtotal = const [],
    this.tax = const [],
    this.taxIncludedStatement = const [],
    this.taxIncludedTotal = const [],
    this.tip = const [],
    this.tipSuggestion = const [],
    this.dateLabels = const [],
    this.dateNoise = const [],
    this.months = const {},
    this.merchantNoise = const [],
    this.streetWords = const [],
    this.streetSuffixes = const [],
    this.card = const [],
    this.cash = const [],
    this.paymentNoise = const [],
    this.tableNet = const [],
    this.tableGross = const [],
  });

  /// ISO 639-1 code, e.g. `en`.
  final String languageCode;

  /// Labels of the amount to pay: `total`, `amount due`, `summe`.
  final List<String> totalStrong;

  /// Labels that often, but not always, mark the total: `balance`, `amount`.
  final List<String> totalWeak;

  /// Labels of amounts that are never the total: `subtotal`, `change`, `cash`.
  final List<String> totalNegative;

  final List<String> subtotal;

  /// Tax names: `gst`, `vat`, `sales tax`, `mwst`.
  final List<String> tax;

  /// Words that turn a tax line into a statement about tax already included
  /// in the total: "Total **includes** GST 4.15".
  final List<String> taxIncludedStatement;

  /// Words that make a total line say it includes tax: "TOTAL **INC** GST".
  final List<String> taxIncludedTotal;

  final List<String> tip;

  /// Words of printed tip suggestions that are not the tip paid.
  final List<String> tipSuggestion;

  /// Labels printed next to the purchase date: `date`, `datum`.
  final List<String> dateLabels;

  /// Labels of dates that are not the purchase date: `expiry`, `valid until`.
  final List<String> dateNoise;

  /// Month names and abbreviations → month number.
  final Map<String, int> months;

  /// Header lines that are not the merchant name: `tax invoice`, `welcome`.
  final List<String> merchantNoise;

  /// Whole words that mark an address line: `street`, `rd`.
  final List<String> streetWords;

  /// Word endings that mark an address line in compound words: `strasse`.
  final List<String> streetSuffixes;

  /// Card payment words: `visa`, `eftpos`, `ec karte`.
  final List<String> card;

  /// Cash payment words: `cash`, `bar`.
  final List<String> cash;

  /// Lines that mention cards or cash but are not about the payment:
  /// loyalty cards, `cash out`.
  final List<String> paymentNoise;

  /// Column headers of the net amount in a tax summary table.
  final List<String> tableNet;

  /// Column headers of the gross amount in a tax summary table.
  final List<String> tableGross;

  static const en = englishLexicon;
  static const de = germanLexicon;

  /// Every built-in lexicon.
  static const all = [en, de];
}
