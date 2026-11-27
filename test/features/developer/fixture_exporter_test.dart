import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_mind/core/db/tables/enums.dart';
import 'package:receipt_mind/features/developer/application/fixture_exporter.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_parser/fixtures.dart';
import 'package:receipt_parser/receipt_parser.dart' hide PaymentMethod;

import 'dev_test_helpers.dart';

class FakeSharer implements FixtureSharer {
  final calls = <(List<String>, String?)>[];

  @override
  Future<void> shareFiles(List<String> paths, {String? subject}) async {
    calls.add((paths, subject));
  }
}

ReceiptDraft draft({
  String currency = 'AUD',
  String merchant = 'Shell',
  LocalDate? date,
  int? total,
  int? subtotal,
  int? tax,
  int? tip,
  PaymentMethod? payment,
}) => ReceiptDraft(
  currency: currency,
  extractionMethod: ExtractionMethod.rules,
  merchant: merchant,
  date: date,
  totalMinor: total,
  subtotalMinor: subtotal,
  taxMinor: tax,
  tipMinor: tip,
  paymentMethod: payment,
);

void main() {
  late Directory temp;
  late FakeSharer sharer;
  late FixtureExporter exporter;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('fixture_export_test');
    sharer = FakeSharer();
    exporter = FixtureExporter(tempDirectory: () async => temp, sharer: sharer);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  group('expectedFixtureJson', () {
    test('has the exact fixture shape with every field set', () {
      final json = expectedFixtureJson(
        draft(
          merchant: '  Woolworths Metro ',
          date: LocalDate(2026, 9, 12),
          total: 4560,
          subtotal: 4145,
          tax: 415,
          tip: 0,
          payment: PaymentMethod.card,
        ),
        auOptions,
      );
      expect(json, {
        'options': {
          'defaultCurrency': 'AUD',
          'dateOrder': 'dmy',
          'today': '2026-09-24',
        },
        'expected': {
          'merchant': 'Woolworths Metro',
          'date': '2026-09-12',
          'total': '45.60',
          'subtotal': '41.45',
          'tax': '4.15',
          'tip': '0.00',
          'currency': 'AUD',
          'paymentMethod': 'card',
        },
        'xfail': <String>[],
        'source': 'real',
        'notes': '',
      });
      // Keys in fixture order.
      expect((json['expected']! as Map).keys, [
        'merchant',
        'date',
        'total',
        'subtotal',
        'tax',
        'tip',
        'currency',
        'paymentMethod',
      ]);
    });

    test('leaves out fields without a value and PaymentMethod.other', () {
      final json = expectedFixtureJson(
        draft(merchant: ' ', total: 999, payment: PaymentMethod.other),
        auOptions,
      );
      expect(json['expected'], {'total': '9.99', 'currency': 'AUD'});
    });

    test('cash is kept', () {
      final json = expectedFixtureJson(
        draft(total: 100, payment: PaymentMethod.cash),
        auOptions,
      );
      expect((json['expected']! as Map)['paymentMethod'], 'cash');
    });

    test('uses the currency minor digits (JPY 0, KWD 3)', () {
      expect(
        expectedFixtureJson(
          draft(currency: 'JPY', total: 1500, tax: 136),
          auOptions,
        )['expected'],
        containsPair('total', '1500'),
      );
      final kwd =
          expectedFixtureJson(
                draft(currency: 'KWD', total: 12345, tax: 5),
                auOptions,
              )['expected']!
              as Map;
      expect(kwd['total'], '12.345');
      expect(kwd['tax'], '0.005');
      expect(kwd['currency'], 'KWD');
    });
  });

  group('names', () {
    test('default name from country, merchant and date', () {
      expect(
        defaultFixtureName(
          merchant: 'Woolworths Metro',
          date: LocalDate(2026, 9, 12),
          countryCode: 'au',
        ),
        'au_woolworths_metro_20260912',
      );
      expect(defaultFixtureName(merchant: 'Café Müller'), 'cafe_mueller');
      expect(defaultFixtureName(merchant: ''), 'receipt');
      expect(
        defaultFixtureName(
          merchant: 'A very long store name that keeps going on',
        ),
        'a_very_long_store_name_t',
      );
    });

    test('sanitizes user input', () {
      expect(sanitizeFixtureName(' DE Café 02 '), 'de_cafe_02');
      expect(sanitizeFixtureName('../../etc/passwd'), 'etc_passwd');
      expect(sanitizeFixtureName('***'), 'receipt');
    });
  });

  test('writes the three files and shares them', () async {
    final document = layoutFixture('au/au_fuel_01');
    final files = await exporter.export(
      document: document,
      corrected: draft(total: 8649, date: LocalDate(2026, 7, 21)),
      options: auOptions,
      name: 'AU Fuel 01',
      subject: 'subject',
    );

    final dir = p.join(temp.path, FixtureExporter.folderName);
    expect(files.name, 'au_fuel_01');
    expect(files.ocrJson.path, p.join(dir, 'au_fuel_01.ocr.json'));
    expect(files.text.path, p.join(dir, 'au_fuel_01.txt'));
    expect(files.expectedJson.path, p.join(dir, 'au_fuel_01.expected.json'));
    expect(sharer.calls, hasLength(1));
    expect(sharer.calls.single.$1, [
      files.ocrJson.path,
      files.text.path,
      files.expectedJson.path,
    ]);
    expect(sharer.calls.single.$2, 'subject');

    const encoder = JsonEncoder.withIndent('  ');
    expect(
      files.ocrJson.readAsStringSync(),
      '${encoder.convert(document.toJson())}\n',
    );
    expect(files.text.readAsStringSync(), '${document.text}\n');
    expect(files.expectedJson.readAsStringSync(), '''
{
  "options": {
    "defaultCurrency": "AUD",
    "dateOrder": "dmy",
    "today": "2026-09-24"
  },
  "expected": {
    "merchant": "Shell",
    "date": "2026-07-21",
    "total": "86.49",
    "currency": "AUD"
  },
  "xfail": [],
  "source": "real",
  "notes": ""
}
''');
  });

  test('a new export replaces the previous one', () async {
    final document = OcrDocument.fromPlainText('SHOP\nTOTAL 1.00');
    await exporter.write(
      document: document,
      corrected: draft(total: 100),
      options: auOptions,
      name: 'first',
    );
    await exporter.write(
      document: document,
      corrected: draft(total: 100),
      options: auOptions,
      name: 'second',
    );
    final names = Directory(
      p.join(temp.path, FixtureExporter.folderName),
    ).listSync().map((e) => p.basename(e.path)).toList()..sort();
    expect(names, ['second.expected.json', 'second.ocr.json', 'second.txt']);
  });

  test('round trip: the export loads in the fixture harness and the parser '
      'scores it', () async {
    final document = layoutFixture('au/au_fuel_01');
    final files = await exporter.write(
      document: document,
      corrected: draft(
        date: LocalDate(2026, 7, 21),
        total: 8649,
        tax: 786,
        payment: PaymentMethod.card,
      ),
      options: auOptions,
      name: 'au_fuel_01',
    );

    final fixture = Fixture.load(files.expectedJson);
    expect(fixture.id, 'au_fuel_01');
    expect(fixture.inputPath, files.ocrJson.path);
    expect(fixture.source, 'real');
    expect(fixture.xfail, isEmpty);
    expect(fixture.expected, {
      'merchant': 'Shell',
      'date': '2026-07-21',
      'total': '86.49',
      'tax': '7.86',
      'currency': 'AUD',
      'paymentMethod': 'card',
    });
    expect(fixture.document.toJson(), document.toJson());

    final receipt = const RuleReceiptParser().parse(
      fixture.document,
      fixture.options,
    );
    final outcomes = fixture.evaluate(receipt);
    expect(
      [for (final o in outcomes) o.field],
      ['merchant', 'date', 'total', 'tax', 'currency', 'paymentMethod'],
    );
    for (final o in outcomes) {
      expect(o.passed, isTrue, reason: '${o.field}: ${o.actual}');
    }

    // The plain-text file alone also loads.
    files.ocrJson.deleteSync();
    final fromText = Fixture.load(files.expectedJson);
    expect(fromText.inputPath, files.text.path);
    expect(fromText.document.text, document.text);
  });

  test('a corrected value the parser misses is scored as a failure', () async {
    final document = layoutFixture('au/au_fuel_01');
    final files = await exporter.write(
      document: document,
      corrected: draft(total: 1),
      options: auOptions,
      name: 'wrong_total',
    );
    final fixture = Fixture.load(files.expectedJson);
    final outcomes = fixture.evaluate(
      const RuleReceiptParser().parse(fixture.document, fixture.options),
    );
    final total = outcomes.firstWhere((o) => o.field == 'total');
    expect(total.passed, isFalse);
    expect(total.expected, '0.01');
  });
}
