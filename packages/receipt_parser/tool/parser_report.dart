// Prints the parser's accuracy on the fixture set as a Markdown table.
//
//   dart run tool/parser_report.dart            # table only
//   dart run tool/parser_report.dart --verbose  # plus every failed field
//   dart run tool/parser_report.dart --check    # exit 1 below the M2 targets
//   dart run tool/parser_report.dart --only holdout  # fixtures whose id matches
//
// Run from packages/receipt_parser.
import 'dart:io';

import 'package:receipt_parser/fixtures.dart';
import 'package:receipt_parser/receipt_parser.dart';

/// The v0.1 targets (docs: total ≥ 90 %, date ≥ 90 %, merchant ≥ 75 %),
/// measured without fixtures that mark the field as `xfail`.
const targets = {'total': 0.90, 'date': 0.90, 'merchant': 0.75};

void main(List<String> args) {
  final verbose = args.contains('--verbose');
  final check = args.contains('--check');
  final only = args.contains('--only')
      ? args[args.indexOf('--only') + 1]
      : null;
  final fixtures = [
    for (final f in Fixture.loadAll(Directory('test/fixtures/receipts')))
      if (only == null || f.id.contains(only)) f,
  ];
  if (fixtures.isEmpty) {
    stderr.writeln('No fixtures found. Run this from packages/receipt_parser.');
    exit(2);
  }

  // country → field → [passed, checked]; xfail fields count as failures.
  final table = <String, Map<String, List<int>>>{};
  // field → [passed, checked] without xfail fields, for the targets.
  final strict = <String, List<int>>{};
  final failures = <String>[];

  for (final fixture in fixtures) {
    final receipt = const RuleReceiptParser().parse(
      fixture.document,
      fixture.options,
    );
    for (final o in fixture.evaluate(receipt)) {
      for (final country in [fixture.country, 'all']) {
        final cell = table
            .putIfAbsent(country, () => {})
            .putIfAbsent(o.field, () => [0, 0]);
        cell[1]++;
        if (o.passed) cell[0]++;
      }
      if (!o.xfail) {
        final cell = strict.putIfAbsent(o.field, () => [0, 0]);
        cell[1]++;
        if (o.passed) cell[0]++;
      }
      if (!o.passed) {
        failures.add(
          '- `${fixture.id}` ${o.field}: expected `${o.expected}`, '
          'got `${o.actual ?? '—'}`${o.xfail ? ' (xfail)' : ''}',
        );
      }
    }
  }

  final fields = [
    for (final f in fixtureFields)
      if (table['all']!.containsKey(f)) f,
  ];
  final countries = table.keys.where((c) => c != 'all').toList()..sort();
  final out = StringBuffer()
    ..writeln(
      '## Parser accuracy (${fixtures.length} fixtures, '
      'receipt_parser $receiptParserVersion)',
    )
    ..writeln()
    ..writeln('| Country | ${fields.join(' | ')} |')
    ..writeln('|---|${fields.map((_) => '---:').join('|')}|');
  for (final country in [...countries, 'all']) {
    final cells = [for (final f in fields) _percent(table[country]![f])];
    final label = country == 'all' ? '**all**' : country.toUpperCase();
    out.writeln('| $label | ${cells.join(' | ')} |');
  }
  out
    ..writeln()
    ..writeln('Fields marked `xfail` in a fixture count as failures above.');

  var passed = true;
  out
    ..writeln()
    ..writeln('Targets (without `xfail` fields):');
  targets.forEach((field, target) {
    final cell = strict[field] ?? [0, 0];
    final rate = cell[1] == 0 ? 1.0 : cell[0] / cell[1];
    final ok = rate >= target;
    passed &= ok;
    out.writeln(
      '- $field ${_percent(cell)} (target ${(target * 100).round()} %) '
      '${ok ? '✅' : '❌'}',
    );
  });

  if (verbose && failures.isNotEmpty) {
    out
      ..writeln()
      ..writeln('### Failed fields')
      ..writeln()
      ..writeAll(failures, '\n')
      ..writeln();
  }
  stdout.write(out);
  if (check && !passed) exit(1);
}

String _percent(List<int>? cell) {
  if (cell == null || cell[1] == 0) return '—';
  return '${(cell[0] * 100 / cell[1]).round()} %';
}
