import '../amount/amount_scanner.dart';
import '../model/parsed_receipt.dart';
import 'parse_context.dart';
import 'tax_extractor.dart';

/// Finds the amount paid.
///
/// Every row with an amount is a candidate. Scores come from keywords (strong
/// `TOTAL`/`SUMME`, weak `BALANCE`), negative keywords (`SUBTOTAL`, `CHANGE`,
/// `CASH`, `SAVINGS`, tax lines), position, text height, and consistency with
/// the subtotal, tax, tip and card payment. Without any keyword the largest
/// plausible amount is used, with low confidence.
final class TotalExtractor {
  const TotalExtractor();

  ParsedField<int>? extract(ParseContext context, TaxResult taxes) {
    final v = context.vocabulary;
    final candidates = <_Candidate>[];
    final paymentAmounts = _paymentAmounts(context);
    final expected = _expectedTotals(taxes);

    for (final line in context.lines) {
      final f = line.folded;
      final strong = v.totalStrong.hasMatch(f);
      final weak = v.totalWeak.hasMatch(f);
      if (!strong && !weak) continue;
      final taxKind = classifyTaxRow(line, context);
      if (taxKind == TaxRowKind.tax ||
          taxKind == TaxRowKind.includedStatement) {
        continue;
      }
      if (_isNegative(line, context)) continue;

      final amount = line.lastAmount ?? _amountOnNextRow(line, context);
      if (amount == null || amount.minor <= 0) continue;

      var score = strong ? 0.6 : 0.3;
      final reasons = [
        strong ? 'keyword:${v.totalStrong.firstMatch(f)}' : 'weak',
      ];
      if (context.position(line) >= 0.4) score += 0.1;
      final subtotalRow = taxes.subtotal?.rowIndex;
      if (subtotalRow != null && line.index < subtotalRow) {
        score -= 0.3; // an item such as "TOTAL CEREAL" above the subtotal
        reasons.add('above-subtotal');
      }
      if (context.isTall(line)) {
        score += 0.15;
        reasons.add('tall');
      }
      if (expected.contains(amount.minor)) {
        score += 0.2;
        reasons.add('consistent');
      }
      if (paymentAmounts.contains(amount.minor)) {
        score += 0.1;
        reasons.add('paid');
      }
      candidates.add(_Candidate(amount.minor, score, line.index, reasons));
    }

    if (candidates.isNotEmpty) {
      // Several total rows: a later, larger total usually adds a tip or
      // surcharge to an earlier one (restaurant slips).
      candidates.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byValue = b.value.compareTo(a.value);
        return byValue != 0 ? byValue : b.row.compareTo(a.row);
      });
      var best = candidates.first;
      final tip = taxes.tip?.value;
      if (tip != null) {
        for (final c in candidates) {
          final withTip = candidates.any(
            (o) => o.row < c.row && o.value + tip == c.value,
          );
          if (withTip && c.score >= best.score - 0.25) {
            best = c;
            best.reasons.add('plus-tip');
            break;
          }
        }
      }
      context.note(
        'total: ${best.value} from row ${best.row} (${best.reasons.join('+')})',
      );
      return ParsedField(
        best.value,
        confidence: best.score.clamp(0.0, 1.0),
        rowIndex: best.row,
        reason: best.reasons.join('+'),
      );
    }

    return _fallback(context, paymentAmounts);
  }

  /// The largest positive line amount outside excluded rows.
  ParsedField<int>? _fallback(ParseContext context, Set<int> paymentAmounts) {
    AmountToken? best;
    int? bestRow;
    for (final line in context.lines) {
      if (_isNegative(line, context)) continue;
      if (classifyTaxRow(line, context) != TaxRowKind.none) continue;
      for (final a in line.lineAmounts) {
        if (a.minor > 0 && (best == null || a.minor > best.minor)) {
          best = a;
          bestRow = line.index;
        }
      }
    }
    if (best == null) {
      context.note('total: none found');
      return null;
    }
    final paid = paymentAmounts.contains(best.minor);
    context.note('total: fallback ${best.raw} from row $bestRow');
    return ParsedField(
      best.minor,
      confidence: paid ? 0.5 : 0.3,
      rowIndex: bestRow,
      reason: paid ? 'largest+paid' : 'largest',
    );
  }

  bool _isNegative(ReceiptLine line, ParseContext context) {
    final v = context.vocabulary;
    if (v.subtotal.hasMatch(line.folded)) return true;
    if (v.tip.hasMatch(line.folded)) return false;
    return v.totalNegative.hasMatch(line.folded);
  }

  /// Amounts on card-payment rows (`VISA 45.60`, `EC-Karte 23,45`).
  Set<int> _paymentAmounts(ParseContext context) => {
    for (final line in context.lines)
      if (context.vocabulary.card.hasMatch(line.folded) &&
          !context.vocabulary.paymentNoise.hasMatch(line.folded))
        for (final a in line.lineAmounts)
          if (a.minor > 0) a.minor,
  };

  /// Totals that would be consistent with the subtotal, tax and tip.
  Set<int> _expectedTotals(TaxResult taxes) {
    final subtotal = taxes.subtotal?.value;
    if (subtotal == null) return const {};
    final tax = taxes.tax?.value ?? 0;
    final tip = taxes.tip?.value ?? 0;
    return {
      for (final delta in [-1, 0, 1]) ...[
        subtotal + tax + tip + delta,
        subtotal + tip + delta,
      ],
    };
  }

  static AmountToken? _amountOnNextRow(ReceiptLine line, ParseContext context) {
    final next = line.index + 1;
    if (next >= context.lines.length) return null;
    final row = context.lines[next];
    if (row.hasLetters) return null;
    return row.lastAmount;
  }
}

final class _Candidate {
  _Candidate(this.value, this.score, this.row, this.reasons);

  final int value;
  final double score;
  final int row;
  final List<String> reasons;
}
