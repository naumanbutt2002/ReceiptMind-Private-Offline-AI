import '../amount/amount_scanner.dart';
import '../model/parsed_receipt.dart';
import 'parse_context.dart';

/// Subtotal, tax and tip, found before the total so the total can be checked
/// against them.
final class TaxResult {
  const TaxResult({
    this.subtotal,
    this.tax,
    this.tip,
    this.taxIncluded = false,
  });

  final ParsedField<int>? subtotal;
  final ParsedField<int>? tax;
  final ParsedField<int>? tip;

  /// The receipt states that its prices include the tax.
  final bool taxIncluded;
}

/// How a row that mentions tax should be read.
enum TaxRowKind {
  /// Not about tax.
  none,

  /// A tax amount: `GST 4.15`, `SALES TAX 8.875% 3.55`.
  tax,

  /// A statement that the total includes tax: `Total includes GST 4.15`.
  includedStatement,

  /// A total that includes tax: `TOTAL INC GST 45.60`. Not a tax amount.
  totalIncludingTax,
}

TaxRowKind classifyTaxRow(ReceiptLine line, ParseContext context) {
  final v = context.vocabulary;
  if (!v.tax.hasMatch(line.folded)) return TaxRowKind.none;
  if (v.taxIncludedStatement.hasMatch(line.folded)) {
    return TaxRowKind.includedStatement;
  }
  if (v.totalStrong.hasMatch(line.folded) &&
      v.taxIncludedTotal.hasMatch(line.folded)) {
    return TaxRowKind.totalIncludingTax;
  }
  return TaxRowKind.tax;
}

/// Finds the subtotal, the tax (single lines, several lines, or a tax summary
/// table) and the tip.
final class TaxExtractor {
  const TaxExtractor();

  TaxResult extract(ParseContext context) {
    final subtotal = _subtotal(context);
    final (tax, included) = _tax(context);
    final tip = _tip(context);
    return TaxResult(
      subtotal: subtotal,
      tax: tax,
      tip: tip,
      taxIncluded: included,
    );
  }

  ParsedField<int>? _subtotal(ParseContext context) {
    for (final line in context.lines) {
      if (!context.vocabulary.subtotal.hasMatch(line.folded)) continue;
      final amount = line.lastAmount ?? _amountOnNextRow(line, context);
      if (amount == null || amount.minor <= 0) continue;
      context.note('subtotal: ${amount.raw} from row ${line.index}');
      return ParsedField(
        amount.minor,
        confidence: 0.85,
        rowIndex: line.index,
        reason: 'keyword:subtotal',
      );
    }
    return null;
  }

  ParsedField<int>? _tip(ParseContext context) {
    final v = context.vocabulary;
    for (final line in context.lines.reversed) {
      if (!v.tip.hasMatch(line.folded)) continue;
      if (v.tipSuggestion.hasMatch(line.folded)) continue;
      // `PG TIPS 3.00` in the item list is tea, not a tip.
      if (!context.isAfterItems(line)) continue;
      final amount = line.lastAmount;
      if (amount == null || amount.minor <= 0) continue;
      context.note('tip: ${amount.raw} from row ${line.index}');
      return ParsedField(
        amount.minor,
        confidence: 0.8,
        rowIndex: line.index,
        reason: 'keyword:tip',
      );
    }
    return null;
  }

  (ParsedField<int>?, bool) _tax(ParseContext context) {
    final table = _taxTable(context);
    final statements = <ReceiptLine>[];
    final taxLines = <ReceiptLine>[];
    for (final line in context.lines) {
      final kind = classifyTaxRow(line, context);
      final amount = line.lastAmount;
      if (amount == null || amount.minor < 0) continue;
      switch (kind) {
        case TaxRowKind.includedStatement:
          statements.add(line);
        case TaxRowKind.tax:
          if (table != null && table.rows.contains(line.index)) continue;
          taxLines.add(line);
        case TaxRowKind.none || TaxRowKind.totalIncludingTax:
          break;
      }
    }

    final included = statements.isNotEmpty;
    if (table != null) {
      context.note('tax: ${table.tax} from table rows ${table.rows}');
      return (
        ParsedField(
          table.tax,
          confidence: 0.8,
          rowIndex: table.rows.first,
          reason: 'table',
        ),
        true,
      );
    }
    if (statements.isNotEmpty) {
      final line = statements.first;
      context.note('tax: included, ${line.lastAmount!.raw} row ${line.index}');
      return (
        ParsedField(
          line.lastAmount!.minor,
          confidence: 0.85,
          rowIndex: line.index,
          reason: 'keyword:included',
        ),
        true,
      );
    }
    if (taxLines.isEmpty) return (null, included);

    final values = [for (final l in taxLines) l.lastAmount!.minor];
    final distinct = values.toSet();
    int value;
    String reason;
    if (distinct.length == 1) {
      value = values.first;
      reason = 'keyword:tax';
    } else {
      // A "total tax" line equal to the sum of the others wins; otherwise the
      // lines are separate taxes (state + city, several rates) and add up.
      final sum = distinct.fold(0, (a, b) => a + b);
      final total = distinct.where((v) => v * 2 == sum).firstOrNull;
      value = total ?? sum;
      reason = total != null ? 'keyword:tax-total' : 'keyword:tax-sum';
    }
    context.note('tax: $value from rows ${taxLines.map((l) => l.index)}');
    return (
      ParsedField(
        value,
        confidence: distinct.length == 1 ? 0.8 : 0.65,
        rowIndex: taxLines.first.index,
        reason: reason,
      ),
      included,
    );
  }

