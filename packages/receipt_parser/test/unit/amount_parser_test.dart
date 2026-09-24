import 'package:receipt_parser/receipt_parser.dart';
import 'package:test/test.dart';

void main() {
  int? usd(String s) => parseMinorUnits(s, minorDigits: 2);

  group('two-decimal currencies', () {
    final cases = <String, int?>{
      '12.50': 1250,
      '12,50': 1250,
      '12.5': 1250,
      '12': 1200,
      '0.99': 99,
      '1,234.56': 123456,
      '1.234,56': 123456,
      '1 234,56': 123456,
      '1 234,56': 123456,
      "1'234.50": 123450,
      '1,234': 123400,
      '1.234': 123400,
      '1,234,567': 123456700,
      '1.234.567,89': 123456789,
      r'$12.50': 1250,
      r'A$ 45.60': 4560,
      '12,50 €': 1250,
      'EUR 12,50': 1250,
      '-3.20': -320,
      '3.20-': -320,
      '(3.20)': -320,
      '+7.00': 700,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () => expect(usd(input), expected));
    });
  });

  group('rejects malformed amounts', () {
    for (final input in [
      '',
      '   ',
      'abc',
      '12.',
      '.50',
      '12.345.6',
      '1,23.45',
      '12.3456',
      '1.2.3,4,5',
      '12:30',
    ]) {
      test('"$input" → null', () => expect(usd(input), isNull));
    }
  });

  group('zero-decimal currencies (JPY)', () {
    int? jpy(String s) => parseMinorUnits(s, minorDigits: 0);

    test('plain', () => expect(jpy('1500'), 1500));
    test('grouped', () => expect(jpy('1,500'), 1500));
    test('trailing zero decimals', () => expect(jpy('1500.00'), 1500));
    test('real decimals are rejected', () => expect(jpy('1500.50'), isNull));
  });

  group('three-decimal currencies (KWD)', () {
    int? kwd(String s, [String? hint]) =>
        parseMinorUnits(s, minorDigits: 3, decimalSeparatorHint: hint);

    test('three decimals', () => expect(kwd('12.345'), 12345));
    test('comma decimals', () => expect(kwd('12,345'), 12345));
    test('hint makes the other separator grouping', () {
      expect(kwd('1,234', '.'), 1234000);
    });
    test('grouped with decimals', () => expect(kwd('1,234.500'), 1234500));
  });
}
