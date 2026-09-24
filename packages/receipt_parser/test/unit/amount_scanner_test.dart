import 'package:receipt_parser/receipt_parser.dart';
import 'package:receipt_parser/src/amount/amount_scanner.dart';
import 'package:test/test.dart';

void main() {
  const scanner = AmountScanner();
  final aud = Currencies.of('AUD');
  List<int> values(String row, [Currency? c]) => [
    for (final t in scanner.scan(row, c ?? aud)) t.minor,
  ];

  group('finds amounts', () {
    final cases = <String, List<int>>{
      'Milk 2L  3.10': [310],
      r'TOTAL  $45.60': [4560],
      'Summe EUR 23,45': [2345],
      '1.234,56 A': [123456],
      'Laptop  1,234.56': [123456],
      'Bananas  1,99 B': [199],
      'Item  4.50A': [450],
      'Discount  -3.00': [-300],
      'Coupon  3.00-': [-300],
      'Savings  (3.00)': [-300],
      r'Promo  -$2.00': [-200],
      'Two things  1.00  2.00': [100, 200],
    };
    cases.forEach((row, expected) {
      test('"$row"', () => expect(values(row), expected));
    });
  });

  group('rejects non-amounts', () {
    for (final row in [
      'Date 12/09/2026 14:32',
      'Datum 12.09.2026',
      'Tel (02) 9876 5432',
      'ABN 12 345 678 901',
      'GST 10%',
      'VAT 20.00%',
      'Unleaded 42.15L',
      'Diesel 38,42 l',
      'Apples 1.5kg',
      'Card **** **** **** 4821',
      'Receipt #1234.56',
      'Qty 12',
      'Barcode 9300675024235',
      'Time 12:30',
    ]) {
      test('"$row"', () => expect(values(row), isEmpty));
    }
  });

  test('marks unit prices', () {
    final tokens = scanner.scan('2 x 3.50  7.00', aud);
    expect(
      [for (final t in tokens) (t.minor, t.isUnitPrice)],
      [(350, true), (700, false)],
    );
    expect(scanner.scan(r'@ $1.90/kg  3.80', aud).first.isUnitPrice, isTrue);
    expect(scanner.scan('2 Stk x 1,29  2,58', aud).first.isUnitPrice, isTrue);
    expect(scanner.scan('Tea 3.20 each', aud).single.isUnitPrice, isTrue);
  });

  test('records the currency marker', () {
    expect(scanner.scan(r'A$ 45.60', aud).single.currencyMarker, r'A$');
    expect(scanner.scan('EUR 12,50', aud).single.currencyMarker, 'EUR');
    expect(scanner.scan('12,50 €', aud).single.currencyMarker, '€');
    expect(scanner.scan('12.50', aud).single.currencyMarker, isNull);
  });

  test('uses the currency decimals', () {
    expect(values('Ramen 1,200', Currencies.of('JPY')), [1200]);
    expect(values('Total 1.250', Currencies.of('KWD')), [1250]);
    expect(values('Total 12.5'), isEmpty);
  });
}
