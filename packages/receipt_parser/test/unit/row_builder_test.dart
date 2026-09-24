import 'package:receipt_parser/receipt_parser.dart';
import 'package:receipt_parser/src/layout/row_builder.dart';
import 'package:test/test.dart';

OcrLine line(String text, double left, double top, {double height = 40}) =>
    OcrLine(text, box: BoxRect(left, top, left + 200, top + height));

void main() {
  const builder = RowBuilder();

  test('plain text: one row per line', () {
    final rows = builder.build(OcrDocument.fromPlainText('A\nB  1.00'));
    expect(rows.map((r) => r.text), ['A', 'B  1.00']);
    expect(rows.map((r) => r.index), [0, 1]);
    expect(rows.first.height, isNull);
  });

  test('column-ordered lines are regrouped into rows, left to right', () {
    final doc = OcrDocument(
      lines: [
        line('SHOP', 400, 0, height: 80),
        line('Milk', 50, 100),
        line('Bread', 50, 160),
        line('TOTAL', 50, 220),
        line('2.00', 800, 100),
        line('3.50', 800, 160),
        line('5.50', 800, 220),
      ],
    );
    final rows = builder.build(doc);
    expect(rows.map((r) => r.text), [
      'SHOP',
      'Milk  2.00',
      'Bread  3.50',
      'TOTAL  5.50',
    ]);
    expect(rows.first.height, 80);
  });

  test('slightly skewed prices still join their row', () {
    final doc = OcrDocument(
      lines: [
        line('Milk', 50, 100),
        line('Bread', 50, 160),
        line('2.00', 800, 108),
        line('3.50', 800, 169),
      ],
    );
    expect(builder.build(doc).map((r) => r.text), [
      'Milk  2.00',
      'Bread  3.50',
    ]);
  });

  test('rows that only touch are kept apart', () {
    final doc = OcrDocument(lines: [line('A', 50, 100), line('B', 800, 125)]);
    expect(builder.build(doc).map((r) => r.text), ['A', 'B']);
  });

  test(
    'a document where some lines lack boxes falls back to reading order',
    () {
      final doc = OcrDocument(lines: [line('B', 50, 200), const OcrLine('A')]);
      expect(builder.build(doc).map((r) => r.text), ['B', 'A']);
    },
  );
}
