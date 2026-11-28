import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/features/developer/application/row_layout.dart';
import 'package:receipt_parser/receipt_parser.dart';

import 'dev_test_helpers.dart';

void main() {
  test('rows match the parser rows on every layout fixture', () {
    final files = layoutFixtureFiles();
    expect(files, isNotEmpty);
    for (final file in files) {
      final document = OcrDocument.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
      );
      final parsed = const RuleReceiptParser().parse(document, auOptions);
      final layout = buildRowLayout(document);
      expect(
        [for (final r in layout) '${r.index}: ${r.text}'],
        [for (final r in parsed.rows) '${r.index}: ${r.text}'],
        reason: file.path,
      );
    }
  });

  // QA M7 (B-2): the debug screen grouped rows without the parser's de-skew,
  // so on a tilted photo it numbered 50 rows where the parser had 44 and
  // tagged "total" on the CUSTOMER COPY line.
  test('rows match the parser rows on real, tilted photo dumps', () {
    final files =
        Directory('packages/receipt_parser/test/data/photo_ocr')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.ocr.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(6));
    for (final file in files) {
      final document = OcrDocument.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
      );
      final parsed = const RuleReceiptParser().parse(document, auOptions);
      final layout = buildRowLayout(document);
      expect(
        [for (final r in layout) '${r.index}: ${r.text}'],
        [for (final r in parsed.rows) '${r.index}: ${r.text}'],
        reason: file.path,
      );
    }
  });

  test('joins lines of one printed row and boxes their union', () {
    const document = OcrDocument(
      lines: [
        OcrLine('4.50', box: BoxRect(300, 102, 360, 122)),
        OcrLine('MILK 2L', box: BoxRect(20, 100, 140, 120)),
        OcrLine('TOTAL', box: BoxRect(20, 150, 120, 180)),
        OcrLine('9.00', box: BoxRect(300, 152, 360, 182)),
      ],
      imageWidth: 400,
      imageHeight: 300,
    );
    final rows = buildRowLayout(document);
    expect(rows, hasLength(2));
    expect(rows[0].index, 0);
    expect(rows[0].text, 'MILK 2L  4.50');
    expect(rows[0].box, const BoxRect(20, 100, 360, 122));
    expect([for (final l in rows[0].lines) l.text], ['MILK 2L', '4.50']);
    expect(rows[1].text, 'TOTAL  9.00');
    expect(rows[1].box, const BoxRect(20, 150, 360, 182));
  });

  test('a document without boxes has no row layout', () {
    final document = OcrDocument.fromPlainText('SHOP\nTOTAL 9.00');
    expect(buildRowLayout(document), isEmpty);
  });
}
