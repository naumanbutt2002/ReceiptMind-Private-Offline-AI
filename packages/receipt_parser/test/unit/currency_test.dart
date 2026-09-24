import 'package:receipt_parser/receipt_parser.dart';
import 'package:test/test.dart';

void main() {
  test('known currencies carry ISO minor digits', () {
    expect(Currencies.of('USD').minorDigits, 2);
    expect(Currencies.of('JPY').minorDigits, 0);
    expect(Currencies.of('KWD').minorDigits, 3);
    expect(Currencies.of('EUR').symbol, '€');
  });

  test('codes are unique, sorted and well-formed', () {
    final codes = Currencies.all.map((c) => c.code).toList();
    expect(codes.toSet(), hasLength(codes.length));
    expect(codes, orderedEquals([...codes]..sort()));
    expect(codes.every(Currencies.isWellFormed), isTrue);
  });

  test('unknown but well-formed codes default to 2 digits', () {
    final xyz = Currencies.of('XYZ');
    expect(xyz.minorDigits, 2);
    expect(xyz.symbol, 'XYZ');
    expect(Currencies.isKnown('XYZ'), isFalse);
  });

  test('malformed codes throw', () {
    expect(() => Currencies.of('usd'), throwsArgumentError);
    expect(() => Currencies.of('US'), throwsArgumentError);
  });
}
