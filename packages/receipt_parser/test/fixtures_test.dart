// Runs the parser on every fixture in test/fixtures/receipts and checks each
// expected field. Fields listed in a fixture's `xfail` are skipped (known
// failures); tool/parser_report.dart still counts them.
@TestOn('vm')
library;

import 'dart:io';

import 'package:receipt_parser/fixtures.dart';
import 'package:receipt_parser/receipt_parser.dart';
import 'package:test/test.dart';

void main() {
  final fixtures = Fixture.loadAll(Directory('test/fixtures/receipts'));

  test('the fixture set covers AU, US, UK and DE', () {
    expect(
      fixtures.map((f) => f.country).toSet(),
      containsAll(['au', 'us', 'uk', 'de']),
    );
    expect(fixtures.length, greaterThanOrEqualTo(20));
  });

  for (final fixture in fixtures) {
    group('${fixture.country}/${fixture.id}', () {
      final receipt = const RuleReceiptParser().parse(
        fixture.document,
        fixture.options,
      );
      for (final outcome in fixture.evaluate(receipt)) {
        test(
          outcome.field,
          () => expect(
            outcome.passed,
            isTrue,
            reason:
                'expected ${outcome.expected}, got ${outcome.actual}\n'
                '${receipt.trace.join('\n')}',
          ),
          skip: outcome.xfail ? 'xfail' : false,
        );
      }
    });
  }
}
