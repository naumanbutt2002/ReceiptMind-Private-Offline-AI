import 'package:receipt_parser/src/text/text_normalizer.dart';
import 'package:test/test.dart';

void main() {
  const normalizer = TextNormalizer();
  String n(String s) => normalizer.normalize(s);

  group('normalize', () {
    final cases = {
      'TOTAL  12. 50': 'TOTAL  12.50',
      'Summe 6 ,50': 'Summe 6,50',
      'Milk  1O.5O': 'Milk  10.50',
      'Bread  1S.99': 'Bread  15.99',
      'Apples  O.99': 'Apples  0.99',
      'Eggs  l2.50': 'Eggs  12.50',
      'TOTAL  S12.50': r'TOTAL  $12.50',
      'Coffee | 4.50 |': 'Coffee  4.50',
      '|12.50': '12.50',
      'Discount  −3.00': 'Discount  -3.00',
      'Tea  3.20': 'Tea  3.20',
      'Total\t９.５０': 'Total  9.50',
      'SOLD OUT': 'SOLD OUT',
      'Qty 2 x 3.50': 'Qty 2 x 3.50',
      'Ref 1O2': 'Ref 1O2', // no separator: not an amount, left alone
    };
    cases.forEach((input, expected) {
      test('"$input"', () => expect(n(input), expected));
    });
  });

  group('foldForKeywords', () {
    final cases = {
      'T0TAL': 'total',
      'SUBT0TAL': 'subtotal',
      'Rückgeld': 'ruckgeld',
      'Straße 5': 'strasse 5',
      'EC-Karte': 'ec karte',
      'Total (inc. GST):': 'total inc gst',
      'Café Crème': 'cafe creme',
      'A5 paper': 'a5 paper', // one letter: left alone
      r'$12.50': r'$12 50',
    };
    cases.forEach((input, expected) {
      test('"$input"', () => expect(foldForKeywords(input), expected));
    });
  });

  test('foldAccents keeps punctuation and digits', () {
    expect(foldAccents('03. März 2026'), '03. marz 2026');
  });
}