  /// A VAT/MwSt summary table: a header naming net/gross/tax columns, then
  /// rows with several amounts. For each row the tax is the smaller addend of
  /// `net + tax = gross`, or else the column the header calls tax (or
  /// gross − net). A table total row, if any, wins.
  _TaxTable? _taxTable(ParseContext context) {
    final v = context.vocabulary;
    final lines = context.lines;
    for (var i = 0; i < lines.length; i++) {
      final header = lines[i];
      if (header.lineAmounts.isNotEmpty) continue;
      final roles = _headerRoles(header.folded, context);
      final named = roles.toSet();
      if (!named.contains(_Column.tax) || named.length < 2) continue;

      final rows = <int>[i];
      var sum = 0;
      int? totalRowTax;
      for (var j = i + 1; j < lines.length && j <= i + 6; j++) {
        final row = lines[j];
        final amounts = [for (final a in row.lineAmounts) a.minor];
        if (amounts.length < 2) break;
        final tax = _taxFromRow(amounts) ?? _taxByHeader(amounts, roles);
        if (tax == null) break;
        rows.add(j);
        if (v.totalStrong.hasMatch(row.folded) ||
            v.subtotal.hasMatch(row.folded)) {
          totalRowTax = tax;
          break;
        }
        sum += tax;
      }
      if (rows.length < 2) continue;
      return _TaxTable(totalRowTax ?? sum, rows);
    }
    return null;
  }

  static int? _taxFromRow(List<int> amounts) {
    for (var a = 0; a < amounts.length; a++) {
      for (var b = 0; b < amounts.length; b++) {
        for (var c = 0; c < amounts.length; c++) {
          if (a == b || b == c || a == c) continue;
          final x = amounts[a];
          final y = amounts[b];
          if (x >= y && (x + y - amounts[c]).abs() <= 1) return y;
        }
      }
    }
    return null;
  }

  /// The amount columns a table header names, left to right.
  static List<_Column> _headerRoles(String folded, ParseContext context) {
    final v = context.vocabulary;
    return [
      for (final word in folded.split(' '))
        if (v.tax.hasMatch(word))
          _Column.tax
        else if (v.tableNet.hasMatch(word))
          _Column.net
        else if (v.tableGross.hasMatch(word))
          _Column.gross,
    ];
  }

  /// Reads a row's tax from the header when the row has fewer amounts than
  /// the header has columns: the amounts fill the right-most columns (the
  /// left-most tax word is usually the tax-code column, `VAT A`).
  static int? _taxByHeader(List<int> amounts, List<_Column> roles) {
    if (roles.length < amounts.length) return null;
    final columns = roles.sublist(roles.length - amounts.length);
    final taxAt = columns.lastIndexOf(_Column.tax);
    if (taxAt >= 0) return amounts[taxAt];
    final net = columns.indexOf(_Column.net);
    final gross = columns.indexOf(_Column.gross);
    if (net >= 0 && gross >= 0 && amounts[gross] >= amounts[net]) {
      return amounts[gross] - amounts[net];
    }
    return null;
  }

  static AmountToken? _amountOnNextRow(ReceiptLine line, ParseContext context) {
    final next = line.index + 1;
    if (next >= context.lines.length) return null;
    final row = context.lines[next];
    if (row.hasLetters) return null;
    return row.lastAmount;
  }
}

final class _TaxTable {
  const _TaxTable(this.tax, this.rows);

  final int tax;
  final List<int> rows;
}

enum _Column { net, tax, gross }
