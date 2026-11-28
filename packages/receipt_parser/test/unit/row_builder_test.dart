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

  group('tilted photo', () {
    // A receipt turned by -1.5° (text rising to the right, as ML Kit reports
    // it): a price 600 px to the right of its label sits ~16 px higher.
    OcrLine tilted(String text, double left, double top, double width) =>
        OcrLine(
          text,
          box: BoxRect(left, top, left + width, top + 26 + width * 0.026),
          angle: -1.5,
        );

    final doc = OcrDocument(
      lines: [
        tilted('Subtotal', 300, 783, 130),
        tilted('Sales Tax 8.875%', 300, 814, 270),
        tilted('Total', 300, 857, 80),
        tilted('107.00', 870, 767, 100),
        tilted('9.50', 900, 801, 60),
        tilted('116.50', 870, 841, 100),
      ],
    );

    test('prices join their labels after de-skewing', () {
      expect(builder.build(doc).map((r) => r.text), [
        'Subtotal  107.00',
        'Sales Tax 8.875%  9.50',
        'Total  116.50',
      ]);
      expect(RowBuilder.skewDegrees(doc.lines), -1.5);
    });

    test('the slant is taken out of the row height', () {
      final long = OcrDocument(
        lines: [
          tilted('Manchester Piccadilly Station', 100, 100, 450),
          tilted('Unit 4', 100, 200, 100),
          tilted('M60 7RA', 100, 300, 120),
        ],
      );
      // 26 px of text plus 450 · 0.026 = 11.7 px of slant.
      expect(builder.build(long).first.height, closeTo(26, 0.5));
    });

    test('without line angles, the word baselines give the skew', () {
      OcrLine words(String a, String b, double top) => OcrLine(
        '$a $b',
        box: BoxRect(100, top - 16, 900, top + 30),
        words: [
          OcrWord(a, box: BoxRect(100, top, 200, top + 30)),
          OcrWord(b, box: BoxRect(800, top - 16, 900, top + 14)),
        ],
      );
      final lines = [
        words('A', 'B', 100),
        words('C', 'D', 200),
        words('E', 'F', 300),
      ];
      expect(RowBuilder.skewDegrees(lines), closeTo(-1.31, 0.01));
    });

    test('a level or steeply rotated document is left as it is', () {
      OcrLine at(double angle) =>
          OcrLine('x', box: const BoxRect(0, 0, 10, 10), angle: angle);
      expect(RowBuilder.skewDegrees([at(0.1), at(-0.1), at(0.1)]), 0);
      expect(RowBuilder.skewDegrees([at(30), at(31), at(29)]), 0);
      expect(RowBuilder.skewDegrees([at(1), at(1)]), 0); // too few lines
    });
  });
}
