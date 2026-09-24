import '../model/date_order.dart';
import '../model/local_date.dart';
import '../model/parsed_receipt.dart';
import '../text/text_normalizer.dart';
import 'parse_context.dart';

/// Finds the purchase date.
///
/// Reads `dd/mm/yyyy`, `dd.mm.yy`, `yyyy-mm-dd`, `mm/dd/yy`, `12 Sep 2026`,
/// `Sep 12, 2026` and `12-SEP-26`. An ambiguous date (both parts ≤ 12) follows
/// [ParseOptions.dateOrder]. Dates after today or more than 10 years old are
/// rejected. A date next to a `Date` label or a time scores higher, one next
/// to `expiry` or `valid until` much lower.
final class DateExtractor {
  const DateExtractor();

  ParsedField<LocalDate>? extract(ParseContext context) {
    final options = context.options;
    final oldest = LocalDate(
      options.today.year - 10,
      options.today.month,
      options.today.month == 2 && options.today.day == 29
          ? 28
          : options.today.day,
    );
    _Candidate? best;
    for (final line in context.lines) {
      for (final found in _findDates(line.text, context)) {
        final date = found.date;
        if (date.isAfter(options.today) || date.isBefore(oldest)) continue;
        var score = 0.7;
        final reasons = <String>[found.kind];
        if (context.vocabulary.dateLabels.hasMatch(line.folded)) {
          score += 0.2;
          reasons.add('label');
        }
        if (_time.hasMatch(line.text)) {
          score += 0.1;
          reasons.add('time');
        }
        if (context.vocabulary.dateNoise.hasMatch(line.folded)) {
          score -= 0.4;
          reasons.add('noise');
        }
        // Ambiguous dates follow the user's date order, which is right on
        // local receipts: a small penalty, so they aren't flagged by default.
        if (found.ambiguous) {
          score -= 0.05;
          reasons.add('ambiguous');
        }
        // Top or bottom are both common; slightly prefer the top.
        score -= 0.05 * context.position(line);
        if (best == null || score > best.score) {
          best = _Candidate(date, score, line.index, reasons.join('+'));
        }
      }
    }
    if (best == null) {
      context.note('date: none found');
      return null;
    }
    context.note('date: ${best.date} from row ${best.row} (${best.reason})');
    return ParsedField(
      best.date,
      confidence: best.score.clamp(0.0, 1.0),
      rowIndex: best.row,
      reason: best.reason,
    );
  }

  Iterable<_Found> _findDates(String text, ParseContext context) sync* {
    final order = context.options.dateOrder;
    for (final m in _ymd.allMatches(text)) {
      final date = _date(int.parse(m[1]!), int.parse(m[3]!), int.parse(m[4]!));
      if (date != null) yield _Found(date, 'ymd', ambiguous: false);
    }
    for (final m in _numeric.allMatches(text)) {
      final a = int.parse(m[1]!);
      final b = int.parse(m[3]!);
      final year = _year(m[4]!);
      final dmy = _date(year, b, a);
      final mdy = _date(year, a, b);
      if (dmy != null && mdy != null && a != b) {
        final preferMdy = order == DateOrder.mdy;
        yield _Found(
          preferMdy ? mdy : dmy,
          preferMdy ? 'mdy' : 'dmy',
          ambiguous: true,
        );
      } else if (dmy != null) {
        yield _Found(dmy, 'dmy', ambiguous: false);
      } else if (mdy != null) {
        yield _Found(mdy, 'mdy', ambiguous: false);
      }
    }

    final lower = foldAccents(text);
    final months = context.vocabulary.months;
    if (months.isEmpty) return;
    for (final m in _dayMonthYear(months).allMatches(lower)) {
      final month = _month(m[2]!, months);
      if (month == null) continue;
      final date = _date(_year(m[3]!), month, int.parse(m[1]!));
      if (date != null) yield _Found(date, 'text', ambiguous: false);
    }
    for (final m in _monthDayYear(months).allMatches(lower)) {
      final month = _month(m[1]!, months);
      if (month == null) continue;
      final date = _date(_year(m[3]!), month, int.parse(m[2]!));
      if (date != null) yield _Found(date, 'text', ambiguous: false);
    }
  }

  static int _year(String text) {
    final y = int.parse(text);
    return text.length == 2 ? 2000 + y : y;
  }

  static int? _month(String word, Map<String, int> months) {
    final w = word.replaceAll('.', '');
    if (months.containsKey(w)) return months[w];
    // Longer spellings of an abbreviation, e.g. `sept.` or `septembre`.
    for (final e in months.entries) {
      if (e.key.length >= 3 && w.startsWith(e.key)) return e.value;
    }
    return null;
  }

  static LocalDate? _date(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return LocalDate(year, month, day);
    } on ArgumentError {
      return null;
    }
  }

  static final _ymd = RegExp(
    r'(?<!\d)(\d{4})([./-])(\d{1,2})\2(\d{1,2})(?!\d)',
  );
  static final _numeric = RegExp(
    r'(?<![\d.,])(\d{1,2})([./-])(\d{1,2})\2(\d{4}|\d{2})(?![\d]|[.,]\d)',
  );
  static final _time = RegExp(r'(?<!\d)\d{1,2}:\d{2}(?!\d)');

  static final _patternCache = Expando<(RegExp, RegExp)>();

  static (RegExp, RegExp) _patterns(Map<String, int> months) =>
      _patternCache[months] ??= () {
        final names =
            (months.keys.toList()..sort((a, b) => b.length - a.length))
                .map(RegExp.escape)
                .join('|');
        final month = '((?:$names)[a-z]*\\.?)';
        return (
          RegExp(
            '(?<![\\d])(\\d{1,2})(?:st|nd|rd|th)?\\.?[\\s/-]*$month'
            '[\\s/,.-]*(\\d{4}|\\d{2})(?!\\d)',
          ),
          RegExp(
            '(?<![a-z])$month\\s*(\\d{1,2})(?:st|nd|rd|th)?,?\\s*'
            r'(\d{4}|\d{2})(?!\d)',
          ),
        );
      }();

  static RegExp _dayMonthYear(Map<String, int> months) => _patterns(months).$1;
  static RegExp _monthDayYear(Map<String, int> months) => _patterns(months).$2;
}

final class _Found {
  const _Found(this.date, this.kind, {required this.ambiguous});

  final LocalDate date;
  final String kind;
  final bool ambiguous;
}

final class _Candidate {
  const _Candidate(this.date, this.score, this.row, this.reason);

  final LocalDate date;
  final double score;
  final int row;
  final String reason;
}
