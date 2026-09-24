import '../lexicon/lexicon.dart';
import 'date_order.dart';
import 'local_date.dart';

/// Settings for one parse. Everything that depends on the user or the clock
/// comes in here, so the parser itself is deterministic.
final class ParseOptions {
  const ParseOptions({
    required this.defaultCurrency,
    required this.dateOrder,
    required this.today,
    this.lexicons = Lexicon.all,
  });

  /// ISO 4217 code used when the receipt shows no unambiguous currency.
  final String defaultCurrency;

  /// How to read ambiguous numeric dates such as `03/04/26`.
  final DateOrder dateOrder;

  /// The current date on the device; purchase dates after it are rejected.
  final LocalDate today;

  /// Keyword sets to recognise, e.g. `[Lexicon.en, Lexicon.de]`.
  final List<Lexicon> lexicons;
}
