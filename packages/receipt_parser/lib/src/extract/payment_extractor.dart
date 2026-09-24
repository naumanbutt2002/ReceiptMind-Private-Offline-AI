import '../model/parsed_receipt.dart';
import 'parse_context.dart';

/// Decides whether the receipt was paid by card or in cash.
///
/// Strong evidence is a payment word on a row with an amount, a masked card
/// number or an approval. Loyalty cards and `cash out` lines are ignored.
/// When both appear, the one whose amount matches the total wins, then card.
final class PaymentExtractor {
  const PaymentExtractor();

  ParsedField<PaymentMethod>? extract(ParseContext context, int? total) {
    final v = context.vocabulary;
    var card = 0.0;
    var cash = 0.0;
    int? cardRow;
    int? cashRow;
    var cardMatchesTotal = false;
    var cashCoversTotal = false;

    for (final line in context.lines) {
      final f = line.folded;
      if (v.paymentNoise.hasMatch(f)) continue;
      final amounts = [for (final a in line.lineAmounts) a.minor];
      if (v.card.hasMatch(f)) {
        var s = 0.4;
        if (amounts.isNotEmpty) s += 0.3;
        if (_masked.hasMatch(line.text)) s += 0.3;
        if (card < s) {
          card = s;
          cardRow = line.index;
        }
        if (total != null && amounts.contains(total)) cardMatchesTotal = true;
      } else if (_approved.hasMatch(f) || _masked.hasMatch(line.text)) {
        if (card < 0.5) {
          card = 0.5;
          cardRow = line.index;
        }
      }
      if (v.cash.hasMatch(f) && amounts.any((a) => a > 0)) {
        const s = 0.7;
        if (cash < s) {
          cash = s;
          cashRow = line.index;
        }
        if (total != null && amounts.any((a) => a >= total)) {
          cashCoversTotal = true;
        }
      }
    }

    if (card == 0 && cash == 0) {
      context.note('payment: unknown');
      return null;
    }
    final PaymentMethod method;
    if (cash > 0 && (card == 0 || (cashCoversTotal && !cardMatchesTotal))) {
      method = PaymentMethod.cash;
    } else {
      method = PaymentMethod.card;
    }
    final isCard = method == PaymentMethod.card;
    context.note('payment: ${method.name}');
    return ParsedField(
      method,
      confidence: isCard ? card.clamp(0.0, 1.0) : cash,
      rowIndex: isCard ? cardRow : cashRow,
      reason: isCard ? 'keyword:card' : 'keyword:cash',
    );
  }

  static final _masked = RegExp(
    r'(?:[*xX•]{4}[\s-]*){1,3}\d{4}|[*xX•]{6,}\d{2,4}',
  );
  static final _approved = RegExp(
    r'\b(?:approved|genehmigt|autorisiert|zahlung erfolgt)\b',
  );
}
