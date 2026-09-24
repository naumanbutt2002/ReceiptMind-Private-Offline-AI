// Drafts a fixture's .expected.json from what the parser reads today.
//
//   dart run tool/new_fixture.dart test/fixtures/receipts/fr/fr_bakery_01.txt \
//       --currency EUR --date-order dmy [--today 2026-09-24] [--source real]
//
// Open the written file, correct every value the parser got wrong, and move
// fields you can't fix yet into "xfail". Run from packages/receipt_parser.
import 'dart:convert';
import 'dart:io';

import 'package:receipt_parser/fixtures.dart';
import 'package:receipt_parser/receipt_parser.dart';

const usage = '''
Usage: dart run tool/new_fixture.dart <receipt.txt|receipt.ocr.json>
         --currency <ISO code> --date-order <dmy|mdy|ymd>
         [--today YYYY-MM-DD] [--source synthetic|real] [--force]''';

void main(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final input = args.where((a) => !a.startsWith('--')).firstOrNull;
  final currency = option('currency');
  final dateOrder = option('date-order');
  if (input == null || currency == null || dateOrder == null) {
    stderr.writeln(usage);
    exit(64);
  }
  final isLayout = input.endsWith('.ocr.json');
  if (!isLayout && !input.endsWith('.txt')) {
    stderr.writeln('The receipt must be a .txt or .ocr.json file.\n$usage');
    exit(64);
  }
  final file = File(input);
  if (!file.existsSync()) {
    stderr.writeln('Not found: $input');
    exit(66);
  }

  final options = parseOptionsFromJson({
    'defaultCurrency': currency.toUpperCase(),
    'dateOrder': dateOrder,
    'today': option('today') ?? LocalDate.fromDateTime(DateTime.now()).toIso(),
  });
  final document = isLayout
      ? OcrDocument.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
        )
      : OcrDocument.fromPlainText(file.readAsStringSync());
  final receipt = const RuleReceiptParser().parse(document, options);

  final base = input.substring(
    0,
    input.length - (isLayout ? '.ocr.json'.length : '.txt'.length),
  );
  final out = File('$base.expected.json');
  if (out.existsSync() && !args.contains('--force')) {
    stderr.writeln('${out.path} exists; pass --force to overwrite it.');
    exit(73);
  }
  final json = {
    'options': parseOptionsToJson(options),
    'expected': {
      for (final field in fixtureFields) field: ?fieldText(receipt, field),
    },
    'xfail': <String>[],
    'source': option('source') ?? 'synthetic',
    'notes': '',
  };
  out.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(json)}\n',
  );

  stdout
    ..writeln('Wrote ${out.path}. The parser read:')
    ..writeln(const JsonEncoder.withIndent('  ').convert(json['expected']))
    ..writeln()
    ..writeln('Trace:')
    ..writeAll(receipt.trace.map((t) => '  $t'), '\n')
    ..writeln()
    ..writeln()
    ..writeln('Now check every value against the receipt and fix it by hand.');
}
